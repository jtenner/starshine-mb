---
kind: entity
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md
  - ../../../raw/research/0426-2026-04-27-type-finalizing-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md
  - ../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0192-2026-04-21-type-finalizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../agent-todo.md
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./leaf-types-public-boundaries-and-sibling-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-types/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
---

# `type-finalizing`

## Role

- `type-finalizing` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer.
- It still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- It does **not** appear in the saved generated-artifact `-O4z` skipped-pass audit.
- `agent-todo.md` currently has **no dedicated `type-finalizing` slice**.
- The 2026-04-24 source refresh found no current Starshine owner file and no preset role.
- It has a close local-registry sibling:
  - local `type-un-finalizing`
  - upstream public `type-unfinalizing`

So this folder is another explicit, source-backed upstream-only registry expansion.

## Why this pass matters

- The original parity queues and the first tracker-expansion wave are already dossier-covered, so this thread needed a newly justified registry target.
- The local boundary-only registry still names `type-finalizing`, but before this thread there was no dedicated living folder explaining what the pass actually does.
- The pass sits directly beside already-documented GC/type neighbors like `remove-unused-types`, `type-merging`, and `unsubtyping`.
- It is easy to misread from the name alone as a broad type optimizer.
- The folder now has immutable 2026-04-24 and 2026-04-27 primary-source manifests, a dedicated Starshine status/port-strategy page, and a first-slice validation bridge.
- The real `version_129` contract is much smaller and more specific:
  - rewrite only **private** heap types
  - only finalize **leaf** private types
  - use one global type-section rewrite helper
  - share the same engine with the unfinalizing sibling

## Beginner summary

A good beginner mental model is:

- Binaryen looks at the module's private nominal heap types,
- decides which of them it is safe to toggle between open and final,
- and then rebuilds the type graph coherently across the whole module.

So this pass is best taught as:

- **private type final/open cleanup**
- not dead-type removal
- not subtype-edge pruning
- not field/type inference
- not a default optimization-pipeline pass

## Most important durable takeaways

- `type-finalizing` is a GC-only **module** pass.
- It does **not** ask for closed-world mode.
- It only modifies **private** heap types.
- In finalizing mode, it only modifies **leaf** private types.
- In unfinalizing mode, the sibling can reopen private types unconditionally.
- The visible work happens through a tiny `GlobalTypeRewriter` subclass that only toggles `setOpen(...)` on selected type-builder entries.
- The pass has a dedicated lit file that proves:
  - public types stay unchanged
  - private leaf types can change
  - parents with subtypes do not become final
  - function heap types participate too

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract, helper dependencies, and algorithmic phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass and its sibling split.
- [`./leaf-types-public-boundaries-and-sibling-split.md`](./leaf-types-public-boundaries-and-sibling-split.md)
  Focused guide to the easiest part to misread: private-vs-public visibility, why only leaf types may become final, and how the `type-unfinalizing` sibling differs.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly module/WAT shape catalog for the main positive, preserved, and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map, with exact local registry, request-rejection, type-model, WAT, validator, and binary-code locations.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge for a future Starshine module pass: local surfaces, safe first slices, shape-to-validation checklist, Binaryen oracle lanes, and open design questions.

## Current maintenance rule

- Treat this folder as the canonical home for future `type-finalizing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from neighboring GC/type passes explicit:
  - `remove-unused-types` removes dead types
  - `type-merging` merges compatible live types
  - `unsubtyping` removes unnecessary subtype edges
  - `type-finalizing` only toggles open/final state on a safe private subset
- Keep the sibling naming split explicit too:
  - local registry: `type-un-finalizing`
  - upstream Binaryen public pass: `type-unfinalizing`

## Sources

- [`../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md)
- [`../../../raw/research/0426-2026-04-27-type-finalizing-port-readiness.md`](../../../raw/research/0426-2026-04-27-type-finalizing-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md)
- [`../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0192-2026-04-21-type-finalizing-binaryen-research.md`](../../../raw/research/0192-2026-04-21-type-finalizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>
