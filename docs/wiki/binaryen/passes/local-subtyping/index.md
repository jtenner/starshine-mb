---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../reorder-locals/parity.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `local-subtyping`

## Role

- `local-subtyping` is an upstream Binaryen GC/local cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Despite the broad CLI name, Binaryen `version_129` uses it for a much narrower job: collect concrete subtype demands from local traffic and then tighten eligible non-parameter local types through the dominance-aware local type updater.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `local-subtyping` in the GC/local cleanup cluster after `optimize-casts` and before `coalesce-locals` plus `local-cse`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `29`
- The saved Binaryen debug log also shows many later reruns of the same local-cleanup neighborhood, which matches the nested rerun story from `opt-utils.h`.
- The repo backlog already treats it as a real parity blocker under slice `LS` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is also one of the missing scheduler neighbors that still block fully honest preset placement around the already-implemented `reorder-locals` and future `coalesce-locals` work.

## Beginner summary

A safe beginner mental model is:

- watch how a local is actually used,
- notice when every concrete use is narrower than the declared type,
- compute one common narrower type that still fits all those uses,
- then update the function through the helper that knows where that narrower type is structurally safe.

That is narrower than “infer all local subtypes.”

## Current durable takeaways

- Binaryen only schedules this pass in the GC-gated local cleanup cluster.
- For `version_129`, the pass body only gathers facts from:
  - `local.get`
  - `local.set` / `local.tee`
  - `ref.as_non_null(local.get ...)`
- Parameters are deliberately skipped by source comment.
- Tuple locals are deliberately skipped by `TypeUpdating::canHandleAsLocal(...)`.
- The pass computes a **least upper bound** of observed concrete subtype facts; it does not simply pick the narrowest leaf type it sees.
- The dangerous rewrite work is delegated to `TypeUpdating::LocalUpdater`, which may add a copy local and uses `LocalStructuralDominance` to keep the change safe around named blocks, loops, and catches.
- `ReFinalize` is part of the rewrite contract after successful updates.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: GC gate, non-parameter-local scope, the tiny fact collector, helper dependencies, scheduler placement, and the real rewrite contract.
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md)
  Dedicated guide to the easiest parts of the pass to misunderstand: why narrowing means least-upper-bound selection rather than “pick the smallest type,” and why the type update step needs structural dominance plus optional copy locals.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.

## Current maintenance rule

- Treat this folder as the canonical home for future `local-subtyping` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `local-subtyping` findings should update both the strategy page and the LUB/dominance page so the algorithm explanation and the example catalog stay aligned.

## Sources

- [`../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`](../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` type helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
