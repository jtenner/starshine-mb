# OptimizeInstructions OI-F boolean constant select cleanup

Date: 2026-06-27

## Scope

This slice narrows one Binaryen `OptimizeInstructions` boolean/select parity gap: direct i32 boolean constant select arms.

Binaryen `version_130` was probed with:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-select-boolean-probe.wat -o .tmp/oi-f-select-boolean-probe.out.wat
```

The oracle rewrote:

- `(select (i32.const 1) (i32.const 0) cond)` to `i32.ne(cond, 0)`.
- `(select (i32.const 0) (i32.const 1) cond)` to `i32.eqz(cond)`.
- The same `1/0` shape with an effectful call condition to `i32.ne(call, 0)`, preserving the condition effect.

## Starshine change

`src/passes/optimize_instructions.mbt` now recognizes those two direct i32 arm pairs in `optimize_instructions_try_fold_const_select(...)` before constant-condition selection:

- `1/0` arms become `i32.ne(condition, 0)`.
- `0/1` arms become `i32.eqz(condition)`.

The rewrite keeps the original condition operand as the compare/unary operand. The dropped select arms are literal i32 constants, so moving the condition before those constants does not change observable behavior.

## Test evidence

Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds boolean const select arms to condition compares`

Before implementation, the focused test failed because Starshine kept the root as `Select(None)` instead of Binaryen's `I32Ne`. After implementation it passed.

## Boundaries

This is deliberately narrow. It does not claim:

- arbitrary select-arm values beyond exact i32 `1/0` and `0/1`,
- non-i32 result arms,
- branch-condition rewrites,
- broader ternary optimization,
- or general boolean algebra beyond the exact direct select shape.

OI-F remains open for the broader Binaryen boolean/select/ternary surface.
