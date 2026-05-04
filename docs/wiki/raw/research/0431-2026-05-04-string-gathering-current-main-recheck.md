---
kind: research
status: supported
last_reviewed: 2026-05-04
sources:
  - ../binaryen/2026-05-04-string-gathering-current-main-recheck.md
  - ../binaryen/2026-04-23-string-gathering-primary-sources.md
  - ./0377-2026-04-25-string-gathering-port-readiness.md
  - ./0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md
  - ../../../wiki/binaryen/passes/string-gathering/index.md
  - ../../../wiki/binaryen/passes/string-gathering/binaryen-strategy.md
  - ../../../wiki/binaryen/passes/string-gathering/implementation-structure-and-tests.md
  - ../../../wiki/binaryen/passes/string-gathering/reuse-naming-and-ordering.md
  - ../../../wiki/binaryen/passes/string-gathering/wat-shapes.md
  - ../../../wiki/binaryen/passes/string-gathering/starshine-strategy.md
  - ../../../wiki/binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/string_gathering.mbt
  - ../../../../src/passes/string_gathering_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
related:
  - ../../../wiki/binaryen/passes/string-gathering/index.md
  - ../../../wiki/binaryen/passes/string-gathering/binaryen-strategy.md
  - ../../../wiki/binaryen/passes/string-gathering/implementation-structure-and-tests.md
  - ../../../wiki/binaryen/passes/string-gathering/reuse-naming-and-ordering.md
  - ../../../wiki/binaryen/passes/string-gathering/wat-shapes.md
  - ../../../wiki/binaryen/passes/string-gathering/starshine-strategy.md
  - ../../../wiki/binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md
---

# `string-gathering` current-main recheck

## Question

The `string-gathering` dossier already had a working contract, but its freshness anchor still pointed at the 2026-04-25 current-main bridge. This run asked whether current Binaryen `main` had changed the teaching-important contract and whether the local Starshine pages should point at more exact code anchors.

## Method

- Re-read the `string-gathering` wiki pages and the repo wiki schema.
- Rechecked official Binaryen `main` sources for `StringLowering.cpp`, `pass.cpp`, `passes.h`, `string-utils.h`, `string-utils.cpp`, `module-utils.h`, `wasm-traversal.h`, `string-gathering.wast`, and `propagate-globals-globally.wast`.
- Rechecked local Starshine anchors in `src/passes/string_gathering.mbt`, `src/passes/string_gathering_test.mbt`, `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, and `src/cmd/cmd_wbtest.mbt`.

## Findings

- No teaching-relevant current-main drift was found. The durable Binaryen contract still matches the dossier:
  - standalone `StringGathering` still lives inside `StringLowering.cpp`
  - the pass still scans exact `StringConst` slots and rewrites those exact slots later
  - it still scans function bodies and module-level code separately
  - reusable globals remain strict: defined, immutable, exact non-null string type, and direct `string.const` initializer
  - first reusable global in module order still wins
  - the pass still performs only a validity-first reorder before `reorder-globals`
- The local implementation status is unchanged: Starshine still has the direct module pass, the active registry entry, the dispatcher arm, and the explicit CLI acceptance test.
- The main local hygiene win was anchor precision: the living pages can now point readers at exact line ranges instead of only whole-file links for the direct pass and validation surface.

## Durable wiki updates made

- Added [`../binaryen/2026-05-04-string-gathering-current-main-recheck.md`](../binaryen/2026-05-04-string-gathering-current-main-recheck.md).
- Refreshed the living `string-gathering` pages with the new current-main bridge and exact local code anchors.
- Updated `docs/wiki/index.md` and `docs/wiki/log.md` so the refreshed source bridge is discoverable from the catalog and audit trail.

## Follow-up

No implementation work was done. The dossier remains a source-backed maintenance guide for a now-active pass; future work should keep the current direct module pass and the `reorder-globals` boundary separate.
