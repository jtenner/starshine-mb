---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../binaryen/2026-04-24-global-effects-primary-sources.md
  - ./0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/global-effects/index.md
  - ../../binaryen/passes/discard-global-effects/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/ir/effects.mbt
  - ../../../../src/ir/analysis_cache.mbt
  - ../../../../src/passes/pass_common.mbt
  - ../../../../src/passes/pass_manager.mbt
---

# `discard-global-effects` source dossier

Date: 2026-04-25

## Scope

This follow-up adds a canonical wiki home for Binaryen's public `discard-global-effects` cleanup pass.

The existing [`global-effects`](../../binaryen/passes/global-effects/index.md) folder already mentioned the sibling, but future readers still had to infer too much from scattered lifecycle notes. The gap was worth closing because `discard-global-effects` is a real registered Binaryen pass with a different contract from `generate-global-effects`: it clears pass-managed metadata instead of producing it.

## Sources reviewed

### Local sources

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/global-effects/`
- `docs/wiki/raw/research/0168-2026-04-21-global-effects-binaryen-research.md`
- `docs/wiki/raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md`
- `src/passes/optimize.mbt`
- `src/ir/effects.mbt`
- `src/ir/analysis_cache.mbt`
- `src/passes/pass_common.mbt`
- `src/passes/pass_manager.mbt`

### Primary online sources

Captured in [`../binaryen/2026-04-25-discard-global-effects-primary-sources.md`](../binaryen/2026-04-25-discard-global-effects-primary-sources.md):

- Binaryen `version_129` release page
- `src/passes/GlobalEffects.cpp` at `version_129` and current `main`
- `src/passes/pass.cpp` at `version_129` and current `main`
- `src/wasm.h` at `version_129`
- `src/ir/effects.h` at `version_129`
- Binaryen Optimizer Cookbook

## Findings

## 1. The pass is real but intentionally metadata-only

`discard-global-effects` is registered publicly in Binaryen's pass registry, immediately beside `generate-global-effects`. Its reviewed owner-file implementation is tiny: iterate over module functions and clear each function's stored global-effect summary.

That means the pass transforms in-memory function metadata, not Wasm bodies. A beginner expecting a WAT diff should be told directly that a standalone run may print the same module before and after.

## 2. The important shape is summary lifecycle, not syntax

The transformed shapes are best taught as pass-state shapes:

- no stored summary -> unchanged
- generated summary -> cleared
- stale summary after an effect-adding transform -> cleared before a later consumer trusts it
- producer plus consumer pipeline -> `generate-global-effects` can enable later optimizations, while `discard-global-effects` prevents stale cross-pass reuse

The source-backed risk is not validation failure. The risk is a later optimization using stale call-effect knowledge and moving or deleting code unsafely.

## 3. Starshine has no local public cleanup sibling today

Local status after the recheck:

- `src/passes/optimize.mbt:128-142` lists `global-effects` as boundary-only, but does not list `discard-global-effects`.
- Unknown pass requests for `discard-global-effects` therefore stay outside the local registry rather than producing the boundary-only producer error.
- `src/ir/effects.mbt:5-279` defines local HOT effect masks and query helpers.
- `src/ir/analysis_cache.mbt:34`, `src/ir/analysis_cache.mbt:70-81`, and `src/ir/analysis_cache.mbt:217-227` cache function-local effect summaries by HOT revision.
- `src/passes/pass_common.mbt:212-234` builds those local summaries on demand.
- `src/passes/pass_manager.mbt:8717-8720` invalidates the local analysis cache after a HOT function revision changes.

So Starshine already has internal cache invalidation for function-local HOT effect summaries. It does not have Binaryen-style persistent module-level `Function.effects` summaries, and therefore does not need a public `discard-global-effects` pass until it adds a persistent global-effects producer.

## 4. Future-port rule

If Starshine eventually ports `generate-global-effects` as persistent interprocedural metadata, it should decide whether to:

1. mirror Binaryen's public `discard-global-effects` pass name, or
2. keep summary discard purely internal to a module-analysis cache.

Until that design is chosen, the wiki should keep `discard-global-effects` as upstream-only source-backed pass research, cross-linked from `global-effects`, not as a local boundary-only registry promise.

## Pages updated

- [`../../binaryen/passes/discard-global-effects/index.md`](../../binaryen/passes/discard-global-effects/index.md)
- [`../../binaryen/passes/discard-global-effects/binaryen-strategy.md`](../../binaryen/passes/discard-global-effects/binaryen-strategy.md)
- [`../../binaryen/passes/discard-global-effects/metadata-shapes.md`](../../binaryen/passes/discard-global-effects/metadata-shapes.md)
- [`../../binaryen/passes/discard-global-effects/starshine-strategy.md`](../../binaryen/passes/discard-global-effects/starshine-strategy.md)
- [`../../binaryen/passes/global-effects/index.md`](../../binaryen/passes/global-effects/index.md)
- [`../../binaryen/passes/global-effects/binaryen-strategy.md`](../../binaryen/passes/global-effects/binaryen-strategy.md)
- [`../../binaryen/passes/global-effects/metadata-naming-and-consumers.md`](../../binaryen/passes/global-effects/metadata-naming-and-consumers.md)
- [`../../binaryen/passes/global-effects/starshine-strategy.md`](../../binaryen/passes/global-effects/starshine-strategy.md)
- [`../../binaryen/passes/index.md`](../../binaryen/passes/index.md)
- [`../../binaryen/passes/tracker.md`](../../binaryen/passes/tracker.md)
- [`../../index.md`](../../index.md)
- [`../../log.md`](../../log.md)

## Remaining questions

- If Starshine gains persistent module-level effect summaries, should the public cleanup pass be registered under the exact upstream name, or should summary invalidation remain an implementation detail?
- Should future docs classify `discard-global-effects` as an optimizer pass, an analysis lifecycle pass, or both? This run calls it a pass-state cleanup transformation to avoid overstating body rewrites.
