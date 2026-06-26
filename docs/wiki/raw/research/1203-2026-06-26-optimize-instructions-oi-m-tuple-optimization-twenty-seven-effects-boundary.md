---
title: OptimizeInstructions OI-M tuple-optimization twenty-seven-effect public multivalue boundary
date: 2026-06-26
kind: research
status: supported
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-M tuple-optimization twenty-seven-effect public multivalue boundary

## Summary

This slice extends the OI-M public `optimize-instructions` + `tuple-optimization` neighbor boundary to a 28-result block: one selected public `i32` lane followed by twenty-seven non-selected effectful lanes.

Binaryen `version_130` localizes the public multivalue block through `tuple.make 28` and tuple/scalar scratch locals. Starshine still keeps the original public block/drop/call/local.get spelling and does not synthesize tuple-scratch reconstruction for this family.

This is boundary/status evidence only, not parity. The retained mismatch remains the same open tuple-scratch localization gap tracked by `[O4Z-AUDIT-OI-M]`.

## Oracle evidence

Probe:

- `.tmp/oi-m-tuple-optimization-twenty-seven-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-seven-effects-probe.wat -o -
```

Observed Binaryen behavior:

- The selected `local.get $x` is stored in a scalar scratch local.
- The twenty-seven later calls are packed into `tuple.make 28` and extracted into tuple/scalar scratch locals.
- The final result reloads the selected scalar scratch.

## Starshine coverage

Added public pipeline boundary test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with twenty-seven later effects through tuple-optimization boundary`

The test asserts Starshine keeps the block/drop/call/local.get spelling and does not introduce `local.set` traffic for this public multivalue shape.

## Boundary

Do not classify this as semantic parity. Binaryen performs visible tuple-scratch localization here; Starshine intentionally leaves the shape unchanged until the tuple-scratch reconstruction/localization implementation exists. Future work should either implement that family or reduce the direct-HOT/full-simplify tuple blockers documented in the OI-M backlog.
