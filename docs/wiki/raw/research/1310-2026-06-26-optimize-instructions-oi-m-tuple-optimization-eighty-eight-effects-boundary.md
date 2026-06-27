# OptimizeInstructions OI-M tuple-optimization eighty-eight-effect boundary

## Summary

Boundary/status-only OI-M coverage now extends the public `optimize-instructions` plus `tuple-optimization` ladder to eighty-eight later non-selected effects. Binaryen `version_130` localizes the public multivalue block through tuple scratch traffic (`tuple.make 89` plus scalar locals). Starshine intentionally keeps the public multivalue `block` / `drop` / effect-call / `local.get` spelling until tuple-scratch reconstruction and localization is implemented.

This is not a parity implementation slice. It records one more valid, source-backed mismatch point in the public text pipeline.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-eighty-eight-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-eight-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-eight-effects-probe.out.wat
```

Result: passed. Binaryen output contains `tuple.make 89` and `88` `local.set` occurrences.

## Starshine coverage

- Added focused boundary/status coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions intentionally keeps public multivalue block with eighty-eight later effects through tuple-optimization boundary`.
- The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(88)` through the public pipeline with `optimize-instructions` and `tuple-optimization`.
- The assertion locks the current Starshine boundary: public block/drop/effect-call/local.get spelling remains, and no tuple/scalar `local.set` traffic is introduced.

## Boundary

The mismatch remains a tuple-scratch reconstruction/localization gap. This note must not be used to claim OI-M closure, Binaryen parity, or a Starshine semantic win. It only extends public boundary evidence for a valid text fixture with eighty-eight later effects.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 89` plus `88` `local.set` occurrences.
- Focused boundary test passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty-eight later effects through tuple-optimization*'` (`1/1`).
