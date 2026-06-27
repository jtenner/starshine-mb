# Optimize-instructions OI-F compare eqz boolean constants

Date: 2026-06-27

## Scope

This slice narrows the Binaryen `OptimizeInstructions` boolean shell gap for direct `i32.eq` / `i32.ne` compares between an `i32.eqz` result and exact boolean constants.

Implemented Starshine scope:

- `i32.eq(i32.eqz(x), 0)` and `i32.eq(0, i32.eqz(x))` rewrite to `i32.ne(x, 0)`.
- `i32.ne(i32.eqz(x), 0)` rewrites to `i32.eqz(x)`.
- `i32.eq(i32.eqz(x), 1)` rewrites to `i32.eqz(x)`.
- `i32.ne(i32.eqz(x), 1)` rewrites to `i32.ne(x, 0)`.

This is deliberately an exact direct-`i32.eqz` plus boolean-constant compare shell. It does not claim arbitrary boolean algebra, non-boolean constants, branch-condition rewrites, non-i32 conditions, or broad condition normalization.

## Binaryen oracle

Probe file: `.tmp/oi-f-compare-eqz-zero-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-compare-eqz-zero-probe.wat -o .tmp/oi-f-compare-eqz-zero-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- `eq(eqz(x), 0)` and the swapped `eq(0, eqz(x))` become `i32.ne(x, 0)`.
- `ne(eqz(x), 0)` and the swapped `ne(0, eqz(x))` become `i32.eqz(x)`.
- `eq(eqz(x), 1)` becomes `i32.eqz(x)`.
- `ne(eqz(x), 1)` becomes `i32.ne(x, 0)`.

## Starshine change

Files:

- `src/passes/optimize_instructions_test.mbt`
- `src/passes/optimize_instructions.mbt`

Test:

- `optimize-instructions folds compare of eqz against boolean constants`

Red-first result before implementation:

```text
Some(I32Eqz) != Some(I32Ne)
```

The previous compare-to-zero rewrite recognized `i32.eq(..., 0)` first and rebuilt `i32.eqz(eqz(x))`, leaving cleanup to a later traversal that does not revisit the freshly built node in the same pass walk. The implementation now recognizes direct `i32.eqz` operands compared against exact `0` or `1` before the generic zero-compare rewrite, rebuilding either `i32.eqz(x)` or `i32.ne(x, 0)` directly.

## Validation

Commands run during the slice:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-compare-eqz-zero-probe.wat -o .tmp/oi-f-compare-eqz-zero-probe.out.wat
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*compare of eqz against boolean constants*'
```

The focused test failed red-first as above, then passed after implementation. Broader `moon fmt`, focused OI test, `moon test src/passes`, and diff whitespace checks are recorded in the commit and handoff for this slice.

## Boundary

This fold is limited to direct `i32.eqz` operands and exact boolean constants in direct `i32.eq` / `i32.ne` compare shells. It does not generalize to non-boolean constants, arbitrary boolean-valued expressions, float or i64 conditions, select rewrites, branch rewrites, or cross-effect motion without fresh Binaryen evidence and tests.
