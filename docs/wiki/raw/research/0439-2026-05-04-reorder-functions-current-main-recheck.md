# 0439 - `reorder-functions` current-main recheck

- Pass: `reorder-functions`
- Date: 2026-05-04
- Kind: wiki-health / freshness follow-up

## Why this note exists

The `reorder-functions` dossier was already source-correct, but its freshness layer still came from the 2026-04-24 capture. I rechecked current main so the living pages can keep teaching the same contract without pretending the review is older than it is.

## What I checked

- `docs/wiki/raw/binaryen/2026-04-24-reorder-functions-primary-sources.md`
- `docs/wiki/binaryen/passes/reorder-functions/`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/duplicate_function_elimination.mbt`
- `agent-todo.md`
- official Binaryen current-main `ReorderFunctions.cpp`
- official Binaryen current-main `pass.cpp`
- official Binaryen current-main `reorder-functions-by-name.wast`

## Findings

- No teaching-relevant drift was found on the reviewed current-main surfaces.
- The Binaryen contract still reads as a small static-use sort over function declarations, not a body optimizer or profile-guided pass.
- The local Starshine state is still boundary-only: known pass name, clear rejection path, no module-pass dispatcher case, no owner file, and no dedicated todo slice.

## Filing result

I used this recheck to justify a new Starshine port-readiness bridge and a small freshness refresh across the `reorder-functions` living pages.
