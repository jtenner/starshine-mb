# OptimizeInstructions OI-F identical float binary local/local select arms

Date: 2026-06-26

## Summary

Starshine now folds a narrow OI-F identical-pure-select-arm family for direct `f32` / `f64` binary payloads whose two select arms use the same floating-point instruction over the same ordered `local.get` operands, with a side-effect-free condition.

This extends the existing identical local/local integer and float-compare select-arm support without generalizing to arbitrary structural equality, operand commutation, algebraic equivalence, value-equivalent float constants, or effectful/trapping conditions.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-float-binary-local-local-arms-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-binary-local-local-arms-probe.wat -o .tmp/oi-select-identical-float-binary-local-local-arms-probe.out.wat
```

The probe covered direct `f32.add`, `f32.sub`, `f32.mul`, `f32.div`, `f32.min`, `f32.max`, `f32.copysign`, and the analogous `f64` payloads. Binaryen eliminated all `select` nodes and retained one float binary instruction per function (`float-binary-count=14`).

## Starshine change

Changed files:

- `src/passes/optimize_instructions_test.mbt`: extended `optimize-instructions folds select with identical pure local-local binary arms` with representative `f32.add`, `f32.div`, `f32.copysign`, `f64.mul`, and `f64.min` direct select-arm coverage.
- `src/passes/optimize_instructions.mbt`: added narrow `f32` / `f64` binary local/local identical-payload recognizers for add/sub/mul/div/min/max/copysign and wired them into the existing side-effect-free identical-select-arm fold.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local-local binary arms*'
```

Before implementation this failed on the new `f32.add` case (`0/1`) because Starshine kept the `select`. After implementation the same focused test passed (`1/1`).

## Boundaries

This slice does not implement or claim:

- commuted operands such as `f32.add(local.get 1, local.get 0)` versus `f32.add(local.get 0, local.get 1)`;
- arbitrary structural equality or algebraic equality;
- value-equivalent float constants, NaN normalization, or lane-equivalent vector spellings;
- effectful or trapping conditions;
- effectful or trapping binary operands;
- broader select/ternary AST parity beyond this direct same-instruction/same-ordered-local shell.

## Validation

- Binaryen oracle command above passed; follow-up count found no `select` occurrences and `14` float binary occurrences.
- Red-first focused Moon test failed before implementation and passed after implementation.
- Final slice validation is recorded in the commit that cites this note.
