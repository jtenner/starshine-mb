---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/binaryen-strategy.md
  - ../../binaryen/passes/code-pushing/segment-selection-and-barriers.md
  - ../../binaryen/passes/code-pushing/wat-shapes.md
  - ../../binaryen/passes/code-pushing/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/tuple-optimization/index.md
  - ../../binaryen/passes/precompute/index.md
  - ../../binaryen/passes/simplify-locals-nostructure/index.md
---

# `code-pushing` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `code-pushing` dossier already had a solid landing page, upstream strategy page, barrier explainer, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder only as an upstream working dossier, without a clean bridge to the exact in-repo Starshine status and future landing zone

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-code-pushing-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `CodePushing.cpp` on `version_129` and `main`
- `pass.cpp`
- `opt-utils.h`
- the supporting helper files `effects.h`, `branch-utils.h`, `parents.h`, and `find_all.h`
- the dedicated `code-pushing*` lit files

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `precompute`, `tuple-optimization`, and `simplify-locals-nostructure`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not a conceptual rewrite

The existing upstream pages were still broadly correct.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, barrier, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the pass explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`code-pushing` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps `code-pushing` in the removed-name registry, so the pass spelling is intentionally tracked rather than forgotten
- the same file keeps `tuple_optimization_exact_slot_prereqs_ready()` false until both `code-pushing` and `simplify-locals-no-structure` graduate from removed names into real hot-pass slots
- `src/passes/optimize_test.mbt` already locks that exact-slot gate in place with a regression asserting tuple-opt stays off the public presets while those neighbors are still removed
- `agent-todo.md` keeps an explicit `CP` backlog slice with motion-safety and rewrite-validation deliverables
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records where the pass belongs in the canonical early function pipeline, between `precompute` and `tuple-optimization`
- the neighboring dossiers for `precompute`, `tuple-optimization`, and `simplify-locals-nostructure` already describe the practical landing zone a future port would have to respect

Before this run, that local status was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story here is “registry and slot planning,” not a fake implementation page

Unlike the already-implemented hot and module passes, `code-pushing` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore makes three things explicit instead of smoothing them over:

- current Starshine executes no `code-pushing` transform today
- the in-repo implementation status is deliberately boundary tracking through the removed-name registry, tuple-slot gating, backlog slice, and scheduler docs
- the exact read-along path for a future implementation already exists in neighboring code and docs, especially the passes that should feed into it and consume its output

That is a more useful beginner-to-advanced teaching frame than pretending the dossier is only upstream-facing until code lands.

### 4. The future local implementation should be taught as an early-cluster HOT rewrite family, not as a free-standing generic motion pass

Re-reading the local scheduler docs and tuple gating surfaces reinforces a useful planning point:

- Binaryen places `code-pushing` after `precompute`
- it then expects `tuple-optimization` and `simplify-locals-nostructure` to see the reshaped body
- Starshine already ships the explicit `precompute` and `tuple-optimization` passes, but still keeps tuple-opt out of presets precisely because `code-pushing` and `simplify-locals-nostructure` are not honest active neighbors yet

That means a future Starshine port should be framed as an early HOT-region rewrite that lands into an already-documented scheduler neighborhood, not as an isolated generic code-motion experiment.

The new local page makes that dependency map explicit.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-code-pushing-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/code-pushing/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/code-pushing/index.md`
- `docs/wiki/binaryen/passes/code-pushing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/segment-selection-and-barriers.md`
- `docs/wiki/binaryen/passes/code-pushing/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `code-pushing` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-code-pushing-primary-sources.md`
2. `docs/wiki/binaryen/passes/code-pushing/index.md`
3. `docs/wiki/binaryen/passes/code-pushing/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/code-pushing/segment-selection-and-barriers.md`
5. `docs/wiki/binaryen/passes/code-pushing/wat-shapes.md`
6. `docs/wiki/binaryen/passes/code-pushing/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `src/passes/optimize_test.mbt`
9. `agent-todo.md`
10. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
11. `docs/wiki/binaryen/passes/precompute/index.md`
12. `docs/wiki/binaryen/passes/tuple-optimization/index.md`
13. `docs/wiki/binaryen/passes/simplify-locals-nostructure/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, and the neighboring local passes that a real future port would need to interoperate with.
