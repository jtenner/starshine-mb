# Optimize-instructions OI-F integer equality boolean select

Date: 2026-06-27

## Scope

This slice narrows the Binaryen `OptimizeInstructions` boolean/select gap for exact i32 boolean select arms around direct integer equality conditions.

Implemented Starshine scope:

- `(select (i32.const 1) (i32.const 0) (i32.eq ...))` and `i32.ne` / `i64.eq` / `i64.ne` variants rewrite to the direct compare condition.
- `(select (i32.const 0) (i32.const 1) (i32.eq ...))` and `i64.eq` variants rewrite to direct `ne`; `ne` variants rewrite to direct `eq`.
- Covered tests use local/local integer equality conditions for i32 and i64.

This does not claim broad nonzero compare-to-constant condition normalization, arbitrary non-compare boolean conditions, branch-condition rewrites, non-select ternary rewrites, non-boolean value-select rewrites, or general boolean algebra.

## Binaryen oracle

Probe file: `.tmp/oi-f-integer-eq-select-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-integer-eq-select-probe.wat -o .tmp/oi-f-integer-eq-select-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- `(select 1 0 (i32.eq x y))` becomes `i32.eq(x, y)`.
- `(select 0 1 (i32.eq x y))` becomes `i32.ne(x, y)`.
- `(select 1 0 (i32.ne x y))` becomes `i32.ne(x, y)`.
- `(select 0 1 (i32.ne x y))` becomes `i32.eq(x, y)`.
- The same direct/inverse spelling holds for `i64.eq` and `i64.ne`.

## Starshine change

Files:

- `src/passes/optimize_instructions_test.mbt`
- `src/passes/optimize_instructions.mbt`

Test:

- `optimize-instructions folds direct integer equality boolean select arms`

Red-first result before implementation:

```text
Some(I32Ne) != Some(I32Eq)
```

The previous generic boolean-arm fallback wrapped `select 1 0 (i32.eq ...)` as `i32.ne(i32.eq(...), 0)`. The implementation now recognizes direct integer equality compare conditions before that fallback, preserving the direct compare for `1/0` arms and rebuilding the exact inverse equality compare for `0/1` arms.

## Validation

Commands run:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-integer-eq-select-probe.wat -o .tmp/oi-f-integer-eq-select-probe.out.wat
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*direct integer equality boolean select arms*'
```

The focused test failed red-first as above, then passed after implementation. Broader `moon fmt`, focused OI test, `moon test src/passes`, and diff whitespace checks are recorded in the commit and handoff for this slice.

## Boundary

This is deliberately narrow. It adds direct boolean-arm cleanup for already-boolean integer equality compare conditions. It does not generalize compare-condition normalization, arbitrary i32 truthiness proofs, branch rewrites, non-boolean value selects, or the broader integer `eq`/`ne` nonzero compare families without fresh Binaryen evidence and tests.
