# OptimizeInstructions OI-F identical float compare local/local select arms

Date: 2026-06-26

## Summary

Starshine now folds a narrow additional OI-F identical-pure-select-arm family: direct `f32` / `f64` comparison payloads whose two select arms use the same comparison instruction over the same ordered `local.get` operands, with a side-effect-free condition.

This extends the existing identical local/local integer compare select-arm support without generalizing to arbitrary structural equality, operand commutation, algebraic equivalence, effectful/trapping conditions, or non-local payloads.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-float-compare-local-local-arms-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-compare-local-local-arms-probe.wat -o .tmp/oi-select-identical-float-compare-local-local-arms-probe.out.wat
```

The probe covered direct `f32.eq`, `f32.ne`, `f32.lt`, `f32.gt`, `f32.le`, `f32.ge`, and the analogous `f64` compare payloads. Binaryen eliminated all `select` nodes and retained one compare per function (`compare-count=12`).

## Starshine change

Changed files:

- `src/passes/optimize_instructions_test.mbt`: extended `optimize-instructions folds select with identical pure local-local binary arms` with `f32.eq(local.get, local.get)` and `f64.ge(local.get, local.get)` direct select-arm coverage.
- `src/passes/optimize_instructions.mbt`: added narrow `f32` / `f64` compare local/local identical-payload recognizers and wired them into the existing side-effect-free identical-select-arm fold.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local-local binary arms*'
```

Before implementation this failed on the new `f32.eq` case (`0/1`) because Starshine kept the `select`. After implementation the same focused test passed (`1/1`).

## Boundaries

This slice does not implement or claim:

- commuted operands such as `f32.eq(local.get 1, local.get 0)` versus `f32.eq(local.get 0, local.get 1)`;
- arbitrary structural equality or algebraic equality;
- value-equivalent float constants, NaN-normalization, or lane-equivalent vector spellings;
- effectful or trapping conditions;
- effectful or trapping compare operands;
- broader select/ternary AST parity beyond this direct same-instruction/same-ordered-local shell.

## Validation

- Binaryen oracle command above passed; follow-up count found no `select` occurrences and `12` float compare occurrences.
- Red-first focused Moon test failed before implementation and passed after implementation.
- Final slice validation is recorded in the commit that cites this note.
