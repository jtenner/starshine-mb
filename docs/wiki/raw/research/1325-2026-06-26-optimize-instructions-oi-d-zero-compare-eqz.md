# Optimize Instructions OI-D Zero-Compare Eqz Cleanup

Date: 2026-06-26

## Scope

Narrow OI-D scalar/boolean cleanup slice for `i32.eqz` wrapped around integer equality/inequality comparisons against zero.

This is an implementation slice, not broad boolean algebra parity. It covers only direct `i32.eq` / `i32.ne` and `i64.eq` / `i64.ne` compare nodes with an exact zero constant operand.

## Binaryen oracle

Probe: `.tmp/oi-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-probe.wat -o .tmp/oi-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- `i32.eqz(i32.ne(local.get, 0))` rewrites to `i32.eqz(local.get)`.
- `i32.eqz(i64.ne(local.get, 0))` rewrites to `i64.eqz(local.get)`.
- `i32.eqz(i32.eq(local.get, 0))` rewrites to `i32.ne(local.get, 0)`.

## Starshine change

Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions rewrites eqz on zero compare into inverted compare`

Before implementation, the focused test failed because Starshine kept the outer `i32.eqz` over the original comparison operand. After implementation, `optimize_instructions_try_fold_eqz(...)` recognizes direct compare operands with an exact zero constant side and rewrites:

- `eqz(i32.ne(x, 0))` / `eqz(i32.ne(0, x))` to `i32.eqz(x)`.
- `eqz(i64.ne(x, 0))` / `eqz(i64.ne(0, x))` to `i64.eqz(x)`.
- `eqz(i32.eq(x, 0))` / `eqz(i32.eq(0, x))` to `i32.ne(x, 0)`.
- `eqz(i64.eq(x, 0))` / `eqz(i64.eq(0, x))` to `i64.ne(x, 0)`.

The rewrite preserves the non-constant operand evaluation and drops only the inert zero constant. It does not rewrite nonzero comparisons, arbitrary nested boolean expressions, commuted nonzero identities, float comparisons, NaN-sensitive forms, branch conditions beyond the existing OI-F control cleanup, or trapping/effectful algebra beyond the direct compare evaluation already present.

## Validation

- Binaryen oracle command above passed and produced the expected simplified compare/eqz spelling.
- Focused test failed red-first with the original comparison still under `i32.eqz`.
- Focused test passed after implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*zero compare*'`.

## Status

This shrinks one OI-D boolean-normalization parity gap. Overall `optimize-instructions` parity remains incomplete; keep the OI audit active.
