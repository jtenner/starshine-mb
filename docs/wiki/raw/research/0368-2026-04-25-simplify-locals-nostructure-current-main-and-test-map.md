# `simplify-locals-nostructure` Current-Main And Test-Map Follow-Up

- **Date:** 2026-04-25
- **Pass:** `simplify-locals-nostructure` / local removed spelling `simplify-locals-no-structure`
- **Status:** absorbed into living wiki pages under `docs/wiki/binaryen/passes/simplify-locals-nostructure/`

## Question

The pass dossier already explained the upstream strategy and transformed shapes, but it still lacked the now-standard implementation/test-map page and carried older 2026-04-22 freshness wording. The run asked whether the folder could be made more usable for a future Starshine port without duplicating the full `simplify-locals` family dossier.

## Sources checked

- Raw source manifest: [`../binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- Existing raw source manifest: [`../binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- Existing research notes: [`0263`](0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md), [`0117`](0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- Local code surfaces: `src/passes/optimize.mbt`, `src/passes/optimize_test.mbt`, `src/passes/pass_manager.mbt`, `src/passes/simplify_locals.mbt`, and `agent-todo.md`

## Findings

- Binaryen `main` still shows no teaching-relevant drift from the `version_129` contract checked here.
- The pass remains the shared locals-family engine instantiated as `SimplifyLocals<true, false, true>`.
- The strongest implementation bridge for readers is now a source/file/test map rather than another algorithm summary.
- `pass.h` is part of the real validation contract because pass-runner nondefaultable-local fixups remain a postcondition for the locals family; earlier no-structure pages under-emphasized that point.
- The Starshine side needed sharper line-specific wording: the current slot-blocker regression is named `tuple-optimization exact preset slot remains unavailable while no-structure neighbor is missing`, and `pass_manager.mbt` dispatches only full `simplify-locals` today.

## Filed-back changes

- Added `docs/wiki/binaryen/passes/simplify-locals-nostructure/implementation-structure-and-tests.md`.
- Refreshed the landing page, Binaryen strategy, WAT-shape catalog, variant-surface guide, and Starshine strategy page to cite the 2026-04-25 raw source bridge and new implementation/test-map page.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Open caveats

- This was a focused current-main recheck, not a complete line-by-line semantic diff of `SimplifyLocals.cpp` between `version_129` and `main`.
- Starshine still has no real `SLNS` transform. The newly improved wiki page is a follow-along and port-planning aid, not implementation evidence.
