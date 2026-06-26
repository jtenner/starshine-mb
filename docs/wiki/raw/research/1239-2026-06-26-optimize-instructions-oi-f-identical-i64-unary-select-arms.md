# Optimize Instructions OI-F Identical i64 Unary Select Arms

Date: 2026-06-26

## Slice

Extend the narrow identical-pure select-arm fold from direct i32 unary local shells to the matching direct i64 unary local shell subset.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-i64-unary-arms-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-i64-unary-arms-probe.wat -o .tmp/oi-select-identical-i64-unary-arms-probe.out.wat
```

Result: passed. The output contains `i64.clz` and `i64.eqz` and no `select`, confirming Binaryen `version_130` folds identical side-effect-free i64 unary arms when the condition is side-effect-free.

## Starshine change

Files:

- `src/passes/optimize_instructions_test.mbt`
- `src/passes/optimize_instructions.mbt`

The focused OI-F test now includes identical `i64.clz(local.get)` select arms. Red-first evidence failed on that new case before implementation.

Implementation adds `optimize_instructions_i64_unary_local_payloads_are_identical_pure(...)` and shares the exact-instruction/local-child matcher with the existing i32 unary helper. Covered i64 unary shells are direct same-instruction, same-local operands for `i64.eqz`, `i64.clz`, `i64.ctz`, `i64.popcnt`, `i64.extend8_s`, `i64.extend16_s`, `i64.extend32_s`, `i64.extend_i32_s`, `i64.extend_i32_u`, `i64.trunc_sat_f32_*`, `i64.trunc_sat_f64_*`, and `i64.reinterpret_f64`.

## Boundaries

This remains an intentionally narrow identical-arm proof:

- no arbitrary structural equality;
- no commuted operands;
- no global value equivalence;
- no NaN payload equality claims;
- no broad reference equality claims;
- no effectful or trapping condition folding.

## Validation

- Binaryen oracle command above: passed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*numeric expression arms*'`: failed `0/1` before implementation on the new `i64.clz` case; passed `1/1` after implementation.
