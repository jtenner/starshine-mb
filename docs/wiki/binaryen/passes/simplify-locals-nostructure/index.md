---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-07-11
sources:
  - ../../../raw/research/1399-2026-06-30-slns-v130-source-refresh-and-tee-gap.md
  - ../../../raw/research/0552-2026-05-08-simplify-locals-nostructure-ordered-slot-replay.md
  - ../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md
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
  - ./parity.md
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
- Despite the name, Binaryen `version_130` does **not** use this pass for “flat locals only” or “no tee.” The real contract is narrower: run the shared simplify-locals engine with teeing still enabled and structure-building rewrites disabled.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `simplify-locals-nostructure` after `code-pushing` plus `tuple-optimization` and before `vacuum` plus the first `reorder-locals`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `22`
- The repo backlog previously tracked the remaining ordered-slot follow-up under `SLNS`; that exact `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` replay is now proven and the standalone slice is closed.
- The current Starshine tuple-slot gate still sees the no-structure pass as active, and the public presets still stay conservative, but the remaining caution now belongs to neighboring tuple/local-cluster slices rather than this pass's own ordered-slot proof.
- The current local oracle is Binaryen `version_130` (`wasm-opt version 130 (version_130)`). The 2026-06-30 source refresh found the dedicated no-structure tests unchanged from `version_129` and the core `SimplifyLocals.cpp` teaching contract unchanged except for unordered container implementation drift; helper changes in effects and linear execution remain active audit inputs. See [`../../../raw/research/1399-2026-06-30-slns-v130-source-refresh-and-tee-gap.md`](../../../raw/research/1399-2026-06-30-slns-v130-source-refresh-and-tee-gap.md).

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
- Current Starshine has a direct transform for this pass: it reuses the existing local-sink/dead-cleanup cycles from full `simplify-locals` while disabling structure-result rewrites. Historical 2026-05 evidence and the early 2026-06-30 residual paragraphs are baseline only; the active source of truth is the [`./parity.md`](./parity.md) checklist plus [`./fuzzing.md`](./fuzzing.md).
- Current `version_130` correctness evidence after the latest SLNS code change is refreshed across the required fuzz matrix: regular GenValid `100000/100000` normalized, explicit wasm-smith `9956/10000` normalized with only `44` Binaryen/oracle command failures, dedicated `simplify-locals-nostructure-all` `10000/10000` compared with `931/931` residuals classified as structured-control result-annotation-only and validating, and random all-profiles `10000/10000` normalized. This is evidence that the previously tracked non-annotation residuals and the broad random embedded-control tee blocker are no longer current blockers.
- Final closeout is still deliberately open for performance, not stale fuzz: the current 100-largest timing baseline has central tendency within the ordinary `starshine_time <= 2 * binaryen_time` floor, but repeat tails still exceed it and no soft performance exception has been approved. Do not report SLNS as audit-complete unless the performance blocker is fixed or explicitly accepted.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_130` implementation: template identity, first-cycle versus later-cycle behavior, linear-trace sink state, effect barriers, late equivalent-get canonicalization, final dead-set cleanup, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner/helper/test map for the no-structure variant, including the current-main no-drift bridge, `pass.h` nondefaultable-local fixup postcondition, and exact Starshine registry / slot-blocker / dispatcher line ranges.
- [`./parity.md`](./parity.md)
  Active `version_130` parity checklist: template identity, get counting, first-cycle sinks, later teeing, dropped-tee cleanup, effect/EH barriers, refinalization, late equivalent-get cleanup, final dead-set cleanup, disabled structure synthesis, dedicated-profile evidence, and performance evidence.
- [`./variant-surface.md`](./variant-surface.md)
  Focused guide to the easiest part of the pass to misunderstand: what “no structure” actually toggles, what it surprisingly leaves on, and how it differs from `simplify-locals`, `simplify-locals-notee-nostructure`, and `simplify-locals-nonesting`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status: active hot pass plus alias, implementation shape, direct parity evidence, canonical no-DWARF slot, and conservative preset-neighborhood follow-up.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge: first slice, negative tests, scheduler honesty, and Binaryen oracle lanes.
- [`./fuzzing.md`](./fuzzing.md)
  Dedicated `simplify-locals-nostructure-all` GenValid aggregate profile, leaf surfaces, manifest metadata, current smoke result, and profile-specific reopening criteria.

## Current maintenance rule

- Treat this folder as the canonical home for `simplify-locals-nostructure` research, direct-pass validation, and preset-neighborhood planning.
- Keep direct-pass evidence and broader preset status separate: the pass and its `simplify-locals-no-structure` alias are active, revalidated, and now exact-slot replay-proven, but public `optimize` / `shrink` placement still depends on neighboring tuple/local-cluster work.
- New `simplify-locals-nostructure` findings should update the strategy, implementation/test-map, variant-surface, and Starshine pages together so the upstream algorithm, source proof surface, variant boundary, and local port story stay aligned.

## Sources

- [`../../../raw/research/1399-2026-06-30-slns-v130-source-refresh-and-tee-gap.md`](../../../raw/research/1399-2026-06-30-slns-v130-source-refresh-and-tee-gap.md)
- [`../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md`](../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md)
- [`../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_130` pass source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/SimplifyLocals.cpp>
- Binaryen `version_130` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- Binaryen `version_130` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/opt-utils.h>
- Binaryen `version_130` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/properties.h>
- Binaryen `version_130` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals-nostructure.txt>
