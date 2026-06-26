# Optimize-instructions OI-M tuple-optimization sixty-seven-effect boundary

## Summary

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` multivalue effect-count ladder from sixty-six to sixty-seven later non-selected effects.

Binaryen `version_130` localizes the probed public multivalue block through `tuple.make 68` plus tuple/scalar scratch locals. Starshine still keeps the public `block` / `drop` / `call` / `local.get` spelling and does not introduce `local.set` traffic, so this remains an open tuple-scratch reconstruction/localization gap rather than parity closure.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-optimization-sixty-seven-effects-probe.wat`.
- Oracle command:
  - `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-sixty-seven-effects-probe.wat -o .tmp/oi-m-tuple-optimization-sixty-seven-effects-probe.out.wat`
- Oracle result: Binaryen output contains `tuple.make 68` and tuple/scalar scratch locals; the probed output had `67` `local.set` occurrences.
- Starshine boundary/status test: `optimize-instructions intentionally keeps public multivalue block with sixty-seven later effects through tuple-optimization boundary` passed and asserts that Starshine keeps `block`, `drop`, all later `call` effects, and `local.get`, while not introducing `local.set`.

## Implementation notes

- Reused `optimize_instructions_tuple_optimization_effect_boundary_fixture(67)` in `src/passes/optimize_instructions_test.mbt`.
- No optimizer behavior was changed in this slice.

## Boundaries

This test is intentionally boundary/status coverage. It does not implement Binaryen's tuple-scratch localization, does not reduce the multi-result selected/sibling reconstruction gap, and does not close OI-M. Future implementation slices still need source-backed lowering that preserves the selected lane while localizing/dropping effectful tuple siblings.
