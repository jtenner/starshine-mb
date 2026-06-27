# OptimizeInstructions OI-M tuple-optimization eighty-seven-effect boundary

## Summary

This boundary/status slice extends public `optimize-instructions` plus `tuple-optimization` coverage to a multivalue block with one selected result followed by eighty-seven later effectful siblings. Binaryen `version_130` localizes the selected value through tuple scratch reconstruction; Starshine still keeps the public multivalue block/drop/call/local.get spelling.

This is evidence for the retained OI-M tuple-scratch reconstruction/localization gap, not a parity implementation or OI-M closure.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-eighty-seven-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-seven-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-seven-effects-probe.out.wat
```

Result: passed. Binaryen produced `tuple.make 88` and `87` `local.set` occurrences, proving the probe is a successful tuple-scratch localization boundary rather than a Binaryen/tool validation failure.

## Starshine coverage

- Reused `optimize_instructions_tuple_optimization_effect_boundary_fixture(87)` in `src/passes/optimize_instructions_test.mbt`.
- Added boundary/status coverage: `optimize-instructions intentionally keeps public multivalue block with eighty-seven later effects through tuple-optimization boundary`.
- The test asserts Starshine keeps the public block, drops, all eighty-seven effect calls, and local.get spelling, and does not introduce scalar `local.set` traffic.

## Boundaries

This slice intentionally documents the mismatch. Starshine still lacks Binaryen-style tuple-scratch reconstruction/localization for this public pipeline. The result should not be counted as semantic parity for the family, only as a validated boundary that keeps the gap explicit.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 88` plus `87` scalar `local.set` occurrences.
- Focused Starshine boundary test passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty-seven later effects through tuple-optimization*'` (`1/1`).
