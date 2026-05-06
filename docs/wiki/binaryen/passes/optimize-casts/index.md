---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md
  - ../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./two-phase-dataflow.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../heap2local/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# `optimize-casts`

## Role

- `optimize-casts` is an upstream Binaryen GC/local cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Despite the broad CLI name, Binaryen `version_129` uses it for a much narrower job: improve how nearby `ref.cast` and `ref.as_non_null` values are reused through locals.
- The dossier now also has immutable raw primary-source manifests recording the reviewed `version_129` release provenance, a 2026-04-25 current-main implementation/test-map bridge, a 2026-05-05 current-main freshness recheck, and a 2026-05-06 port-readiness research note, plus dedicated implementation/test-map, Starshine status, and port-readiness pages tying upstream owner/helper/test surfaces to current local registry, backlog, scheduler, and GC/local-neighbor code locations.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `optimize-casts` in the GC/local cleanup cluster after `heap2local` and before `local-subtyping` plus `coalesce-locals`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `28`
- The saved Binaryen debug log also shows many more `optimize-casts` executions later in the same full run, which matches the nested rerun story from `opt-utils.h`.
- The repo backlog already treats it as a real parity blocker under slice `OC` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).

## Beginner summary

A safe beginner mental model is:

- if one use of a local has already been narrowed by a cast,
- try to reuse that narrower value instead of going back to the wider local,
- and if a better cast appears a little later in straight-line code,
- duplicate it earlier only when that move is clearly safe.

That is narrower than “optimize all casts.”

## Current durable takeaways

- Binaryen only runs this pass when GC is enabled.
- For `version_129`, the pass handles only:
  - `ref.cast`
  - `ref.as_non_null`
- The pass is really **two** algorithms:
  1. move the best cast earlier inside a strict linear-execution window
  2. save and reuse the best already-computed cast later in a slightly wider adjacent-block window
- Extern-conversion `ref.as` forms are deliberately ignored here.
- The pass adds new locals and `local.tee`s; it does not try to delete every redundant old cast immediately.
- `ReFinalize` runs after both rewrite phases because the new locals and gets become more refined than before.
- The implementation comment explicitly positions `optimize-casts` next to `simplify-locals`, `rse`, and `local-cse` as related work, but not the same work.
- The 2026-05-05 current-main recheck found no teaching-relevant drift from the `version_129` contract, and the new implementation/test-map page plus port-readiness bridge are the canonical owner/helper/lit proof-surface and validation-map pages.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: GC gate, early cast motion, later cast reuse, effect barriers, helper utilities, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-location map for `OptimizeCasts.cpp`, scheduler/helper surfaces, the official `optimize-casts.wast` proof families, and exact current Starshine prerequisite code locations.
- [`./two-phase-dataflow.md`](./two-phase-dataflow.md)
  Dedicated guide to the easiest part of the pass to misunderstand: why moving a cast earlier is stricter than reusing it later, and why Binaryen therefore splits the pass into two internal dataflow phases.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and port-planning bridge: removed-name registry tracking, backlog slice `OC`, canonical no-DWARF slot, the local-scope mismatch to keep explicit, and the practical `heap2local -> local-subtyping -> coalesce-locals -> local-cse` landing zone for a future port.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Dedicated implementation-readiness bridge: first-slice scope, exact local code surfaces, validation ladder, and the explicit non-goals that keep the port narrower than the backlog wording.

## Current maintenance rule

- Treat this folder as the canonical home for future `optimize-casts` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `optimize-casts` findings should update the Binaryen strategy page, implementation/test-map page, shape pages, Starshine status page, and port-readiness bridge together so the upstream algorithm, concrete examples, source proof, validation ladder, and local port story stay aligned.

## Sources

- [`../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md)
- [`../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md`](../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md)
- [`../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md`](../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md`](../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md)
- [`../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md`](../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md)
- [`../../../raw/research/0500-2026-05-06-optimize-casts-starshine-port-readiness.md`](../../../raw/research/0500-2026-05-06-optimize-casts-starshine-port-readiness.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>