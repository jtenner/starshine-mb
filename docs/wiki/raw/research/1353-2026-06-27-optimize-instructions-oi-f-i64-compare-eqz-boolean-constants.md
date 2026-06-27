# Optimize-instructions OI-F i64 compare eqz boolean constants

Date: 2026-06-27

## Scope

This slice extends the direct boolean-constant compare cleanup from `i32.eqz` results to direct `i64.eqz` results. The compared value is still an i32 boolean result, so the outer compare shell remains `i32.eq` / `i32.ne` against exact `i32.const 0` or `i32.const 1`.

Implemented Starshine scope:

- `i32.eq(i64.eqz(x), 0)` rewrites to `i64.ne(x, 0)`.
- `i32.ne(i64.eqz(x), 0)` rewrites to `i64.eqz(x)`.
- `i32.eq(i64.eqz(x), 1)` rewrites to `i64.eqz(x)`.
- `i32.ne(i64.eqz(x), 1)` rewrites to `i64.ne(x, 0)`.

This deliberately does not claim arbitrary boolean algebra, non-boolean constants, non-direct `eqz` producers, branch rewrites, select rewrites, or broader i64 compare-condition normalization.

## Binaryen oracle

Probe file: `.tmp/oi-f-i64-compare-eqz-boolean-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-i64-compare-eqz-boolean-probe.wat -o .tmp/oi-f-i64-compare-eqz-boolean-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- `eq(i64.eqz(x), 0)` becomes `i64.ne(x, 0)`.
- `ne(i64.eqz(x), 0)` becomes `i64.eqz(x)`.
- `eq(i64.eqz(x), 1)` becomes `i64.eqz(x)`.
- `ne(i64.eqz(x), 1)` becomes `i64.ne(x, 0)`.

## Starshine change

Files:

- `src/passes/optimize_instructions_test.mbt`
- `src/passes/optimize_instructions.mbt`

Test:

- `optimize-instructions folds compare of i64 eqz against boolean constants`

Red-first result before implementation:

```text
Some(I32Eqz) != Some(I64Ne)
```

The prior cleanup recognized only direct `i32.eqz` producers. The implementation now recognizes both direct `i32.eqz` and direct `i64.eqz` producers in exact boolean-constant compare shells, rebuilding the correct same-width `eqz` or `ne(x, 0)` result for the producer operand type.

## Validation

Commands run during the slice:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-i64-compare-eqz-boolean-probe.wat -o .tmp/oi-f-i64-compare-eqz-boolean-probe.out.wat
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i64 eqz against boolean constants*'
```

The focused test failed red-first as above, then passed after implementation. Broader `moon fmt`, focused OI test, `moon test src/passes`, and diff whitespace checks are recorded in the commit and handoff for this slice.

## Boundary

This fold is limited to direct `i64.eqz` operands and exact i32 boolean constants in direct `i32.eq` / `i32.ne` compare shells. It does not generalize to non-boolean constants, arbitrary boolean-valued expressions, branch rewrites, select rewrites, non-direct producers, or cross-effect motion without fresh Binaryen evidence and tests.
