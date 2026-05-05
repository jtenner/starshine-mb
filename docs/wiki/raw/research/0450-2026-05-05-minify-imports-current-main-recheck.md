# 0450 - `minify-imports` current-main recheck and source-anchor refresh

Date: 2026-05-05  
Status: completed research ingest  
Pass: `minify-imports` / upstream plain import-base minification helper  
Local registry status: upstream-only / unknown locally  
Related living dossier: `docs/wiki/binaryen/passes/minify-imports/`

## Why this follow-up exists

The plain `minify-imports` dossier already had a corrected source story, but its freshness layer and some local code anchors were still pinned to the 2026-04-27 bridge.
This follow-up records a 2026-05-05 current-main recheck so the living pages can carry a fresher provenance layer and a cleaner Starshine status map.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/MinifyImportsAndExports.cpp`
  - `src/passes/pass.cpp`
  - `src/passes/passes.h`
- Tagged comparison anchors:
  - the same owner and registration files on `version_129`
- Existing living dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract: plain `minify-imports` rewrites qualifying import base names and emits JSON map output.
- The plain mode still uses the `env` / `wasi_` module gate, still walks all import kinds, and still keeps export-name mutation and module-name merging in the sibling passes.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Starshine local status

The local status is unchanged by this source refresh:

- `minify-imports` remains unknown to the local registry and dispatcher;
- the future implementation is still module-scoped, not HOT-scoped;
- the exact local import/module-name, decode/encode, and WAT-lowering surfaces remain the right follow-along path.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-minify-imports-current-main-recheck.md`
- `docs/wiki/binaryen/passes/minify-imports/index.md`
- `docs/wiki/binaryen/passes/minify-imports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports/wat-shapes.md`
- `docs/wiki/binaryen/passes/minify-imports/starshine-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/minify-imports/env-wasi-json-map-and-module-merge.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the 2026-04-26 source-correction and 2026-04-27 port-readiness layers.
It does not change the contract story; it only refreshes the provenance and exact local code anchors while keeping the plain-pass vs sibling-pass split explicit.
