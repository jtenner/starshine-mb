# 0453 - `local-cse` current-main refresh and stale-anchor cleanup

Date: 2026-05-05  
Status: completed research ingest  
Pass: `local-cse`  
Local registry status: `removed` in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/local-cse/`

## Why this follow-up exists

The `local-cse` dossier already had a strong source-backed shape, but it was still anchored to the 2026-04-25 current-main bridge.
This follow-up records the 2026-05-05 current-main recheck so the living pages can point at a fresher provenance layer and the Starshine status page can keep its local code anchors honest.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/LocalCSE.cpp`
  - `src/passes/pass.cpp`
  - `src/passes/opt-utils.h`
  - `test/lit/passes/local-cse.wast`
- Tagged comparison anchor:
  - the same owner, scheduler, helper, and lit files on `version_129`
- Existing living dossier pages for the pass

## Source-backed Binaryen conclusions

- `local-cse` still exposes the same contract on the reviewed `main` surfaces: repeated whole-tree reuse in a limited linear window, first-occurrence originals, parent-over-child request cancellation, shallow side-effect and generativity filtering, trap-insensitive invalidation for repeated loads, and the narrow idempotent-direct-call exception.
- `pass.cpp` still registers `local-cse` as a public pass and still keeps it in the same late local-cleanup / aggressive-prelude neighborhoods.
- `opt-utils.h` still supports the nested rerun story the dossier already teaches.
- The dedicated lit surface still exercises the same teaching-relevant families: repeated arithmetic and load positives, before-`if` positives, local-write and after-`if` barriers, nested-call and generativity negatives, switch-child ordering, and the small-root profitability no-op cases.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Starshine local status

The local status is unchanged by this source refresh:

- `local-cse` remains removed-registry only in Starshine;
- there is no active dispatcher case;
- there is no implementation file;
- the `LCSE` backlog slice remains the honest future-port home.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`
- `docs/wiki/binaryen/passes/local-cse/index.md`
- `docs/wiki/binaryen/passes/local-cse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-cse/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/local-cse/basic-block-windows-and-barriers.md`
- `docs/wiki/binaryen/passes/local-cse/wat-shapes.md`
- `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the earlier 2026-04-25 source-correction layer.
It does not change the contract story; it only refreshes the provenance and current-main freshness layer.
