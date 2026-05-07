---
kind: entity
status: implemented
last_reviewed: 2026-05-08
sources:
  - ../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md
  - ../../../raw/research/0518-2026-05-06-coalesce-locals-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md
  - ../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md
  - ../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./interference-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../local-subtyping/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `coalesce-locals`

## Role

- `coalesce-locals` is an upstream Binaryen late local-cleanup pass.
- It is now an active Starshine module pass implemented in [`../../../../../src/passes/coalesce_locals.mbt`](../../../../../src/passes/coalesce_locals.mbt) and wired through the registry, dispatcher, CLI, and pass-fuzz harness.
- Despite the broad CLI name, Binaryen `version_129` uses it for a narrower and more structured job: compute which locals can safely reuse the same storage slot, then renumber the function so those locals share indices and redundant copies disappear.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `coalesce-locals` **twice**:
  - first in the GC/local cleanup cluster after `local-subtyping`
  - then again after `local-cse`, `simplify-locals`, `vacuum`, and `reorder-locals`
- The saved generated-artifact `-O4z` audit records both real skipped top-level upstream slots:
  - top-level slot `30`
  - top-level slot `35`
- The saved Binaryen debug log also shows many later reruns of the same local-cleanup neighborhood, which matches the nested rerun story from `opt-utils.h`.
- The ordered-slot replay that used to live under slice `CL` is now closed: `src/passes/coalesce_locals_test.mbt` covers both exact neighborhoods, and [`../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md`](../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md) records the current-head proof.
- The first `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` slot is now explicitly proven in-tree and remains the public `optimize` / `shrink` cluster.
- The second `reorder-locals -> coalesce-locals -> reorder-locals` slot is now replayable as a focused neighborhood and compares green on the checked-in debug artifact, while public `reorder-locals` scheduling still stays with the separate reorder-locals policy work.

## Beginner summary

A safe beginner mental model is:

- think of locals as storage slots,
- see which locals are never simultaneously live with **different** values,
- keep only one slot for those compatible locals,
- then delete the copies and dead stores that became pointless.

That is narrower than “merge any locals that look unused.”

## Current durable takeaways

- Starshine's current direct-pass validation is green on focused tests, CLI coverage, full `moon test`, the refreshed 2026-05-08 mixed-generator direct parity lane (`6759/10000` compared, `6759` normalized matches, `0` mismatches, `20` Binaryen empty-recursion-group command failures), earlier 10k `gen-valid` Binaryen compare, mixed-generator comparable cases, and compatible Binaryen 128 self-opt artifact compare on both rebuilt debug and optimized WASI artifacts.
- The exact `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` and `reorder-locals -> coalesce-locals -> reorder-locals` neighborhoods are now both regression-covered in `src/passes/coalesce_locals_test.mbt`.
- The debug-artifact `reorder-locals -> coalesce-locals -> reorder-locals` replay at `.tmp/self-opt-cl-reorder-sandwich-20260508` is green on normalized WAT and canonical-function equality.
- The pass header explicitly says the algorithm is **nonlinear in the number of locals**, so Binaryen schedules it late after earlier local-cleanup passes have already reduced the local set.
- Exact local type equality is mandatory while coalescing. This pass does **not** use subtype compatibility.
- Two locals can overlap in liveness and still share a slot if Binaryen can prove they hold the same current value.
- Implicit local zero-initialization and fixed param ordering are part of the correctness story.
- Loop backedge copies get extra priority because removing them can avoid branch-only copy work.
- Binaryen tries two greedy orders by default and has a separate `coalesce-locals-learning` variant, but the default optimize pipeline uses the normal greedy pass.
- Post-coloring cleanup is part of the contract: redundant copies are deleted, dead sets are removed, and some dead tee rewrites require `ReFinalize()`.
- A focused 2026-05-05 current-`main` recheck found no teaching-relevant drift on `CoalesceLocals.cpp`, `pass.cpp`, `opt-utils.h`, or `coalesce-locals.wast`; treat that as a narrow freshness bridge, not proof that every helper detail is byte-identical to `version_129`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: helper dependencies, liveness/value-number interference, greedy coloring, rewrite cleanup, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file and test-map page covering `CoalesceLocals.cpp`, helper headers, registration/scheduler files, the dedicated lit test, and the exact local Starshine status/prerequisite surfaces.
- [`./interference-and-ordering.md`](./interference-and-ordering.md)
  Dedicated guide to the easiest parts of the pass to misunderstand: why equal values can overlap without interfering, why zero-init matters, why greedy order matters, and how backedge weighting changes outcomes.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and active-pass map: registry/dispatcher/CLI wiring, backlog slice `CL`, honest scheduler/preset story, and the exact neighboring MoonBit declaration-rewrite and cleanup files the pass composes with.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness and validation matrix for the active direct pass: current registry/dispatcher/preset/backlog state, reusable Starshine local-index and cleanup substrates, focused tests, and parity signoff ladder.

## Current maintenance rule

- Treat this folder as the canonical home for future `coalesce-locals` research, direct-pass validation, and ordered-pipeline follow-up.
- Keep the Starshine pages aligned with the active implementation in `src/passes/coalesce_locals.mbt` and record any future divergence from Binaryen as explicit parity debt.
- Treat [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md) as the immutable provenance anchor for the official release/source/test surfaces reviewed on 2026-04-22.
- Treat [`../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md) as the narrow current-`main` freshness bridge added on 2026-05-05.
- New `coalesce-locals` findings should update the Binaryen strategy page, the implementation/test map, the interference/order page, the Starshine strategy page, and the port-readiness matrix together so the algorithm explanation, example catalog, source map, local status story, and future validation ladder stay aligned.

## Sources

- [`../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md)
- [`../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md)
- [`../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md`](../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md)
- [`../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md`](../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md`](../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md)
- [`../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md`](../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md)
- [`../../../raw/research/0518-2026-05-06-coalesce-locals-direct-revalidation.md`](../../../raw/research/0518-2026-05-06-coalesce-locals-direct-revalidation.md)
- [`../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md`](../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CoalesceLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/coalesce-locals.wast>
