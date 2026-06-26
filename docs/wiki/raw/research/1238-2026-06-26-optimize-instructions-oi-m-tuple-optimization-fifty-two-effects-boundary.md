---
kind: research
status: supported
created: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../wiki/binaryen/passes/optimize-instructions/index.md
  - ../../../../src/passes/optimize_instructions_test.mbt
---

# OI-M tuple-optimization fifty-two-effect boundary

## Summary

This is boundary/status evidence for the public `optimize-instructions` + `tuple-optimization` neighbor, not an implementation slice. It extends the public multivalue effect-count ladder to fifty-two later non-selected effects.

Binaryen `version_130` localizes the probed public multivalue block through tuple scratch reconstruction (`tuple.make 53` plus tuple/scalar locals). Starshine still keeps the public `block` / `drop` / `call` / `local.get` spelling and does not introduce `local.set` traffic because tuple-scratch reconstruction/localization remains an open OI-M gap.

## Oracle

Probe: `.tmp/oi-m-tuple-optimization-fifty-two-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fifty-two-effects-probe.wat -o .tmp/oi-m-tuple-optimization-fifty-two-effects-probe.out.wat
```

Result: passed. The Binaryen output contains `tuple.make 53` and `local.set $scratch_*` traffic.

## Starshine coverage

Added focused boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with fifty-two later effects through tuple-optimization boundary`

The test runs the public pipeline with `['optimize-instructions', 'tuple-optimization']`, then asserts that the optimized function still contains the public block/drop/call/local.get spelling and no `local.set` scratch traffic.

## Validation

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fifty-two later effects through tuple-optimization*'
# passed 1/1
```

## Boundary

This deliberately does not close OI-M tuple/multivalue parity. The retained difference is an open tuple-scratch reconstruction/localization gap, not a Starshine win or semantic-safe acceptance claim.
