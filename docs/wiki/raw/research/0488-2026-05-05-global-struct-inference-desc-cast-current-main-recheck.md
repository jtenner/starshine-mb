# 0488 - 2026-05-05 - global-struct-inference-desc-cast current-main recheck

Date: 2026-05-05  
Status: completed research ingest  
Pass: `global-struct-inference-desc-cast` / upstream `gsi-desc-cast`  
Local registry status: boundary-only  
Related living dossier: `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/`

## Why this follow-up exists

The `global-struct-inference-desc-cast` dossier was already source-correct, but its freshness layer was still pinned to the 2026-04-24 bridge.
This follow-up records a 2026-05-05 current-main recheck so the living pages can carry a fresher provenance layer and exact local code anchors.

## Primary source files reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/GlobalStructInference.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/gsi-to-desc-cast.wast`
  - `test/lit/passes/gsi-desc.wast`
  - `test/lit/passes/gsi.wast`
- Existing corrected dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract on the reviewed surfaces.
- `visitRefCast(RefCast*)` still owns the desc-cast-specific rewrite.
- The rewrite still requires desc-cast mode, a non-`unreachable` result, descriptor existence, exact-or-no-strict-subtypes legality, and exactly one descriptor global.
- `pass.cpp` still publishes `gsi-desc-cast` as a distinct public sibling of `gsi`.
- `gsi-to-desc-cast.wast` still proves the sibling delta directly.
- `gsi-desc.wast` still proves the shared descriptor-read and un-nesting machinery.

## Starshine local status

The local status is unchanged by this source refresh:

- `global-struct-inference-desc-cast` remains boundary-only in the registry;
- explicit requests still fail before dispatch;
- there is still no owner file;
- the exact local code map still points to the boundary-only registry, the request guard, and the active plain-GSI sibling rather than a desc-cast implementation;
- the existing port-readiness bridge remains the right local implementation ladder.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md`
- `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/index.md`
- `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/descriptor-singleton-gate-and-dedicated-tests.md`
- `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Supersession note

This note extends the 2026-04-24 primary-source correction and the 2026-04-24 Starshine follow-up.
It does not change the contract story; it only refreshes the provenance and exact local code anchors while keeping the boundary-only status explicit.
