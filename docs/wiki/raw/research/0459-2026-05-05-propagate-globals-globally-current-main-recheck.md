---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../binaryen/2026-04-24-propagate-globals-globally-primary-sources.md
  - ./0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md
  - ./0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
  - ./0162-2026-04-21-propagate-globals-globally-binaryen-research.md
  - ../../binaryen/passes/propagate-globals-globally/index.md
  - ../../binaryen/passes/propagate-globals-globally/binaryen-strategy.md
  - ../../binaryen/passes/propagate-globals-globally/implementation-structure-and-tests.md
  - ../../binaryen/passes/propagate-globals-globally/shared-engine-and-startup-boundaries.md
  - ../../binaryen/passes/propagate-globals-globally/wat-shapes.md
  - ../../binaryen/passes/propagate-globals-globally/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
---

# `propagate-globals-globally` current-main recheck

## Question

The `propagate-globals-globally` dossier already had a source-corrected contract, but it needed a freshness-layer current-main recheck so the living pages could stay honest about upstream drift.

## Source review

Reviewed current-main sources:

- `SimplifyGlobals.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `propagate-globals-globally.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/propagate-globals-globally.wast>

## Findings

- Current `main` still exposes `propagate-globals-globally` as a public Binaryen pass.
- The implementation still lives in `SimplifyGlobals.cpp`, with the narrow `PropagateGlobalsGlobally` subclass calling `propagateConstantsToGlobals()` only.
- The broader `simplify-globals` sibling still owns function-body propagation through `propagateConstantsToCode()`.
- The dedicated lit file still proves the startup/global-only boundary by leaving ordinary function-body `global.get` uses intact for this pass.
- No teaching-relevant drift was found on the checked surfaces.

## Living-page updates

- Refreshed the `propagate-globals-globally` overview, Binaryen strategy, implementation/test-map, startup-boundary guide, WAT-shape catalog, and Starshine strategy page to cite the 2026-05-05 freshness layer.
- Refreshed the shared catalogs and log so the new recheck is discoverable from the living index pages.

## Conclusion

This is a freshness update, not a contract revision. `propagate-globals-globally` remains upstream-only in Starshine and still needs a real module-pass implementation before any parity claim changes.
