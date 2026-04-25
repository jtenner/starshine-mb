---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md
  - ../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md
  - ../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md
  - ../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../agent-todo.md
  - ../tracker.md
  - ../reorder-globals/index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./small-module-threshold-scoring-and-proof.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../reorder-globals/index.md
  - ../global-struct-inference/index.md
  - ../tracker.md
---

# `reorder-globals-always`

## Role

- `reorder-globals-always` is a real upstream Binaryen sibling of [`../reorder-globals/index.md`](../reorder-globals/index.md).
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `reorder-globals-always` slice**.
- The folder now has a sibling-specific immutable raw primary-source manifest and a dedicated Starshine status/port-strategy page.
- It shares the same implementation engine as `reorder-globals`, but changes the exact policy for small modules and for candidate scoring.

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened tracker wave are already dossier-covered, so this folder is an explicit justified expansion for another real local-registry pass name that still lacked a dedicated landing page.
- The local registry still exposes `reorder-globals-always` as its own boundary-only name, but before this thread the wiki only mentioned it inside the broader `reorder-globals` folder.
- It is easy to mis-teach the sibling as either:
  - just a hidden boolean mode,
  - just a lit-test convenience,
  - or just the same as production `reorder-globals`.
- The real source-backed contract is sharper:
  - same sorting engine,
  - no public `< 128` early return,
  - exact smooth synthetic cost model `1.0 + (i / 128.0)`,
  - and one important internal caller in `GlobalStructInference` that uses it for fresh-global fixup.
- This refreshed folder now also has a dedicated proof page that puts the cutoff removal, the exact cost formula, the strongest lit-backed small-module examples, and the current-`main` no-drift result in one place.

## Beginner summary

A good beginner mental model is:

- Binaryen still counts global uses,
- still respects imports and initializer dependencies,
- and still searches for a better declaration order,
- but this sibling runs even on tiny modules and uses a smooth fake cost model so the differences stay visible.

So this pass is best taught as:

- **the small-module / test / internal-fixup sibling of `reorder-globals`**
- not a different global-optimization algorithm
- not the ordinary production late-tail pass
- not a generic dead-global or constant-propagation pass

## Most important durable takeaways

- The pass is created by the same `ReorderGlobals.cpp` engine as `reorder-globals`.
- The shared algorithm still includes:
  - parallel `global.get` + `global.set` counting
  - module-code counting
  - initializer dependency DAG construction
  - four candidate order families
  - imports-first ordering
  - earliest-best tie behavior
  - declaration-list rebuild plus `updateMaps()`
- The sibling-specific differences are:
  - no public `< 128` bailout
  - exact smooth synthetic cost scoring `1.0 + (i / 128.0)`
  - dedicated official lit-backed small-module proof in `reorder-globals.wast`
  - no reviewed current-`main` drift on `ReorderGlobals.cpp`
- The strongest source-backed internal interaction is:
  - `GlobalStructInference` runs nested `reorder-globals-always` after adding helper globals.
- Current Starshine keeps the pass boundary-only, rejects active requests, omits it from presets, has no owner file or sibling-specific backlog slice, and would need a whole-module `GlobalIdx` remap layer before it could run.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the exact sibling contract, the shared engine, and the precise policy split from ordinary `reorder-globals`.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the sibling's public and practical role.
- [`./small-module-threshold-scoring-and-proof.md`](./small-module-threshold-scoring-and-proof.md)
  Focused source-confirmed guide to the exact `< 128` cutoff removal, exact `1.0 + (i / 128.0)` scoring formula, strongest lit-backed proof families, nested `GlobalStructInference` caller, and current-`main` no-drift result.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly module/WAT shape catalog showing tiny-module positives, dependency-preserving reorders, internal-fixup shapes, and main bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: boundary-only registry entry, request rejection, preset omission, no owner file, no sibling backlog slice, and the numeric `GlobalIdx` repair surface a faithful port would need.

## Current maintenance rule

- Treat this folder as the canonical home for future `reorder-globals-always` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from [`../reorder-globals/index.md`](../reorder-globals/index.md) explicit: the default pass is the production late-tail size pass, while this sibling removes the tiny-module cutoff and uses the smooth scoring model.
- Keep the internal-fixup story explicit too: this is not only a test convenience; upstream `GlobalStructInference` also depends on it.

## Sources

- [`../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md`](../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md)
- [`../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md`](../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md)
- [`../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md`](../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md)
- [`../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md`](../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- [`../reorder-globals/index.md`](../reorder-globals/index.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
