# `heap-store-optimization` current-main source and Starshine code-map follow-up

_Date:_ 2026-04-25  
_Status:_ absorbed into the living `heap-store-optimization` dossier

## Question

The `heap-store-optimization` dossier was already useful, but it still had two maintenance gaps compared with newer pass folders:

1. it had no dedicated upstream implementation/test-map page, even though active neighboring passes now do;
2. the Starshine strategy page named owner helpers but did not point readers to exact current line ranges for the active HOT implementation, dispatcher, raw fast-skip lane, and test surfaces.

This follow-up asks whether current upstream Binaryen changed the pass contract since the 2026-04-22 dossier and then refreshes the living pages around exact source and local-code map evidence.

## Sources checked

Primary source manifest:

- `docs/wiki/raw/binaryen/2026-04-25-heap-store-optimization-current-main-code-map.md`

Earlier sources retained:

- `docs/wiki/raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`
- `docs/wiki/raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md`
- `docs/wiki/raw/research/0246-2026-04-22-heap-store-optimization-primary-sources-and-code-map-followup.md`

Living pages refreshed:

- `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`

## Findings

- Current Binaryen `main` did not show teaching-relevant drift from the existing `version_129` contract.
- The pass remains a narrow `struct.set`-into-fresh-`struct.new` family, not generic heap dead-store elimination or load forwarding.
- The generic heap TODO is still present in the owner file.
- Current `main` still records only `StructSet` and `Block` action sites.
- The same two positive families remain central:
  - immediate `local.tee(struct.new ...)` folds;
  - later `local.set(struct.new ...)` plus `struct.set(local.get ...)` chains.
- `trySwap(...)` remains a small local motion helper.
- `LazyLocalGraph::canMoveSet(...)` remains the control-flow safety helper for moved values that might skip a local assignment.
- Starshine's current implementation remains a HOT-region implementation of the same semantic target, not a line-by-line CFG walker port.
- Starshine's exact active code map is now anchored in line ranges for registry, presets, dispatcher, raw fast-skip, helper families, the fold core, recursive region processing, tests, perf tests, and CLI replay lanes.

## Living-doc changes made

- Added `implementation-structure-and-tests.md` to the pass folder.
- Updated the overview page's page map, freshness note, source list, and `last_reviewed` date.
- Updated the Binaryen strategy page to cite the new current-main source bridge and implementation/test-map page.
- Replaced the Starshine strategy's high-level code map with exact current file/line ranges while keeping the Binaryen-vs-HOT distinction explicit.
- Updated the wiki index, pass-folder map, tracker, and log so the new implementation/test-map page and source bridge are discoverable.

## Open caveats

- The current-main recheck was focused on teaching-relevant pass-contract surfaces, not a byte-for-byte formal diff of every helper file.
- Starshine's wider HOT-specific wrapper and writeback repairs are local implementation facts; they should not be retrofitted back into the Binaryen strategy page as if upstream needed the same machinery.
- Any future upstream implementation of the TODO dead-store / load-forwarding family would be a material contract change and should get a new source-correction note rather than being folded silently into this dossier.
