# 0472 - `reorder-locals` current-main refresh and status retention

Date: 2026-05-05  
Status: completed research ingest  
Pass: `reorder-locals`  
Local registry status: `implemented` module in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/reorder-locals/`

## Why this follow-up exists

The `reorder-locals` dossier already had a corrected source story, but it was still anchored to the 2026-04-27 validation layer.
This follow-up records the 2026-05-05 current-main recheck so the living pages can point at a fresher provenance layer without changing the contract story.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/ReorderLocals.cpp`
  - `src/passes/pass.cpp`
  - `test/passes/reorder-locals.wast`
  - `test/passes/reorder-locals.txt`
  - `test/passes/reorder-locals_print_roundtrip.wast`
  - `test/passes/reorder-locals_print_roundtrip.txt`
- Tagged comparison anchor:
  - the same owner, scheduler, and lit files on `version_129`
- Existing living dossier pages for the pass

## Source-backed Binaryen conclusions

- `reorder-locals` still exposes the same contract on the reviewed `main` surfaces: access counting, first-use ordering, parameter stability, zero-count body-local truncation, local-user reindexing, and local-name repair.
- `pass.cpp` still registers `reorder-locals` as a normal public pass and still places it in the repeated no-DWARF local-cleanup cluster.
- The dedicated lit files still exercise the same teaching-relevant families: hot-body ordering, write-only and tee-only survival, params-fixed behavior, and print-roundtrip declaration-order stability.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Starshine local status

The local status is unchanged by this source refresh:

- `reorder-locals` remains an active module pass in Starshine;
- explicit pass correctness is still covered by the dedicated module implementation and tests;
- preset readiness is still intentionally gated on neighboring local passes and ordered no-DWARF replay evidence.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md`
- `docs/wiki/binaryen/passes/reorder-locals/index.md`
- `docs/wiki/binaryen/passes/reorder-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-locals/parity.md`
- `docs/wiki/binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the earlier 2026-04-27 validation layer.
It does not change the contract story; it only refreshes the provenance and current-main freshness layer.
