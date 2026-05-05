# 0487 - `dae-optimizing` current-main recheck and port-readiness bridge

Date: 2026-05-05  
Status: completed research ingest  
Pass: `dae-optimizing` / upstream optimizing dead-argument-elimination sibling  
Local registry status: exact upstream spelling is still unknown locally; the descriptive local spelling remains boundary-only  
Related living dossier: `docs/wiki/binaryen/passes/dae-optimizing/`

## Why this follow-up exists

The `dae-optimizing` dossier already had a corrected source story and a source-confirmed implementation/test-map page.
This follow-up records a 2026-05-05 current-main recheck so the living pages can carry a fresher provenance layer and a dedicated Starshine implementation-readiness bridge.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/DeadArgumentElimination.cpp`
  - `src/passes/pass.cpp`
  - `src/passes/opt-utils.h`
  - `test/lit/passes/dae-optimizing.wast`
  - `test/lit/passes/dae-refine-params-and-optimize.wast`
  - `test/lit/passes/dae-gc.wast`
  - `test/lit/passes/dae-gc-refine-params.wast`
  - `test/lit/passes/dae-gc-refine-return.wast`
  - `test/lit/passes/dae_tnh.wast`
- Current-main line anchors worth keeping in view:
  - `pass.cpp#L2394-L2402` for the public `dae` / `dae-optimizing` split
  - `opt-utils.h#L536-L565` for the optimizing-only cleanup helper
- Existing living dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract: `dae-optimizing` shares the same core boundary engine as plain `dae` and adds the nested cleanup replay on changed functions.
- The direct-call boundary rewrite, GC refinement, dropped-result cleanup, and optimization-replay story still match the living dossier.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Starshine local status

The local status is unchanged by this source refresh:

- `dae-optimizing` remains unknown to the local registry under the exact upstream spelling;
- the current boundary-only registry spelling is `dead-argument-elimination-optimizing`;
- the future implementation is still a module/boundary feature plus nested rerun scheduler support, not a HOT peephole.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md`
- `docs/wiki/binaryen/passes/dae-optimizing/index.md`
- `docs/wiki/binaryen/passes/dae-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae-optimizing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dae-optimizing/signature-updates-and-nested-reruns.md`
- `docs/wiki/binaryen/passes/dae-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the 2026-04-24 primary-source capture and the 2026-04-25 current-main implementation/test-map bridge.
It does not change the contract story; it only refreshes the provenance and opens a dedicated implementation-readiness bridge while keeping the local naming caveat explicit.
