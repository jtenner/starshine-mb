# OptimizeInstructions OI-M tuple-optimization eighty-two-effect boundary

Date: 2026-06-26

## Slice

Boundary/status slice for public `optimize-instructions` followed by `tuple-optimization` on a multivalue block whose selected result has eighty-two later non-selected effectful siblings.

This does not implement tuple-scratch reconstruction/localization. It extends the public effect-count ladder so future tuple-localization work has narrower parser/pipeline evidence at this size.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-eighty-two-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-two-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-two-effects-probe.out.wat
```

Observed Binaryen output:

- `tuple.make 83`: `1`
- `local.set`: `82`

This confirms Binaryen localizes the public multivalue block through tuple/scalar scratch traffic at eighty-two later effects.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with eighty-two later effects through tuple-optimization boundary`

The test runs the public pass pipeline with `optimize-instructions` then `tuple-optimization` using `optimize_instructions_tuple_optimization_effect_boundary_fixture(82)`. It asserts Starshine keeps the public multivalue `block` / `drop` / effect `call` / `local.get` spelling and does not introduce `local.set` traffic.

## Validation

- Binaryen oracle passed and produced `tuple.make 83` plus `82` `local.set` occurrences.
- Focused Starshine boundary test passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty-two later effects through tuple-optimization*'` reported `1/1`.

## Retained mismatch

This remains a parity gap, not a Starshine win. Binaryen performs tuple-scratch localization while Starshine preserves the original public multivalue block spelling. The retained blocker is local tuple-scratch reconstruction/localization for public multivalue blocks with effectful siblings.
