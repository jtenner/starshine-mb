# Optimize Instructions OI-M Tuple Optimization Fifty-Four Effects Boundary

Date: 2026-06-26

## Slice

Add boundary/status coverage for the public `optimize-instructions` plus `tuple-optimization` neighbor on a multivalue block with fifty-four later non-selected effectful siblings.

This is intentionally not a parity implementation slice. It extends the public tuple effect-count ladder and keeps the tuple-scratch localization gap visible.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-fifty-four-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fifty-four-effects-probe.wat -o .tmp/oi-m-tuple-optimization-fifty-four-effects-probe.out.wat
```

Result: passed. Binaryen localizes the public multivalue block through `tuple.make 55` plus tuple/scalar scratch locals; the output contains `tuple.make 55` and `local.set` traffic.

## Starshine coverage

Files:

- `src/passes/optimize_instructions_test.mbt`

The new focused boundary/status test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(54)` and runs the public pass pipeline with `optimize-instructions` followed by `tuple-optimization`.

The assertion deliberately records the current Starshine boundary:

- the public multivalue `block` spelling remains;
- the later effectful calls and `drop`s remain;
- the selected `local.get` remains;
- no tuple-scratch `local.set` traffic is introduced.

## Classification

This remains an open OI-M parity gap, not an intentional Starshine win. Binaryen demonstrates successful tuple-scratch localization for this public shape. Starshine keeps the direct public multivalue spelling until tuple-scratch reconstruction/localization is implemented safely.

## Validation

- Binaryen oracle command above: passed and produced `tuple.make 55` plus tuple/scalar scratch locals.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fifty-four later effects through tuple-optimization*'`: passed `1/1`.
