# OptimizeInstructions OI-F identical integer local/constant select arms with effectful conditions

## Summary

Starshine now folds a narrow source-backed OI-F family where both `select` arms are the same ordered integer local/constant nontrapping shell and the condition is effectful. Binaryen `version_130` drops the condition for effects, removes the `select`, and keeps one copy of the arm.

Covered shells are same-instruction and same-ordered `i32` / `i64` local/constant add, sub, mul, bitwise, shift/rotate, and integer compare forms. Integer div/rem remains excluded because it can trap.

## Oracle evidence

Probe: `.tmp/oi-select-identical-int-localconst-effectful-condition-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-int-localconst-effectful-condition-probe.wat -o .tmp/oi-select-identical-int-localconst-effectful-condition-probe.out.wat
```

Result: passed. The Binaryen output contains no `select` instructions. Each exported body preserves `(drop (call $cond))` before the surviving `i32.add`, `i64.xor`, `i32.lt_u`, or `i64.ge_s` expression.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions preserves effectful condition when folding identical integer local-const select arms`.
- The focused test failed before implementation (`0/1`) because Starshine kept the first `select`.
- Extended `src/passes/optimize_instructions.mbt` with narrow nontrapping i32/i64 local/constant identical-arm predicates used only by the effectful-condition preservation path.

## Boundaries

This is not a general expression-equality proof. It intentionally excludes commuted operands, value-equivalent constants, arbitrary expression equality, trapping integer div/rem, trapping conversions, SIMD algebraic equality, and broader arm reordering across effectful conditions.

## Validation

- Binaryen oracle command above passed.
- Red-first focused test failed before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*integer local-const select arms*'` (`0/1`).
- Focused test passed after implementation: same command (`1/1`).
