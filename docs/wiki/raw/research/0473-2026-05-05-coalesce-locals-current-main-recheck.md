# 0473-2026-05-05-coalesce-locals-current-main-recheck

## Question

Did Binaryen `coalesce-locals` drift on current `main`, and did the exact Starshine code anchors in the living dossier need a refresh?

## Answer

No teaching-relevant current-`main` drift was found. The reviewed upstream contract is still the same late local-slot coalescer:

- exact-type slot sharing with value-aware interference;
- greedy order selection that prefers removing more copies;
- loop-backedge copy weighting;
- dead-set / dead-tee cleanup in the pass tail;
- a distinct `coalesce-locals-learning` ordering variant;
- repeated reruns through the surrounding local-cleanup neighborhood.

The local Starshine code map did need a refresh, mainly to pin the active owner and dispatcher lines more precisely.

## Files involved

- `docs/wiki/raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md`
- `docs/wiki/binaryen/passes/coalesce-locals/index.md`
- `docs/wiki/binaryen/passes/coalesce-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/coalesce-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/coalesce-locals/interference-and-ordering.md`
- `docs/wiki/binaryen/passes/coalesce-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md`
- `docs/wiki/binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md`

## Follow-up

The living dossier was updated to point at the new 2026-05-05 raw capture, keep the 2026-04-25 tagged release anchor explicit, and refresh the local code-map lines for the active Starshine implementation.
