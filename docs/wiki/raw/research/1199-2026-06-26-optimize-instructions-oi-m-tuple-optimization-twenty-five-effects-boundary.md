---
kind: research
status: supported
date: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-M tuple-optimization twenty-five-effect public multivalue boundary

## Question

How does Binaryen `version_130` handle a public multivalue block whose selected first lane is followed by twenty-five non-selected effectful lanes under `--optimize-instructions --tuple-optimization`, and what does Starshine currently preserve?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-twenty-five-effects-probe.wat`

The probe builds a 26-result block: a selected `i32` `local.get` followed by twenty-five calls returning a rotating set of `i64`, `f32`, `f64`, and `i32` lanes. The function drops all later lanes and returns the selected first lane.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-five-effects-probe.wat -o -
```

Binaryen succeeds and localizes through tuple scratch reconstruction, including `tuple.make 26` and scalar `local.set` traffic for the non-selected lanes.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with twenty-five later effects through tuple-optimization boundary`

The test runs the public pipeline with `optimize-instructions` plus `tuple-optimization` and asserts that Starshine keeps the block/drop/call/local.get spelling without introducing temp locals. This is intentionally not a parity claim; it extends the public neighbor boundary ladder and keeps the tuple-scratch localization gap visible.

## Classification

Boundary/status slice. Binaryen performs tuple-scratch localization for this shape; Starshine currently preserves the public multivalue block because local tuple reconstruction/localization for broad public multivalue blocks remains open under OI-M.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-five-effects-probe.wat -o -` passed and showed `tuple.make 26` plus scalar-local reconstruction.
- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*twenty-five later effects through tuple-optimization*'` passed `1/1`.
