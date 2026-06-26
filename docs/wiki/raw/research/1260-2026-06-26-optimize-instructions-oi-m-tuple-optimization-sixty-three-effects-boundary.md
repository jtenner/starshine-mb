# Optimize-instructions OI-M tuple-optimization sixty-three-effect boundary

## Summary

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` effect-count ladder to sixty-three later non-selected effects.

Binaryen `version_130` localizes the probed public multivalue block into `tuple.make 64` plus tuple/scalar scratch locals. Starshine still keeps the public multivalue block/drop/call/local.get spelling and does not introduce tuple-scratch reconstruction/localization traffic. This remains an open tuple-scratch parity gap, not an OI-M closure.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-optimization-sixty-three-effects-probe.wat`.
- Oracle command:
  - `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-sixty-three-effects-probe.wat -o .tmp/oi-m-tuple-optimization-sixty-three-effects-probe.out.wat`
- Oracle result: the output contains `tuple.make 64` and sixty-three `local.set` occurrences in the probed output.
- Starshine focused boundary/status test: `optimize-instructions intentionally keeps public multivalue block with sixty-three later effects through tuple-optimization boundary` passes and asserts the retained `block` / `drop` / `call` / `local.get` spelling with no `local.set` traffic.

## Implementation notes

- Reused `optimize_instructions_tuple_optimization_effect_boundary_fixture(63)` in `src/passes/optimize_instructions_test.mbt`.
- No optimizer implementation changed in this slice.

## Boundaries

This is boundary/status coverage only. It does not claim successful tuple-scratch reconstruction, scalar-local localization, full `tuple-optimization` parity, full `simplify-locals` neighbor parity, or direct-HOT repair of the known full-simplify `InvalidChildRef` blocker.
