---
kind: entity
status: working
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md
  - ../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
related:
  - ./binaryen-strategy.md
  - ./two-phase-dataflow.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../heap2local/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# `optimize-casts`

## Role

- `optimize-casts` is an upstream Binaryen GC/local cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Despite the broad CLI name, Binaryen `version_129` uses it for a much narrower job: improve how nearby `ref.cast` and `ref.as_non_null` values are reused through locals.
- The dossier now also has an immutable raw primary-source manifest recording that the reviewed official Binaryen `version_129` release page on 2026-04-22 showed publish date **2026-04-01**, plus a dedicated Starshine status/port-map page tying the upstream story directly to the current local registry, backlog, scheduler, and GC/local-neighbor surfaces.

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

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: GC gate, early cast motion, later cast reuse, effect barriers, helper utilities, and scheduler placement.
- [`./two-phase-dataflow.md`](./two-phase-dataflow.md)
  Dedicated guide to the easiest part of the pass to misunderstand: why moving a cast earlier is stricter than reusing it later, and why Binaryen therefore splits the pass into two internal dataflow phases.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and port-planning bridge: removed-name registry tracking, backlog slice `OC`, canonical no-DWARF slot, the local-scope mismatch to keep explicit, and the practical `heap2local -> local-subtyping -> coalesce-locals -> local-cse` landing zone for a future port.

## Current maintenance rule

- Treat this folder as the canonical home for future `optimize-casts` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `optimize-casts` findings should update the Binaryen strategy page, the shape pages, and the Starshine status page together so the upstream algorithm, concrete examples, and local port story stay aligned.

## Sources

- [`../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md)
- [`../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md`](../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md)
- [`../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md`](../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>