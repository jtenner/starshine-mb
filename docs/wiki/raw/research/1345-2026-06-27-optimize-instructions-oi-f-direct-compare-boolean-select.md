# Optimize-instructions OI-F direct compare boolean select

Date: 2026-06-27

## Scope

This slice narrows another Binaryen `OptimizeInstructions` boolean/select gap: exact i32 boolean select arms around a direct compare condition.

Implemented Starshine scope:

- `(select (i32.const 1) (i32.const 0) (compare ...))` rewrites to the compare condition itself.
- `(select (i32.const 0) (i32.const 1) (compare ...))` rewrites to the direct inverse compare when Starshine already has a Binaryen-shaped inverse spelling via the existing `eqz(compare)` inversion table.
- Covered examples include integer relational `i32.lt_s -> i32.ge_s` and float equality `f32.eq -> f32.ne`.

This does not claim arbitrary non-compare boolean conditions, branch-condition rewrites, non-select ternary rewrites, non-boolean value-select rewrites, broad boolean algebra, or nonzero integer `eq`/`ne` inversion beyond already-covered zero-compare paths.

## Binaryen oracle

Probe file: `.tmp/oi-f-select-compare-boolean-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-select-compare-boolean-probe.wat -o .tmp/oi-f-select-compare-boolean-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- `(select 1 0 (i32.lt_s x y))` becomes `i32.lt_s(x, y)`.
- `(select 0 1 (i32.lt_s x y))` becomes `i32.ge_s(x, y)`.
- `(select 1 0 (f32.eq x y))` becomes `f32.eq(x, y)`.
- `(select 0 1 (f32.eq x y))` becomes `f32.ne(x, y)`.

## Starshine change

Files:

- `src/passes/optimize_instructions_test.mbt`
- `src/passes/optimize_instructions.mbt`

Test:

- `optimize-instructions folds direct compare boolean select arms`

Red-first result before implementation:

```text
Some(I32Ne) != Some(I32LtS)
```

The old fallback wrapped true/false boolean-select arms as `i32.ne(compare, 0)` instead of returning the direct compare. The implementation now recognizes direct compare conditions before that fallback and either replaces the select with the condition or rebuilds the inverse compare.

## Validation

Commands run:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-select-compare-boolean-probe.wat -o .tmp/oi-f-select-compare-boolean-probe.out.wat
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*direct compare boolean select arms*'
```

The focused test failed red-first as above, then passed after implementation. Broader `moon fmt`, focused OI test, `moon test src/passes`, and diff whitespace checks are recorded in the commit and handoff for this slice.

## Boundary

This is deliberately narrow. In particular, it does not reopen the previously documented warnings against broad nonzero integer `eq`/`ne` inversion, arbitrary compare-condition normalization, branch-condition rewrites, non-select ternary rewrites, or general boolean algebra without fresh Binaryen evidence and tests.
