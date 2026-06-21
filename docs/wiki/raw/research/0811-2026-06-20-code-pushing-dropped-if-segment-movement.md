---
kind: research-note
status: working
created: 2026-06-20
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ./0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md
  - ./0809-2026-06-20-code-pushing-if-segment-movement.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../docs/wiki/binaryen/passes/code-pushing/fuzzing.md
---

# 0811-2026-06-20 code-pushing dropped-if segment movement

## Question

Can Starshine consume the existing `candidate:dropped-if` segment-window inventory in the smallest source-backed mutating family without widening trap, atomics, GC, EH, or multi-set behavior?

## Short answer

Yes, for the narrow after-push-point movement family where a single SFA `local.set` appears before a dropped value `if`, the dropped `if` does not read that local, and every read of the local is a same-region suffix read after the dropped wrapper. Starshine now moves the set to immediately after the `drop (if (result ...))` root, matching the local Binaryen `version_130` oracle for the reduced shape.

This is not full `code-pushing` closeout. Conditional branches, switch/`br_table`, ordered multi-set movement, precise `orderedBefore` modeling, atomics/GC/EH/trap-option widening, and the final four-lane signoff matrix remain open.

## Binaryen oracle probe

Input probe:

```wat
(module
  (func (param $c i32) (local $tmp i32)
    i32.const 7
    local.set $tmp
    local.get $c
    if (result i32)
      i32.const 1
    else
      i32.const 2
    end
    drop
    local.get $tmp
    drop))
```

Command:

```sh
wasm-opt --all-features --code-pushing -S .tmp/cp-dropped-probe.wat -o .tmp/cp-dropped-probe.opt.wat
```

Observed result: Binaryen moves `local.set $tmp (i32.const 7)` after the `drop (if (result i32) ...)` wrapper and before the suffix `drop (local.get $tmp)`.

## Implementation

Changed [`src/passes/code_pushing.mbt`](../../../../src/passes/code_pushing.mbt):

- `code_pushing_try_sink_set_after_if_push_point(...)` now accepts either `candidate:if` or `candidate:dropped-if` from `code_pushing_segment_window_diagnostic(...)`.
- For ordinary `candidate:if`, it keeps the previous void-`if` result-arity guard.
- For `candidate:dropped-if`, it unwraps the single drop child as the inner `if`, checks arm reads through that inner `if`, and still inserts the moved set after the original dropped-wrapper root.
- Existing total/suffix get accounting continues to reject cases where the dropped `if` condition or arms read the moved local before the new destination.

Changed [`src/passes/code_pushing_test.mbt`](../../../../src/passes/code_pushing_test.mbt):

- Added the red-first positive `code-pushing moves pure SFA set after dropped value if before later use`. Before implementation it failed with root-count drift (`3 != 4`) because Starshine did not move the set after the dropped wrapper.
- Added the boundary `code-pushing keeps SFA set before dropped if when the dropped if reads it`, proving local reads inside the dropped push point do not move past their own dependency.

Changed [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) and [`src/validate/gen_valid_tests.mbt`](../../../../src/validate/gen_valid_tests.mbt):

- Added `CodePushingDroppedIfProfile` / `code-pushing-dropped-if`.
- Added it to the `code-pushing-all` composite.
- Added a deterministic generated one-function dropped-if module plus focused profile-resolution, aggregate-sampling, validation, and candidate-shape tests.
- Updated [`src/validate/pkg.generated.mbti`](../../../../src/validate/pkg.generated.mbti) for the new public enum variant.

## Validation

Focused red/green and regression tests:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*dropped value if*'
# red before implementation: 0/1, failed with `3 != 4`
# green after implementation: 1/1

moon test --target native src/passes/code_pushing_test.mbt --filter '*dropped*'
# 2/2

moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'
# 24/24

moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
# 3/3
```

Repo/package checks run in this slice:

```sh
moon fmt
# passed

moon info
# passed with pre-existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt

moon build --target native --release src/cmd
# passed with pre-existing unused-function warnings in src/passes/pass_manager.mbt
```

Bounded native dedicated-profile lane after adding the new leaf:

```sh
bun scripts/pass-fuzz-compare.ts --count 300 --seed 0x5eed --pass code-pushing \
  --gen-valid-profile code-pushing-all \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-code-pushing-dropped-if-profile-300 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 50 \
  --keep-going-after-command-failures
```

Result: compared `300/300`, normalized matches `90`, cleanup-normalized matches `210`, raw mismatches `0`, validation failures `0`, generator failures `0`, property failures `0`, command failures `0`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 295 hits/5 misses`, `Binaryen failures 0 hits/0 misses`. Selected profiles from `cases.jsonl`: `code-pushing-dropped-if: 90`, `code-pushing-if-arm: 98`, `code-pushing-after-if: 112`.

The `--normalize local-cleanup-debris` normalizer remains required for this bounded dedicated lane because Starshine removes local cleanup debris that Binaryen leaves. This is bounded movement-family evidence, not raw output parity or final pass closeout.

## Boundaries and reopening criteria

Still out of scope for this slice:

- conditional branch mutation;
- switch/`br_table` mutation;
- ordered multi-set segment movement;
- precise `EffectAnalyzer::orderedBefore(...)` parity;
- atomics/GC/EH/trap-option widening;
- public preset scheduling;
- full regular GenValid, wasm-smith, dedicated-profile `10000`, and broad all-profile closeout matrix.

Reopen this dropped-wrapper slice if a generated or focused case shows the moved set crossing a dropped push point that reads the same local, crossing an effect/trap boundary not covered by the current strict movable-value gate, producing invalid wasm, or regressing the `code-pushing-dropped-if` profile lane beyond the documented local-cleanup normalization.
