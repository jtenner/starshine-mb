# Optimize Instructions OI-M Tuple-Optimization Seventy-Effect Boundary

Date: 2026-06-26

## Scope

Boundary/status slice for the public `optimize-instructions` + `tuple-optimization` pipeline on a multivalue block with one selected value and seventy later non-selected effectful values.

This is not a parity implementation. It preserves explicit coverage for the current Starshine tuple-scratch reconstruction/localization gap.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-seventy-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization \
  .tmp/oi-m-tuple-optimization-seventy-effects-probe.wat \
  -o .tmp/oi-m-tuple-optimization-seventy-effects-probe.out.wat
```

Result:

- command passed
- Binaryen output contains `tuple.make 71`
- Binaryen output contains `70` `local.set` occurrences

The observed Binaryen shape localizes the multivalue block through tuple scratch plus scalar-local traffic.

## Starshine coverage

File:

- `src/passes/optimize_instructions_test.mbt`

The new focused public-pipeline boundary test is:

```text
optimize-instructions intentionally keeps public multivalue block with seventy later effects through tuple-optimization boundary
```

It reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(70)` and asserts that Starshine currently keeps the public block/drop/call/local.get spelling and does not introduce `local.set` traffic.

## Validation evidence

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*seventy later effects through tuple-optimization*'
```

Result: passed `1/1`.

Full slice validation is recorded in the commit body.

## Boundary

This slice does not close OI-M tuple/multivalue parity. The retained mismatch is still the tuple-scratch reconstruction/localization gap for public `tuple-optimization` neighbor behavior. Do not report this as successful tuple-optimization parity; it is only a covered boundary/status point through seventy later effects.
