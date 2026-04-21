---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../tuple-optimization/scheduler-and-gates.md
  - ../reorder-locals/parity.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `simplify-locals-nostructure`

## Role

- `simplify-locals-nostructure` is an upstream Binaryen early locals-cleanup pass.
- It is currently **unimplemented** in Starshine and still lives only as a removed-name placeholder in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The upstream Binaryen name is `simplify-locals-nostructure`, while the current removed-name placeholder in Starshine is spelled `simplify-locals-no-structure`.
- Despite the name, Binaryen `version_129` does **not** use this pass for “flat locals only” or “no tee.” The real contract is narrower: run the shared simplify-locals engine with teeing still enabled and structure-building rewrites disabled.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `simplify-locals-nostructure` after `code-pushing` plus `tuple-optimization` and before `vacuum` plus the first `reorder-locals`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `22`
- The saved Binaryen debug log also shows many repeated later reruns of the same local-cleanup neighborhood, which matches the nested rerun story from `opt-utils.h`.
- The repo backlog already treats it as a real parity blocker under slice `SLNS` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is also one of the missing scheduler neighbors that still block fully honest preset placement around the already-implemented `tuple-optimization` and `reorder-locals` work.

## Beginner summary

A safe beginner mental model is:

- count how many times each local is still read,
- sink easy `local.set` values forward into the real use sites,
- create a tee later if the first use still needs the value to stay live,
- delete dead or overwritten local traffic,
- but **do not** create new block/`if`/loop return values yet.

That is narrower than “full simplify-locals.”

## Current durable takeaways

- Binaryen implements this pass as `SimplifyLocals<true, false, true>`.
- So `simplify-locals-nostructure` still allows:
  - tee creation
  - nesting into existing expression positions
  - late equivalent-get canonicalization
  - final dead-set cleanup
- The disabled feature is specifically the structure-building family:
  - loop return lifting
  - block return lifting
  - `if` / `if-else` return lifting
  - one-armed `if` speculative else-side `local.get` insertion
- The first fixpoint cycle is still stricter than later ones: it only sinks easy single-use locals.
- The main analysis is deliberately linear-trace based and uses directional effect invalidation instead of whole-function CFG reasoning.
- The late equivalent-local phase still canonicalizes `local.get`s, but it does **not** remove equivalent sets in this variant because `removeEquivalentSets = allowStructure`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: template identity, first-cycle versus later-cycle behavior, linear-trace sink state, effect barriers, late equivalent-get canonicalization, final dead-set cleanup, and scheduler placement.
- [`./variant-surface.md`](./variant-surface.md)
  Focused guide to the easiest part of the pass to misunderstand: what “no structure” actually toggles, what it surprisingly leaves on, and how it differs from `simplify-locals`, `simplify-locals-notee-nostructure`, and `simplify-locals-nonesting`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-locals-nostructure` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `simplify-locals-nostructure` findings should update both the strategy page and the variant-surface page so the algorithm explanation and the “what is actually disabled” explanation stay aligned.

## Sources

- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
