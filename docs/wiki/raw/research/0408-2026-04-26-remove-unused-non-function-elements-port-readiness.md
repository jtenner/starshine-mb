# `remove-unused-non-function-elements` port-readiness bridge

_Date:_ 2026-04-26  
_Status:_ filed back into living wiki pages

## Question

The `remove-unused-non-function-elements` folder already had a source-backed overview, Binaryen strategy, module-shape catalog, and Starshine status page. Future Starshine implementers still had to infer the safe first local slice, validation order, and exact way to reuse active full-RUME machinery without accidentally changing full `remove-unused-module-elements` behavior. This note records the port-readiness bridge added in this run.

## Sources rechecked

- `docs/wiki/raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/remove_unused_module_elements.mbt`
- `src/passes/remove_unused_module_elements_test.mbt`
- `src/cmd/cmd.mbt`

## Findings

- The current official Binaryen surfaces checked for this pass did not show teaching-relevant drift from the `version_129` contract captured on 2026-04-24.
- The Binaryen contract remains a small but important sibling mode on the shared RUME engine: seed all defined functions as roots, then run ordinary module-element reachability and rewrite.
- A Starshine port should not duplicate RUME or do a non-function-only ad hoc sweep. It should add a policy mode to the existing local RUME liveness entry point, preserve the current full-RUME default, and dispatch the sibling as a separate module pass only after tests prove the policy split.
- The first safe implementation slice should be analyzer/no-rewrite or minimal rewrite around root seeding: prove that dead defined helpers are marked live under sibling mode but not full-RUME mode, while imported functions remain ordinary reachability candidates.
- The first mutating slice should reuse the existing RUME rewrite path unchanged after policy-based liveness seeding. That slice should test defined-helper retention, imported-function removal, dead non-function cleanup, type compaction, no-op start metadata cleanup, and full-RUME non-regression.
- The validation ladder should compare the local spelling against Binaryen's upstream spelling `--remove-unused-nonfunction-module-elements`, not against `--remove-unused-module-elements`, except where a paired differential test intentionally proves the sibling split.

## Living wiki updates

- Added `docs/wiki/binaryen/passes/remove-unused-non-function-elements/starshine-port-readiness-and-validation.md`.
- Refreshed the `remove-unused-non-function-elements` landing page and Starshine strategy page to include the new bridge.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/binaryen/passes/tracker.md` so the folder is classified as deep port-ready documentation while still boundary-only in Starshine.

## Uncertainty

The main unresolved implementation choice is spelling and alias policy. The repository already has the local boundary-only spelling `remove-unused-non-function-elements`; Binaryen exposes `remove-unused-nonfunction-module-elements`. The port-readiness page assumes the local spelling remains the primary internal name, but a future implementation may add an upstream-compatible alias after deciding how Starshine wants to present Binaryen spellings in CLI help and pass-fuzz comparisons.
