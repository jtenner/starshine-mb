# 0503 - `type-ssa` current-main recheck and freshness-layer refresh

Date: 2026-05-06  
Status: completed research ingest  
Pass: `type-ssa` / upstream public GC allocation-type specialization  
Local registry status: upstream-only  
Related living dossier: `docs/wiki/binaryen/passes/type-ssa/`

## Why this follow-up exists

The `type-ssa` dossier was already source-correct, but its freshness layer was still pinned to the 2026-04-26 correction/port-readiness bridge.
This follow-up records a 2026-05-06 current-main recheck so the living pages can carry a fresher provenance layer and keep the stale created-type propagation interpretation retired.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/TypeSSA.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/type-ssa.wast`
- Comparison anchors on `version_129`:
  - the same owner, registration, and lit files
- Existing living dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract on the reviewed surfaces.
- The pass remains a GC allocator-type splitter, not a local/global SSA-like value-flow pass.
- `struct.new` and array allocation families remain the core positive shapes.
- Exact-observation blockers, interestingness filtering, fresh rec-group creation, and `ReFinalize` are still the real contract.
- No teaching-relevant current-main drift was found.

## Starshine local status

The local status is unchanged by this source refresh:

- `type-ssa` remains upstream-only in the registry;
- the future implementation is still module/type-section work, not a HOT peephole;
- direct requests must still fail before dispatch;
- the safest first implementation slice is still analysis-only.

## Living page updates from this follow-up

Updated or refreshed:

- `docs/wiki/raw/binaryen/2026-05-06-type-ssa-current-main-recheck.md`
- `docs/wiki/binaryen/passes/type-ssa/index.md`
- `docs/wiki/binaryen/passes/type-ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-ssa/created-exact-types-control-values-and-signature-rewrites.md`
- `docs/wiki/binaryen/passes/type-ssa/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the 2026-04-26 source correction and the 2026-04-26 port-readiness bridge.
It does not change the contract story; it only refreshes the provenance and exact local code anchors while keeping the upstream-only status explicit.
