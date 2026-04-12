---
kind: concept
status: working
last_reviewed: 2026-04-12
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md
  - ../../../raw/research/0077-2026-04-11-code-pushing-result-if-sink.md
  - ../../../raw/research/0078-2026-04-11-code-pushing-result-if-reorder.md
  - ../../../raw/research/0079-2026-04-12-code-pushing-one-off-alias-tail-prefix.md
  - ../../../raw/research/0080-2026-04-12-code-pushing-crossed-condition-set-alias.md
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/ir/hot_lower_live_repro_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../scripts/pass-fuzz-compare.ts
  - ../../../../../scripts/self-optimize-compare.ts
related:
  - ./index.md
  - ./parity.md
  - ./artifact-frontiers.md
  - ./performance-and-runtime.md
---

# `code-pushing` Validation And Fuzzing

## Validation Philosophy

- This pass cannot be trusted on unit tests alone.
- It mutates lifted HOT control structure, explicit exits, and result carriers, so
  every meaningful growth step needs evidence at four layers:
  - focused pass behavior
  - HOT lowering validity
  - randomized Starshine vs Binaryen comparison
  - real debug-artifact replay

## Layer 1: Focused Pass Tests

- The primary suite is
  [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt).
- That file covers several distinct groups:
  - SFA eligibility and summary accounting
  - same-region root reordering
  - one-arm `if` sinking, including result-producing `if` arms
  - dead-gap and alias-barrier behavior
  - explicit-exit and non-void prefix boundaries
  - dropped-carrier extraction
  - narrow artifact-shaped reducers that prove a tempting explanation is already
    handled or still blocked
- The pass suite is where new rewrite rules should go red first.

## Layer 2: HOT Lowering Proofs

- The secondary proof layer is
  [`../../../../../src/ir/hot_lower_live_repro_test.mbt`](../../../../../src/ir/hot_lower_live_repro_test.mbt).
- These tests manually perform the intended HOT rewrite and then lower the result
  back to Wasm for validation.
- This layer is critical for:
  - dropped-carrier extractions
  - explicit-exit carrier rewrites
  - parent-result and branch-arity boundary investigations
- A pass reducer is not enough when the risk is "the rewrite is locally sensible
  but lowering invalidates the function."

## Layer 3: Native CLI Validation

- The native command path is covered in
  [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt).
- This layer matters because a pass can look fine through HOT verification and
  still fail on the real artifact when the surrounding pipeline, local ordering,
  or lowering details differ from the tiny repro.
- The debug artifact replay should be treated as first-class validation, not as an
  optional last-mile check.

## Layer 4: Differential Pass Fuzzing

- The dedicated harness is
  [`../../../../../scripts/pass-fuzz-compare.ts`](../../../../../scripts/pass-fuzz-compare.ts).
- The canonical direct-pass command shape is:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass code-pushing \
  --generator gen-valid \
  --count 1000 \
  --max-failures 5 \
  --out-dir .tmp/pass-fuzz-code-pushing-<label>
