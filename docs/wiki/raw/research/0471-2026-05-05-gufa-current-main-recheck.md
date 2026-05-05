---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../binaryen/2026-05-05-gufa-current-main-recheck.md
  - ../../../binaryen/passes/gufa/index.md
  - ../../../binaryen/passes/gufa/binaryen-strategy.md
  - ../../../binaryen/passes/gufa/implementation-structure-and-tests.md
  - ../../../binaryen/passes/gufa/content-oracle-variants-and-boundaries.md
  - ../../../binaryen/passes/gufa/wat-shapes.md
  - ../../../binaryen/passes/gufa/starshine-strategy.md
  - ../../../binaryen/passes/gufa/starshine-port-readiness-and-validation.md
---

# `gufa` Current-Main Recheck

## Question

Did Binaryen drift from the current `gufa` teaching contract, and what should the wiki expose for future Starshine port work?

## Finding

No teaching-relevant drift was found on the reviewed surfaces.

The refreshed reading is still:

- plain `gufa` is the shared `GUFA.cpp` engine with `optimizing = false, castAll = false`
- `gufa-optimizing` reuses the same engine and adds nested `dce` + `vacuum`
- `gufa-cast-all` reuses the same engine and adds `addNewCasts`
- the core oracle remains the closed-world `ContentOracle` / `PossibleContents` model
- the dedicated lit files still split the public contract the same way

## Durable updates from this recheck

- Added a new raw source manifest: [`../../binaryen/2026-05-05-gufa-current-main-recheck.md`](../../binaryen/2026-05-05-gufa-current-main-recheck.md).
- Added a new Starshine port-readiness / validation bridge for plain `gufa`.
- Refreshed the plain `gufa` wiki pages to use the 2026-05-05 manifest as the newest source anchor.

## Why this matters

The plain `gufa` folder is already teachable, but future ports still need an explicit bridge from the oracle contract to local ownership, validation, and sibling behavior. The new port-readiness page keeps that gap visible without implying a contract change.
