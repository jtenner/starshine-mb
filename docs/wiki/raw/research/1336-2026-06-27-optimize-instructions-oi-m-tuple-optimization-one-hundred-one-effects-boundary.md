# OptimizeInstructions OI-M tuple-optimization one-hundred-one-effect boundary

Date: 2026-06-27

## Scope

Boundary/status slice for the public `optimize-instructions` + `tuple-optimization` neighborhood. This extends the existing public multivalue effect-count ladder from one hundred to one hundred one later non-selected effects.

## Binaryen oracle

Generated probe: `.tmp/oi-m-tuple-optimization-one-hundred-one-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-one-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-one-effects-probe.out.wat
```

Result: passed. Binaryen localized the public multivalue block through `tuple.make 102`; the output contained one `tuple.make 102` spelling and `101` `local.set` spellings.

## Starshine status

Added focused boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with one hundred one later effects through tuple-optimization boundary`

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(101)` and runs the public pipeline `['optimize-instructions', 'tuple-optimization']`. It asserts that Starshine still keeps the public multivalue `block`, every effect call, `drop`, and the selected `local.get`, and does not introduce `local.set` traffic.

This passed before and after formatting. It is boundary/status coverage only, not a parity implementation.

## Classification

The mismatch remains an open OI-M tuple-scratch reconstruction/localization gap. Binaryen's successful localization proves this is not a Binaryen/tool validation failure for the generated one-hundred-one-effect shape.

## Boundaries

This slice does not claim OI-M closure, dedicated `tuple-optimization` parity, full `simplify-locals` neighborhood parity, multi-result selected/sibling localization, or a Starshine semantic win. It only extends the public effect-count boundary coverage through one hundred one later effects.
