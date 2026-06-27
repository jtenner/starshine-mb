# OptimizeInstructions OI-M Tuple-Optimization Eighty-Effect Boundary

Date: 2026-06-26

## Summary

This is boundary/status coverage, not a Starshine parity implementation. Binaryen `version_130` localizes a public multivalue block with one selected lane and eighty later effectful lanes under `--optimize-instructions --tuple-optimization`, using tuple scratch reconstruction. Starshine still keeps the public multivalue block/drop/call/local.get spelling because local tuple-scratch reconstruction/localization is not implemented for this family.

The mismatch remains an open OI-M tuple-scratch reconstruction/localization gap. Do not treat this note as OI-M closure.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-eighty-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-effects-probe.out.wat
```

Observed Binaryen output contains `tuple.make 81` and `80` `local.set` occurrences, proving Binaryen localized the selected value and non-selected effects through tuple/scalar scratch locals for this public tuple-optimization neighbor shape.

## Starshine coverage

Added public-pipeline boundary coverage in `src/passes/optimize_instructions_test.mbt` using `optimize_instructions_tuple_optimization_effect_boundary_fixture(80)`. The test asserts that Starshine successfully runs `optimize-instructions` plus `tuple-optimization`, preserves the public `block` / `drop` / all `call` effects / `local.get` spelling, and does not introduce `local.set` traffic.

This test intentionally passes with current behavior and documents the retained mismatch. Red-first is not applicable because this slice is a boundary/status guard rather than an implementation.

## Retained boundary

Starshine lacks the local tuple-scratch reconstruction/localization needed to match Binaryen's tuple-optimization neighbor output for this public multivalue shape. Broader OI-M work remains open for multi-result selected/sibling tuple-scratch localization, dedicated `tuple-optimization` / `simplify-locals` neighbor reductions, and direct-HOT replay blockers.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 81` plus `80` `local.set` occurrences.
- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty later effects through tuple-optimization*'` passed `1/1`.

Full slice validation is recorded in the commit that references this note.
