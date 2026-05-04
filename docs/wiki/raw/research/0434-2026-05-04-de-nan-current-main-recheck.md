# 0434 - 2026-05-04 - de-nan current-main recheck

## Question

Did Binaryen current `main` drift from the existing `version_129` `denan` contract enough to change the Starshine wiki story for `de-nan`?

## Answer

No teaching-relevant drift was found.

The reviewed current-main surface still matches the existing oracle on the important parts of the pass:

- `denan` remains a NaN-to-zero instrumentation pass, not an optimizer
- constant NaNs still rewrite to zero constants when legal
- nonconstant float/SIMD producers still route through helper calls
- defined-function entry params still get sanitized
- `local.get` and fallthrough shells are still skipped
- helper names still need collision-safe generation
- helper calls are still effect-adding
- the SIMD helper still uses lane-wise scalar checks rather than direct vector equality

## Files reviewed

- `src/passes/DeNaN.cpp`
- `src/passes/pass.cpp`
- `src/ir/properties.h`
- `src/ir/names.h`
- `src/wasm-builder.h`
- `src/pass.h`
- `test/lit/passes/denan.wast`

## Consequence for the wiki

The existing `de-nan` dossier stays current.
The right update is freshness stamping plus a port-readiness bridge, not a contract correction.

## Raw source note

- [`../../binaryen/2026-05-04-de-nan-current-main-recheck.md`](../../binaryen/2026-05-04-de-nan-current-main-recheck.md)
