---
kind: entity
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md
  - ../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md
  - ../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0193-2026-04-21-type-un-finalizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../agent-todo.md
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./private-boundaries-sibling-split-and-no-leaf-rule.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-finalizing/index.md
  - ../remove-unused-types/index.md
  - ../type-merging/index.md
---

# `type-un-finalizing` / upstream `type-unfinalizing`

## Role

- `type-unfinalizing` is a real public Binaryen pass.
- Starshine currently tracks the same concept under the local boundary-only alias `type-un-finalizing`.
- It is currently **unimplemented** in Starshine's active optimizer.
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- It does **not** appear in the saved generated-artifact `-O4z` skipped-pass audit.
- `agent-todo.md` currently has **no dedicated `type-un-finalizing` slice**.

So this folder is another explicit, source-backed upstream-only registry expansion. As of the 2026-04-27 refresh, it is anchored by immutable raw primary-source manifests, a dedicated Starshine status / future-port map, and a port-readiness / validation bridge rather than only the older 0193 research note.

## Why this pass matters

- The main parity queues and the first tracker-expansion wave are already dossier-covered.
- The immediately previous thread closed the dedicated `type-finalizing` dossier, which made the missing sibling gap even clearer.
- The local boundary-only registry still names `type-un-finalizing`, but before this thread there was no dedicated living folder explaining what the sibling actually does.
- It sits directly beside already-documented GC/type neighbors like `type-finalizing`, `remove-unused-types`, `type-merging`, and `unsubtyping`.
- It is easy to misread from the name alone as either a synonym for `type-finalizing` or a broad “open all types” preparatory pass.
- The real `version_129` contract is much smaller and more exact:
  - rewrite only **private** heap types
  - reopen those private types without the leaf-only restriction
  - use the same tiny `GlobalTypeRewriter` + `setOpen(...)` rewrite engine as `type-finalizing`
  - stay outside the default optimize presets

## Beginner summary

A good beginner mental model is:

- Binaryen finds the module's private nominal heap types,
- rebuilds the type graph coherently,
- and marks those private types **open** again.

So this pass is best taught as:

- **private type reopening**
- not type deletion
- not type merging
- not subtype pruning
- not a default optimization-pipeline pass

## Most important durable takeaways

- `type-unfinalizing` is a GC-only **module** pass.
- It does **not** ask for closed-world mode.
- It only modifies **private** heap types.
- Unlike `type-finalizing`, it does **not** require the selected type to be a leaf.
- The visible work happens through the same tiny `GlobalTypeRewriter` subclass used by `type-finalizing`.
- The actual mutation is just `setOpen(true)` on the selected type-builder entries.
- The dedicated lit file proves:
  - private final types reopen
  - public final types stay final
  - function heap types participate too
  - the sibling is a real public pass, not just an internal mode flag

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract, helper dependencies, and algorithmic phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass and its sibling split.
- [`./private-boundaries-sibling-split-and-no-leaf-rule.md`](./private-boundaries-sibling-split-and-no-leaf-rule.md)
  Focused guide to the easiest part to misread: private-vs-public visibility, why the sibling drops the leaf-only rule, and how it differs from `type-finalizing`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly module/WAT shape catalog for the main positive, preserved, and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: local boundary-only registry entry, active request rejection, no owner file, no preset role, no backlog slice, and the exact type-section / parser / validator / binary surfaces a future port must reuse.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge for a future Starshine port: current boundary-only invariants, local type/WAT/validator/binary surfaces, first safe slices, shape-to-validation checklist, Binaryen oracle lanes, and open private-type / naming design questions.

## Current maintenance rule

- Treat this folder as the canonical home for future `type-un-finalizing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from neighboring GC/type passes explicit:
  - `type-finalizing` finalizes safe private leaves
  - `remove-unused-types` removes dead types
  - `type-merging` merges compatible live types
  - `unsubtyping` removes unnecessary subtype edges
  - `type-unfinalizing` only reopens the private subset Binaryen is allowed to rewrite
- Keep the local-vs-upstream naming split explicit too:
  - local registry: `type-un-finalizing`
  - upstream Binaryen public pass: `type-unfinalizing`

## Sources

- [`../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md)
- [`../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md`](../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md)
- [`../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0193-2026-04-21-type-un-finalizing-binaryen-research.md`](../../../raw/research/0193-2026-04-21-type-un-finalizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>
