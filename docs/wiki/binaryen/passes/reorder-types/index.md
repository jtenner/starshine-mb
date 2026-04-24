---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md
  - ../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0157-2026-04-21-reorder-types-binaryen-research.md
  - ../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../index.md
  - ../late-pipeline-dispatch.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./ordering-cost-model-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tracker.md
  - ../index.md
  - ../late-pipeline-dispatch.md
  - ../reorder-globals/index.md
  - ../minimize-rec-groups/index.md
  - ../remove-unused-types/index.md
---

# `reorder-types`

## Role

- `reorder-types` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt); the exact local follow-along map is now in [`./starshine-strategy.md`](./starshine-strategy.md).
- Upstream `version_129` registers it publicly as `reorder-types`, plus a hidden testing sibling `reorder-types-for-testing`.
- It is **not** part of the repo's canonical no-DWARF default optimize path.
- `agent-todo.md` currently has **no dedicated `reorder-types` slice**.
- The 2026-04-24 raw primary-source manifest is [`../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md).

## The real `version_129` contract in one paragraph

Binaryen `version_129` `reorder-types` is a small **GC-only**, **closed-world-only** pass that reorders only **private** heap types to reduce cumulative encoded type-index cost. It gathers used-IR heap types plus visibility, builds a predecessor graph containing only private declared supertypes and private described types, tries 21 successor-weight propagation factors, picks the cheapest topologically valid order, then rebuilds the reordered private types through `GlobalTypeRewriter` and rewrites all affected type-bearing module surfaces.

## Why this dossier is now complete enough to follow

The earlier dossier was useful but explicitly provisional.
It still left several source-backed questions open:

- whether the ordering unit was a single type or an entire rec group
- whether public types could move
- what legality edges mattered exactly
- what profitability model Binaryen used
- which helper files and lit tests actually defined the behavior

That major gap was closed by the 2026-04-21 source-confirmation follow-up, and the 2026-04-24 follow-up closes the remaining provenance/local-status gap by adding an immutable primary-source manifest plus the dedicated Starshine strategy page.
The living folder is no longer a working-contract guess.
It now teaches the real `version_129` implementation structure and the exact current Starshine non-implementation status.

## Most important durable takeaways

- `reorder-types` is **not** a default no-DWARF preset obligation.
- It does **nothing** without GC.
- It fatally requires `--closed-world`.
- It reorders only **private** heap types; public groups remain fixed.
- The legality graph is exact and small:
  - private supertype predecessors
  - private described-type predecessors
- The objective is encoded-index byte cost, not vague hotness.
- The sort tries 21 successor-propagation factors from `0.0` to `1.0` and keeps the cheapest result.
- The pass sorts individual private heap types, then rebuilds them into one fresh large private rec group via `GlobalTypeRewriter`.
- The rewrite surface includes code, locals, declarations, tables, globals, tags, element types, type names, and preserved type-index metadata.
- `agent-todo.md` still has **no dedicated `reorder-types` slice**.

## Beginner warning: what the name still hides

The easy wrong mental model is:

- Binaryen just sorts types by frequency.

The accurate source-backed mental model is:

- Binaryen freezes public types,
- counts only used IR heap-type traffic,
- imposes topological constraints from supertypes and described types,
- tries several successor-aware weightings,
- minimizes cumulative LEB index cost,
- then rewrites the whole module to match the new private-type order.

So the pass is not a cosmetic sort.
It is a constrained whole-module type-remap pass.

## What this pass is not

- It is **not** `remove-unused-types`.
  That pass deletes dead private types.
- It is **not** `minimize-rec-groups`.
  That pass changes recursion-group structure.
- It is **not** a general GC type optimizer like `type-refining` or `type-merging`.
  It changes layout, not semantics.
- It is **not** allowed to move public boundary-visible types.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Source-confirmed algorithm, scheduler placement, helper dependencies, and future-port rules.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Official file/test map for `ReorderTypes.cpp`, `GlobalTypeRewriter`, `collectHeapTypeInfo`, pass registration, and the dedicated lit surface.
- [`./ordering-cost-model-and-boundaries.md`](./ordering-cost-model-and-boundaries.md)
  - Focused guide to the exact cost model, the legality edges, the private/public boundary, and the single-large-rec-group rebuild rule.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering unconstrained positives, supertype/described-type barriers, successor-weight tie breaks, regression coverage, and preserved public/no-GC/open-world cases.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and port map: boundary-only registry entry, active request rejection, dispatcher gap, no owner file, no active backlog slice, and the exact type-section/parser/validator/binary surfaces a future module pass would need.

## Current maintenance rule

- Treat this folder as the canonical living home for `reorder-types` in this repo.
- Keep the scheduler story honest:
  - tracked upstream
  - boundary-only locally
  - absent from the current no-DWARF parity path
- Keep the distinction from neighboring passes explicit:
  - `remove-unused-types` deletes
  - `minimize-rec-groups` repartitions groups
  - `reorder-types` relays out surviving **private** type indices
- If a future thread checks current `main` for drift, update this folder instead of reopening the old uncertainty-heavy version of the dossier.

## Sources

- [`../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md)
- [`../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md`](../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0157-2026-04-21-reorder-types-binaryen-research.md`](../../../raw/research/0157-2026-04-21-reorder-types-binaryen-research.md)
- [`../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md`](../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- Official Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderTypes.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-types.wast>
