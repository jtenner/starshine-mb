# 0325 - `reorder-functions-by-name` primary sources and Starshine follow-up

## Status

- Date: 2026-04-24
- Type: Pass-wiki source ingest / Starshine status bridge
- Pass: `reorder-functions-by-name`
- Upstream release oracle: Binaryen `version_129`
- Local Starshine status: boundary-only registry name; not implemented as a module pass

## Why this pass was chosen

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/`
- the existing `docs/wiki/binaryen/passes/reorder-functions-by-name/` folder

The folder already had a good overview, Binaryen strategy, implementation/test map, exact lexical proof page, and module-shape page. It still had two durable gaps compared with the newer dossier standard:

1. no immutable raw Binaryen primary-source manifest, only older research notes plus direct URLs;
2. no dedicated Starshine status/port-strategy page with exact local code locations.

That made `reorder-functions-by-name` a good health target: the pass is already locally named, has a tiny but real upstream contract, and is easy to blur with the count-based `reorder-functions` sibling.

## Primary online sources reviewed and ingested

The new raw manifest is:

- `docs/wiki/raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md`

It captures:

- Binaryen `version_129` release page
- `src/passes/ReorderFunctions.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/reorder-functions-by-name.wast`
- current `main` `src/passes/ReorderFunctions.cpp` spot check

## Binaryen source conclusions

The source-backed contract remains tiny and precise:

- `reorder-functions-by-name` is a separate public pass registered from `pass.cpp`.
- The upstream description frames it as useful for debugging.
- `ReorderFunctionsByName::run(Module* module)` sorts `module->functions` by ascending Binaryen internal function name.
- The pass reports that it does not require non-nullable local fixups because it changes declaration order only.
- The dedicated lit file checks four `$a/$b/$c` declaration permutations and normalizes each to the same ascending lexical order.
- The sibling `reorder-functions` shares the owner file but uses a static-reference count model instead; the two pass names should not be merged in teaching or in a future port.

## Starshine source conclusions

The exact local status is now captured in `docs/wiki/binaryen/passes/reorder-functions-by-name/starshine-strategy.md`.

Code locations reviewed:

- `src/passes/optimize.mbt`
  - `pass_registry_boundary_only_names()` contains `reorder-functions-by-name`.
  - `HotPassRegistryCache::new()` keeps boundary-only names out of help output.
  - `run_hot_pipeline_expand_passes(...)` rejects explicit boundary-only pass requests.
  - `optimize_preset_passes(...)` / `shrink_preset_passes(...)` omit this pass.
- `src/lib/types.mbt`
  - `Module` stores function declarations, bodies, exports, start section, element segments, names, and function annotations as separate surfaces.
  - `FuncSec`, `CodeSec`, `StartSec`, and `FuncIdx` define the function-order/index model a future reorder must update.
- `src/passes/remove_unused_module_elements.mbt`
  - existing function-index remap helpers and name/annotation rewrites are the closest local examples for a future implementation.
- `src/binary/encode.mbt`
  - binary encoding writes the `Module` surfaces as provided; it is not a late function-reordering layer.
- `src/wast/lower_to_lib.mbt`
  - WAT lowering resolves named function references to numeric `FuncIdx` values, so a later reorder must rewrite indices after lowering.

## Main local porting takeaway

A Starshine implementation cannot be just “sort `func_sec` and `code_sec`.”

Because Starshine's lowered module model uses numeric `FuncIdx` references, a faithful port must also remap at least:

- direct `call` / `return_call`,
- `ref.func`,
- element segment function lists and expression initializers,
- function exports,
- `start_sec`,
- function names, local names, label names,
- function annotations,
- and any future function-index-bearing metadata.

That is why the pass remains boundary-only until a module-level function-permutation rewrite is implemented.

## Pages updated

- `docs/wiki/binaryen/passes/reorder-functions-by-name/index.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/lexical-order-proof-and-boundaries.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/module-shapes.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Uncertainties and boundaries

- The current-main check was intentionally narrow: it confirmed no teaching-relevant drift in `ReorderFunctions.cpp` for the by-name pass. It did not audit unrelated Binaryen writer/index-remap internals.
- The local Starshine page is a port map, not an implementation claim. There is no owner file, no module dispatcher case, no active preset role, and no active backlog slice for this pass today.
- The older 2026-04-21 notes remain useful for history, but the new raw manifest is the preferred provenance anchor for primary-source links.

## Durable conclusion

`reorder-functions-by-name` now matches the newer pass-wiki dossier standard: immutable raw primary-source manifest, overview, transformed-shape page, Binaryen strategy, implementation/test map, focused proof page, and Starshine status/port-strategy page with exact repo code locations.
