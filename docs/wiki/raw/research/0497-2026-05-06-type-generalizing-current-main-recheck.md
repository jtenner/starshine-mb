# 0497 - `type-generalizing` current-main recheck and freshness-layer refresh

Date: 2026-05-06  
Status: completed research ingest  
Pass: `type-generalizing` / upstream hidden test `experimental-type-generalizing`  
Local registry status: boundary-only  
Related living dossier: `docs/wiki/binaryen/passes/type-generalizing/`

## Why this follow-up exists

The `type-generalizing` dossier was already source-correct, but its freshness layer was still pinned to the 2026-05-05 bridge.
This follow-up records a 2026-05-06 current-main recheck so the living pages can carry a fresher provenance layer and keep the stale local-flow interpretation retired.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/TypeGeneralizing.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/type-generalizing.wast`
- Comparison anchors on `version_129`:
  - the same owner, registration, and lit files
- Existing living dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract on the reviewed surfaces.
- The pass remains hidden, experimental, CFG-backed, and not-yet-sound.
- `call_ref`, struct, array, table, global, and local requirement families are still part of the real contract.
- No teaching-relevant current-main drift was found.

## Starshine local status

The local status is unchanged by this source refresh:

- `type-generalizing` remains boundary-only in the registry;
- the future implementation is still module/type-graph work, not a HOT peephole;
- direct requests must still fail before dispatch;
- the safest first implementation slice is still analysis-only.

## Living page updates from this follow-up

Updated or refreshed:

- `docs/wiki/raw/binaryen/2026-05-06-type-generalizing-current-main-recheck.md`
- `docs/wiki/binaryen/passes/type-generalizing/index.md`
- `docs/wiki/binaryen/passes/type-generalizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-generalizing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-generalizing/type-requirements-cfg-and-unsupported-families.md`
- `docs/wiki/binaryen/passes/type-generalizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-generalizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-generalizing/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the 2026-04-27 primary-source correction and the 2026-04-27 port-readiness bridge.
It does not change the contract story; it only refreshes the provenance and exact local code anchors while keeping the boundary-only status explicit.
