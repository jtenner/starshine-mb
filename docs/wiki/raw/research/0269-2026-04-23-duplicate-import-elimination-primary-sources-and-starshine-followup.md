---
kind: research
status: superseded
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-duplicate-import-elimination-current-main-recheck.md
  - ../binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md
  - ../../binaryen/passes/duplicate-import-elimination/index.md
  - ../../binaryen/passes/duplicate-import-elimination/binaryen-strategy.md
  - ../../binaryen/passes/duplicate-import-elimination/implementation-structure-and-tests.md
  - ../../binaryen/passes/duplicate-import-elimination/identity-and-rewrite-surface.md
  - ../../binaryen/passes/duplicate-import-elimination/wat-shapes.md
  - ../../binaryen/passes/duplicate-import-elimination/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/simplify-globals-optimizing/index.md
  - ../../binaryen/passes/remove-unused-module-elements/index.md
---

# `duplicate-import-elimination` primary-source and Starshine follow-up

> Supersession note, 2026-04-25: this note remains useful for the original raw-source provenance and the then-current boundary-only local status. Its Starshine status claims are now stale because `duplicate-import-elimination` is an active module pass in `src/passes/duplicate_import_elimination.mbt`, registered in `src/passes/optimize.mbt`, and dispatched in `src/passes/pass_manager.mbt`. Use [`../binaryen/2026-04-25-duplicate-import-elimination-current-main-recheck.md`](../binaryen/2026-04-25-duplicate-import-elimination-current-main-recheck.md) plus the living dossier pages for current status.

## Why this follow-up exists

The existing `duplicate-import-elimination` dossier already had a corrected landing page, Binaryen strategy page, implementation/test map, identity/rewrite explainer, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still stopped at the corrected upstream contract instead of also giving readers one clean bridge into the exact in-repo Starshine status and future landing zone

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `DuplicateImportElimination.cpp` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `opt-utils.h`
- `import-utils.h`
- the dedicated `duplicate-import-elimination.wast` and `.txt` test pair

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `duplicate-function-elimination`, `simplify-globals-optimizing`, and `remove-unused-module-elements`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not another contract rewrite

The existing upstream pages were still broadly correct after the 2026-04-21 source correction.
The missing piece was provenance:

- on 2026-04-23 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, implementation-map, identity/rewrite, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the already-corrected Binaryen explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`duplicate-import-elimination` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps `duplicate-import-elimination` in the boundary-only registry surface
- the same file's `run_hot_pipeline_expand_passes(...)` path rejects the pass with a boundary-only error rather than pretending it exists in the active hot pipeline
- `agent-todo.md` already keeps a dedicated `DIE` backlog slice
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records the canonical late-tail slot between `duplicate-function-elimination` and `simplify-globals-optimizing`
- the neighboring `duplicate-function-elimination`, `simplify-globals-optimizing`, and `remove-unused-module-elements` dossiers already describe the practical late-boundary landing zone a future port would need to respect

Before this run, that local status was scattered.
The new Starshine page turns it into one teachable path.

### 3. The current backlog wording is broader than reviewed Binaryen `version_129`

The most important local contradiction exposed by this follow-up is in `agent-todo.md`.
The current `DIE` slice still says future work should:

- compare import module, field, and external type exactly
- patch function, table, global, and memory import users consistently

That is broader than the reviewed Binaryen `version_129` contract.
The reviewed upstream pass is still function-import-only today, with rewrites limited to the function-name surface.

This follow-up does **not** silently smooth over that mismatch.
Instead it makes the contradiction explicit in the new Starshine page and the refreshed catalogs so future port work starts from the corrected Binaryen contract rather than from the older broader backlog wording.

### 4. The honest Starshine story here is “boundary-only tracking plus a corrected port map,” not a fake implementation page

Unlike the already-implemented module passes, `duplicate-import-elimination` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore keeps three things explicit:

- current Starshine executes no `duplicate-import-elimination` transform today
- the repo still intentionally preserves the pass spelling, boundary-only classification, request guard, backlog slice, and scheduler slot
- a future Starshine parity port should start from the reviewed Binaryen function-import-only contract, not from the older all-import or cross-kind merge idea

That is more useful than leaving the folder as corrected-upstream-only research with no exact local read-along map.

### 5. A future local implementation should be taught as a small late boundary/module pass

Re-reading the local scheduler docs and registry surface reinforces a planning point:

- Binaryen places `duplicate-import-elimination` late, after `duplicate-function-elimination`
- the pass depends on module import declarations and module-level function-reference rewrites, not HOT-region local rewriting
- its real implementation surface is small: imported-function scan, `(module, base)` bucketing, exact function-type equality, function-name rewrites, and immediate duplicate import removal

So the right local mental model is a small late boundary/module pass.
It is not a generic import deduplicator, and it is not a function-local hot pass.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0269-2026-04-23-duplicate-import-elimination-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/duplicate-import-elimination/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/duplicate-import-elimination/index.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `duplicate-import-elimination` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md`
2. `docs/wiki/binaryen/passes/duplicate-import-elimination/index.md`
3. `docs/wiki/binaryen/passes/duplicate-import-elimination/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/duplicate-import-elimination/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/duplicate-import-elimination/identity-and-rewrite-surface.md`
6. `docs/wiki/binaryen/passes/duplicate-import-elimination/wat-shapes.md`
7. `docs/wiki/binaryen/passes/duplicate-import-elimination/starshine-strategy.md`
8. `src/passes/optimize.mbt`
9. `agent-todo.md`
10. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
11. `docs/wiki/binaryen/passes/duplicate-function-elimination/index.md`
12. `docs/wiki/binaryen/passes/simplify-globals-optimizing/index.md`
13. `docs/wiki/binaryen/passes/remove-unused-module-elements/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the corrected scope mismatch in local planning, and the neighboring local passes that a real future port would need to interoperate with.
