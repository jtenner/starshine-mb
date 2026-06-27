# Optimize Instructions OI-F Identical Integer Unary Effectful Condition

## Summary

This slice extends the narrow OI-F identical-select-arm cleanup for effectful conditions to same-instruction integer unary local shells. Binaryen `version_130` drops the effectful condition before one surviving `i32.clz` / `i64.popcnt` arm; Starshine now matches that shape for integer unary local-only shells already recognized by the side-effect-free identical-arm matcher.

The proof is intentionally narrow: `i32.eqz`, `i32.clz`, `i32.ctz`, `i32.popcnt`, `i64.eqz`, `i64.clz`, `i64.ctz`, and `i64.popcnt` over the same local are nontrapping and cannot observe the condition's effects, so evaluating the dropped condition before the surviving unary arm is safe. This is not arbitrary expression equality, trapping conversion cleanup, SIMD equivalence, or algebraic reasoning.

## Oracle

Probe: `.tmp/oi-select-identical-int-unary-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-int-unary-effectful-condition-probe.wat -o .tmp/oi-select-identical-int-unary-effectful-condition-probe.out.wat
```

Observed Binaryen output removes both `select` instructions, preserves two `(drop (call $effect))` prefixes, and emits surviving `i32.clz(local.get 0)` and `i64.popcnt(local.get 1)` arms.

## Starshine change

- Added focused red-first coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions preserves effectful condition when folding identical integer unary select arms`.
- Before implementation, the focused test failed because Starshine kept the `i32.clz` select root.
- Admitted `optimize_instructions_i32_unary_local_payloads_are_identical_pure` and `optimize_instructions_i64_unary_local_payloads_are_identical_pure` to `optimize_instructions_select_arms_are_identical_nontrapping_reorderable` in `src/passes/optimize_instructions.mbt`.

## Validation

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*integer unary select arms*'` failed red-first (`0/1`) before implementation.
- The same focused command passed after implementation (`1/1`).

## Boundaries

- Covered: same-instruction `i32`/`i64` unary local-only arms with effectful/trapping conditions preserved as dropped prefixes.
- Not covered: trapping conversions, div/rem, commuted or algebraically equivalent expressions, arbitrary structural equality, SIMD unary/vector equivalence, or any expression that can trap or observe condition-side effects.
