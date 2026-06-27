# OptimizeInstructions OI-F identical v128 splat select arms with effectful conditions

## Summary

Starshine now folds a narrow source-backed OI-F family where both `select` arms are the same direct-local SIMD splat shell and the condition is effectful. Binaryen `version_130` drops the condition for effects, removes the `select`, and keeps one copy of the splat.

Covered shells are same-instruction, same-local `i8x16.splat`, `i16x8.splat`, `i32x4.splat`, `i64x2.splat`, `f32x4.splat`, and `f64x2.splat` forms through the existing shared splat predicate.

## Oracle evidence

Probe: `.tmp/oi-select-identical-v128-splat-effectful-condition-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-v128-splat-effectful-condition-probe.wat -o .tmp/oi-select-identical-v128-splat-effectful-condition-probe.out.wat
```

Result: passed. The Binaryen output contains no `select` instructions and preserves each `(drop (call $effect))` before the surviving `i8x16.splat`, `i16x8.splat`, or `f32x4.splat` expression.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions preserves effectful condition when folding identical v128 splat select arms`.
- The focused test failed before implementation (`0/1`) because Starshine kept the `select`.
- Extended the effectful-condition identical-arm predicate in `src/passes/optimize_instructions.mbt` to admit the existing direct-local v128 splat identical-arm proof.

## Boundaries

This is not a SIMD algebraic-equality proof. It intentionally excludes lane-equivalent vector spellings, v128 unary/binary algebra, commuted operands, arbitrary expression equality, and broader arm reordering across effectful conditions. A prior v128 unary attempt remains blocked by text-lowering support for at least `v128.not`.

## Validation

- Binaryen oracle command above passed.
- Red-first focused test failed before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*v128 splat select arms*'` (`0/1`).
- Focused test passed after implementation: same command (`1/1`).
