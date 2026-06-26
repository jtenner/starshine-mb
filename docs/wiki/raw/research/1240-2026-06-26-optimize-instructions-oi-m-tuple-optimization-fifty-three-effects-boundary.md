# Optimize Instructions OI-M Tuple Optimization Fifty-Three-Effect Boundary

Date: 2026-06-26

## Slice

Extend the public `optimize-instructions` + `tuple-optimization` boundary ladder to a multivalue block with fifty-three later non-selected effects.

This is boundary/status coverage only. It does not implement tuple-scratch reconstruction or close OI-M.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-fifty-three-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fifty-three-effects-probe.wat -o .tmp/oi-m-tuple-optimization-fifty-three-effects-probe.out.wat
```

Result: passed. Binaryen localizes the public multivalue block through `tuple.make 54` plus tuple/scalar scratch locals, including `local.set` / `local.get` traffic.

## Starshine status

File: `src/passes/optimize_instructions_test.mbt`.

Added focused boundary/status test:

- `optimize-instructions intentionally keeps public multivalue block with fifty-three later effects through tuple-optimization boundary`

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(53)`, runs the public pipeline with `optimize-instructions` then `tuple-optimization`, and asserts Starshine keeps block/drop/call/local.get spelling without introducing local.set traffic.

## Classification

Agent classification: open parity gap / representation boundary. Binaryen proves that the source shape is valid and localizable; Starshine intentionally records current no-localization behavior until local tuple-scratch reconstruction/localization exists.

Do not classify this as OI-M closure.

## Validation

- Binaryen oracle command above: passed and emitted `tuple.make 54` plus scratch-local traffic.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fifty-three later effects through tuple-optimization*'`: passed `1/1`.
