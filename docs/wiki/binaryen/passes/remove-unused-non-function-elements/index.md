---
kind: entity
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-05-remove-unused-non-function-elements-current-main-recheck.md
  - ../../../raw/research/0458-2026-05-05-remove-unused-non-function-elements-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-remove-unused-non-function-elements-current-main-line-anchor-refresh.md
  - ../../../raw/research/0509-2026-05-06-remove-unused-non-function-elements-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md
  - ../../../raw/research/0408-2026-04-26-remove-unused-non-function-elements-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md
  - ../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0194-2026-04-21-remove-unused-non-function-elements-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-rooting-and-defined-vs-imported-functions.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
---

# `remove-unused-non-function-elements` / upstream `remove-unused-nonfunction-module-elements`

## Role

- `remove-unused-nonfunction-module-elements` is a real public Binaryen pass.
- Starshine now exposes the upstream-compatible module pass spelling `remove-unused-nonfunction-module-elements`; the older local dashed name remains a historical dossier label, not the active CLI spelling.
- It is implemented in Starshine's active optimizer as a sibling mode on the existing RUME machinery; the current local status and validation evidence are mapped in [`./starshine-strategy.md`](./starshine-strategy.md).
- The 2026-04-24 raw primary-source manifest is [`../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md); the 2026-04-26 port-readiness recheck is [`../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md); the 2026-05-05 current-main recheck is [`../../../raw/binaryen/2026-05-05-remove-unused-non-function-elements-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-remove-unused-non-function-elements-current-main-recheck.md); the 2026-05-06 line-anchor refresh is [`../../../raw/binaryen/2026-05-06-remove-unused-non-function-elements-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-06-remove-unused-non-function-elements-current-main-line-anchor-refresh.md).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- It does **not** appear in the saved generated-artifact `-O4z` skipped-pass audit.
- `agent-todo.md` currently has **no dedicated `remove-unused-non-function-elements` slice**; the implemented slice reused the existing full-RUME code path directly.

So this folder is now the source-backed status page for the implemented upstream-compatible sibling pass.

## Why this pass matters

- The main parity queues and the first tracker-expansion wave are already dossier-covered.
- The historical local registry once named `remove-unused-non-function-elements`; the original 0194 dossier made the upstream sibling understandable, the 2026-04-24 refresh added immutable provenance plus a Starshine follow-along map, and the 2026-04-26 implementation updated Starshine to the upstream-compatible active spelling.
- It sits directly beside the already-documented `remove-unused-module-elements` engine and is easy to mis-teach as either:
  - just another spelling for full RUME, or
  - a pass that literally never changes anything related to functions.
- The real `version_129` contract is smaller and more exact:
  - use the same `RemoveUnusedModuleElements.cpp` engine as full RUME
  - root **all defined functions** before running the shared analyzer
  - still remove dead non-function module structure
  - still allow some function-adjacent cleanup such as imported-function removal, function-type cleanup, and no-op start removal

## Beginner summary

A good beginner mental model is:

- Binaryen first marks every **defined function body** as live,
- then runs the ordinary module-element cleanup logic,
- so the pass mainly deletes dead memories, tables, globals, tags, segments, and other non-function module structure without deleting dead defined helper functions.

So this pass is best taught as:

- **RUME with defined functions force-kept**
- not a brand-new algorithm
- not a promise to preserve every possible function-related declaration

## Most important durable takeaways

- This is a **module** pass built on the same shared engine as `remove-unused-module-elements`.
- The sibling split is one constructor toggle: `rootAllFunctions = true`.
- The pass roots **defined** functions, not every function declaration of every kind.
- Because of that, unused imported functions can still disappear.
- The pass still uses the ordinary RUME roots for:
  - exports
  - start
  - active imported-parent segments
  - startup-trap retention unless TNH is enabled
- The pass still performs shared cleanup such as:
  - removing dead memories / tables / globals / tags / segments
  - compacting unused function types
  - dropping a no-op start declaration while preserving the defined body itself

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract, the current-main freshness bridge, helper dependencies, and algorithmic phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass and its sibling split.
- [`./shared-engine-rooting-and-defined-vs-imported-functions.md`](./shared-engine-rooting-and-defined-vs-imported-functions.md)
  Focused guide to the easiest part to misread: same shared engine as RUME, but with defined-functions-only rooting rather than a blanket “keep every function thing forever” policy.
- [`./module-shapes.md`](./module-shapes.md)
  Beginner-friendly module-shape catalog for the main positive, preserved, and surprising families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status, implementation map, and validation evidence, including exact registry / dispatcher / reusable full-RUME code locations.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation and validation bridge: policy-first sequencing, required differential tests, Binaryen oracle spelling, and signoff ladder.

## Current maintenance rule

- Treat this folder as the canonical home for future `remove-unused-non-function-elements` research and port planning.
- Keep it marked as an active Starshine module pass under the upstream-compatible spelling unless the registry status changes again.
- Keep the split from neighboring passes explicit:
  - `remove-unused-module-elements` can delete dead defined functions
  - `remove-unused-nonfunction-module-elements` force-keeps defined functions before the shared cleanup
  - `remove-unused-types` is a different closed-world GC/type cleanup pass
- Keep the local-vs-upstream naming split explicit too:
  - historical local dossier label: `remove-unused-non-function-elements`
  - active Starshine and upstream Binaryen public pass: `remove-unused-nonfunction-module-elements`

## Sources

- [`../../../raw/binaryen/2026-05-05-remove-unused-non-function-elements-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-remove-unused-non-function-elements-current-main-recheck.md)
- [`../../../raw/research/0458-2026-05-05-remove-unused-non-function-elements-current-main-recheck.md`](../../../raw/research/0458-2026-05-05-remove-unused-non-function-elements-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md)
- [`../../../raw/research/0408-2026-04-26-remove-unused-non-function-elements-port-readiness.md`](../../../raw/research/0408-2026-04-26-remove-unused-non-function-elements-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md)
- [`../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md`](../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0194-2026-04-21-remove-unused-non-function-elements-binaryen-research.md`](../../../raw/research/0194-2026-04-21-remove-unused-non-function-elements-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
