---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
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
  - one-arm `if` sinking
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
- Current named reduced lane:
  - `pass-fuzz-code-pushing-genvalid-20260409j` completed `1000/1000` with `0`
    mismatches, `0` validation failures, and `0` command failures
- Mixed-generator and smith-only lanes have also stayed semantically clean on the
  kept pass surface, with remaining failures attributed to Binaryen-side parser or
  canonicalization rejects such as invalid type-index families

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
- This distinction matters because the current branch is blocked before honest WAT
  comparison: the output fails validation with `stack underflow` in `Func 1977`.

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
