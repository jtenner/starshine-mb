---
kind: entity
status: working
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md
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
- It is now an active direct hot pass in Starshine, implemented in [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt) and registered in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The upstream Binaryen name is `simplify-locals-nostructure`, while Starshine also accepts compatibility spelling `simplify-locals-no-structure` as an alias.
- Despite the name, Binaryen `version_129` does **not** use this pass for “flat locals only” or “no tee.” The real contract is narrower: run the shared simplify-locals engine with teeing still enabled and structure-building rewrites disabled.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `simplify-locals-nostructure` after `code-pushing` plus `tuple-optimization` and before `vacuum` plus the first `reorder-locals`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `22`
- The repo backlog records the direct `SLNS` slice as landed and keeps ordered preset-neighborhood replay as the remaining follow-up in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- The current Starshine tuple-slot gate now sees the no-structure pass as active, but the public presets still stay conservative until the broader ordered local neighborhood is proven.
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
- Current Starshine has a direct transform for this pass: it reuses the existing local-sink/dead-cleanup cycles from full `simplify-locals` while disabling structure-result rewrites. The 2026-05-06 refreshed harness revalidation recorded 6759 compared canonical-spelling cases plus 6759 compared alias-spelling cases with 0 mismatches; direct oracle evidence is recorded in the strategy and validation pages.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: template identity, first-cycle versus later-cycle behavior, linear-trace sink state, effect barriers, late equivalent-get canonicalization, final dead-set cleanup, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner/helper/test map for the no-structure variant, including the current-main no-drift bridge, `pass.h` nondefaultable-local fixup postcondition, and exact Starshine registry / slot-blocker / dispatcher line ranges.
- [`./variant-surface.md`](./variant-surface.md)
  Focused guide to the easiest part of the pass to misunderstand: what “no structure” actually toggles, what it surprisingly leaves on, and how it differs from `simplify-locals`, `simplify-locals-notee-nostructure`, and `simplify-locals-nonesting`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status: active hot pass plus alias, implementation shape, direct parity evidence, canonical no-DWARF slot, and conservative preset-neighborhood follow-up.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge: first slice, negative tests, scheduler honesty, and Binaryen oracle lanes.

## Current maintenance rule

- Treat this folder as the canonical home for `simplify-locals-nostructure` research, direct-pass validation, and preset-neighborhood planning.
- Keep direct-pass evidence and ordered-preset status separate: the pass and its `simplify-locals-no-structure` alias are active and revalidated after the 2026-05-06 harness changes, but public `optimize` / `shrink` placement still needs ordered replay.
- New `simplify-locals-nostructure` findings should update the strategy, implementation/test-map, variant-surface, and Starshine pages together so the upstream algorithm, source proof surface, variant boundary, and local port story stay aligned.

## Sources

- [`../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md`](../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md)
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
