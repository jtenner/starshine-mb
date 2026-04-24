---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-dataflow-optimization-primary-sources.md
  - ../../binaryen/passes/dataflow-optimization/index.md
  - ../../binaryen/passes/dataflow-optimization/binaryen-strategy.md
  - ../../binaryen/passes/dataflow-optimization/implementation-structure-and-tests.md
  - ../../binaryen/passes/dataflow-optimization/flat-ir-dataflow-ir-and-boundaries.md
  - ../../binaryen/passes/dataflow-optimization/wat-shapes.md
  - ../../binaryen/passes/dataflow-optimization/starshine-strategy.md
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/simplify-locals-nonesting/index.md
  - ../../binaryen/passes/souperify/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../docs/0065-2026-03-24-ir2-execution-plan.md
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../agent-todo.md
---

# `dataflow-optimization` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `dataflow-optimization` dossier already had the required living overview, Binaryen strategy page, implementation/test map, and transformed-shape coverage.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still taught the pass mainly as an upstream-only removed-registry dossier instead of also giving readers one clean bridge into the exact in-repo Starshine status, neighboring code, and current planning uncertainty

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future Starshine planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `DataFlowOpts.cpp` on `version_129` and `main`
- `pass.cpp`
- `src/dataflow/{graph,node,users,utils}.h`
- `src/ir/flat.h`
- the combo lit file `flatten_simplify-locals-nonesting_dfo_O3.wast`

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/0065-2026-03-24-ir2-execution-plan.md`
- `src/passes/precompute.mbt`
- `src/passes/simplify_locals.mbt`
- `agent-todo.md`
- the neighboring living dossiers for `flatten`, `simplify-locals-nonesting`, and `souperify`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not another algorithm rewrite

The existing upstream pages were still broadly correct after the 2026-04-21 research wave.
The missing piece was provenance:

- on 2026-04-23 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, implementation/test, focused mechanics, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the already-correct Binaryen explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`dataflow-optimization` is still unimplemented in Starshine, but the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps the pass in the removed-name registry and rejects requests for it explicitly
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still places it in the Batch 1 removed-until-hot-implementation roster
- `docs/0065-2026-03-24-ir2-execution-plan.md` does **not** currently call it out in the preferred next implementation order, even though the older batch map still tracks it
- `agent-todo.md` still has **no dedicated `dataflow-optimization` / `dfo` slice**
- the nearest active implementation neighbors are `precompute` and `simplify-locals`, while the nearest conceptual dossier neighbors are `flatten`, `simplify-locals-nonesting`, and `souperify`

Before this run, that story was scattered across omissions and neighboring docs.
The new Starshine page turns it into one explicit teachable path.

### 3. The honest Starshine story is removed-registry tracking plus planning uncertainty, not hidden partial implementation

The repo does know the pass name today, unlike the upstream-only `type-ssa` case.
But it knows it only as a removed registry name.
That means the most honest current local conclusion is:

- the pass spelling is intentionally preserved
- the active pipeline rejects the pass honestly rather than silently no-oping
- there is still no `src/passes/dataflow_optimization.mbt` owner file
- there is still no dedicated backlog slice
- the current execution-plan note no longer gives it near-term priority even though the older batch map still preserves it

That is a useful durable teaching point.
It keeps future readers from overreading the presence of the name in the registry as evidence that a HOT-native or flat-IR-local implementation already exists.

### 4. The most useful current local bridge is through neighboring active passes, not through hidden DataFlow infrastructure

Re-reading the local code sharpened the practical future-port map:

- `precompute` is the nearest active local analogue for the nested constant-evaluation half of the upstream algorithm
- `simplify-locals` is the nearest active local locals-cleanup family, but it is still tree/HOT oriented rather than a flat side-graph pass
- there is no current `src/passes/dataflow_optimization.mbt`
- there is no current `src/dataflow/` or `src/ir/flat*` local substrate in this repository

That last point is an inference from the current repo layout rechecked in this run, not a direct source-file statement.
It matters because it means a future Starshine port would need either:

- a new flat/DataFlow side representation, or
- a consciously different HOT-native implementation strategy that still preserves the reviewed Binaryen contract where possible

### 5. Even without a local owner, the future correctness contract is already clear

The Binaryen dossier is mature enough that a future Starshine port already has a stable source-backed invariant list to preserve:

- hard flat-input gating
- integer-local relevance filtering
- the synthetic DataFlow node vocabulary and unsupported-op degradation rules
- the deliberate loop-precision cutoff
- identical-constant-phi collapse
- nested-`precompute`-driven constant-expression folding
- expectation of later ordinary cleanup after the flatten-era pass

That means the missing local decision is not “what does `dfo` do?”
It is “does Starshine want to reproduce this flat-side-graph pass faithfully, and if yes, where should that new substrate live relative to today's HOT-native optimizer?”

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0278-2026-04-23-dataflow-optimization-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/dataflow-optimization/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/dataflow-optimization/index.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `dataflow-optimization` work needs a clean provenance-plus-local-status path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md`
2. `docs/wiki/binaryen/passes/dataflow-optimization/index.md`
3. `docs/wiki/binaryen/passes/dataflow-optimization/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/dataflow-optimization/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/dataflow-optimization/flat-ir-dataflow-ir-and-boundaries.md`
6. `docs/wiki/binaryen/passes/dataflow-optimization/wat-shapes.md`
7. `docs/wiki/binaryen/passes/dataflow-optimization/starshine-strategy.md`
8. `docs/wiki/binaryen/passes/flatten/index.md`
9. `docs/wiki/binaryen/passes/simplify-locals-nonesting/index.md`
10. `docs/wiki/binaryen/passes/souperify/index.md`
11. `src/passes/optimize.mbt`
12. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
13. `docs/0065-2026-03-24-ir2-execution-plan.md`
14. `src/passes/precompute.mbt`
15. `src/passes/simplify_locals.mbt`
16. `agent-todo.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status: the name is preserved and honestly rejected, there is still no local implementation or active backlog slice, the batch map and execution-plan docs currently point in slightly different planning directions, and the nearest concrete local neighbors are `precompute` and `simplify-locals` rather than a hidden flat/DataFlow substrate.
