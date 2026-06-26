# Optimize-instructions OI-F identical i64 mul local-local select arms

## Summary

This slice extends the narrow identical-pure select-arm matcher from direct same-ordered-local `i64.add(local.get, local.get)` arms to the matching `i64.mul(local.get, local.get)` shell.

Binaryen `version_130` folds a `select` whose true and false arms are the same ordered `i64.mul(local.get 0, local.get 1)` expression and whose condition is side-effect-free. Starshine now matches that specific behavior by recognizing only direct same-instruction, same-ordered-local `i64.mul` arms inside the existing identical-select-arm fold.

## Evidence

- Binaryen oracle probe: `.tmp/oi-select-identical-i64-mul-local-local-arms-probe.wat`.
- Oracle command:
  - `wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-i64-mul-local-local-arms-probe.wat -o .tmp/oi-select-identical-i64-mul-local-local-arms-probe.out.wat`
- Oracle result: the output contains `i64.mul` with the two `local.get` operands and no `select`.
- Red-first Starshine test: `optimize-instructions folds select with identical pure local-local binary arms` failed before implementation on the new `i64.mul` case, then passed after adding the narrow matcher.

## Implementation notes

- Added `optimize_instructions_i64_mul_local_local_payloads_are_identical_pure` in `src/passes/optimize_instructions.mbt` using the existing ordered local/local payload helper.
- Wired that helper into `optimize_instructions_select_arms_are_identical_pure` alongside the existing i32/i64 add helpers.
- Extended the existing local-local select-arm test in `src/passes/optimize_instructions_test.mbt` with the i64 mul sibling.

## Boundaries

This is intentionally not arbitrary expression equality. It does not claim support for commuted operands, other i64 binary instructions, algebraic equality, nested expression equality, effectful/trapping payloads, or effectful/trapping conditions. Those remain separate parity slices requiring fresh oracle evidence and focused tests.
