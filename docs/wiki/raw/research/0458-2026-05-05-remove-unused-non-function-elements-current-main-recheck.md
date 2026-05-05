# `remove-unused-non-function-elements` current-main recheck

_Date:_ 2026-05-05  
_Status:_ filed back into living wiki pages

## Question

The `remove-unused-non-function-elements` folder already had a source-backed overview, implementation map, shape catalog, and Starshine status page. The missing piece was a dedicated Binaryen strategy page that explains the upstream sibling as a policy mode on the shared RUME engine rather than as a separate algorithm.

## Sources rechecked

- `docs/wiki/raw/binaryen/2026-05-05-remove-unused-non-function-elements-current-main-recheck.md`
- `docs/wiki/raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/remove_unused_module_elements.mbt`
- `src/passes/remove_unused_module_elements_test.mbt`
- `src/ir/module-utils.h`

## Findings

- The current Binaryen `main` surfaces still match the source-backed `version_129` contract on the reviewed surfaces.
- The pass is a sibling mode on shared `RemoveUnusedModuleElements.cpp`, not a separate engine.
- The meaningful difference is the `rootAllFunctions` policy toggle: root all **defined** functions, then reuse the ordinary module-element liveness and rewrite pipeline.
- Imported functions are not force-rooted by the sibling policy, so unused imported functions can still disappear.
- The shared engine still handles exports, start sections, imported-parent active segments, TNH retention, function-type cleanup, and module index rewrite.
- The new Starshine implementation should therefore be taught as a policy mode on the existing RUME machinery, not as a bespoke non-function-only sweep.

## Living wiki updates

- Added `docs/wiki/binaryen/passes/remove-unused-non-function-elements/binaryen-strategy.md`.
- Refreshed the folder overview and status pages so the new Binaryen strategy is cross-linked from the living dossier.
- Added this research note and the raw current-main recheck manifest so the new strategy page can cite a current primary-source bridge.

## Uncertainty

The remaining wording choice is purely pedagogical: whether to emphasize “defined functions only” or “root all defined functions before analysis.” The source-backed contract is the same either way.
