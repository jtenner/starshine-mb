# 0420 - `remove-unused` port-readiness and registry-hygiene bridge

Date: 2026-04-27

## Scope

This run continued the pass-wiki health loop and chose local boundary-only `remove-unused` because its lineage dossier was source-correct but still lacked a dedicated first-step / validation bridge for what Starshine should do with the ambiguous historical alias.

The existing folder already had the required overview, shape catalog, Binaryen strategy, Starshine status, and historical-lineage pages. The useful improvement was to make the future action space explicit: keep rejecting the alias, remove/rename it, or implement the old function-only pass literally, rather than accidentally routing the short name to modern RUME.

## Overlap check

Before editing, this run re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/`
- the existing `docs/wiki/binaryen/passes/remove-unused/` folder
- the existing raw manifest `docs/wiki/raw/binaryen/2026-04-25-remove-unused-primary-sources.md`
- the prior research note `docs/wiki/raw/research/0339-2026-04-25-remove-unused-source-bridge.md`

The correct action was to update the existing folder, not create a duplicate pass page.

## Primary online sources rechecked

Official Binaryen sources:

- Current `main` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Current `main` `RemoveUnusedModuleElements.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp>
- Historical `RemoveUnusedFunctions.cpp`: <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>

The durable source capture is now `docs/wiki/raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md`.

## Durable findings

- Current Binaryen `main` still exposes the modern removal-family names, but not `remove-unused` or `remove-unused-functions`.
- Current Binaryen `main` still schedules `remove-unused-module-elements` in the default global optimization paths.
- Historical `RemoveUnusedFunctions.cpp` remains the best source-backed model for what a literal old `remove-unused` implementation would mean: start/export/table-segment roots, direct-call reachability, erase unreachable functions, update the function map.
- Starshine still keeps `remove-unused` only in `pass_registry_boundary_only_names()`.
- Starshine's active module dispatcher has modern RUME/RUNE cases but no `remove-unused` case.
- Starshine already has a broader implemented successor-like pass in `remove_unused_module_elements.mbt`; that pass should not be silently treated as the local short-name implementation.

## Wiki changes made

- Added `docs/wiki/raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/remove-unused/starshine-port-readiness-and-validation.md`.
- Refreshed the `remove-unused` landing page, Starshine strategy page, top-level wiki index, pass index, tracker, and log so the new bridge is discoverable.

## Future implementation guardrails

If the alias remains boundary-only, tests should prove request rejection stays clear and non-ambiguous.

If the alias is removed or renamed, update this folder as the migration record and keep linking modern work to `remove-unused-module-elements`.

If a literal old-function-DCE port is requested, do it in two slices:

1. analyzer-only root/reachability report for start, exports, active table elements, and direct calls;
2. mutation slice with function deletion and all affected function-index, export, start, table/element, name, and validation repair checks.

Do not add `remove-unused` to presets unless its meaning is chosen explicitly.
