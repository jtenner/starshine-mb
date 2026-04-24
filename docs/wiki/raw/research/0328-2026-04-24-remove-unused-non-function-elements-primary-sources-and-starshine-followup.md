# 0328 - `remove-unused-non-function-elements` primary sources and Starshine follow-up

Date: 2026-04-24  
Author: OpenAI Codex  
Status: archived research feeding living wiki pages

## Scope

This run followed the wiki-health task loop:

1. re-read `AGENTS.md` and `docs/README.md`;
2. inspected `docs/wiki/`, `docs/wiki/index.md`, `docs/wiki/log.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/raw/research/` for overlapping work;
3. checked `git status` before edits;
4. selected an existing pass dossier that had useful coverage but still lacked an immutable 2026-04-24 raw primary-source manifest and a dedicated Starshine status/port-strategy page.

Chosen target:

- local Starshine spelling: `remove-unused-non-function-elements`
- upstream Binaryen spelling: `remove-unused-nonfunction-module-elements`

## Why this was the right next wiki improvement

The folder already had a living overview, Binaryen strategy, implementation/test map, defined-vs-imported-function guide, and module-shape catalog from `0194`.
However, compared with neighboring recently refreshed dossiers, it still lacked:

- an immutable raw source manifest under `docs/wiki/raw/binaryen/`;
- a dedicated Starshine strategy/status bridge;
- refreshed page metadata pointing readers at the current raw capture instead of only direct online links and the older research note;
- an explicit tracker/log statement that the former provenance and local-follow-along gap is closed.

That made it a good health-oriented pass-wiki target without creating a near-duplicate page.

## Primary sources captured

Added:

- `docs/wiki/raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`

Primary sources recorded there include:

- Binaryen `version_129` release page
- `src/passes/RemoveUnusedModuleElements.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/module-utils.h`
- `test/passes/remove-unused-nonfunction-module-elements_all-features.wast`
- inherited full-RUME lit files for configureAll, refs, tables, and TNH behavior
- current-`main` spot-check URLs for the owner file, registration files, helper header, and dedicated test

## Source-backed Binaryen conclusions

The refreshed source reading preserves the earlier `0194` conclusion but gives it better provenance:

- The upstream public pass name is `remove-unused-nonfunction-module-elements`.
- It is a real public pass registered in `pass.cpp`, not just a private testing mode.
- It shares `RemoveUnusedModuleElements.cpp` with full `remove-unused-module-elements`.
- The core implementation distinction is the `rootAllFunctions` constructor policy.
- In sibling mode, Binaryen roots all **defined** functions before running the shared analyzer.
- Imported functions are not protected by that sibling-specific root rule.
- The sibling still inherits shared RUME behavior for start/export roots, imported-parent active segments, startup-trap retention, non-function deletion, index repair, and function-type cleanup.
- A no-op start declaration can still disappear while the defined function body remains.

## Current-main caveat

A narrow 2026-04-24 current-`main` spot check confirmed that the pass identity, factory split, and dedicated test path remain present.
The owner file has helper/container drift after `version_129`, so the living strategy pages intentionally remain anchored to `version_129` and do not claim whole-file semantic equivalence with current `main`.

## Starshine findings

Added:

- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/starshine-strategy.md`

Exact local status:

- `src/passes/optimize.mbt` lists `remove-unused-non-function-elements` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt` converts that spelling to `HotPassRegistryCategory::BoundaryOnly` through the generic registry-entry builder.
- Lower-level pass expansion rejects boundary-only names with a “not implemented in the hot pipeline” error.
- `src/cmd/cmd.mbt` only accepts `HotPass`, `ModulePass`, and `Preset` pass categories in CLI pass resolution, so boundary-only names are rejected before execution and hidden from the help pass list.
- `src/passes/pass_manager.mbt` dispatches active module passes including full `remove-unused-module-elements`, but has no sibling case.
- `src/passes/remove_unused_module_elements.mbt` implements the reusable full-RUME liveness/rewrite engine but has no `root_all_defined_functions` sibling mode today.
- `src/passes/remove_unused_module_elements_test.mbt` has reusable full-RUME fixtures and validation tests, but no sibling-specific expectations that dead defined functions survive.
- `agent-todo.md` has no dedicated active slice for this sibling.

## Future port sketch

A faithful implementation should parameterize the current full-RUME machinery rather than fork a new pass:

1. add an active module-pass registry entry only when implemented;
2. add a liveness-seeding policy that roots all defined functions;
3. preserve imported-function removability;
4. reuse the existing RUME traversal, remap, type cleanup, data-count, annotation/name repair, and validation paths;
5. add tests for dead defined-function preservation, dead non-function deletion, imported-function removal, function-type compaction, no-op start metadata cleanup, and full-RUME non-regression.

## Pages updated

- `docs/wiki/raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/index.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/shared-engine-rooting-and-defined-vs-imported-functions.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/module-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/starshine-strategy.md`
- `docs/wiki/raw/research/0194-2026-04-21-remove-unused-non-function-elements-binaryen-research.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Supersession note

This note does not make `0194` obsolete as the first investigation.
It supersedes only the provenance and local-status gaps left by `0194`.
Use the new raw manifest and Starshine strategy page as the current source pointers; keep `0194` as historical source-confirmation research.
