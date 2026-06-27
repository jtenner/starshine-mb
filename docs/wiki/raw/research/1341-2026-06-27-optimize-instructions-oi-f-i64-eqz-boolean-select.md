# OptimizeInstructions OI-F i64 eqz boolean select cleanup

Date: 2026-06-27

## Scope

This slice narrows one Binaryen `OptimizeInstructions` boolean/select parity gap: exact i32 boolean select arms whose condition is a direct `i64.eqz` shell.

Binaryen `version_130` was probed with:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-i64-eqz-probe.wat -o .tmp/oi-select-i64-eqz-probe.out.wat
```

The oracle behavior was narrow:

- `(select 1 0 (i64.eqz x))` rewrites to `i64.eqz(x)`.
- `(select 0 1 (i64.eqz x))` rewrites to `i64.ne(x, 0)`.
- A non-boolean value select such as `(select 42 13 (i64.eqz x))` stays a select with the `i64.eqz` condition.

A sibling probe `.tmp/oi-select-i64-zero-compare-probe.wat` showed Binaryen canonicalizes direct `i64.eq(x, 0)` select conditions to `i64.eqz(x)`, while non-boolean `i64.ne(x, 0)` select conditions remain compare-shaped. This slice does not implement a broader i64 zero-compare select-condition normalizer.

## Starshine change

`src/passes/optimize_instructions.mbt` now recognizes direct `i64.eqz` select conditions in `optimize_instructions_try_fold_const_select(...)` only when the value arms are exact i32 booleans:

- `select 1/0` becomes `i64.eqz(inner)`.
- `select 0/1` becomes `i64.ne(inner, 0)`.
- Non-boolean value selects remain unchanged.

This avoids the previous generic boolean-select lowering through an extra `i32.ne(i64.eqz(inner), 0)` wrapper and matches the observed Binaryen spelling.

## Test evidence

Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds i64 eqz boolean select arms`

Before implementation, the focused test failed because Starshine produced `i32.ne(i64.eqz(local.get), 0)` for the `1/0` case. After implementation, the focused test passed for `1/0`, `0/1`, and the non-boolean value-select boundary.

## Boundaries

This is deliberately narrow. It does not claim:

- non-boolean `i64.eqz` value-select rewrites,
- arbitrary i64 compare-condition normalization,
- i32 condition normalization beyond already-covered direct shells,
- branch-condition rewrites,
- non-select ternary rewrites,
- broader boolean algebra,
- or movement of trapping/effectful value arms across the condition.

OI-F remains open for broader Binaryen boolean/select/ternary behavior.