```

- The repo policy in [`AGENTS.md`](../../../../../AGENTS.md) is to treat
  `10000` comparisons as the preferred parity target where possible.
- This harness is good at finding:
  - local alias and dead-gap mistakes
  - missed barrier families
  - invalid lowered output on smaller generated programs
- It is not sufficient for final signoff because it does not reproduce every
  carrier shape the real debug artifact can generate.

## Current Compare-Pass Evidence

- Smoke evidence:
  - the initial one-case lane completed with `1/1` compared, `1` normalized
    match, and `0` mismatches
- Historical larger `gen-valid` evidence:
  - `pass-fuzz-code-pushing-genvalid-10000-20260408b` completed `10000/10000`
    with `0` mismatches after the dead-gap correction
- Current same-tree lanes:
  - `pass-fuzz-code-pushing-genvalid-20260410x` completed `10000/10000` with
    `0` mismatches, `0` validation failures, and `0` command failures
  - `pass-fuzz-code-pushing-genvalid-20260410ac3` completed `10000/10000` with
    `0` mismatches, `0` validation failures, `0` generator failures, and
    `0` command failures after the expression-position value-block carrier work
  - `pass-fuzz-code-pushing-genvalid-20260411e` completed `10000/10000` with
    `0` mismatches, `0` validation failures, `0` generator failures, and
    `0` command failures after the result-producing-`if` arm sink fix
  - `pass-fuzz-code-pushing-genvalid-20260411h` completed `10000/10000` with
    `0` mismatches, `0` validation failures, `0` generator failures, and
    `0` command failures after readmitting reorders past result-producing `if`
    pushpoints
  - `pass-fuzz-code-pushing-20260412a` completed `10000/10000` with `0`
    mismatches, `0` validation failures, `0` generator failures, and `0`
    command failures after narrowing the one-off alias-if-tail fence to the
    explicit-exit-carrier-fed subset
  - `pass-fuzz-code-pushing-20260412c` completed `10000/10000` with `0`
    mismatches, `0` validation failures, `0` generator failures, and `0`
    command failures after narrowing the crossed condition-set carrier alias
    guard to the real same-source aliasing case
- Mixed-generator and smith-only lanes have also stayed semantically clean on the
  kept pass surface, with remaining failures attributed to Binaryen-side parser or
  canonicalization rejects such as invalid type-index families. After the same
  result-`if` sink fix, `pass-fuzz-code-pushing-20260411f` completed
  `997/1000` compared with `0` mismatches, `0` validation failures, and only `3`
  Binaryen-side command failures. After the result-`if` pushpoint reorder fix,
  `pass-fuzz-code-pushing-20260411i` kept the same smith-only outcome:
  `997/1000` compared, `0` mismatches, `0` validation failures, and `3`
  Binaryen-side command failures. After the one-off alias-if-tail narrowing,
  `pass-fuzz-code-pushing-20260412b` kept that same smith-only outcome too:
  `997/1000` compared, `0` mismatches, `0` validation failures, and `3`
  Binaryen-side command failures. After the crossed condition-set alias-guard
  narrowing, `pass-fuzz-code-pushing-20260412d` kept that same smith-only
  outcome too: `997/1000` compared, `0` mismatches, `0` validation failures,
  and `3` Binaryen-side command failures.

## Direct Artifact Replay

- The canonical artifact compare command is:

```sh
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --code-pushing
```

- The current practical workflow is:
  - first ensure native `--code-pushing` output validates at all
  - only then trust normalized WAT and timing deltas from the compare output
- The current same-tree state is therefore:
  - reduced compare-pass parity is green on the kept safe tree
  - the current named compare-pass lanes
    `pass-fuzz-code-pushing-genvalid-20260410x` and
    `pass-fuzz-code-pushing-genvalid-20260410ac3` are both `10000/10000` with
    `0` mismatches; the latter is the same-tree signoff for the new
    expression-position value-block carrier slice
  - the reduced live-carried call-prefixed carrier is now also pinned directly
    in-tree through the repaired lowered raw shape, not only through artifact
    replay
  - the current mixed-generator lane
    `pass-fuzz-code-pushing-both-20260410s` is `998/998` with `0` mismatches,
    `0` validation failures, and only `2` Binaryen parser failures
    (`binaryen-rec-group-zero`)
  - native `--code-pushing` replay `.tmp/code-pushing-native-20260410w.wasm`
    validates again
  - the old live trace fact from `2026-04-10` is still recorded here for
    provenance: the kept tree at that point changed only `Func 148` and
    `Func 1948`, while `Func 1977` no longer reported `skip-invalid-lower`
  - the current tree now adds a stronger artifact contract on top of that:
    Binaryen `--code-pushing` is a no-op on printed `func $127`, so native
    `cmd` coverage now expects `Func 148` to stay unchanged while `Func 1948`
    still rewrites
  - traced serial replay contains `0` `skip-invalid-lower` lines
  - whole-artifact direct compare is still red, but now as a valid semantic diff
    whose first hunk is back at `44251` rather than the newer `48978` family
  - Binaryen no-pass writeback still does not converge within five roundtrips on
    this artifact, so direct whole-artifact WAT must still be interpreted with
    that boundary noise in mind
  - a newer reduced regression now pins the Binaryen-matched nested-`if`
    outer-read bailout directly: if a local is still read after the enclosing
    block, Starshine no longer sinks the set into that nested arm
  - the refreshed compare-pass lane
    `.tmp/pass-fuzz-code-pushing-genvalid-20260410aa` is clean at
    `10000/10000` with `0` mismatches, `0` validation failures, `0` generator
    failures, and `0` command failures
  - the refreshed whole-artifact compare at
    `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-4176613` is
    still red, which confirms that the reduced nested-block fix is real but not
    the current debug-artifact frontier
  - the newer kept fast-path lane
    `.tmp/pass-fuzz-code-pushing-genvalid-20260410ab` is also clean at
    `10000/10000` with `0` mismatches, `0` validation failures, `0` generator
    failures, and `0` command failures
  - the newer whole-artifact compare at
    `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3345552` is
    still red at the same `44251` / `44254` family, but Starshine pass time is
    now down to `928.451 ms` vs Binaryen `55.628 ms`
  - the newer traced serial replay at `/tmp/code-pushing-trace-perf1.log`
    still changes only `Func 148` and `Func 1948`, contains `0`
    `skip-invalid-lower` lines, drops total traced `pass:code-pushing` to
    `934833 us`, and cuts unchanged `Func 3665` from `3311870 us` to `858 us`
  - comparing Binaryen no-pass-vs-pass output against Starshine no-pass-vs-pass
    output now shows the historical stable `48978` move on both sides, so the
    remaining semantic frontier is later than that old dropped-carrier family

## What Each Layer Catches Best

- Focused pass tests catch:
  - wrong movement rules
  - missing guard conditions
  - order-preservation bugs
- HOT-lowering repros catch:
  - invalid result-carrier rewrites
  - branch-target and payload-site mistakes
- Compare-pass fuzz catches:
  - small parity gaps on generated code
  - accidental invalid output on reduced shapes
- Direct artifact replay catches:
  - the real whole-function carrier families
  - pipeline-shaped parity gaps
  - the runtime cost story

## Current Signoff Rule

- Treat `code-pushing` parity as signed off only when the same tree satisfies all
  of the following:
  - `moon info && moon fmt`
  - focused `moon test` coverage for pass, IR, and CLI surfaces
  - a current-tree `10000`-comparison pass-fuzz lane with no semantic mismatches
  - native `--code-pushing` validation on the debug artifact
  - direct artifact replay against Binaryen with only explicitly accepted
    residual gaps

## Practical Rule For Future Work

- If a new reducer only passes layers 1 and 2, it is not done.
- If a new reducer passes layers 1 through 3 but fails the debug artifact, do not
  celebrate the fuzz result as final parity.
- If the direct artifact output is invalid, fix that before spending time on small
  normalized-WAT deltas somewhere else.
- If Binaryen itself leaves the frontier function unchanged, treat the shape as
  a Starshine fence question first, not as missing upstream transform coverage.
