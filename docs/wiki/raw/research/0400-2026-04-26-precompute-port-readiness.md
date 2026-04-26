# `precompute` Starshine port-readiness follow-up

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages  
_Related:_ `docs/wiki/binaryen/passes/precompute/`

## Question

The `precompute` folder already had a deep source-backed dossier, but it did not yet have the same explicit implementation-readiness / validation bridge now present for many neighboring passes. The missing bridge made future work harder in two ways:

1. readers had to infer which part of Binaryen's large interpreter-driven contract Starshine implements today, and
2. readers had to infer which local validation guards are part of the current `precompute` contract even though they live in the pass manager rather than `src/passes/precompute.mbt`.

## Sources rechecked

- Official Binaryen `Precompute.cpp`, `pass.cpp`, `opt-utils.h`, interpreter/helper files, and pass tests listed in [`../binaryen/2026-04-26-precompute-current-main-port-readiness.md`](../binaryen/2026-04-26-precompute-current-main-port-readiness.md).
- Starshine local code in:
  - `src/passes/precompute.mbt`
  - `src/passes/pass_manager.mbt`
  - `src/passes/optimize.mbt`
  - `src/passes/precompute_test.mbt`
  - `src/passes/optimize_test.mbt`
  - `src/passes/registry_test.mbt`
  - `src/cmd/cmd_wbtest.mbt`

## Findings filed back

- Added `docs/wiki/raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md` as a primary-source capture and local code-location map.
- Added `docs/wiki/binaryen/passes/precompute/starshine-port-readiness-and-validation.md` to explain the safe next-slice order, validation ladder, Binaryen oracle comparison expectations, and the exact local HOT/pass-manager/test surfaces future implementers should read first.
- Refreshed the `precompute` landing page and Starshine strategy page with backlinks to the new bridge.
- Updated wiki catalogs and log entries so `precompute` no longer looks complete only in the older source-dossier sense; it now also has the implementation-readiness page used by the newer pass-wiki campaign.

## Durable conclusion

Starshine's current `precompute` is useful and active, but it should not be described as a partial Binaryen interpreter port. It is a HOT fixpoint over exact scalar constants, immutable defined globals, constant control selection, pure-drop cleanup, and writeback-safe region cleanup. The right next improvements are small, trap-free, oracle-comparable slices unless the project deliberately invests in a larger interpreter/flow engine.

## Remaining uncertainty

- The exact future boundary between local HOT fold helpers and a possible shared interpreter/flow abstraction is still a design decision.
- The wiki continues to use Binaryen `version_129` as the teaching baseline while recording current-main drift separately. A future oracle bump should revisit all current-main drift notes together rather than silently editing this pass in isolation.
