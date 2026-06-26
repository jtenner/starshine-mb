# Optimize-instructions OI-F identical local-local select arms

## Summary

This slice extends the OI-F identical-pure-arm `select` fold to a narrow direct `i32.add(local.get A, local.get B)` shell where both arms use the same instruction and the same ordered local operands, and the condition is side-effect-free.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-local-local-arms-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-local-local-arms-probe.wat -o .tmp/oi-select-identical-local-local-arms-probe.out.wat
```

Result: Binaryen `version_130` removes the `select` and keeps the single `i32.add(local.get 0, local.get 1)` expression.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions folds select with identical pure local-local binary arms`.
- The test failed before implementation because Starshine kept the `select`.
- `src/passes/optimize_instructions.mbt` now recognizes only direct same-instruction/same-ordered-local `i32.add` arms via a small local-local payload helper and reuses the existing side-effect-free arm and condition guards.

## Boundaries

This is deliberately narrower than arbitrary expression equality. It does not claim commuted operand equality (`i32.add(local.get 1, local.get 0)`), other integer binary instructions, nested structural equality, algebraic equality, effectful payloads, trapping payloads, or effectful/trapping condition folding.

## Validation

- Red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local-local binary arms*'` failed `0/1` with the expected select-retention assertion.
- Focused test after implementation: same command passed `1/1`.
