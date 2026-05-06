# `local-cse` Starshine status correction

_Capture date:_ 2026-05-05  
_Status:_ repo-authored health note superseding stale Starshine-status wording in older `local-cse` bridges

## Why this note exists

The upstream Binaryen capture at `docs/wiki/raw/binaryen/2026-05-05-local-cse-current-main-recheck.md` is still a valid source bridge for Binaryen `main`, but its Starshine-status sentence is now stale.

Current local Starshine code shows `local-cse` has landed as an active direct pass, so the living wiki needs to distinguish:

- **upstream Binaryen contract**: unchanged
- **local Starshine direct pass**: active
- **public preset / ordered-neighborhood parity**: still gated

## Current local evidence

- `src/passes/local_cse.mbt:2-7,217-...`
  - direct pass summary, descriptor, and the main rewrite pipeline
- `src/passes/local_cse_test.mbt:14-94`
  - registry, repeated-tree, parent-over-child, load-barrier, and local-write-window tests
- `src/passes/optimize.mbt:253,437-448`
  - registers `local-cse` as an active module pass and keeps the exact aggressive neighborhood gated
- `src/passes/pass_manager.mbt:8941`
  - dispatches `local-cse` through `local_cse_run_module_pass(...)`
- `src/passes/optimize_test.mbt:510-512`
  - keeps `local-cse` classified as an active module pass in the regression surface
- `src/cmd/cmd_wbtest.mbt:7564-...`
  - direct debug-artifact replay lane for `simplify-locals`

## What remains incomplete

- Exact public preset parity for the upstream `flatten -> simplify-locals-notee-nostructure -> local-cse` and `coalesce-locals -> local-cse -> simplify-locals` neighborhoods.
- Full neighbor-slot proof should stay explicit until the surrounding missing slots are representable end to end.

## How to use this note

Cite this note when a living page needs to explain why older `local-cse` status language that says “removed-registry only” is stale for the current Starshine tree.

Do not use this note to restate the upstream Binaryen algorithm; use the living `local-cse` dossier pages for that.
