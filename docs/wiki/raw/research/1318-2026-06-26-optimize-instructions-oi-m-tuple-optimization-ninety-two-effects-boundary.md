# Optimize-instructions OI-M tuple-optimization ninety-two-effect boundary

## Slice

This OI-M boundary/status slice extends the public `optimize-instructions` plus `tuple-optimization` effect-count ladder to a multivalue block with ninety-two later non-selected effect calls.

The slice is intentionally not a parity implementation. It keeps the retained Starshine mismatch visible while adding another valid public fixture for the tuple-scratch reconstruction/localization gap.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-ninety-two-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ninety-two-effects-probe.wat -o .tmp/oi-m-tuple-optimization-ninety-two-effects-probe.out.wat
```

Result: passed. Binaryen `version_130` localized the probe through one `tuple.make 93` and ninety-two `local.set` occurrences.

## Starshine coverage

Files:

- `src/passes/optimize_instructions_test.mbt`

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ninety-two later effects through tuple-optimization*'
```

Result: passed `1/1`.

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(92)` and asserts that the public pipeline still preserves the multivalue `block`, `drop` chain, every effect call, and the selected `local.get`, while not introducing `local.set` traffic.

## Boundaries

This is boundary/status evidence only. The observed mismatch remains an open tuple-scratch reconstruction/localization gap: Binaryen materializes tuple/scalar scratch traffic, while Starshine keeps the public multivalue block/drop spelling.

This does not claim:

- multi-result selected-child tuple extraction parity;
- multi-result sibling scalarization;
- `simplify-locals` or full `tuple-optimization` neighbor parity;
- direct-HOT replay repair for the existing `InvalidChildRef` full-simplify blocker;
- semantic equivalence beyond the narrow public fixture evidence.
