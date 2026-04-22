---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/local-cse/binaryen-strategy.md
  - ../../binaryen/passes/local-cse/basic-block-windows-and-barriers.md
  - ../../binaryen/passes/local-cse/wat-shapes.md
  - ../../binaryen/passes/local-cse/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/index.md
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/reorder-locals/index.md
---

# `local-cse` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `local-cse` dossier already had a useful landing page, Binaryen strategy page, windows/barriers page, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder only as an upstream research home, without a clean bridge to the exact in-repo Starshine status and future port surfaces

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-local-cse-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `LocalCSE.cpp` on `version_129` and `main`
- `pass.cpp`
- `opt-utils.h`
- `linear-execution.h`, `effects.h`, `properties.{h,cpp}`, `intrinsics.h`, and `cost.h`
- the dedicated `local-cse.wast` file

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `src/passes/simplify_locals.mbt`
- `src/passes/reorder_locals.mbt`
- `src/passes/pass_manager_wbtest.mbt`
- `src/cmd/cmd_wbtest.mbt`
- the neighboring living dossiers for `flatten`, `simplify-locals-notee-nostructure`, `coalesce-locals`, `simplify-locals`, and `reorder-locals`

## Durable findings

### 1. The Binaryen side did not need a rewrite; it needed provenance and freshness anchors

The existing upstream pages were still broadly correct.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` check did not surface a new teaching-relevant drift beyond the existing strategy, windows/barriers, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and then thread that provenance into the living pages, not to replace the pass explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`local-cse` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already has a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps the upstream spelling `local-cse` in the removed-name registry, so the pass is intentionally tracked rather than forgotten
- `agent-todo.md` keeps an explicit `LCSE` backlog slice with delivery expectations
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records where the pass belongs in the canonical no-DWARF local-cleanup cluster
- neighboring implementation and test surfaces already show the local traffic and effect-barrier machinery a future port would likely need to compose with, especially `src/passes/simplify_locals.mbt`, `src/passes/reorder_locals.mbt`, `src/passes/pass_manager_wbtest.mbt`, and `src/cmd/cmd_wbtest.mbt`

Before this run, that local state was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story here is “boundary and port plan,” not a fake implementation page

Unlike the already-implemented hot and module passes, `local-cse` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore makes three things explicit instead of smoothing them over:

- current Starshine executes no `local-cse` transform today
- the in-repo implementation status is deliberately boundary tracking through the removed-name registry, backlog slice, and scheduler docs
- the exact read-along path for a future implementation already exists in neighboring code and docs, especially the local-cleanup and local-index-rewrite files that already teach effect barriers, local traffic, and slot rewriting in MoonBit terms

That is a more useful beginner-to-advanced teaching frame than pretending the dossier is only upstream-facing until code lands.

### 4. The future local port should be taught as a bridge between existing cleanup families, not as a stand-alone generic optimizer

Re-reading the local scheduler docs and neighboring pass dossiers reinforces a useful planning point:

- the aggressive upstream slot is `flatten -> simplify-locals-notee-nostructure -> local-cse`
- the ordinary late slot is `coalesce-locals -> local-cse -> simplify-locals`
- current Starshine already has mature local-cleanup machinery in `simplify-locals`, plus active neighboring docs and code for `reorder-locals`
- current Starshine still lacks `flatten`, `simplify-locals-notee-nostructure`, `coalesce-locals`, and `local-cse`, so exact slot placement remains intentionally blocked

That means the practical Starshine strategy today is:

- keep the pass tracked in the registry and backlog
- keep the pipeline slot documented honestly
- point future port work at the exact local neighbor files that already solve the closest local-traffic and effect-barrier problems
- avoid pretending that the exact Binaryen slot can be claimed before the missing neighbors land

### 5. The current local landing zone is concrete enough to document now

The new Starshine page records the most useful exact read-along path for a future port:

- registry and removed-name truth in `src/passes/optimize.mbt`
- backlog and artifact-proof expectations in `agent-todo.md`
- scheduler truth in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- local-effect and sinkability machinery in `src/passes/simplify_locals.mbt`
- local-index scan/rewrite machinery in `src/passes/reorder_locals.mbt`
- raw local-traffic regression surfaces in `src/passes/pass_manager_wbtest.mbt`
- CLI and artifact replay surfaces in `src/cmd/cmd_wbtest.mbt`

That map is useful even before any `local-cse.mbt` file exists because it tells future contributors where the closest already-landed local reasoning lives in this repo.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-local-cse-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/local-cse/index.md`
- `docs/wiki/binaryen/passes/local-cse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-cse/basic-block-windows-and-barriers.md`
- `docs/wiki/binaryen/passes/local-cse/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `local-cse` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-local-cse-primary-sources.md`
2. `docs/wiki/binaryen/passes/local-cse/index.md`
3. `docs/wiki/binaryen/passes/local-cse/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/local-cse/basic-block-windows-and-barriers.md`
5. `docs/wiki/binaryen/passes/local-cse/wat-shapes.md`
6. `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `agent-todo.md`
9. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
10. `src/passes/simplify_locals.mbt`
11. `src/passes/reorder_locals.mbt`
12. `src/passes/pass_manager_wbtest.mbt`
13. `src/cmd/cmd_wbtest.mbt`
14. `docs/wiki/binaryen/passes/flatten/index.md`
15. `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/index.md`
16. `docs/wiki/binaryen/passes/coalesce-locals/index.md`
17. `docs/wiki/binaryen/passes/simplify-locals/index.md`
18. `docs/wiki/binaryen/passes/reorder-locals/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the removed-registry tracking, and the neighboring implementation files and dossiers that a real future local port would need to interoperate with.
