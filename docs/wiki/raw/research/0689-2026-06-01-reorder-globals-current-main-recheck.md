# 0689 - `reorder-globals` current-main recheck and freshness refresh

Date: 2026-06-01  
Status: completed research ingest  
Pass: `reorder-globals` / upstream public late global layout pass  
Local registry status: active direct public module pass  
Related living dossier: `docs/wiki/binaryen/passes/reorder-globals/`

## Why this follow-up exists

The `reorder-globals` dossier is source-correct, but its freshness layer was still pinned to the 2026-05-20 catalog review and the 2026-04-25 current-main bridge.
This follow-up records a 2026-06-01 current-main recheck so the living pages can carry a fresher provenance layer while keeping the reviewed contract story unchanged.

## Primary online sources reviewed

- Binaryen GitHub source files on `main` and `version_130`:
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
- Existing living dossier pages for the pass family
- The Binaryen `version_130` release horizon

## Source-backed Binaryen conclusions

- Current `main` still matches the reviewed `version_129` / `version_130` teaching contract on the reviewed owner, helper, and test surfaces.
- The pass remains a late module-wide global declaration-layout pass, not a function-local rewrite pass.
- Static `global.get` / `global.set` counting, module-code scanning, initializer dependency constraints, candidate-family search, true-count scoring, and the public `< 128` cutoff remain the real contract.
- `reorder-globals-always` remains the separate sibling helper, and the public pass still differs from it only by the `< 128` bailout and scoring policy.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Starshine local status

The local status is unchanged by this source refresh:

- `reorder-globals` remains a direct public Starshine module pass;
- `reorder-globals-always` remains boundary-only;
- the local representation still needs numeric `GlobalIdx` remapping across module, binary, validation, and name/export surfaces.

## Living page updates from this follow-up

Updated or refreshed:

- `docs/wiki/raw/binaryen/2026-06-01-reorder-globals-current-main-recheck.md`
- `docs/wiki/binaryen/passes/reorder-globals/index.md`
- `docs/wiki/binaryen/passes/reorder-globals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-globals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-globals/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the 2026-04-25 source bridge and the 2026-05-06 direct revalidation.
It does not change the contract story; it only refreshes the provenance and exact local code anchors while keeping the upstream-only / sibling-boundary split explicit.
