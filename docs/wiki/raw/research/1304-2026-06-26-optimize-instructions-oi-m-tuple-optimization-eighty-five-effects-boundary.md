# OptimizeInstructions OI-M tuple-optimization eighty-five-effect boundary

## Summary

This boundary/status slice extends public `optimize-instructions` + `tuple-optimization` coverage to a multivalue block with eighty-five later non-selected effects. It does not implement tuple-scratch reconstruction/localization.

Binaryen `version_130` localizes the shape through tuple/scalar scratch traffic, while Starshine intentionally keeps the public block/drop/call/local.get spelling for now. The mismatch remains an OI-M tuple-scratch parity gap.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-eighty-five-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-five-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-five-effects-probe.out.wat
```

Result: passed. The Binaryen output contains `tuple.make 86` and `85` `local.set` occurrences.

## Starshine coverage

Added boundary-only public-pipeline coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with eighty-five later effects through tuple-optimization boundary`

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(85)` and asserts that Starshine keeps:

- `block`
- `drop`
- every side-effect call (`call (Func 0)` through `call (Func 84)`)
- `local.get`

It also asserts Starshine does not introduce `local.set` traffic.

## Boundary

This is a successful boundary/status slice only. It should not be treated as OI-M closure or as proof that the Binaryen tuple-scratch behavior is semantically optional. The open parity work remains implementing or otherwise source-backed resolving tuple-scratch reconstruction/localization for public multivalue blocks and related `tuple-optimization` / `simplify-locals` neighbor shapes.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 86` plus `85` `local.set` occurrences.
- Focused Starshine boundary test passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty-five later effects through tuple-optimization*'` (`1/1`).
