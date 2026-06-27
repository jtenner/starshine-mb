# Optimize-instructions OI-F eqz compare boolean select

Date: 2026-06-27

## Scope

This slice narrows the Binaryen `OptimizeInstructions` boolean/select gap for exact i32 boolean select arms around `i32.eqz(compare ...)` conditions.

Implemented Starshine scope:

- `(select (i32.const 1) (i32.const 0) (i32.eqz (compare ...)))` rewrites to the inverse compare when Binaryen has a direct inverse spelling.
- `(select (i32.const 0) (i32.const 1) (i32.eqz (compare ...)))` rewrites to the inner compare.
- Covered tests include integer equality, integer relational, and float equality compare shells over direct local operands.

This does not claim arbitrary boolean algebra, branch-condition rewrites, non-select ternary rewrites, non-boolean value-select rewrites, broader condition normalization, or cross-effect motion.

## Binaryen oracle

Probe file: `.tmp/oi-f-select-eqz-compare-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-select-eqz-compare-probe.wat -o .tmp/oi-f-select-eqz-compare-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- `(select 1 0 (i32.eqz (i32.eq x y)))` becomes `i32.ne(x, y)`.
- `(select 0 1 (i32.eqz (i64.ne x y)))` becomes `i64.ne(x, y)`.

The focused Starshine test also locks relational and float equality shells through the same direct inverse/inner-compare rule.

## Starshine change

Files:

- `src/passes/optimize_instructions_test.mbt`
- `src/passes/optimize_instructions.mbt`

Test:

- `optimize-instructions folds eqz compare boolean select arms`

Red-first result before implementation:

```text
Some(I32Eqz) != Some(I32Ne)
```

The previous `i32.eqz` condition branch returned `i32.eqz(compare)` for exact `1/0` arms or `i32.ne(i32.eqz(compare), 0)` for exact `0/1` arms. The implementation now recognizes direct compare payloads under the `eqz` condition first, using a narrow inverse-compare helper for `1/0` arms and reusing the inner compare for `0/1` arms.

## Validation

Commands run during the slice:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-select-eqz-compare-probe.wat -o .tmp/oi-f-select-eqz-compare-probe.out.wat
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eqz compare boolean select arms*'
```

The focused test failed red-first as above, then passed after implementation. Broader `moon fmt`, focused OI test, `moon test src/passes`, and diff whitespace checks are recorded in the commit and handoff for this slice.

## Boundary

This is deliberately narrow. It removes an exact select/eqz/compare shell that Binaryen folds, but it does not generalize to arbitrary non-compare boolean conditions, branch rewrites, effectful compare operands beyond existing HOT safety checks, non-boolean select values, or broad boolean algebra without fresh oracle evidence and tests.
