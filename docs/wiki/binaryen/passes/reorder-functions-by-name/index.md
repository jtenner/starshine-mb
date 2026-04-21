---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md
  - ../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lexical-order-proof-and-boundaries.md
  - ./module-shapes.md
  - ../reorder-functions/index.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
  - ../reorder-types/index.md
  - ../tracker.md
---

# `reorder-functions-by-name`

## Role

- `reorder-functions-by-name` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `reorder-functions-by-name` slice**.
- Official Binaryen exposes it from the same implementation file as [`../reorder-functions/index.md`](../reorder-functions/index.md), but it is a separate public pass with a different ordering policy.

## Why this pass matters

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered, so this folder is another explicit tracker expansion for a real local registry pass.

This pass is worth teaching because it is easy to mis-handle in two opposite ways:

- dismiss it as too tiny to matter
- or silently collapse it into `reorder-functions`

The real `version_129` contract is tiny but specific:

- sort the module's function declarations by **ascending internal name**
- leave function bodies alone
- use it mainly as a **debugging-oriented orderer**, not as a size heuristic

## Beginner summary

A good beginner mental model is:

1. Ignore call counts.
2. Ignore start/export/table references.
3. Look only at each function's internal Binaryen name.
4. Sort the function list alphabetically.

So this pass is best taught as:

- **a lexical function-ordering pass for debugging and determinism**
- not a body optimizer
- not a profile-guided hotness pass
- not the same thing as `reorder-functions`

## Most important durable takeaways

- The implementation lives in the same tiny upstream file as `reorder-functions`: `ReorderFunctions.cpp`.
- `reorder-functions-by-name` only changes function declaration order; it does not rewrite bodies.
- The comparator is exactly **ascending function name**: `a->name < b->name`.
- The pass also explicitly reports `requiresNonNullableLocalFixups() = false`, which matches its declaration-only mutation surface.
- Upstream `pass.cpp` explicitly describes it as **useful for debugging**.
- The sibling `reorder-functions` instead sorts by a small static-use count model, so the two public names must stay separate in teaching and in any future port.
- The shipped `reorder-functions-by-name.wast` lit file proves the core positive surface directly with four checked declaration permutations that all normalize to `$a`, `$b`, `$c`.
- A 2026-04-21 narrow current-`main` check found no drift on the reviewed surface, so `version_129` remains a reliable oracle here.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: the tiny comparator-only algorithm, the sibling split from `reorder-functions`, nearby-pass interactions, and the main future-port rules.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-surface map for the upstream implementation, including the dedicated lit file and the small current-main check.
- [`./lexical-order-proof-and-boundaries.md`](./lexical-order-proof-and-boundaries.md)
  Compact source-confirmed page for the exact comparator, declaration-only boundary, four lit-backed permutation proofs, and current-`main` no-drift result.
- [`./module-shapes.md`](./module-shapes.md)
  Beginner-friendly module-order shape catalog showing the direct lit-backed positive families, preserved cases, and the explicit split from count-based `reorder-functions`.

## Current maintenance rule

- Treat this folder as the canonical home for future `reorder-functions-by-name` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real module/boundary pass for it.
- Keep the split from [`../reorder-functions/index.md`](../reorder-functions/index.md) explicit: this sibling is lexical/debug ordering, while the main pass is static-use-count ordering.
- Keep the split from [`../reorder-globals/index.md`](../reorder-globals/index.md) and [`../reorder-types/index.md`](../reorder-types/index.md) explicit too: this pass has no count model, dependency DAG, or legality phase.

## Sources

- [`../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md`](../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast>
- current-main spot check:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
