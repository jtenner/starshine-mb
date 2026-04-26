---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-discard-global-effects-implementation-test-map.md
  - ../binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../binaryen/2026-04-24-global-effects-primary-sources.md
  - ../../binaryen/passes/discard-global-effects/index.md
  - ../../binaryen/passes/discard-global-effects/implementation-structure-and-tests.md
related:
  - ../../binaryen/passes/discard-global-effects/binaryen-strategy.md
  - ../../binaryen/passes/discard-global-effects/metadata-shapes.md
  - ../../binaryen/passes/discard-global-effects/starshine-strategy.md
  - ../../binaryen/passes/global-effects/implementation-structure-and-tests.md
---

# `discard-global-effects` implementation/test-map follow-up

## Question

The existing `discard-global-effects` dossier correctly explained the metadata-only cleanup contract, but it lacked the standard owner/helper/test-map page used by neighboring pass dossiers. That made it too easy for a future reader to miss the pass-runner lifecycle hook and to over-expect a standalone WAT diff.

## What was rechecked

Primary-source surfaces rechecked on 2026-04-26:

- Binaryen `version_129` and current `main` `GlobalEffects.cpp`
- Binaryen `version_129` and current `main` `pass.cpp`
- Binaryen `version_129` and current `main` `pass.h`
- Binaryen `version_129` `wasm.h`
- Binaryen `version_129` `ir/effects.h`
- Binaryen Optimizer Cookbook pass-authoring guidance
- Existing Starshine effect-cache and registry surfaces documented in the living dossier

## Findings

- The cleanup sibling remains tiny and source-stable: `DiscardGlobalEffects::run(...)` resets every module function's stored `effects` pointer.
- `pass.cpp` is more important than the first dossier said because it proves two lifecycle surfaces: public registration for manual scheduling and automatic cleanup before passes that report they can add effects.
- `pass.h` provides the capability seam (`addsEffects()`), so this pass should be taught as part of Binaryen's metadata invalidation design, not just as a CLI-visible no-op.
- No dedicated `discard-global-effects.wast` expected-output file was found. That is not a missing rewrite proof; it follows from the fact that the pass normally changes only metadata.
- Existing producer/consumer tests in the `global-effects` dossier remain the best behavior evidence for why clearing stale metadata matters.

## Wiki changes made from this research

- Added `docs/wiki/raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md` as the primary-source bridge.
- Added `docs/wiki/binaryen/passes/discard-global-effects/implementation-structure-and-tests.md`.
- Refreshed the landing, Binaryen strategy, metadata-shape, Starshine strategy, catalogs, tracker, and log so the folder is now a deep dossier rather than a small source note.

## Remaining uncertainty

A metadata-observing Binaryen API test could prove `discard-global-effects` directly, but the reviewed CLI/lit source set does not expose one. Until then, docs should keep the no-standalone-WAT-diff caveat explicit and use source plus producer/consumer tests as the evidence chain.
