---
kind: research
status: supported
created: 2026-06-26
sources:
  - ../../../passes/optimize-instructions/index.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# Optimize Instructions OI-M Tuple Optimization Fifty-Nine Effects Boundary

## Question

What happens to a public multivalue block that returns one selected value and has fifty-nine later non-selected effectful results when running Binaryen `--optimize-instructions --tuple-optimization`, and how should Starshine record the current boundary?

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-fifty-nine-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fifty-nine-effects-probe.wat -o .tmp/oi-m-tuple-optimization-fifty-nine-effects-probe.out.wat
```

Result: passed. Binaryen localizes the public multivalue block through `tuple.make 60` plus tuple/scalar scratch locals.

## Starshine status coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with fifty-nine later effects through tuple-optimization boundary`

The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(59)` and runs the public pipeline with `optimize-instructions` followed by `tuple-optimization`. It asserts Starshine currently keeps the public `block` / `drop` / `call` / `local.get` spelling and does not introduce `local.set` traffic.

## Classification

This is a boundary/status slice, not a parity implementation. The retained mismatch is still an OI-M tuple-scratch reconstruction/localization gap. The result should not be used to close tuple/multivalue parity.

## Validation

- Binaryen oracle command above: passed and produced `tuple.make 60`.
- Focused Moon command: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fifty-nine later effects through tuple-optimization*'` passed `1/1`.
