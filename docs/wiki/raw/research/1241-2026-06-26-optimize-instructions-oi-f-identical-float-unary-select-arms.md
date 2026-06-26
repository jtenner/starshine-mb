# Optimize Instructions OI-F Identical Float Unary Select Arms

Date: 2026-06-26

## Slice

Extend the narrow identical-pure select-arm fold to direct f32/f64 unary local shells.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-float-unary-arms-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-unary-arms-probe.wat -o .tmp/oi-select-identical-float-unary-arms-probe.out.wat
```

Result: passed. The output contains direct `f32.abs`, `f64.neg`, and `f64.sqrt` roots with no `select`, confirming Binaryen `version_130` folds identical side-effect-free float unary arms when the condition is side-effect-free.

## Starshine change

Files:

- `src/passes/optimize_instructions_test.mbt`
- `src/passes/optimize_instructions.mbt`

The focused OI-F numeric-expression test now includes identical `f32.abs(local.get)` and `f64.neg(local.get)` select arms. Red-first evidence failed on the new `f32.abs` case before implementation.

Implementation adds direct f32/f64 unary local-payload matchers that reuse the existing exact-instruction/same-local-child proof. Covered float unary shells are direct same-instruction, same-local operands for `f32.abs`, `f32.neg`, `f32.ceil`, `f32.floor`, `f32.trunc`, `f32.nearest`, `f32.sqrt`, and the f64 siblings.

## Boundaries

This remains an intentionally narrow identical-arm proof:

- no arbitrary structural equality;
- no commuted operands;
- no global value equivalence;
- no float binary arithmetic equality;
- no broad NaN payload equality claims beyond the observed identical direct unary shell fold;
- no broad reference equality claims;
- no effectful or trapping condition folding.

## Validation

- Binaryen oracle command above: passed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*numeric expression arms*'`: failed `0/1` before implementation on the new `f32.abs` case; passed `1/1` after implementation.
