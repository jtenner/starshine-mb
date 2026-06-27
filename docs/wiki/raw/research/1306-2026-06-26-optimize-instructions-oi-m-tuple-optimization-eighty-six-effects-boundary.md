# OptimizeInstructions OI-M tuple-optimization eighty-six-effect boundary

## Summary

This boundary/status slice extends the public `tuple-optimization` neighbor ladder to a public multivalue block with one selected value followed by eighty-six non-selected effectful siblings. Binaryen `version_130` localizes the selected value through tuple scratch plus scalar locals under `--optimize-instructions --tuple-optimization`; Starshine still keeps the public block/drop/call/local.get spelling until tuple-scratch reconstruction/localization is implemented.

This is boundary coverage, not closure of the OI-M tuple-scratch reconstruction gap.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-eighty-six-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-six-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-six-effects-probe.out.wat
```

Result: passed. The Binaryen output contains `tuple.make 87` and `86` `local.set` occurrences, showing successful tuple-scratch localization for this valid public multivalue shape.

## Starshine coverage

- Reused `optimize_instructions_tuple_optimization_effect_boundary_fixture(86)` in `src/passes/optimize_instructions_test.mbt`.
- Added boundary/status coverage: `optimize-instructions intentionally keeps public multivalue block with eighty-six later effects through tuple-optimization boundary`.
- The test asserts Starshine keeps the public `block` / `drop` / every effect call / `local.get` spelling and does not introduce `local.set` traffic.

## Boundaries

This does not implement Binaryen's tuple-scratch reconstruction/localization. The mismatch remains a parity gap for public `tuple-optimization` and broader OI-M tuple/multivalue work. Treat the retained Starshine spelling as current status only, not a semantic win or accepted final divergence.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 87` plus `86` `local.set` occurrences.
- Focused Starshine boundary test passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty-six later effects through tuple-optimization*'` (`1/1`).
