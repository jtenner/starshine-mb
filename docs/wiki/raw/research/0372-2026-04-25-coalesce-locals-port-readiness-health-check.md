# `coalesce-locals` port-readiness health check

Status: absorbed into living wiki pages  
Date: 2026-04-25  
Pass: `coalesce-locals`  
Related dossier: `docs/wiki/binaryen/passes/coalesce-locals/`

## Why this run picked the pass

The main no-DWARF / saved-`-O4z` queue is now broadly dossier-covered, so this run looked for a pass where coverage was present but still uneven.
`coalesce-locals` was a good health target because:

- the folder already had the required overview, Binaryen strategy, transformed-shape catalog, implementation/test map, and Starshine strategy page;
- the tracker still labeled it `dossier` rather than `deep`, unlike neighboring local-cleanup dossiers with comparable or weaker page coverage;
- the Starshine strategy page mapped current status, but future implementers still had to infer the actual port-readiness and validation ladder across several pages;
- the pass remains an important missing local-neighborhood blocker for honest `local-subtyping -> coalesce-locals -> local-cse` and `reorder-locals -> coalesce-locals -> reorder-locals` scheduling.

## Primary sources checked

This run reused the committed Binaryen raw manifests instead of creating a duplicate source capture:

- `docs/wiki/raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`

Those manifests point to official Binaryen sources:

- Binaryen `version_129` `CoalesceLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- Binaryen current `main` `CoalesceLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CoalesceLocals.cpp>
- Binaryen `version_129` pass registration and scheduling: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen current `main` pass registration and scheduling: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen `version_129` `coalesce-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
- Binaryen current `main` `coalesce-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/coalesce-locals.wast>

No new teaching-level Binaryen drift was found beyond the existing 2026-04-25 current-main bridge.

## Local sources checked

- `src/passes/optimize.mbt`
  - `pass_registry_removed_names()` still includes `coalesce-locals` at the current line map.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` still do not schedule the pass.
- `src/passes/reorder_locals.mbt`
  - existing local-index scan/rewrite/module-pass surfaces remain the nearest landed declaration-rewrite substrate.
- `src/passes/simplify_locals.mbt`
  - existing HOT local cleanup phases remain the nearest landed later cleanup consumer.
- `agent-todo.md`
  - `CL` still exists as the compatibility/lifetime and dual-slot rewrite planning slice.

Unrelated local source edits existed in the worktree before this run (`src/cmd/cmd_wbtest.mbt`, `src/passes/optimize_instructions.mbt`, and `src/passes/optimize_instructions_test.mbt`), so this run kept all edits in docs and wiki files.

## Durable conclusions filed back

- Added `docs/wiki/binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md`.
- Updated the `coalesce-locals` landing page and Starshine strategy page so the new port-readiness matrix is linked from the dossier entry points.
- Updated `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md` so the new page is discoverable.
- Updated `docs/wiki/binaryen/passes/tracker.md` so `coalesce-locals` is now marked `deep` rather than `dossier`.
- Updated `docs/wiki/log.md` and `CHANGELOG.md` with the source-backed health pass.

## Remaining uncertainty

The upstream source contract is clear enough for documentation: exact-type coalescing, value-aware interference, greedy ordering, backedge priority, and cleanup/refinalization boundaries.
The remaining uncertainty is local implementation architecture, not Binaryen behavior:

- a future port could model the analysis directly as a module/function pass with local declaration repair;
- or it could use HOT-assisted per-function analysis for body facts, then perform module-level declaration/name-section repair afterward.

Either route must still preserve Binaryen's scheduler-neighborhood contract and should not broaden `coalesce-locals` into subtype merging, local-CSE, or generic dead-store elimination.
