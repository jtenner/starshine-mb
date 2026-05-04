# 0433 - `simplify-locals-nostructure` current-main recheck

- **Date:** 2026-05-04
- **Question:** does the existing `simplify-locals-nostructure` dossier still match current Binaryen main, and can the folder be made easier to use for a future Starshine port without creating a duplicate pass page?
- **Status:** absorbed into the living wiki pages under `docs/wiki/binaryen/passes/simplify-locals-nostructure/`

## Sources checked

- [`../binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md)
- [`../binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- Existing living dossier pages under `docs/wiki/binaryen/passes/simplify-locals-nostructure/`
- Local planning surfaces: `src/passes/optimize.mbt`, `src/passes/optimize_test.mbt`, `src/passes/pass_manager.mbt`, `src/passes/simplify_locals.mbt`, `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`, and `agent-todo.md`

## Findings

- Current Binaryen main still matches the source-backed `version_129` no-structure contract on the reviewed surfaces.
- The pass remains the shared locals-family engine instantiated as `SimplifyLocals<true, false, true>`.
- The existing folder had the upstream algorithm and shape coverage, but it still lacked the now-standard implementation-readiness bridge for Starshine.
- The current Starshine story is still a tracked missing pass plus a scheduler/tuple-slot honesty rule, not an implementation.

## Wiki changes filed from this note

- Added `docs/wiki/binaryen/passes/simplify-locals-nostructure/starshine-port-readiness-and-validation.md`.
- Refreshed the existing no-structure landing page, strategy page, implementation/test-map, variant-surface, and WAT-shape pages with the new provenance anchor.
- Updated the pass catalogs and log so the new port-readiness page is discoverable from the shared indexes.

## Open caveat

- This was a focused current-main recheck, not a complete semantic diff of all `SimplifyLocals.cpp` internals against `version_129`.
