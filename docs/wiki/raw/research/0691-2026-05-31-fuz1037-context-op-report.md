# FUZ1037R4 Context/Op Feature-Fact Attribution

## Scope

`[FUZ]1037R4` asked whether GenValid const-expression reporting should identify which context/op-family pairs appeared, or whether the coarse `ConstExprVariants` row should remain the v0.1.0 boundary.

This slice keeps `ConstExprVariants` coarse for feature-floor compatibility, but adds a focused detailed report API for callers and future fuzz reporting that need context/op-family attribution.

## Implementation

- Added `GcConstructorConstExprOp` to the `GenValidConstExprOpFamily` vocabulary so the existing safe struct/descriptor constructor initializer coverage is named alongside numeric constants, `ref.null`, `ref.func`, immutable `global.get`, and `ref.i31`.
- Added `GenValidConstExprObservedOps` and `gen_valid_const_expr_observed_op_matrix(...)` in `src/validate/gen_valid.mbt`.
- The report returns one row per existing const-expression context:
  - `GlobalInitializerConstExpr`
  - `DataOffsetConstExpr`
  - `ElementOffsetConstExpr`
  - `ElementPayloadConstExpr`
  - `TableInitializerConstExpr`
- Each row lists the observed op families in that context. The scanner treats `i32.const 31; ref.i31` as the `I31RefConstExprOp` family instead of double-counting the leading scalar literal as a separate numeric context observation. Descriptor-bearing initializers can report both imported immutable `global.get` and GC constructor families because both operations are semantically present in that initializer.

## Tests

Added `gen-valid const-expression observed-op report attributes contexts` in `src/validate/gen_valid_tests.mbt`. The fixture builds a synthetic module with:

- numeric and `ref.i31` global initializers,
- a global initializer that combines `global.get` with a GC constructor,
- an active data offset backed by `global.get`,
- an active element offset backed by a numeric literal,
- an element payload backed by `ref.func`, and
- a table initializer backed by `ref.null`.

TDD evidence:

- `moon test src/validate` first failed because `gen_valid_const_expr_observed_op_matrix(...)` and `GcConstructorConstExprOp` did not exist.
- After implementation, `moon test src/validate` passed with `1502` tests.
- Targeted smoke passed: `moon run src/fuzz -- validate-valid smoke --seed 0x1037 --out-dir .tmp/fuz1037r4-validate-valid-smoke` (`pass=true`, `attempts=128`).
- Commit-ready validation passed: `moon fmt`, `moon info`, full `moon test` (`4476` tests), and `git diff --check`.

## Docs

Updated:

- `docs/wiki/fuzzing/generator-coverage-ledger.md`
- `docs/wiki/validate/constant-expressions.md`
- `docs/wiki/log.md`

## Result

`[FUZ]1037R4` is closed. The v0.1.0 ledger keeps the stable coarse `ConstExprVariants` counter for feature floors, while `gen_valid_const_expr_observed_op_matrix(...)` provides exact context/op-family attribution for detailed fuzz reports and future closeout checks.
