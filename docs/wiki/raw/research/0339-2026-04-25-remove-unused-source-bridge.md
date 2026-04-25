# 0339 - `remove-unused` source bridge and Starshine status

Date: 2026-04-25

## Scope

This thread continued the pass-wiki health loop and chose local boundary-only `remove-unused` because the dossier already existed but still had two durable gaps:

1. no immutable raw primary-source manifest for the historical Binaryen lineage; and
2. no dedicated Starshine status / port-strategy page with exact local code locations.

The prior living pages and note `0195` already established the broad finding: local `remove-unused` is best read as a stale local alias for historical upstream `remove-unused-functions`, not as a current upstream `version_129` public pass spelling or a direct synonym for modern `remove-unused-module-elements`.

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
- existing `docs/wiki/binaryen/passes/remove-unused/` pages
- existing note `docs/wiki/raw/research/0195-2026-04-21-remove-unused-binaryen-research.md`

The run found that the correct action was to update the existing folder, not create a duplicate pass page.

## Primary online sources reviewed

Official Binaryen sources:

- Historical `RemoveUnusedFunctions.cpp`: <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
- Historical `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/pass.cpp>
- Historical `passes.h`: <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/passes.h>
- Supersession commit: <https://github.com/WebAssembly/binaryen/commit/98e9e604c7e2e4f928abe8f05691df90cddf09e4>
- Supersession `RemoveUnusedModuleElements.cpp`: <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp>
- Current `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Current `main` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Current help surfaces: `test/lit/help/wasm-opt.test`, `wasm-metadce.test`, and `wasm2js.test` at `version_129`
- Binaryen README overview: <https://github.com/WebAssembly/binaryen>

The durable source capture is now `docs/wiki/raw/binaryen/2026-04-25-remove-unused-primary-sources.md`.

## Durable findings

- Historical Binaryen exposed `remove-unused-functions`.
- Historical `RemoveUnusedFunctions.cpp` rooted the start function, exported functions, and functions named in table segments; then it used direct-call reachability, erased unreachable functions, and rebuilt the functions map.
- Binaryen commit `98e9e604...` is the useful supersession anchor: the public registration, scheduler use, and factory surface moved to `remove-unused-module-elements`.
- Current Binaryen `version_129` and the current `main` spot check expose modern removal-family names but not `remove-unused` or `remove-unused-functions`.
- Starshine currently keeps the short name `remove-unused` as boundary-only in `src/passes/optimize.mbt`.
- Active requests for `remove-unused` fail during `run_hot_pipeline_expand_passes(...)` with the boundary-only error before any module dispatcher can run.
- Starshine's implemented modern replacement is the separate `remove-unused-module-elements` module pass in `src/passes/remove_unused_module_elements.mbt`, dispatched from `src/passes/pass_manager.mbt`.

## Local code map added to the living wiki

The new `starshine-strategy.md` maps readers to:

- `src/passes/optimize.mbt` for boundary-only classification and request rejection;
- `src/passes/pass_manager.mbt` for the implemented module dispatcher roster, which includes modern RUME but no `remove-unused` case;
- `src/passes/remove_unused_module_elements.mbt` for the implemented successor-like modern module pass;
- `src/passes/registry_test.mbt` for registry/preset category expectations;
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` for the Batch 4 boundary-cleanup grouping;
- `agent-todo.md` as the active-backlog check, which has no dedicated `remove-unused` slice.

## Uncertainty preserved

The living dossier still does not claim there is a direct local commit proving `remove-unused` was intentionally coined as an alias for historical upstream `remove-unused-functions`. It records that relation as the best source-backed inference from:

- the local short registry name;
- the Batch 4 cleanup grouping;
- the old upstream function-only pass;
- the modern upstream absence of a public `remove-unused` spelling.

## Wiki changes made

- Added `docs/wiki/raw/binaryen/2026-04-25-remove-unused-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/remove-unused/starshine-strategy.md`.
- Refreshed the existing `remove-unused` landing, Binaryen strategy, implementation/test-map, lineage, and module-shape pages so they cite the raw manifest and the new Starshine page.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.
- Marked this note as superseding `0195` only for raw-source provenance and Starshine status; `0195` remains the original folder-creation and lineage-research note.

## Suggested future work

- If the local registry eventually removes or renames `remove-unused`, update this dossier rather than deleting it; it should become the migration note that points users to modern `remove-unused-module-elements`.
- If someone wants a literal historical function-only pass, create a new backlog slice and decide whether the public spelling should be `remove-unused-functions` rather than preserving the ambiguous short alias.
- Do not add `remove-unused` to presets unless the registry name is clarified and an implementation contract is chosen explicitly.
