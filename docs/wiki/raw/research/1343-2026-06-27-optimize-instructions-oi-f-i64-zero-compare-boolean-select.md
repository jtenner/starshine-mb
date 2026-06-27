# OptimizeInstructions OI-F i64 zero-compare boolean select cleanup

Date: 2026-06-27

## Scope

This slice narrows one Binaryen `OptimizeInstructions` boolean/select parity gap: exact i32 boolean select arms whose condition is a direct `i64.eq` / `i64.ne` comparison against zero.

Binaryen `version_130` was probed with:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-i64-zero-compare-condition-probe.wat -o .tmp/oi-select-i64-zero-compare-condition-probe.out.wat
```

The oracle behavior was narrow:

- `(select 1 0 (i64.eq x 0))` rewrites to `i64.eqz(x)`.
- `(select 0 1 (i64.eq x 0))` rewrites to `i64.ne(x, 0)`.
- `(select 1 0 (i64.ne x 0))` rewrites to `i64.ne(x, 0)`.
- `(select 0 1 (i64.ne x 0))` rewrites to `i64.eqz(x)`.
- A non-boolean value select such as `(select 42 13 (i64.eq x 0))` remains a select, with the zero equality condition canonicalized to `i64.eqz(x)`.

## Starshine change

`src/passes/optimize_instructions.mbt` now recognizes direct `i64.eq` / `i64.ne` select conditions where either compare operand is an exact zero constant and the select arms are exact i32 booleans:

- `eq` plus `1/0` becomes `i64.eqz(inner)`.
- `eq` plus `0/1` becomes `i64.ne(inner, 0)`.
- `ne` plus `1/0` becomes `i64.ne(inner, 0)`.
- `ne` plus `0/1` becomes `i64.eqz(inner)`.

The non-boolean value-select path still only drops the redundant compare condition when it is a zero compare, preserving the select and its value arms.

## Test evidence

Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds i64 zero-compare boolean select arms`

Before implementation, the focused test failed because Starshine lowered the `i64.ne(x, 0)` boolean-select case through an `i32.ne` wrapper instead of producing Binaryen's direct `i64.ne(x, 0)` result. After implementation, the focused test passed for `i64.eq` and `i64.ne` `1/0` and `0/1` arm combinations, plus the non-boolean value-select boundary.

## Boundaries

This is deliberately narrow. It does not claim:

- non-boolean i64 value-select rewrites,
- arbitrary i64 compare constants beyond exact zero,
- branch-condition rewrites,
- non-select ternary rewrites,
- broader boolean algebra,
- or movement of trapping/effectful value arms across the condition.

OI-F remains open for broader Binaryen boolean/select/ternary behavior.
