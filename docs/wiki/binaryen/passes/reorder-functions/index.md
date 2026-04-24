---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-reorder-functions-primary-sources.md
  - ../../../raw/research/0297-2026-04-24-reorder-functions-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0179-2026-04-21-reorder-functions-binaryen-research.md
  - ../../../raw/research/0211-2026-04-21-reorder-functions-source-confirmation-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./count-surfaces-ordering-and-omissions.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
  - ../reorder-types/index.md
  - ../tracker.md
---

# `reorder-functions`

## Role

- `reorder-functions` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `reorder-functions` slice**.
- [`./starshine-strategy.md`](./starshine-strategy.md) is the dedicated local status page: Starshine knows the name, rejects active requests as boundary-only, has no owner file or dispatcher case, and would need a module-level function-index permutation/remap pass for a future port.
- Official Binaryen also exposes a sibling pass, `reorder-functions-by-name`, from the same source file.

## Why this pass matters

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered, so this folder is an explicit tracker expansion for another real local registry pass.

This pass is worth teaching because the name can make it sound much bigger than it is.
The real `version_129` contract is small and specific:

- count only a few **static function-use surfaces**
- sort function declarations by those counts
- break ties by function name
- leave function bodies alone

That puts it conceptually near `reorder-globals`, `reorder-locals`, and `reorder-types`, but its actual algorithm is much simpler than those neighbors.

## Beginner summary

A good beginner mental model is:

1. Give every function a score.
2. Increase that score when Binaryen sees a direct call to the function.
3. Also increase it if the function is the start function, a function export, or appears in an element segment.
4. Put higher-score functions earlier in the module.
5. If two functions tie, order them by name.

So this pass is best taught as:

- **a static function-ordering pass for binary-size-oriented layout**
- not a function-body optimizer
- not a profile-guided runtime hotness pass
- not a callgraph simplifier

## Most important durable takeaways

- The implementation lives almost entirely in one tiny upstream file: `ReorderFunctions.cpp`; the 2026-04-24 raw manifest now records the official `version_129` release/source/test URLs used by this dossier.
- `reorder-functions` only changes function declaration order; it does not rewrite bodies, and the pass explicitly reports `requiresNonNullableLocalFixups() == false`.
- The counted surfaces in `version_129` are:
  - direct `call` targets
  - the start function
  - exported functions
  - functions referenced by element segments
- The pass pre-seeds one counter per function, counts direct `Call` targets in a function-parallel walker, then adds start/export/element-segment bumps serially.
- The file contains explicit TODOs for two count sources it does **not** handle yet:
  - `ref.func`
  - declaration-section mentions
- The plain pass sorts by **descending count**, then **descending name** on ties.
- The sibling `reorder-functions-by-name` sorts by **ascending name** and is mainly a debugging-oriented orderer.
- The implementation comment explicitly says the pass may reduce raw wasm binary size while still hurting gzip size.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: counting sources, sorting rule, nearby-pass interactions, and the main future-port rules.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-surface map for the upstream implementation, including the small current-main check.
- [`./count-surfaces-ordering-and-omissions.md`](./count-surfaces-ordering-and-omissions.md)
  Focused guide to the exact count surfaces, serial-vs-parallel assembly split, descending-name tie rule, explicit `ref.func` / declaration TODO omissions, and the declaration-only / no-local-fixup boundary.
- [`./module-shapes.md`](./module-shapes.md)
  Beginner-friendly module-order shape catalog showing the positive, preserved, and surprising ordering families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine boundary-only status plus the future module-pass code map: registry, dispatcher gap, preset omission, numeric `FuncIdx` remap requirements, and reusable DFE remap surfaces.

## Current maintenance rule

- Treat this folder as the canonical home for future `reorder-functions` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real module pass and dispatcher case for it.
- Keep the split from [`../reorder-functions-by-name`](./implementation-structure-and-tests.md#the-sibling-pass-matters) explicit: the sibling is lexical/debug ordering, while the main pass is static-use-count ordering.
- Keep the split from [`../reorder-globals/index.md`](../reorder-globals/index.md) and [`../reorder-types/index.md`](../reorder-types/index.md) explicit too: this pass has no dependency DAG or type-graph legality phase.

## Sources

- [`../../../raw/binaryen/2026-04-24-reorder-functions-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-functions-primary-sources.md)
- [`../../../raw/research/0297-2026-04-24-reorder-functions-primary-sources-and-starshine-followup.md`](../../../raw/research/0297-2026-04-24-reorder-functions-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0179-2026-04-21-reorder-functions-binaryen-research.md`](../../../raw/research/0179-2026-04-21-reorder-functions-binaryen-research.md)
- [`../../../raw/research/0211-2026-04-21-reorder-functions-source-confirmation-followup.md`](../../../raw/research/0211-2026-04-21-reorder-functions-source-confirmation-followup.md)
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
