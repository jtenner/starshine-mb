# 0447 - `local-subtyping` current-main refresh and status retention

Date: 2026-05-05  
Status: completed research ingest  
Pass: `local-subtyping`  
Local registry status: `removed` in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/local-subtyping/`

## Why this follow-up exists

The `local-subtyping` dossier already had a corrected source story, but it was still anchored to the 2026-04-25 source-correction layer.
This follow-up records the 2026-05-05 current-main recheck so the living pages can point at a fresher provenance layer without changing the contract story.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/LocalSubtyping.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/local-subtyping.wast`
- Tagged comparison anchor:
  - the same owner and lit files on `version_129`
- Existing living dossier pages for the pass

## Source-backed Binaryen conclusions

- `local-subtyping` still exposes the same contract on the reviewed `main` surfaces: reference-local scanning, set/tee-fed LUB narrowing, get-aware non-null dominance, body-local declaration rewriting, get/tee retagging, and iterative refinalization.
- `pass.cpp` still registers `local-subtyping` as a normal public pass and still places it before `coalesce-locals` in the GC/local cleanup neighborhood.
- The dedicated lit file still exercises the same teaching-relevant families: repeated refinement, dominance, tee retagging, parameter preservation, and nondefaultable preservation.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Starshine local status

The local status is unchanged by this source refresh:

- `local-subtyping` remains removed-registry only in Starshine;
- there is no active dispatcher case;
- there is no implementation file;
- the `LS` backlog slice remains the honest future-port home.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`
- `docs/wiki/binaryen/passes/local-subtyping/index.md`
- `docs/wiki/binaryen/passes/local-subtyping/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-subtyping/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/local-subtyping/lubs-and-dominance.md`
- `docs/wiki/binaryen/passes/local-subtyping/wat-shapes.md`
- `docs/wiki/binaryen/passes/local-subtyping/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the earlier 2026-04-25 source-correction layer.
It does not change the contract story; it only refreshes the provenance and current-main freshness layer.
