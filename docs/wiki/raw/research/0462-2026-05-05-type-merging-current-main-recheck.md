---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-type-merging-current-main-recheck.md
  - ../binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../binaryen/passes/type-merging/index.md
  - ../../binaryen/passes/type-merging/binaryen-strategy.md
  - ../../binaryen/passes/type-merging/implementation-structure-and-tests.md
  - ../../binaryen/passes/type-merging/dfa-partitions-casts-and-refinalization.md
  - ../../binaryen/passes/type-merging/wat-shapes.md
  - ../../binaryen/passes/type-merging/starshine-strategy.md
  - ../../binaryen/passes/type-merging/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast_tests.mbt
  - ../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../../src/validate/env.mbt
---

# `type-merging` current-main recheck and port-readiness follow-up

## Why this follow-up exists

The `type-merging` dossier was already source-correct and teaching-complete for the `version_129` contract, but it still lacked two maintenance pieces:

1. a fresh current-main bridge that rechecked the reviewed surfaces against the live upstream source, and
2. a dedicated Starshine port-readiness / validation page that turns the boundary-only status into a concrete future landing map.

This follow-up records both changes together so the folder's freshness layer and local implementation planning stay in sync.

## Primary source rechecked

The refreshed source bridge rechecked official Binaryen `main` sources for:

- `src/passes/TypeMerging.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-merging.wast`

The review stayed aligned with the existing contract on the reviewed surface.
The only surfaced `main`-vs-`version_129` difference was a comment typo fix in `TypeMerging.cpp`, not a teaching-relevant semantic change.

## Durable updates

- Added `docs/wiki/raw/binaryen/2026-05-05-type-merging-current-main-recheck.md`.
- Added `docs/wiki/binaryen/passes/type-merging/starshine-port-readiness-and-validation.md`.
- Refreshed the folder's living pages so the new freshness bridge is visible from the overview, strategy, and catalog layers.

## Starshine takeaway

The local Starshine status did not change:

- `type-merging` remains boundary-only.
- There is still no owner file or active dispatcher implementation.
- The pass still needs a module-level type-graph rewrite story before it can be ported honestly.

The new port-readiness page documents the exact local surfaces and validation ladder needed for that future work.

## Pages updated by this follow-up

- `docs/wiki/raw/binaryen/2026-05-05-type-merging-current-main-recheck.md`
- `docs/wiki/raw/research/0462-2026-05-05-type-merging-current-main-recheck.md`
- `docs/wiki/binaryen/passes/type-merging/index.md`
- `docs/wiki/binaryen/passes/type-merging/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-merging/dfa-partitions-casts-and-refinalization.md`
- `docs/wiki/binaryen/passes/type-merging/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-merging/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
