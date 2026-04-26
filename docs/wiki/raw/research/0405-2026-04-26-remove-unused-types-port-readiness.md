# `remove-unused-types` port-readiness bridge

_Date:_ 2026-04-26  
_Status:_ filed back into living wiki pages

## Question

The `remove-unused-types` folder already had a corrected source-backed dossier, but future Starshine implementers still had to infer the first safe local slice, validation ladder, and exact reason this pass must be module/type-section work. This note records the port-readiness bridge added in this run.

## Sources rechecked

- `docs/wiki/raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-26-remove-unused-types-port-readiness-primary-sources.md`
- `docs/wiki/binaryen/passes/remove-unused-types/`
- `src/passes/optimize.mbt`
- `src/lib/types.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/wast/module_wast_tests.mbt`
- `src/validate/env.mbt`

## Findings

- The current official Binaryen `main` surfaces checked for this pass did not show teaching-relevant drift from the `version_129` contract captured on 2026-04-24.
- The corrected Binaryen strategy remains helper-owned: `RemoveUnusedTypes.cpp` is a small GC/open-world wrapper around `GlobalTypeRewriter(*module).update()`.
- A Starshine port should not start as a HOT peephole. It needs module-level type inventory, public/private visibility, dependency ordering, old-to-new heap-type remapping, and whole-module type-use repair.
- The first safe Starshine slice should be a no-rewrite closed-world/GC analyzer plus registry-state transition tests, not immediate type-section mutation.
- The second useful slice should delete one unused private singleton rec group and prove complete old-to-new type-use repair in the smallest module surface before attempting old-rec-group compaction or descriptor-heavy cases.
- Descriptor/described links and public-group anchors should be negative/retention tests from the beginning; otherwise the implementation risks reintroducing the superseded whole-old-rec-group or pass-local-scanner mental models.

## Living wiki updates

- Added `docs/wiki/binaryen/passes/remove-unused-types/starshine-port-readiness-and-validation.md`.
- Refreshed the `remove-unused-types` landing page and Starshine strategy page to include the new bridge.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/binaryen/passes/tracker.md` so the folder is classified as deep port-ready documentation while still boundary-only in Starshine.

## Uncertainty

The main unresolved design choice is where Starshine should host the shared closed-world type-rewrite helper. `remove-unused-types`, `type-merging`, `minimize-rec-groups`, `unsubtyping`, and `type-refining` all need overlapping infrastructure, so a one-off helper only for this pass would likely be the wrong long-term shape.
