# OptimizeInstructions OI-M tuple-optimization eighty-three-effect boundary

Date: 2026-06-26

## Slice

This is boundary/status coverage for the public `optimize-instructions` + `tuple-optimization` neighbor on a multivalue block with eighty-three later non-selected effect calls.

It does not implement tuple-scratch reconstruction/localization. The retained mismatch remains an OI-M tuple/multivalue parity gap.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-eighty-three-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-three-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-three-effects-probe.out.wat
```

Observed Binaryen output localized the public multivalue block through `tuple.make 84` and emitted `83` `local.set` occurrences for the later effect results.

## Starshine coverage

Added focused boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with eighty-three later effects through tuple-optimization boundary`

The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(83)` and runs the public pipeline `optimize-instructions` followed by `tuple-optimization`. It asserts that Starshine keeps the public block/drop/call/local.get spelling and does not introduce `local.set` traffic.

This is intentionally not red-first implementation coverage: the expected Starshine behavior is the current documented boundary until tuple-scratch reconstruction/localization is implemented.

## Validation

- Binaryen oracle probe passed and produced `tuple.make 84` plus `83` `local.set` occurrences.
- Focused Starshine boundary test passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty-three later effects through tuple-optimization*'` reported `1/1`.

## Retained gap

Binaryen localizes the selected value through tuple/scalar scratch locals. Starshine still keeps the multivalue block and drops non-selected effects directly. This is not classified as parity or a Starshine win; it remains a tuple-scratch reconstruction/localization gap for OI-M.
