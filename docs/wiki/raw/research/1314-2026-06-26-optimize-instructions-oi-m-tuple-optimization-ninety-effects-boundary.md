# Optimize Instructions OI-M Tuple Optimization Ninety-Effect Boundary

## Summary

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` multivalue effect-count ladder to ninety later non-selected effects. Binaryen `version_130` localizes the selected value through tuple-scratch reconstruction (`tuple.make 91`) plus scalar-local traffic; Starshine still keeps the original public multivalue block/drop/call/local.get spelling.

This is boundary evidence, not parity implementation. The retained mismatch remains the known tuple-scratch reconstruction/localization gap.

## Oracle

Probe: `.tmp/oi-m-tuple-optimization-ninety-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ninety-effects-probe.wat -o .tmp/oi-m-tuple-optimization-ninety-effects-probe.out.wat
```

Observed Binaryen output contains `tuple.make 91` once and `90` `local.set` occurrences.

## Starshine change

- Reused `optimize_instructions_tuple_optimization_effect_boundary_fixture` in `src/passes/optimize_instructions_test.mbt`.
- Added focused boundary/status coverage: `optimize-instructions intentionally keeps public multivalue block with ninety later effects through tuple-optimization boundary`.
- The test asserts Starshine keeps the public `block` / `drop` / every effect `call` / `local.get` spelling and does not introduce `local.set` traffic.

## Validation

- Binaryen oracle command above passed and produced the expected tuple-scratch localization evidence.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ninety later effects through tuple-optimization*'` passed (`1/1`).

## Boundaries

- Covered: public parser/pipeline success and current Starshine keep-spelling behavior for ninety later non-selected effects under `optimize-instructions` plus `tuple-optimization`.
- Still open: implementing Binaryen-style tuple-scratch localization/reconstruction, direct-HOT multi-result sibling localization, and broader `simplify-locals` / `tuple-optimization` neighbor parity.
