# 0506 - 2026-05-06 - global-struct-inference current-main recheck

Date: 2026-05-06  
Status: completed research ingest  
Pass: `global-struct-inference` / upstream `gsi`  
Related living dossier: `docs/wiki/binaryen/passes/global-struct-inference/`

## Why this follow-up exists

The `global-struct-inference` dossier already had a corrected Binaryen source manifest and a solid implementation/test-map page, but it still lacked a fresh current-main provenance layer and a dedicated Starshine strategy page.
This follow-up records the 2026-05-06 source refresh so the living pages can carry exact local anchors and a stable current-main note.

## Primary source files reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/GlobalStructInference.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/gsi.wast`
  - `test/lit/passes/gsi-desc.wast`
- Existing corrected dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract on the reviewed surfaces.
- `run(Module*)` still keeps the GC gate, the closed-world branch, and the always-on optimizer call structure.
- The same open-world direct-global fast path and closed-world `typeGlobals` reasoning remain in view.
- `gsi.wast` still proves the broad plain-pass surface, and `gsi-desc.wast` still covers the shared descriptor-read machinery.

## Starshine local status

The local status is unchanged by this source refresh:

- `global-struct-inference` remains an active module pass.
- the local implementation is still a closed-world direct-global subset rather than the full Binaryen origin-analysis pass;
- the current MoonBit code still rewrites only immediate `global.get` + `struct.get*` pairs and preserves traps explicitly;
- the exact local code map still points to `src/passes/global_struct_inference.mbt`, `src/passes/global_struct_inference_test.mbt`, `src/passes/pass_manager.mbt`, and `src/passes/optimize.mbt`.

## Wiki updates made

- Added `docs/wiki/raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md`.
- Added `docs/wiki/raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md`.
- Added `docs/wiki/binaryen/passes/global-struct-inference/starshine-strategy.md`.
- Refreshed the Binaryen strategy, implementation/test-map, WAT-shape, closed-world/un-nesting, Starshine HOT-IR detail, parity, pass-folder index, root wiki index, pass catalog, tracker, log, and changelog entries so the new current-main provenance layer is discoverable.

## Health-check notes

- The folder had a real gap rather than just a wording issue: no dedicated Starshine strategy page and several stale local line anchors in the implementation/code-map surfaces.
- The health fix was integrated with the main wiki-development change so the page set now matches the current local code map instead of duplicating the old anchor set.
- The remaining distinction between the local closed-world subset and the full upstream contract stays explicit.
