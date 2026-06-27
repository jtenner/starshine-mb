# Optimize Instructions OI-M Tuple Optimization Eighty-Nine-Effect Boundary

## Summary

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` multivalue effect-count ladder to eighty-nine later non-selected effects.

Binaryen `version_130` localizes the public multivalue block through tuple scratch reconstruction (`tuple.make 90`) and scalar local traffic. Starshine still keeps the public block/drop/call/local.get spelling. This remains a tuple-scratch reconstruction/localization parity gap, not a Starshine win or an OI-M closure.

## Oracle

Probe: `.tmp/oi-m-tuple-optimization-eighty-nine-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-nine-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-nine-effects-probe.out.wat
```

Observed Binaryen output:

- `tuple.make 90` count: `1`
- `local.set` count: `89`

## Starshine coverage

Added boundary/status-only coverage in `src/passes/optimize_instructions_test.mbt` using `optimize_instructions_tuple_optimization_effect_boundary_fixture(89)`:

- test name: `optimize-instructions intentionally keeps public multivalue block with eighty-nine later effects through tuple-optimization boundary`
- pipeline: `optimize-instructions`, then `tuple-optimization`
- assertions: Starshine output still contains the public `block`, `drop`s, every side-effect call, and `local.get`, while not introducing `local.set` traffic.

## Validation

- Binaryen oracle command passed and produced `tuple.make 90` plus `89` `local.set` occurrences.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty-nine later effects through tuple-optimization*'` passed (`1/1`).

## Boundary

This is intentionally not a red-first behavior implementation. It records a known retained OI-M mismatch so future tuple-scratch reconstruction work can distinguish successful Binaryen localization from Starshine's current public spelling. The broader OI-M gap remains open.
