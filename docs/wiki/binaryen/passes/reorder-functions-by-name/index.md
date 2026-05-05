---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md
  - ../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md
  - ../../../raw/binaryen/2026-05-05-reorder-functions-by-name-current-main-recheck.md
  - ../../../raw/research/0481-2026-05-05-reorder-functions-by-name-current-main-recheck.md
  - ../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md
  - ../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lexical-order-proof-and-boundaries.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../reorder-functions/index.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
  - ../reorder-types/index.md
  - ../tracker.md
---

# `reorder-functions-by-name`

## Role

- `reorder-functions-by-name` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `reorder-functions-by-name` slice**.
- Official Binaryen exposes it from the same implementation file as [`../reorder-functions/index.md`](../reorder-functions/index.md), but it is a separate public pass with a different ordering policy.

## Beginner summary

A good beginner mental model is:

1. Ignore call counts.
2. Ignore start/export/table references.
3. Look only at each function's internal Binaryen name.
4. Sort the function declaration list alphabetically.

So this pass is best taught as:

- **a lexical function-ordering pass for debugging and determinism**,
- not a body optimizer,
- not a profile-guided hotness pass,
- and not the same thing as count-based `reorder-functions`.

## Why this pass matters

This pass is tiny, but it is easy to mishandle in two opposite ways:

- dismiss it as too small to document,
- or silently collapse it into [`../reorder-functions/index.md`](../reorder-functions/index.md).

The real `version_129` contract is small but specific:

- sort the module's function declarations by ascending internal name,
- leave function bodies semantically alone,
- keep the public pass identity separate from `reorder-functions`,
- and use it mainly as a debugging-oriented orderer, not as a size heuristic.

## Current durable takeaways

- The implementation lives in the same tiny upstream file as `reorder-functions`: `ReorderFunctions.cpp`.
- `reorder-functions-by-name` only changes function declaration order.
- The comparator is exactly ascending function name: `a->name < b->name`.
- The pass reports `requiresNonNullableLocalFixups() = false`, matching its declaration-only mutation surface.
- Upstream `pass.cpp` describes it as useful for debugging.
- The sibling `reorder-functions` instead sorts by a static-use count model, so the two public names must stay separate.
- The shipped `reorder-functions-by-name.wast` lit file proves the core positive surface directly with four checked declaration permutations that all normalize to `$a`, `$b`, `$c`.
- A 2026-05-05 current-main recheck of `ReorderFunctions.cpp`, `pass.cpp`, and the dedicated `reorder-functions-by-name.wast` surface found no teaching-relevant drift on the reviewed `ReorderFunctionsByName` surface.
- The folder now also has a dedicated Starshine implementation-readiness bridge for the remaining module-pass gap.
- Current Starshine tracks the name as boundary-only, rejects active requests, and has no module dispatcher case, owner file, preset role, or backlog slice for it.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main Binaryen implementation walkthrough: public identity, comparator-only algorithm, sibling split, and source-backed non-goals.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-surface map for the upstream implementation, including the dedicated lit file and current-main spot check.
- [`./lexical-order-proof-and-boundaries.md`](./lexical-order-proof-and-boundaries.md)
  Compact source-confirmed page for the exact comparator, declaration-only boundary, four lit-backed permutation proofs, and current-main no-drift result.
- [`./module-shapes.md`](./module-shapes.md)
  Beginner-friendly module-order shape catalog showing direct lit-backed positive families, preserved cases, and the explicit split from count-based `reorder-functions`.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: boundary-only registry, request rejection, omitted presets, module-function permutation requirements, and exact local code locations.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge covering the module-pass gap, remap surfaces, and validation ladder.

## Current maintenance rule

- Treat this folder as the canonical home for future `reorder-functions-by-name` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real module/boundary pass for it.
- Keep the split from [`../reorder-functions/index.md`](../reorder-functions/index.md) explicit: this sibling is lexical/debug ordering, while the main pass is static-use-count ordering.
- Keep the split from [`../reorder-globals/index.md`](../reorder-globals/index.md) and [`../reorder-types/index.md`](../reorder-types/index.md) explicit too: this pass has no count model, dependency DAG, or legality phase.

## Sources

- [`../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md)
- [`../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md`](../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md`](../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md)
- [`../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md`](../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
