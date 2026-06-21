---
kind: research
status: supported
last_reviewed: 2026-06-20
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/segment-selection-and-barriers.md
  - ../../binaryen/passes/code-pushing/starshine-strategy.md
  - ../../binaryen/passes/code-pushing/fuzzing.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# Code-pushing ordered multi-set movement

## Question

Can Starshine close the first ordered multi-set `optimizeSegment(...)` gap without broadening into switch/`br_table`, branch-value conditional branches, GC/EH/atomics, or trap-option behavior?

## Binaryen oracle probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe input:

```wat
(module
  (func (param i32) (local i32 i32)
    i32.const 7
    local.set 1
    i32.const 9
    local.set 2
    local.get 0
    if
      nop
    end
    local.get 1
    drop
    local.get 2
    drop))
```

Command:

```sh
wasm-opt --all-features --code-pushing -S .tmp/cp-multiset-probe.wat -o .tmp/cp-multiset-probe.opt.wat
```

Finding: Binaryen moved both SFA sets after the void `if` and preserved their original order: `local.set $1` before `local.set $2`, followed by the two suffix reads.

## Starshine pre-fix behavior

A red-first focused HOT test showed Starshine's existing fixed-point single-set movement could reverse adjacent moved sets. After moving the first set, the second pass inserted the second set immediately after the same `if`, ahead of the already-moved first set. The red-first command failed as intended:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*multiple SFA*'
# failed: first moved local was 2, expected 1
```

This was not a semantic mismatch for the constant-only probe, but it was a Binaryen behavior-parity gap and a risk for future broader value families.

## Implemented slice

`src/passes/code_pushing.mbt` now has a bounded ordered multi-set helper for ordinary void `if` push points:

- recognizes two or more adjacent void `local.set` roots before an ordinary void `if`;
- requires each local to be SFA under the existing whole-function counters;
- requires every read of each moved local to be in the same-region suffix after the `if`;
- rejects if either `if` arm reads any moved local;
- rejects values containing local gets, keeping this first ordered slice to local-independent movable values such as constants and guarded pure/global values;
- inserts all cloned sets after the `if` in source order, then replaces the original roots with `nop`.

This slice deliberately does **not** implement ordered multi-set movement for dropped value-`if`, `br_if`, switch/`br_table`, branch-value branches, loop-target branches, or values whose movement depends on local-read ordering.

## Tests and profile growth

Focused pass coverage:

- `code-pushing preserves order when moving multiple SFA sets after if` protects the Binaryen-backed order-preservation shape.

GenValid coverage:

- added `CodePushingMultiSetProfile` / `code-pushing-multi-set`;
- `code-pushing-all` now samples five leaf profiles: `code-pushing-if-arm`, `code-pushing-after-if`, `code-pushing-dropped-if`, `code-pushing-br-if`, and `code-pushing-multi-set`;
- generator tests prove profile naming, composite membership, aggregate sampling, validation, and the deterministic multi-set candidate shape.

Public API note: `src/validate/pkg.generated.mbti` was updated for the new public `GenValidProfile` variant.

## Validation

Commands run:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*multiple SFA*'
# passed 1/1 after implementation

moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'
# passed 27/27

moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
# passed 3/3

moon fmt
# passed

moon info
# passed with pre-existing warnings in gen_valid.mbt and gen_valid_ssa.mbt

moon test src/passes
# passed 2730/2730

moon test src/validate
# passed 1627/1627

moon test
# passed 6060/6060

moon build --target native --release src/cmd
# passed with pre-existing unused-function warnings in pass_manager.mbt
```

Bounded dedicated native compare:

```sh
bun scripts/pass-fuzz-compare.ts --count 500 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-multi-set-profile-500 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `500/500`; normalized matches `227`; cleanup-normalized matches `273`; raw mismatches `0`; validation failures `0`; generator failures `0`; property failures `0`; command failures `0`; cache `wasm-smith 0 hits/0 misses`, `Binaryen 498 hits/2 misses`, `Binaryen failures 0 hits/0 misses`. Selected subprofiles: `code-pushing-after-if: 91`, `code-pushing-multi-set: 85`, `code-pushing-if-arm: 97`, `code-pushing-dropped-if: 121`, `code-pushing-br-if: 106`.

The `--normalize local-cleanup-debris` caveat remains the same as the prior slices: Starshine cleans standalone `nop` / empty-else debris that Binaryen leaves. This is bounded slice evidence, not final raw-output parity or full closeout.

## Remaining gaps

`[O4Z-AUDIT-CP]` remains active. Remaining work includes switch/`br_table` mutation, ordered movement for other push-point families, broader conditional branches (`br_on_*`, loop targets, branch values), precise `orderedBefore` / atomics / GC / EH / trap-option boundaries, full direct compare refresh, the pass-specific `10000` profile lane, and the full four-lane final closeout matrix.

## Reopening criteria

Reopen this slice if:

- adjacent local-independent multi-set movement reverses source order again;
- Starshine output fails validation for the multi-set shape;
- Binaryen `version_130` evidence shows this bounded ordinary-void-`if` order-preservation model is stale;
- a future broader value family needs local-read-dependent ordering that this slice intentionally rejects.
