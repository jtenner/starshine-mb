# 0434 - 2026-05-04 tuple-optimization current-main recheck and Starshine strategy bridge

_Status:_ supported  
_Kind:_ research

## Question

The `tuple-optimization` dossier already had a strong working contract, but its freshness anchor still pointed at the earlier 2026-04-22 source capture and it still lacked a dedicated Starshine strategy page. This run asked whether current Binaryen `main` had changed the teaching-important contract and what exact local code anchors should now be surfaced for the Starshine implementation.

## Method

- Re-read `AGENTS.md`, `docs/README.md`, `docs/wiki/`, `docs/wiki/index.md`, `docs/wiki/log.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and the full `docs/wiki/binaryen/passes/tuple-optimization/` folder.
- Rechecked official Binaryen current `main` sources for `TupleOptimization.cpp`, `pass.cpp`, `OptimizeInstructions.cpp`, and `test/lit/passes/tuple-optimization.wast`.
- Rechecked local Starshine anchors in `src/passes/tuple_optimization.mbt`, `src/passes/pass_manager.mbt`, `src/passes/optimize.mbt`, `src/passes/registry_test.mbt`, `src/passes/tuple_optimization_wbtest.mbt`, `src/cmd/cmd_wbtest.mbt`, and `src/cmd/cmd_native_wbtest.mbt`.

## Findings

- No teaching-relevant current-main drift was found. The durable Binaryen contract still matches the dossier:
  - `tuple-optimization` remains a narrow tuple-local scalarization pass, not a general multivalue optimizer.
  - copy-connected components still poison together when any member escapes the approved tuple-local surface.
  - tuple tees still require explicit preservation of the yielded lane value.
  - direct `tuple.extract(tuple.make(...))` cleanup still belongs to `OptimizeInstructions.cpp`, not tuple-opt.
  - the pass still runs after `code-pushing` and before `simplify-locals-nostructure`.
- The local implementation status is unchanged: Starshine still has the active direct hot pass, explicit-pass tests, CLI acceptance coverage, and native Binaryen-oracle coverage.
- The main local hygiene win was anchor precision: the living pages can now point readers at exact line ranges for the direct pass, preset gate, analysis entry, and rewrite entry rather than only whole-file links.

## Durable wiki updates made

- Added [`../binaryen/2026-05-04-tuple-optimization-current-main-recheck.md`](../binaryen/2026-05-04-tuple-optimization-current-main-recheck.md).
- Added [`../../../wiki/binaryen/passes/tuple-optimization/starshine-strategy.md`](../../../wiki/binaryen/passes/tuple-optimization/starshine-strategy.md) as the missing Starshine strategy page for this dossier.
- Refreshed the living `tuple-optimization` pages with the new current-main bridge and exact local code anchors.
- Updated `docs/wiki/index.md` and `docs/wiki/log.md` so the refreshed source bridge and new Starshine strategy page are discoverable from the catalog and audit trail.

## Follow-up

No implementation work was done. The dossier remains a source-backed maintenance guide for a live active pass; future work should keep the direct pass, the preset boundary, and the `reorder-globals` neighbor separate.
