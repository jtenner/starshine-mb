---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `local-subtyping`

## Role

- `local-subtyping` is an upstream Binaryen GC/local cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The strongest current reading is the 2026-04-25 source correction: Binaryen `version_129` uses an iterative reference-local declaration refinement pass that records both sets and gets, computes LUBs from assigned values, gates non-nullability with structural dominance over gets, rewrites body-local declarations, retags `local.get` / `local.tee` expression types, and refinalizes between improvement rounds.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `local-subtyping` in the GC/local cleanup cluster after `heap2local` and `optimize-casts`, before `coalesce-locals` and `local-cse`.
- The saved generated-artifact `-O4z` audit records it as skipped top-level slot `29`.
- The repo backlog tracks it under slice `LS` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is one of the missing local-neighborhood passes that keep current Starshine preset placement intentionally conservative around `reorder-locals`, `coalesce-locals`, and `local-cse`.

## Beginner summary

A safe beginner mental model is:

1. look at reference-typed locals,
2. record where they are assigned and where they are read,
3. compute one common narrower type from the values assigned to each body local,
4. keep non-nullability only when all relevant gets are safely dominated,
5. rewrite the body-local declaration,
6. retag gets and tees so expression typing agrees,
7. repeat after refinalization while new declaration types expose more precise assigned-value types.

That is more precise than both older overreads:

- not a generic all-local flow-inference pass with copy-local insertion;
- not a tiny set/tee-only pass with no get or refinalization surface.

## Current durable takeaways

- `LocalSubtyping.cpp` is the owner file; the pass is function-parallel and GC-gated.
- The scanner records both set/tee sites and get sites for reference-typed locals.
- Candidate declaration types are still computed from assigned values, not from consumer wishes at gets.
- Gets matter for non-null dominance and type repair.
- Parameters may be scanned but are not rewritten; declaration rewriting starts at the body-local base.
- Non-reference and tuple/nondefaultable local shapes are preserved rather than forced through the pass.
- The pass is iterative and uses `ReFinalize()` between improvement rounds.
- The dedicated official lit file proves repeated refinement, dominance, tee retagging, parameter preservation, nondefaultable preservation, and local-cleanup-neighborhood interactions.
- The 2026-04-25 current-main spot check found no teaching-relevant drift from the tagged `version_129` owner/test contract; the important change is a correction to this repo's earlier interpretation.
- The 2026-05-05 current-main recheck keeps that correction fresh without changing the pass contract.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Corrected Binaryen strategy: GC gate, relevant-local scan, set-fed LUBs, get-aware dominance/type repair, iterative refinalization, body-local rewrite, scheduler placement before `coalesce-locals`, and the 2026-05-05 current-main freshness recheck.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner/helper/test map for upstream Binaryen plus exact current Starshine registry, dispatcher-gap, preset-honesty, backlog, type-model, validator, and HOT-local prerequisite surfaces, now with a 2026-05-05 current-main freshness layer.
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md)
  Dedicated guide to LUBs, gets, dominance, nullability, repeated refinement, and why the 2026-04-22 set-only wording is superseded; the 2026-05-05 recheck keeps that correction intact.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog covering reference-local narrowing, common-parent LUBs, tee retagging, non-null dominance, repeated refinement, param preservation, nondefaultable bailouts, and the 2026-05-05 current-main freshness refresh.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port map: removed-name registry tracking, no dispatcher, `LS` backlog, honest preset exclusion, exact local type/validation surfaces, neighboring pass cluster, and the fresh current-main provenance bridge.

## Maintenance rule

- Treat this folder as the canonical home for future `local-subtyping` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- Treat [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md) as the strongest current provenance anchor.
- Treat the older 2026-04-22 manifest and research note as partially superseded for the specific owner-file mechanics corrected on 2026-04-25.
- New findings should update the Binaryen strategy, implementation/test map, LUB/dominance guide, shape catalog, and Starshine strategy together.

## Sources

- [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md)
- [`../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md`](../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md)
- [`../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`](../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
- Binaryen current-main pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalSubtyping.cpp>
