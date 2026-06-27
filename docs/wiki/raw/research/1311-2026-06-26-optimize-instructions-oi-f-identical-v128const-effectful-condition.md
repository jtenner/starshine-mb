# Optimize Instructions OI-F Identical `v128.const` Effectful Condition

## Summary

This slice extends the narrow OI-F identical-select-arm cleanup for effectful conditions to byte-identical `v128.const` arms. Binaryen `version_130` drops the effectful condition before one surviving vector constant; Starshine now matches that shape for exact `V128Const` instruction equality.

This is not SIMD algebra, lane-equivalent vector spelling, or arbitrary vector expression equality. The admitted proof is only byte-identical constants, which are side-effect-free, nontrapping, and safe to materialize after preserving the condition as a dropped prefix.

## Oracle

Probe: `.tmp/oi-select-identical-v128-const-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-v128-const-effectful-condition-probe.wat -o .tmp/oi-select-identical-v128-const-effectful-condition-probe.out.wat
```

Observed Binaryen output removes `select`, preserves `(drop (call $effect))`, and emits a single `v128.const i32x4 0x00000001 0x00000002 0x00000003 0x00000004`.

## Starshine change

- Added focused red-first coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions preserves effectful condition when folding identical v128.const select arms`.
- Before implementation, the focused test failed because Starshine kept the `select` root.
- Added `optimize_instructions_v128_consts_are_identical_pure` in `src/passes/optimize_instructions.mbt` and admitted that helper to `optimize_instructions_select_arms_are_identical_nontrapping_reorderable`.

## Validation

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*v128.const select arms*'` failed red-first (`0/1`) before implementation.
- The same focused command passed after implementation (`1/1`).

## Boundaries

- Covered: exact byte-identical `v128.const` arms with effectful/trapping conditions preserved as dropped prefixes.
- Not covered: lane-equivalent vector constants, SIMD algebraic equality, non-constant SIMD expressions, `v128.not` / unsupported text-lowering shapes, or any trap/effect reordering beyond this exact constant-arm proof.
