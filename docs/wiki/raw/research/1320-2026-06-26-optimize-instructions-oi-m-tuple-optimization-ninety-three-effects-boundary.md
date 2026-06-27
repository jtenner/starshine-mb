# Optimize-instructions OI-M tuple-optimization ninety-three-effect boundary

Date: 2026-06-26

## Summary

This boundary/status slice extends public `optimize-instructions` + `tuple-optimization` coverage to a multivalue block with ninety-three later non-selected effects. It is not a parity implementation slice: Binaryen localizes through tuple scratch traffic, while Starshine still keeps the public multivalue block/drop spelling.

## Oracle evidence

Fresh Binaryen probe:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization \
  .tmp/oi-m-tuple-optimization-ninety-three-effects-probe.wat \
  -o .tmp/oi-m-tuple-optimization-ninety-three-effects-probe.out.wat
```

Observed output evidence:

- `tuple.make 94` occurs once.
- `local.set` occurs `93` times.

This is classified as successful Binaryen tuple-scratch localization, not a tool failure.

## Starshine evidence

The focused Starshine status test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(93)` and the public pass sequence `optimize-instructions`, `tuple-optimization`. Starshine keeps the `block`, `drop`s, all ninety-three effect calls, and `local.get`, and does not introduce `local.set` traffic.

## Boundary

This is boundary/status coverage only. The mismatch remains an OI-M tuple-scratch reconstruction/localization gap for public multivalue blocks with many later effects. It does not close OI-M, implement multi-result selected-child localization, or prove tuple-optimization neighbor parity.
