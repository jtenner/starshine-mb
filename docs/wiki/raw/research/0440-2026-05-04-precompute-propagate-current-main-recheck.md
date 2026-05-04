# Research 0440: 2026-05-04 precompute-propagate current-main recheck

## Question

Did Binaryen `precompute-propagate` drift on current `main` in any way that changes the existing wiki teaching contract, and do the Starshine pages need a new implementation-readiness bridge?

## Primary sources

- [`../binaryen/2026-05-04-precompute-propagate-current-main-recheck.md`](../binaryen/2026-05-04-precompute-propagate-current-main-recheck.md)
- `docs/wiki/binaryen/passes/precompute-propagate/`

## Findings

- The reviewed Binaryen current-`main` surfaces still match the existing `version_129` contract for the reviewed teaching-level points.
- `precompute-propagate` remains a real public upstream pass, not an alias or internal scheduler label.
- The pass still shares the `Precompute.cpp` core with plain `precompute` and adds a bounded `LazyLocalGraph` propagation phase plus one extra rerun.
- The scheduler story is still the important one for future ports: aggressive top-level slots and `optimizeAfterInlining(...)` still use the sibling for nested cleanup.
- Starshine still does not implement the sibling; the local name remains removed, and plain `precompute` is only the nearest landing zone.

## Durable filing decision

- Refresh the `precompute-propagate` living pages with the new 2026-05-04 recheck manifest.
- Add a dedicated Starshine port-readiness / validation bridge so readers can move from the strategy page to the concrete first-slice and oracle plan without chat history.
- Keep the distinction between plain `precompute` and `precompute-propagate` explicit in the folder and catalog entries.

## Follow-ups filed into the wiki

- `docs/wiki/binaryen/passes/precompute-propagate/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/precompute-propagate/index.md`
- `docs/wiki/binaryen/passes/precompute-propagate/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute-propagate/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/precompute-propagate/wat-shapes.md`
- `docs/wiki/binaryen/passes/precompute-propagate/starshine-strategy.md`
