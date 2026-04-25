# `heap2local` current-main source and Starshine code-map follow-up

_Date:_ 2026-04-25  
_Status:_ absorbed into the living `heap2local` dossier

## Question

The `heap2local` dossier was already useful, but it still had two maintenance gaps compared with newer active pass folders:

1. it did not have the now-standard dedicated upstream implementation/test-map page;
2. the Starshine strategy page listed helper names but did not anchor the current implementation, dispatcher, preset, and test surfaces to exact line ranges.

This follow-up asks whether current upstream Binaryen changed the pass contract since the 2026-04-22 dossier and then refreshes the living pages around exact source and local-code-map evidence.

## Sources checked

Primary source manifest:

- `docs/wiki/raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md`

Earlier sources retained:

- `docs/wiki/raw/binaryen/2026-04-22-heap2local-primary-sources.md`
- `docs/wiki/raw/research/0245-2026-04-22-heap2local-primary-sources-and-code-map-followup.md`
- `docs/wiki/raw/research/0135-2026-04-20-heap2local-binaryen-research.md`
- `docs/wiki/raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md`

Living pages refreshed:

- `docs/wiki/binaryen/passes/heap2local/index.md`
- `docs/wiki/binaryen/passes/heap2local/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/heap2local/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/heap2local/starshine-hot-ir-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Findings

- Current Binaryen `main` did not show teaching-relevant drift beyond the already-recorded 2026-04-22 caveat around tighter array/cmpxchg/unreachable-`ref.test` handling.
- The released `version_129` contract remains the teaching oracle: `heap2local` is conservative GC scalarization, not generic heap-to-stack allocation.
- Upstream still centers on `Heap2Local.cpp`, with helper dependencies in `LocalGraph`, `Parents`, branch utilities, EH repair, packed-field bit helpers, builder helpers, the pass framework's nondefaultable-local repair, and the dedicated `heap2local.wast` lit file.
- The pass still has three major implementation phases that readers need to keep distinct:
  1. candidate discovery via nonescape plus exclusivity;
  2. arrays lowered through synthetic structs before scalarization;
  3. struct scalarization with field/descriptor locals, direct ref-op folds, refinalization, EH repair, and generic nondefaultable-local fixups.
- Starshine's active implementation remains narrower and HOT/use-def driven. It matches a meaningful subset through one-write struct/array owner locals, direct local-copy/tee/block families, direct array element localization, and a few direct ref-op folds, but it is not a line-by-line port of Binaryen's `EscapeAnalyzer` plus array-to-struct machinery.
- Starshine's exact active code map is now anchored in line ranges for descriptor/summary, registry, presets, dispatcher, struct candidate analysis, array candidate analysis, direct ref folds, rewrites, cleanup, tests, and active backlog notes.

## Living-doc changes made

- Added `implementation-structure-and-tests.md` to the pass folder.
- Updated the overview page's page map, freshness note, source list, `last_reviewed` date, and maintenance rules.
- Updated the Binaryen strategy page to cite the new source bridge and implementation/test-map page.
- Replaced the Starshine strategy's high-level code map with exact current file/line ranges while keeping the Binaryen-vs-Starshine architecture split explicit.
- Updated the wiki index, pass-folder map, tracker, changelog, and log so the new source bridge and implementation/test-map page are discoverable.

## Open caveats

- The current-main recheck was focused on teaching-relevant pass-contract surfaces, not a byte-for-byte diff of every upstream helper file.
- Binaryen's source-backed direct-ref, descriptor, packed, atomic, RMW, and cmpxchg surface is wider than Starshine's current local tests; do not shrink the upstream contract down to the current local subset.
- Starshine's direct element-localization path for arrays is intentionally simpler than upstream's array-to-synthetic-struct design. If Starshine later ports upstream's wider array/type-flow behavior, this page should be updated rather than retroactively pretending the current local design already had that coverage.
