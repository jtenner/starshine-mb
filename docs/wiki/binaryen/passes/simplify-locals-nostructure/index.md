---
kind: entity
status: working
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
  - ../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/index.md
  - ../tuple-optimization/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
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
- The repo backlog already treats it as a real parity blocker under slice `SLNS` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- The current Starshine tuple-slot gate also treats it as a real missing neighbor: `tuple_optimization_exact_slot_prereqs_ready()` stays false until both `code-pushing` and `simplify-locals-no-structure` stop being removed placeholders.
- The reviewed official Binaryen `version_129` release page rechecked on 2026-04-22 showed publish date **2026-04-01**. A focused 2026-05-04 current-`main` recheck found no teaching-relevant drift beyond the current dossier claims. See [`../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md).

## Beginner summary

A safe beginner mental model is:

- count how many times each local is still read,
- sink easy `local.set` values forward into the real use sites,
- create a tee later if the first use still needs the value to stay live,
- delete dead or overwritten local traffic,
- but **do not** create new block / `if` / loop return values yet.

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
- Current Starshine still has **no transform** for this pass, but the dossier now has dedicated implementation/test-map, status / port-map, and validation pages tying together upstream proof files, removed-name registry, tuple-slot blocker, backlog slice, scheduler note, dispatcher gap, and neighboring MoonBit implementation files.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: template identity, first-cycle versus later-cycle behavior, linear-trace sink state, effect barriers, late equivalent-get canonicalization, final dead-set cleanup, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner/helper/test map for the no-structure variant, including the current-main no-drift bridge, `pass.h` nondefaultable-local fixup postcondition, and exact Starshine registry / slot-blocker / dispatcher-gap line ranges.
- [`./variant-surface.md`](./variant-surface.md)
  Focused guide to the easiest part of the pass to misunderstand: what “no structure” actually toggles, what it surprisingly leaves on, and how it differs from `simplify-locals`, `simplify-locals-notee-nostructure`, and `simplify-locals-nonesting`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port map: removed-name registry tracking, tuple exact-slot blocker coverage, backlog slice `SLNS`, canonical no-DWARF slot, and the practical MoonBit local-cleanup / local-index rewrite files that a future port would compose with.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge: first slice, negative tests, scheduler honesty, and Binaryen oracle lanes.

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-locals-nostructure` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `simplify-locals-nostructure` findings should update the strategy, implementation/test-map, variant-surface, and Starshine pages together so the upstream algorithm, source proof surface, variant boundary, and local port story stay aligned.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- [`../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
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
