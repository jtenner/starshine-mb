# Optimize-instructions OI-M tuple-optimization sixty-one-effect boundary

## Summary

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` effect-count ladder to sixty-one later non-selected effects. It is not a parity implementation slice.

The retained mismatch is the same tuple-scratch reconstruction/localization gap as the neighboring public tuple-optimization probes: Binaryen reconstructs the public multivalue block as tuple scratch traffic, while Starshine keeps the public block/drop/call/local.get spelling.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-sixty-one-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-sixty-one-effects-probe.wat -o .tmp/oi-m-tuple-optimization-sixty-one-effects-probe.out.wat
```

Result: Binaryen `version_130` accepts the probe and emits one `tuple.make 62` plus tuple/scalar scratch-local traffic. The probed output contains sixty-one `local.set` occurrences.

## Starshine coverage

Added focused public-pipeline boundary coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions intentionally keeps public multivalue block with sixty-one later effects through tuple-optimization boundary`.

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(61)` and asserts that Starshine keeps the public block/drop/call/local.get spelling and does not introduce local-set tuple scratch traffic.

## Boundary

This slice does not close OI-M. Multi-result selected/sibling localization, public tuple-scratch reconstruction, dedicated `tuple-optimization` parity, and the known full-simplify direct-HOT blocker remain open.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 62` plus sixty-one `local.set` occurrences.
- Focused Starshine test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*sixty-one later effects through tuple-optimization*'` passed `1/1`.
