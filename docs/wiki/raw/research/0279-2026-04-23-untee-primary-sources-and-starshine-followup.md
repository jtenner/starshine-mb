---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-untee-primary-sources.md
  - ../../binaryen/passes/untee/index.md
  - ../../binaryen/passes/untee/binaryen-strategy.md
  - ../../binaryen/passes/untee/implementation-structure-and-tests.md
  - ../../binaryen/passes/untee/flattening-code-pushing-and-tee-boundaries.md
  - ../../binaryen/passes/untee/wat-shapes.md
  - ../../binaryen/passes/untee/starshine-strategy.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/simplify-locals-notee/index.md
  - ../../../../src/passes/optimize.mbt
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../agent-todo.md
---

# `untee` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `untee` dossier already had the required living overview, Binaryen strategy page, implementation/test map, and transformed-shape coverage.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still taught the pass mainly as an upstream-only removed-registry dossier instead of also giving readers one clean bridge into the exact in-repo Starshine status, neighboring code, and current planning reality

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future Starshine planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-untee-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `Untee.cpp` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `SimplifyLocals.cpp`
- the dedicated lit file `untee.wast`

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `src/passes/simplify_locals.mbt`
- `src/passes/pass_manager_wbtest.mbt`
- `agent-todo.md`
- the neighboring living dossiers for `code-pushing`, `simplify-locals`, and `simplify-locals-notee`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not another algorithm rewrite

The existing upstream pages were still broadly correct after the 2026-04-21 research wave.
The missing piece was provenance:

- on 2026-04-23 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, implementation/test, focused mechanics, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the already-correct Binaryen explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`untee` is still unimplemented in Starshine, but the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps the pass in the removed-name registry and rejects requests for it explicitly
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still places it in the Batch 1 removed-until-hot-implementation roster
- `agent-todo.md` still has **no dedicated `untee` slice**
- the nearest active local implementation neighbor is `simplify-locals`, whose current HOT pass still reasons about tees from the opposite direction rather than eliminating them

Before this run, that story was scattered across omissions and neighboring docs.
The new Starshine page turns it into one explicit teachable path.

### 3. The honest Starshine story is removed-registry tracking plus an explicit split from current tee-using locals rewrites

The repo does know the pass name today.
But it knows it only as a removed registry name.
That means the most honest current local conclusion is:

- the pass spelling is intentionally preserved
- the active pipeline rejects the pass honestly rather than silently no-oping
- there is still no `src/passes/untee.mbt` owner file
- there is still no dedicated backlog slice
- the nearest local locals optimizer, `simplify-locals`, still has focused proof surfaces around adjacent-tee rewrites in `src/passes/pass_manager_wbtest.mbt`

That last point matters because it keeps future readers from overreading the presence of tee-related logic in the repo as evidence that a real `untee` transform already exists.
The local code today still optimizes with tee-aware rewrite helpers; it does not yet ship a source-backed pass whose job is to desugar tees away.

### 4. The best future local landing zone is near `simplify-locals`, but as a separate explicit pass

Re-reading the local code sharpened the practical port map:

- `src/passes/simplify_locals.mbt` is the clearest neighboring implementation area because it already owns the repo's main locals-rewrite machinery
- `src/passes/pass_manager_wbtest.mbt` proves that current locals-family work still explicitly reasons about tee-producing rewrites and tee-adjacent structure
- the upstream dossier keeps the split from `simplify-locals-notee` explicit, so a future port should do the same locally rather than folding `untee` into some broader variant by name alone

That means the most useful current Starshine bridge is not a fake owner file.
It is a truthful status page that points to the exact removed-registry handling now, plus the exact locals-family code a future explicit `untee` pass would likely need to compose with.

### 5. Even without a local owner, the future correctness contract is already clear

The Binaryen dossier is mature enough that a future Starshine port already has a stable source-backed invariant list to preserve:

- exact public name `untee`
- function-parallel scope
- `LocalSet` / tee-only candidate selection
- postorder nested expansion
- reachable tee rewrite into explicit set plus get
- declared-local-type reuse for the synthetic get
- unreachable-tee deletion instead of fabricating a get-after-unreachable wrapper
- explicit separation from `simplify-locals-notee` and from generic flattening claims

That means the missing local decision is not “what does `untee` do?”
It is “when and where should Starshine expose this very small explicit tee-desugaring pass without blurring it into the broader locals family?”

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-untee-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0279-2026-04-23-untee-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/untee/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/untee/index.md`
- `docs/wiki/binaryen/passes/untee/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/untee/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `untee` work needs a clean provenance-plus-local-status path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-untee-primary-sources.md`
2. `docs/wiki/binaryen/passes/untee/index.md`
3. `docs/wiki/binaryen/passes/untee/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/untee/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/untee/flattening-code-pushing-and-tee-boundaries.md`
6. `docs/wiki/binaryen/passes/untee/wat-shapes.md`
7. `docs/wiki/binaryen/passes/untee/starshine-strategy.md`
8. `docs/wiki/binaryen/passes/code-pushing/index.md`
9. `docs/wiki/binaryen/passes/simplify-locals/index.md`
10. `docs/wiki/binaryen/passes/simplify-locals-notee/index.md`
11. `src/passes/optimize.mbt`
12. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
13. `src/passes/simplify_locals.mbt`
14. `src/passes/pass_manager_wbtest.mbt`
15. `agent-todo.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status: the name is preserved and honestly rejected, there is still no local implementation or active backlog slice, the nearest live locals code still reasons about tees from the optimization side rather than the desugaring side, and the right future landing zone is therefore near `simplify-locals` but still as a separate explicit pass.
