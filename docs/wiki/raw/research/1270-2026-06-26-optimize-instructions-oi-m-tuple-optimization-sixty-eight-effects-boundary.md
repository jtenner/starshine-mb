# Optimize-instructions OI-M tuple-optimization sixty-eight-effect boundary

## Summary

This boundary/status slice extends the public `optimize-instructions` plus `tuple-optimization` multivalue effect-count ladder from sixty-seven to sixty-eight later non-selected effects.

Binaryen `version_130` localizes the probed public multivalue block through a `tuple.make 69` tuple plus scalar and tuple scratch locals. Starshine still keeps the original public multivalue `block` / `drop` / `call` / `local.get` spelling and does not introduce local scratch traffic. This is retained as an open tuple-scratch reconstruction/localization gap, not as parity closure.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-optimization-sixty-eight-effects-probe.wat`.
- Oracle command:
  - `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-sixty-eight-effects-probe.wat -o .tmp/oi-m-tuple-optimization-sixty-eight-effects-probe.out.wat`
- Oracle result: the output contains `tuple.make 69` and `68` `local.set` occurrences for tuple/scalar scratch localization.
- Starshine focused boundary/status test: `optimize-instructions intentionally keeps public multivalue block with sixty-eight later effects through tuple-optimization boundary` passed (`1/1`). It asserts retained `block`, `drop`, all effectful `call` roots, and `local.get`, while asserting no `local.set` traffic appears.

## Implementation notes

- Reused `optimize_instructions_tuple_optimization_effect_boundary_fixture(68)` in `src/passes/optimize_instructions_test.mbt`.
- No optimizer behavior changed in this slice.
- The fixture remains public-pipeline WAT coverage because the direct tuple-scratch reconstruction/localization work is still blocked on broader tuple/multivalue lowering and representation support.

## Boundaries

This slice intentionally documents a mismatch. It does not implement tuple-scratch reconstruction, sibling selected-lane localization, full `tuple-optimization` parity, full `simplify-locals` neighbor parity, direct-HOT tuple lowering for this public shape, or any multi-result selected/sibling tuple localization. Future slices should treat this as a reproducible open OI-M gap.
