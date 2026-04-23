---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-directize-primary-sources.md
  - ../../binaryen/passes/directize/index.md
  - ../../binaryen/passes/directize/binaryen-strategy.md
  - ../../binaryen/passes/directize/implementation-structure-and-tests.md
  - ../../binaryen/passes/directize/table-info-and-immutability.md
  - ../../binaryen/passes/directize/wat-shapes.md
  - ../../binaryen/passes/directize/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/duplicate-import-elimination/index.md
  - ../../binaryen/passes/simplify-globals-optimizing/index.md
  - ../../binaryen/passes/remove-unused-module-elements/index.md
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/reorder-globals/index.md
---

# `directize` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `directize` dossier already had a solid landing page, upstream strategy page, implementation/test map, focused table-facts explainer, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder mostly as upstream research instead of a clean bridge from the reviewed Binaryen contract to the exact in-repo Starshine status and future landing zone

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-directize-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `Directize.cpp` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `call-utils.h`
- `table-utils.h`
- `table-utils.cpp`
- `type-updating.h`
- the dedicated `directize_all-features`, `directize-gc`, and `directize-wasm64` lit files

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `duplicate-import-elimination`, `simplify-globals-optimizing`, `remove-unused-module-elements`, `string-gathering`, and `reorder-globals`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not a conceptual rewrite

The existing upstream pages were still broadly correct.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, implementation-map, table-facts, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the pass explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`directize` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps `directize` in the boundary-only registry surface, so the pass spelling and its “late boundary work” classification are intentionally tracked rather than forgotten
- the same file's `run_hot_pipeline_expand_passes(...)` path rejects `directize` requests with the boundary-only error rather than pretending the pass exists in the active hot pipeline
- `agent-todo.md` already keeps an explicit `DIR` backlog slice with eligibility, rewrite, boundary-regression, and artifact-proof deliverables
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records that `directize` is the final pass in the canonical no-DWARF tail
- the neighboring dossiers for `duplicate-import-elimination`, `simplify-globals-optimizing`, `remove-unused-module-elements`, `string-gathering`, and `reorder-globals` already describe the exact late-tail landing zone a future port would need to respect

Before this run, that local status was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story here is “boundary-only status and landing-zone planning,” not a fake implementation page

Unlike the already-implemented hot and module passes, `directize` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore makes three things explicit instead of smoothing them over:

- current Starshine executes no `directize` transform today
- the in-repo implementation status is deliberately tracked through the boundary-only registry, the generic boundary-only request guard, the backlog slice, and the scheduler docs
- the exact read-along path for a future implementation already exists in neighboring code and docs, especially the late-tail passes that should run before it and the boundary-sensitive call/table work it would need to add

That is a more useful beginner-to-advanced teaching frame than pretending the dossier is only upstream-facing until code lands.

### 4. The future local implementation should be taught as a late boundary/module pass, not as just another hot peephole

Re-reading the local scheduler docs and registry surfaces reinforces a useful planning point:

- Binaryen places `directize` after `reorder-globals`
- it is the final top-level pass in the canonical no-DWARF tail
- its correctness depends on module-wide table analysis before function-local call rewriting starts
- the backlog already frames the work in terms of call-target eligibility, table behavior, and boundary regressions rather than generic local cleanup

That means a future Starshine port should be framed as a late boundary/module pass with whole-module table facts plus function-local rewrites, not as an ordinary HOT-region peephole.
The new local page makes that dependency map explicit.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-directize-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/directize/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/directize/index.md`
- `docs/wiki/binaryen/passes/directize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/directize/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/directize/table-info-and-immutability.md`
- `docs/wiki/binaryen/passes/directize/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `directize` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-directize-primary-sources.md`
2. `docs/wiki/binaryen/passes/directize/index.md`
3. `docs/wiki/binaryen/passes/directize/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/directize/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/directize/table-info-and-immutability.md`
6. `docs/wiki/binaryen/passes/directize/wat-shapes.md`
7. `docs/wiki/binaryen/passes/directize/starshine-strategy.md`
8. `src/passes/optimize.mbt`
9. `agent-todo.md`
10. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
11. `docs/wiki/binaryen/passes/duplicate-import-elimination/index.md`
12. `docs/wiki/binaryen/passes/simplify-globals-optimizing/index.md`
13. `docs/wiki/binaryen/passes/remove-unused-module-elements/index.md`
14. `docs/wiki/binaryen/passes/string-gathering/index.md`
15. `docs/wiki/binaryen/passes/reorder-globals/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, and the neighboring local passes that a real future port would need to interoperate with.
