# OptimizeInstructions OI-M tuple-optimization ninety-eight-effect boundary

## Summary

Binaryen `version_130` `--optimize-instructions --tuple-optimization` localizes a public multivalue block with one selected local value plus ninety-eight later non-selected effect calls into tuple/scalar local traffic.

Starshine intentionally keeps the public multivalue block/drop spelling for this shape because the tuple-scratch reconstruction/localization implementation is still missing. This is boundary/status coverage, not OI-M closure.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-ninety-eight-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ninety-eight-effects-probe.wat -o .tmp/oi-m-tuple-optimization-ninety-eight-effects-probe.out.wat
```

Result: passed. The Binaryen output contained one `tuple.make 99` occurrence and `98` `local.set` occurrences, showing successful tuple-scratch localization for the selected value plus ninety-eight later effect siblings.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions intentionally keeps public multivalue block with ninety-eight later effects through tuple-optimization boundary`.

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(98)` and asserts that Starshine's public pipeline with `optimize-instructions` followed by `tuple-optimization` still contains the block/drop/effect-call spelling, retains `local.get`, and does not introduce `local.set` traffic.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 99` once plus `98` `local.set` occurrences.
- Focused Starshine boundary command passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ninety-eight later effects through tuple-optimization*'`.

## Boundaries

This slice only extends public tuple-optimization effect-count boundary coverage through ninety-eight later effects. It does not implement tuple-scratch reconstruction/localization, does not reduce the multi-result selected/sibling tuple gap, and should not be treated as parity for the observed Binaryen tuple-localization shape.
