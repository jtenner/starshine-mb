# Optimize-instructions OI-F identical i32 bitwise local-local select arms

## Summary

This slice extends the narrow identical-pure select-arm matcher from direct same-ordered-local arithmetic local/local shells to the matching `i32.and`, `i32.or`, and `i32.xor` local/local bitwise shells.

Binaryen `version_130` folds a `select` whose true and false arms are the same ordered `i32.and`, `i32.or`, or `i32.xor` expression over matching `local.get` operands and whose condition is side-effect-free. Starshine now matches that specific behavior by recognizing only direct same-instruction, same-ordered-local i32 bitwise arms inside the existing identical-select-arm fold.

## Evidence

- Binaryen oracle probe: `.tmp/oi-select-identical-i32-bitwise-local-local-arms-probe.wat`.
- Oracle command:
  - `wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-i32-bitwise-local-local-arms-probe.wat -o .tmp/oi-select-identical-i32-bitwise-local-local-arms-probe.out.wat`
- Oracle result: the output contains direct `i32.and`, `i32.or`, and `i32.xor` bodies with ordered `local.get` operands and no `select`.
- Red-first Starshine test: `optimize-instructions folds select with identical pure local-local binary arms` failed before implementation on the new `i32.and` case (`0/1`), then passed after adding the narrow bitwise matcher (`1/1`).

## Implementation notes

- Added `optimize_instructions_i32_bitwise_local_local_payloads_are_identical_pure` in `src/passes/optimize_instructions.mbt` using the existing ordered local/local payload helper for `i32.and`, `i32.or`, and `i32.xor`.
- Wired that helper into `optimize_instructions_select_arms_are_identical_pure` alongside the existing i32/i64 add, mul, and sub helpers.
- Extended the existing local-local select-arm test in `src/passes/optimize_instructions_test.mbt` with the three i32 bitwise siblings.

## Boundaries

This is intentionally not arbitrary expression equality. It does not claim support for commuted operands, operand reordering, i64 bitwise local/local shells, shifts/rotates/div/rem/compare local/local shells, algebraic equality, nested expression equality, effectful/trapping payloads, or effectful/trapping conditions. Those remain separate parity slices requiring fresh oracle evidence and focused tests.
