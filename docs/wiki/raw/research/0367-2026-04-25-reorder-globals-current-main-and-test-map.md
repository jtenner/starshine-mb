# 0367 - `reorder-globals` current-main and implementation/test map

## Status

- Date: 2026-04-25
- Type: focused wiki follow-up / source bridge
- Scope: close the remaining `reorder-globals` dossier gap by adding a dedicated implementation/test-map page, refreshing current-main provenance, and sharpening the exact Starshine code/prerequisite map.
- Supersedes: none. This extends the earlier `0125` and `0270` work; those remain useful for the original Binaryen strategy and Starshine follow-up history.

## Why this pass

The `reorder-globals` folder already had a good overview, Binaryen strategy, transformed-shape catalog, size/dependency page, and Starshine status page. The clear remaining gap compared with neighboring late-tail dossiers was the lack of a dedicated page answering:

- which upstream files own the pass,
- which helper files matter,
- which official lit tests prove which behavior,
- what current-main recheck says,
- and exactly which Starshine local code locations a future numeric-`GlobalIdx` port would need to touch.

That made `reorder-globals` a good health target even though it was not missing a folder.

## Primary sources ingested

Added `docs/wiki/raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md`, capturing official Binaryen `version_129` and current-main source/test URLs for:

- `src/passes/ReorderGlobals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/pass.h`
- `src/wasm-traversal.h`
- `src/support/topological_sort.h`
- `src/wasm.h`
- `src/passes/GlobalStructInference.cpp`
- `test/lit/passes/reorder-globals.wast`
- `test/lit/passes/reorder-globals-real.wast`

It also records the local Starshine code surfaces rechecked for the port map:

- `src/passes/optimize.mbt`
- `src/lib/types.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `src/validate/validate.mbt`
- `src/ir/hot.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`

## Findings

- No teaching-relevant current-main drift was found in the focused owner/helper/test surface. The maintained `version_129` contract still stands.
- The upstream owner/test map is now explicit: `ReorderGlobals.cpp` owns counting, dependency search, candidate scoring, public cutoff, sibling `always` mode, and final module-global vector reorder; `pass.cpp` / `passes.h` own public spellings and scheduling; `pass.h` / `wasm-traversal.h` explain module-code scanning; `topological_sort.h` owns dependency-safe ordering; `wasm.h` explains why Binaryen can reorder by names instead of rewriting numeric uses.
- The lit-test split matters: `reorder-globals.wast` mostly proves visible sort families through `--reorder-globals-always`, while `reorder-globals-real.wast` proves production cutoff / 129-global behavior.
- Starshine's future port is stricter than a Binaryen-name-vector reorder because local IR and binary surfaces carry numeric `GlobalIdx` values. A real local pass must remap imports/exports, global initializers, function and module-code uses, and validation-sensitive declaration order.

## Wiki updates made

- Added `docs/wiki/binaryen/passes/reorder-globals/implementation-structure-and-tests.md`.
- Refreshed `reorder-globals` overview, Binaryen strategy, size/dependency guide, WAT-shape catalog, and Starshine strategy page to cite the new raw source bridge and implementation/test-map page.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, and `CHANGELOG.md` so the new implementation/test-map coverage is discoverable.

## Open caveats

- The exponential dependent-count candidate remains source-confirmed but not isolated by a single obvious dedicated lit test in the reviewed proof surface.
- The focused current-main recheck covered the pass owner/helper/test surfaces, not every downstream Binaryen binary writer or pass-runner file.
- The Starshine port map is still a plan: there is no `src/passes/reorder_globals.mbt`, no dispatcher case, and no reduced local pass test yet.
