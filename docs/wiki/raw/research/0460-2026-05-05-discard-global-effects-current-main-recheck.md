---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-discard-global-effects-current-main-recheck.md
  - ../binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../binaryen/2026-04-24-global-effects-primary-sources.md
  - ./0353-2026-04-25-discard-global-effects-source-dossier.md
  - ../../binaryen/passes/discard-global-effects/index.md
  - ../../binaryen/passes/discard-global-effects/binaryen-strategy.md
  - ../../binaryen/passes/discard-global-effects/metadata-shapes.md
  - ../../binaryen/passes/discard-global-effects/starshine-strategy.md
  - ../../binaryen/passes/discard-global-effects/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/global-effects/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/ir/effects.mbt
  - ../../../../src/ir/analysis_cache.mbt
  - ../../../../src/passes/pass_common.mbt
---

# `discard-global-effects` current-main recheck

Date: 2026-05-05

## Scope

This follow-up refreshes the Binaryen cleanup-sibling dossier with a current-main source recheck and closes the missing Starshine port-readiness bridge for the same pass.

The pass is small, but it is easy to misread: it clears pass-managed `Function.effects` summaries rather than rewriting WAT. That makes it a lifecycle boundary for `generate-global-effects`, not a body optimizer.

## Sources reviewed

### Local sources

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/global-effects/`
- `docs/wiki/binaryen/passes/discard-global-effects/`
- `docs/wiki/raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md`
- `src/passes/optimize.mbt`
- `src/ir/effects.mbt`
- `src/ir/analysis_cache.mbt`
- `src/passes/pass_common.mbt`

### Primary online sources

Captured in [`../binaryen/2026-05-05-discard-global-effects-current-main-recheck.md`](../binaryen/2026-05-05-discard-global-effects-current-main-recheck.md):

- Binaryen `version_129` release page
- `src/passes/GlobalEffects.cpp` at `version_129` and current `main`
- `src/passes/pass.cpp` at `version_129` and current `main`
- Binaryen Optimizer Cookbook
- `src/wasm.h` and `src/ir/effects.h` as retained baseline sources for the storage/consumer model

## Findings

## 1. The cleanup sibling contract is unchanged on current `main`

The current-main review still sees the same implementation shape: public registration, per-function summary clearing, and pass-runner lifecycle guidance for summary invalidation.

That means the dossier can keep teaching `discard-global-effects` as a metadata-only cleanup pass rather than as a WAT optimizer.

## 2. The missing teaching gap was the Starshine port bridge

The folder already had the overview, Binaryen strategy, shape catalog, implementation map, and Starshine status page. What it lacked was a small explicit port-readiness page that explains why there is still no local cleanup pass and what would need to exist first.

This note fills that gap by linking the cleanup sibling back to the producer-side `global-effects` dossier and forward to the local cache-invalidation analogues.

## 3. Starshine still has only the local analogue, not the Binaryen pass

Starshine currently has revision-keyed HOT effect summaries and cache invalidation, not persistent module-level `Function.effects` metadata.

So the correct local story remains:

- keep `global-effects` boundary-only
- keep `discard-global-effects` unregistered
- invalidate the HOT cache on revision change
- add a cleanup pass only if persistent module-level summaries ever land

## Pages updated

- [`../../binaryen/passes/discard-global-effects/index.md`](../../binaryen/passes/discard-global-effects/index.md)
- [`../../binaryen/passes/discard-global-effects/binaryen-strategy.md`](../../binaryen/passes/discard-global-effects/binaryen-strategy.md)
- [`../../binaryen/passes/discard-global-effects/metadata-shapes.md`](../../binaryen/passes/discard-global-effects/metadata-shapes.md)
- [`../../binaryen/passes/discard-global-effects/starshine-strategy.md`](../../binaryen/passes/discard-global-effects/starshine-strategy.md)
- [`../../binaryen/passes/discard-global-effects/starshine-port-readiness-and-validation.md`](../../binaryen/passes/discard-global-effects/starshine-port-readiness-and-validation.md)
- [`../../binaryen/passes/discard-global-effects/implementation-structure-and-tests.md`](../../binaryen/passes/discard-global-effects/implementation-structure-and-tests.md)
- [`../../binaryen/passes/discard-global-effects` folder](../../binaryen/passes/discard-global-effects/)
- [`../../binaryen/passes/index.md`](../../binaryen/passes/index.md)
- [`../../binaryen/passes/tracker.md`](../../binaryen/passes/tracker.md)
- [`../../index.md`](../../index.md)
- [`../../log.md`](../../log.md)

## Remaining questions

- If Starshine ever stores persistent module-level effect summaries, should cleanup be a public pass name or an internal invalidation helper?
- Should the local wiki keep calling this an optimizer pass, or stick with the more precise metadata-cleanup framing?
