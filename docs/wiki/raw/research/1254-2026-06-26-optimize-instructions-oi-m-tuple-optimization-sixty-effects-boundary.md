# Optimize Instructions OI-M tuple-optimization sixty-effect boundary

Date: 2026-06-26

## Scope

This is boundary/status coverage for the public `optimize-instructions` + `tuple-optimization` neighbor. It extends the effect-count ladder to a multivalue block where the selected first result is followed by sixty later non-selected effectful results.

This does not implement tuple-scratch reconstruction/localization and does not close OI-M.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-sixty-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-sixty-effects-probe.wat -o .tmp/oi-m-tuple-optimization-sixty-effects-probe.out.wat
```

Result: passed. Binaryen localized the public multivalue block through `tuple.make 61` plus tuple/scalar scratch locals. The output contains sixty `local.set` occurrences in the probed shape.

## Starshine coverage

`src/passes/optimize_instructions_test.mbt` adds boundary/status test `optimize-instructions intentionally keeps public multivalue block with sixty later effects through tuple-optimization boundary` using `optimize_instructions_tuple_optimization_effect_boundary_fixture(60)`.

The test asserts that Starshine currently keeps the public block/drop/call/local.get spelling and does not introduce `local.set` traffic. That is an open tuple-scratch localization gap, not a semantic-safe closure claim.

## Validation

Focused boundary command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*sixty later effects through tuple-optimization*'
```

passed `1/1`.

Broader commit validation is recorded in the commit body for this slice.

## Remaining gap

Starshine still lacks the tuple/scalar scratch reconstruction/localization needed to match Binaryen's public `tuple-optimization` neighbor for these selected-lane multivalue block shapes. Continue treating OI-M tuple/multivalue parity as active until that representation and lowering gap is solved or narrowed with stronger implementation evidence.
