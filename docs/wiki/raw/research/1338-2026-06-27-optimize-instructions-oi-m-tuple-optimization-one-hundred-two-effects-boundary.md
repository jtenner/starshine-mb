# OptimizeInstructions OI-M tuple-optimization one-hundred-two-effect boundary

Date: 2026-06-27

## Scope

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` multivalue neighbor ladder to a block with one selected local and one hundred two later non-selected effect calls.

Binaryen `version_130` was probed with:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-two-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-two-effects-probe.out.wat
```

The oracle accepted the WAT and localized the multivalue block through tuple scratch reconstruction:

- one `tuple.make 103`,
- one hundred two `local.set` occurrences,
- and scalar local traffic for the non-selected effect results.

## Starshine status

Starshine still keeps the public multivalue block/drop/call/local.get spelling for this family. That is a retained OI-M parity gap, not a Starshine-win claim: tuple-scratch reconstruction/localization remains unimplemented for this public `tuple-optimization` neighbor shape.

## Test evidence

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with one hundred two later effects through tuple-optimization boundary`

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(102)`, asserts the public pipeline succeeds, and verifies Starshine still keeps the block/drop/effect-call/local.get spelling without introducing `local.set` traffic.

This is not red-first implementation coverage; it is an explicit boundary/status slice documenting the current mismatch against Binaryen's tuple-scratch localization.

## Boundaries

This slice does not implement tuple-scratch reconstruction, multi-result sibling localization, full `simplify-locals` parity, or dedicated `tuple-optimization` parity. It only extends the public effect-count boundary evidence through one hundred two later effects.
