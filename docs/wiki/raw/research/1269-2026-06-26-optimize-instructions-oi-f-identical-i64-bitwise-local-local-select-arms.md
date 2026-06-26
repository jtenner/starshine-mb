# Optimize-instructions OI-F identical i64 bitwise local-local select arms

## Summary

This slice extends the narrow identical-pure select-arm matcher from covered i64 arithmetic local/local shells and i32 bitwise local/local shells to the matching `i64.and`, `i64.or`, and `i64.xor` local/local bitwise shells.

Binaryen `version_130` folds a `select` whose true and false arms are the same ordered `i64.and`, `i64.or`, or `i64.xor` expression over matching `local.get` operands and whose condition is side-effect-free. Starshine now matches that specific behavior by recognizing only direct same-instruction, same-ordered-local i64 bitwise arms inside the existing identical-select-arm fold.

## Evidence

- Binaryen oracle probe: `.tmp/oi-select-identical-i64-bitwise-local-local-arms-probe.wat`.
- Oracle command:
  - `wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-i64-bitwise-local-local-arms-probe.wat -o .tmp/oi-select-identical-i64-bitwise-local-local-arms-probe.out.wat`
- Oracle result: the output contains direct `i64.and`, `i64.or`, and `i64.xor` bodies with ordered `local.get` operands and no `select`.
- Red-first Starshine test: `optimize-instructions folds select with identical pure local-local binary arms` failed before implementation on the new `i64.and` case (`0/1`), then passed after adding the narrow i64 bitwise matcher (`1/1`).

## Implementation notes

- Added `optimize_instructions_i64_bitwise_local_local_payloads_are_identical_pure` in `src/passes/optimize_instructions.mbt` using the existing ordered local/local payload helper for `i64.and`, `i64.or`, and `i64.xor`.
- Wired that helper into `optimize_instructions_select_arms_are_identical_pure` alongside the existing i32/i64 add, mul, sub, and i32 bitwise helpers.
- Extended the existing local-local select-arm test in `src/passes/optimize_instructions_test.mbt` with the three i64 bitwise siblings.

## Boundaries

This is intentionally not arbitrary expression equality. It does not claim support for commuted operands, operand reordering, shifts/rotates/div/rem/compare local/local shells, algebraic equality, nested expression equality, effectful/trapping payloads, or effectful/trapping conditions. Those remain separate parity slices requiring fresh oracle evidence and focused tests.
