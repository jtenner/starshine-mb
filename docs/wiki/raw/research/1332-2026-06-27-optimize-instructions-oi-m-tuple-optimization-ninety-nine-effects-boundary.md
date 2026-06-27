# OptimizeInstructions OI-M: Tuple-Optimization Ninety-Nine-Effect Boundary

Date: 2026-06-27

## Scope

Boundary/status-only OI-M coverage for a public multivalue block that returns one selected value plus ninety-nine later effect results, followed by dropping every later result under the `optimize-instructions` + `tuple-optimization` neighbor.

This does not implement tuple-scratch reconstruction or localization in Starshine. It records another representable public-pipeline boundary while the broader OI-M tuple/multivalue parity gap remains open.

## Binaryen evidence

Probe: `.tmp/oi-m-tuple-optimization-ninety-nine-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization \
  .tmp/oi-m-tuple-optimization-ninety-nine-effects-probe.wat \
  -o .tmp/oi-m-tuple-optimization-ninety-nine-effects-probe.out.wat
```

Result: passed. Binaryen localized the public multivalue block through tuple/scalar scratch traffic, producing:

- one `tuple.make 100`
- ninety-nine `local.set` occurrences

## Starshine coverage

Added focused boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with ninety-nine later effects through tuple-optimization boundary`

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(99)` and asserts Starshine keeps the public `block`, `drop`, all side-effect calls, and `local.get` spelling while not introducing `local.set` traffic.

## Classification

This is a retained parity gap, not a Starshine-win claim. Binaryen's tuple-scratch localization remains the target behavior for the neighbor, but Starshine currently preserves the public multivalue/drop spelling until local tuple-scratch reconstruction/localization exists.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ninety-nine-effects-probe.wat -o .tmp/oi-m-tuple-optimization-ninety-nine-effects-probe.out.wat` — passed; `tuple.make 100` count `1`, `local.set` count `99`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ninety-nine later effects through tuple-optimization*'` — passed.
