# OptimizeInstructions OI-M tuple-optimization one-hundred-four-effect boundary

Date: 2026-06-27

## Scope

This is boundary/status coverage for the public `optimize-instructions` + `tuple-optimization` neighborhood. It extends the existing public multivalue effect-count ladder from one hundred three to one hundred four later non-selected effects.

Binaryen `version_130` was probed with:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-four-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-four-effects-probe.out.wat
```

The oracle accepted the fixture and localized the selected first lane through tuple scratch:

- one `tuple.make 105`,
- `104` `local.set` occurrences,
- and scalar/tuple local traffic for the later non-selected effect calls.

## Starshine behavior

Starshine still keeps the public multivalue block/drop/call/local.get spelling for this shape when running `optimize-instructions` followed by `tuple-optimization`. This is retained as an OI-M tuple-scratch reconstruction/localization gap, not parity closure and not a Starshine-win classification.

## Test evidence

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with one hundred four later effects through tuple-optimization boundary`

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(104)` and asserts that Starshine keeps the block, drops, every effect call, and the selected `local.get`, without introducing `local.set` traffic.

This is a passing boundary test by design; red-first is not applicable because the slice documents and guards an intentionally retained mismatch boundary rather than implementing tuple-scratch localization.

## Boundaries

This slice does not implement tuple-scratch reconstruction/localization. It does not close OI-M, full `simplify-locals`, dedicated `tuple-optimization`, multi-result selected/sibling tuple-scratch localization, or public parser/text coverage gaps.
