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

# OptimizeInstructions OI-M tuple-optimization ten-effect public multivalue boundary

## Question

How does Binaryen `version_130` handle a public multivalue block whose first lane is selected and whose ten later lanes are dropped when `--optimize-instructions` is followed by `--tuple-optimization`, and does Starshine currently match that neighbor-pipeline shape?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-ten-effects-probe.wat`

The probe returns the first lane from a public block with result type `(i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32)` and drops the ten later lanes produced by calls `$side_a` through `$side_j`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ten-effects-probe.wat -o -
```

Observed Binaryen output localizes the full tuple into a scratch tuple local, extracts the selected first lane into a scalar local, then reconstructs the dropped later lanes through scalar scratch locals and nested block/drop traffic. This is the same tuple-scratch localization family observed for the earlier one- through nine-effect public multivalue probes.

## Starshine coverage

Added public-pipeline boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with ten later effects through tuple-optimization boundary`

The test runs `optimize-instructions` followed by `tuple-optimization` and asserts that Starshine keeps the public block/drop/call/local.get spelling and does not introduce `local.set` tuple-scratch traffic.

## Classification

Boundary/status slice, not parity implementation. Binaryen's output is the current parity target for this neighbor pipeline, but Starshine does not yet have tuple-scratch reconstruction/localization for the public WAT multivalue block shape. This extends the documented dedicated `tuple-optimization` boundary beyond the earlier one-, two-, three-, four-, five-, six-, seven-, eight-, and nine-effect probes.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ten-effects-probe.wat -o -` passed and showed tuple-scratch plus scalar-local localization.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ten later effects through tuple-optimization*'` passed `1/1`.
