# Optimize-instructions OI-F identical shift/rotate local-local select arms

## Summary

This slice extends the narrow identical-pure select-arm matcher from covered arithmetic and bitwise local/local shells to same-ordered-local integer shift and rotate shells.

Binaryen `version_130` folds a `select` whose true and false arms are the same direct `i32.shl`, `i32.shr_s`, `i32.shr_u`, `i32.rotl`, `i32.rotr`, `i64.shl`, `i64.shr_s`, `i64.shr_u`, `i64.rotl`, or `i64.rotr` expression over matching ordered `local.get` operands and whose condition is side-effect-free. Starshine now matches that specific behavior by recognizing only direct same-instruction, same-ordered-local shift/rotate arms inside the existing identical-select-arm fold.

## Evidence

- Binaryen oracle probe: `.tmp/oi-select-identical-shift-rot-local-local-arms-probe.wat`.
- Oracle command:
  - `wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-shift-rot-local-local-arms-probe.wat -o .tmp/oi-select-identical-shift-rot-local-local-arms-probe.out.wat`
- Oracle result: the output contains direct shift/rotate bodies with ordered `local.get` operands and no `select` for the probed i32 and i64 siblings.
- Red-first Starshine test: `optimize-instructions folds select with identical pure local-local binary arms` failed before implementation on the new `i32.shl` case (`0/1`), then passed after adding the narrow shift/rotate matchers (`1/1`).

## Implementation notes

- Added `optimize_instructions_i32_shift_rotate_local_local_payloads_are_identical_pure` and `optimize_instructions_i64_shift_rotate_local_local_payloads_are_identical_pure` in `src/passes/optimize_instructions.mbt` using the existing ordered local/local payload helper.
- Wired those helpers into `optimize_instructions_select_arms_are_identical_pure` alongside the existing i32/i64 arithmetic and bitwise local/local helpers.
- Extended the existing local-local select-arm test in `src/passes/optimize_instructions_test.mbt` with representative i32 and i64 shift/rotate siblings.

## Boundaries

This is intentionally not arbitrary expression equality. It does not claim support for commuted operands, operand reordering, div/rem/compare local/local shells, algebraic equality, nested expression equality, effectful/trapping payloads, or effectful/trapping conditions. Those remain separate parity slices requiring fresh oracle evidence and focused tests.
