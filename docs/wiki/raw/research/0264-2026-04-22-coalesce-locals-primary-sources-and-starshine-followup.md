---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/binaryen-strategy.md
  - ../../binaryen/passes/coalesce-locals/interference-and-ordering.md
  - ../../binaryen/passes/coalesce-locals/wat-shapes.md
  - ../../binaryen/passes/coalesce-locals/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../src/passes/reorder_locals_test.mbt
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/local-subtyping/index.md
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/simplify-locals/index.md
---

# `coalesce-locals` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `coalesce-locals` dossier already had a useful landing page, Binaryen strategy page, interference/order guide, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder only as an upstream research home, without a clean bridge to the exact in-repo Starshine status and future port surfaces

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `CoalesceLocals.cpp` on `version_129` and `main`
- `pass.cpp`
- `opt-utils.h`
- `liveness-traversal.h`, `numbering.h`, and `utils.h`
- the dedicated `coalesce-locals.wast` file

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/reorder_locals.mbt`
- `src/passes/reorder_locals_test.mbt`
- `src/passes/simplify_locals.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `local-subtyping`, `local-cse`, `reorder-locals`, and `simplify-locals`

## Durable findings

### 1. The Binaryen side did not need a rewrite; it needed provenance and freshness anchors

The existing upstream pages were still broadly correct.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` check did not surface a new teaching-relevant drift beyond the existing strategy, interference/order, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and then thread that provenance into the living pages, not to replace the pass explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`coalesce-locals` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already has a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps the upstream spelling `coalesce-locals` in the removed-name registry, so the pass is intentionally tracked rather than forgotten
- `agent-todo.md` keeps an explicit `CL` backlog slice with delivery expectations around compatibility analysis, rewrite stability, and `reorder-locals` interaction
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records both top-level no-DWARF slots where the pass belongs in the canonical late local-cleanup cluster
- `src/passes/optimize_test.mbt` already locks in one important honesty rule: current `optimize` and `shrink` presets do **not** schedule `reorder-locals` before its neighboring missing passes like `coalesce-locals` land
- neighboring implementation and test surfaces already show the local index-rewrite and cleanup machinery a future port would likely need to compose with, especially `src/passes/reorder_locals.mbt`, `src/passes/reorder_locals_test.mbt`, and `src/passes/simplify_locals.mbt`

Before this run, that local state was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story here is “boundary and port plan,” not a fake implementation page

Unlike the already-implemented hot and module passes, `coalesce-locals` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore makes three things explicit instead of smoothing them over:

- current Starshine executes no `coalesce-locals` transform today
- the in-repo implementation status is deliberately boundary tracking through the removed-name registry, backlog slice, and scheduler docs
- the exact read-along path for a future implementation already exists in neighboring code and docs, especially the module-side local-index rewrite and local-cleanup files that already teach slot rewriting, local metadata repair, and later local traffic cleanup in MoonBit terms

That is a more useful beginner-to-advanced teaching frame than pretending the dossier is only upstream-facing until code lands.

### 4. The future local port should be taught as a bridge between the current local-type and local-tree passes, not as a stand-alone register allocator

Re-reading the local scheduler docs and neighboring pass dossiers reinforces a useful planning point:

- Binaryen runs `coalesce-locals` after `local-subtyping`, because exact-type-only coalescing should see the narrowed declarations first
- Binaryen then hands the result to `local-cse` and later `simplify-locals`, so the pass sits in a cleanup cluster rather than alone
- Binaryen runs `coalesce-locals` again later between two `reorder-locals` slots, so repeated local declaration compaction is part of the real story
- current Starshine already has the late declaration/index rewrite neighbor (`reorder-locals`) and the later cleanup consumer (`simplify-locals`), but it still lacks the missing upstream neighbors `local-subtyping`, `coalesce-locals`, and `local-cse`

That means the practical Starshine strategy today is:

- keep the pass tracked in the registry and backlog
- keep the pipeline slots documented honestly
- point future port work at the exact local neighbor files that already solve the closest index-rewrite, name-rewrite, and cleanup problems
- avoid pretending that the exact Binaryen slot can be claimed before the missing neighbors land

### 5. The current local landing zone is concrete enough to document now

The new Starshine page records the most useful exact read-along path for a future port:

- removed-name registry truth in `src/passes/optimize.mbt`
- preset-honesty proof in `src/passes/optimize_test.mbt`
- backlog and artifact-proof expectations in `agent-todo.md`
- scheduler truth in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- module-side local index scan/rewrite and grouped-local-run rebuild logic in `src/passes/reorder_locals.mbt`
- local-name and raw-name-section repair proof in `src/passes/reorder_locals_test.mbt`
- later local-traffic cleanup machinery in `src/passes/simplify_locals.mbt`
- neighboring living dossiers that define the intended upstream cluster: `local-subtyping`, `local-cse`, `reorder-locals`, and `simplify-locals`

That map is useful even before any `coalesce_locals.mbt` file exists because it tells future contributors where the closest already-landed local reasoning lives in this repo.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/coalesce-locals/index.md`
- `docs/wiki/binaryen/passes/coalesce-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/coalesce-locals/interference-and-ordering.md`
- `docs/wiki/binaryen/passes/coalesce-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `coalesce-locals` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`
2. `docs/wiki/binaryen/passes/coalesce-locals/index.md`
3. `docs/wiki/binaryen/passes/coalesce-locals/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/coalesce-locals/interference-and-ordering.md`
5. `docs/wiki/binaryen/passes/coalesce-locals/wat-shapes.md`
6. `docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `src/passes/optimize_test.mbt`
9. `agent-todo.md`
10. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
11. `src/passes/reorder_locals.mbt`
12. `src/passes/reorder_locals_test.mbt`
13. `src/passes/simplify_locals.mbt`
14. `docs/wiki/binaryen/passes/local-subtyping/index.md`
15. `docs/wiki/binaryen/passes/local-cse/index.md`
16. `docs/wiki/binaryen/passes/reorder-locals/index.md`
17. `docs/wiki/binaryen/passes/simplify-locals/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the removed-registry tracking, and the neighboring implementation files and dossiers that a real future local port would need to interoperate with.
