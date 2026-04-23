---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-reorder-globals-primary-sources.md
  - ../../binaryen/passes/reorder-globals/index.md
  - ../../binaryen/passes/reorder-globals/binaryen-strategy.md
  - ../../binaryen/passes/reorder-globals/size-model-and-dependency-order.md
  - ../../binaryen/passes/reorder-globals/wat-shapes.md
  - ../../binaryen/passes/reorder-globals/starshine-strategy.md
  - ../../binaryen/passes/reorder-globals-always/index.md
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/directize/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `reorder-globals` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `reorder-globals` dossier already had the required living overview, Binaryen strategy page, transformed-shape coverage, and the focused size/dependency explainer.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder as upstream-only planning instead of also giving readers one clean bridge into the exact in-repo Starshine status and future landing zone

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-reorder-globals-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `ReorderGlobals.cpp` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `pass.h`
- `wasm-traversal.h`
- `topological_sort.h`
- `wasm.h`
- `GlobalStructInference.cpp`
- the dedicated `reorder-globals.wast` and `reorder-globals-real.wast` tests

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `string-gathering`, `reorder-globals-always`, and `directize`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not another algorithm rewrite

The existing upstream pages were still broadly correct after the 2026-04-20 research wave.
The missing piece was provenance:

- on 2026-04-23 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, size/dependency, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the already-correct Binaryen explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`reorder-globals` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps both `reorder-globals` and `reorder-globals-always` in the boundary-only registry surface
- the same file's `run_hot_pipeline_expand_passes(...)` path rejects the pass with a boundary-only error rather than pretending it exists in the active hot pipeline
- `agent-todo.md` already keeps a dedicated `RG` backlog slice
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records the canonical late-tail slot `string-gathering -> reorder-globals -> directize`
- the neighboring `string-gathering`, `reorder-globals-always`, and `directize` dossiers already describe the practical landing zone and sibling boundaries a future port would need to respect

Before this run, that local status was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story is boundary-only tracking plus a reindexing-centered port map

Unlike the already-implemented module passes, `reorder-globals` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore keeps three things explicit:

- current Starshine executes no `reorder-globals` transform today
- the repo still intentionally preserves the pass spelling, boundary-only classification, request guard, backlog slice, and scheduler slot
- a future Starshine parity port should be taught as a global-index remap and declaration-layout pass, not as a HOT peephole and not as just a cleanup-after-`string-gathering` helper

That is more useful than leaving the folder as upstream-only research with no exact local read-along map.

### 4. `reorder-globals-always` is a real sibling boundary the local page now needs to point at directly

The existing `reorder-globals` folder already taught the public-vs-`always` split on the Binaryen side.
But the local planning side still needed a cleaner bridge to the sibling dossier.
That matters because a future Starshine port will likely need two policy decisions that are easy to blur together:

- whether the public `reorder-globals` path should preserve Binaryen's `< 128` no-op rule exactly
- whether the repo ever needs a separate internal or test-facing helper surface mirroring `reorder-globals-always`

The new Starshine page and refreshed catalogs keep that sibling boundary explicit instead of teaching `reorder-globals` as if it were the only local planning surface.

### 5. The right local implementation shape is a late module pass whose hard part is safe remapping, not just heuristic scoring

Re-reading the local scheduler docs and backlog reinforces a planning point:

- Binaryen places `reorder-globals` late, after `string-gathering`
- the pass depends on whole-module global declarations, initializer dependencies, and final index-sensitive layout
- Binaryen IR can apply the reorder by symbolic global names, but a future local Starshine port still needs a safe declaration reorder plus index-user remap story appropriate to local IR and emit paths

That makes the backlog wording in `agent-todo.md` importantly right in spirit here:

- the hard local deliverable is not merely “copy the score heuristic”
- it is “port the cost model and compute a safe remap after late global cleanup and string gathering”

So the right local mental model is a small but real late boundary/module pass with explicit reindexing and validation concerns.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-reorder-globals-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/reorder-globals/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/reorder-globals/index.md`
- `docs/wiki/binaryen/passes/reorder-globals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-globals/size-model-and-dependency-order.md`
- `docs/wiki/binaryen/passes/reorder-globals/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `reorder-globals` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-reorder-globals-primary-sources.md`
2. `docs/wiki/binaryen/passes/reorder-globals/index.md`
3. `docs/wiki/binaryen/passes/reorder-globals/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/reorder-globals/size-model-and-dependency-order.md`
5. `docs/wiki/binaryen/passes/reorder-globals/wat-shapes.md`
6. `docs/wiki/binaryen/passes/reorder-globals/starshine-strategy.md`
7. `docs/wiki/binaryen/passes/reorder-globals-always/index.md`
8. `docs/wiki/binaryen/passes/string-gathering/index.md`
9. `docs/wiki/binaryen/passes/directize/index.md`
10. `src/passes/optimize.mbt`
11. `agent-todo.md`
12. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the local `reorder-globals` vs `reorder-globals-always` planning boundary, and the neighboring late-tail passes that a real future port would need to interoperate with.
