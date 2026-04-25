---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ./0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ./0111-2026-04-20-merge-blocks-binaryen-research.md
  - ../../binaryen/passes/merge-blocks/index.md
  - ../../binaryen/passes/merge-blocks/binaryen-strategy.md
  - ../../binaryen/passes/merge-blocks/wat-shapes.md
  - ../../binaryen/passes/merge-blocks/implementation-structure-and-tests.md
  - ../../binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md
  - ../../../../src/passes/merge_blocks.mbt
  - ../../../../src/passes/merge_blocks_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../src/ir/hot_lower_test.mbt
---

# `merge-blocks` source correction and code-map refresh

## Why this note exists

The `merge-blocks` dossier was complete enough to be useful, but its Binaryen strategy page taught a stale over-narrow contract: tail-child-only block flattening, unnamed child positives, and same-name-only named merging. A fresh read of official Binaryen `version_129` plus current `main` source on 2026-04-25 showed that the actual pass is broader and differently gated.

This note records the correction, adds the missing implementation/test-map page now standard for active pass folders, and refreshes the Starshine code map with exact local line ranges.

## Primary source ingested

Added:

- `docs/wiki/raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`

That raw capture records official URLs for:

- Binaryen `version_129` `MergeBlocks.cpp`
- Binaryen current-main `MergeBlocks.cpp`
- the dedicated `test/lit/passes/merge-blocks.wast` file on both refs
- `pass.cpp` and the helper surfaces in `branch-utils.h`, `effects.h`, and `wasm-traversal.h`

The current-main check found no teaching-relevant drift from the corrected `version_129` interpretation. The correction is against the local wiki's previous reading, not against a newly changed upstream source.

## Corrected Binaryen findings

The durable corrected contract is:

1. Binaryen's `merge-blocks` is a named-block deblocking pass, not an unnamed-tail-wrapper pass.
2. `ProblemFinder` still performs a function-wide prescan, but it is a guard against ambiguous branch-retargeting, not evidence that every successful rewrite is a tail-child rewrite.
3. `canChangeTo(...)` is the main legality proof: direct same-name parent/child cases are trivial, but different child names can also be legal when all branch users can be recursively retargeted to the parent without crossing invalidating effects.
4. `visitBlock(...)` scans named child blocks in the containing block list, checks named grandchildren, splices accepted child contents into the parent, rewrites scope-name uses, and refinalizes.
5. `visitIf(...)` owns a separate deblocking path for named block wrappers in `if` arms.
6. `visitThrow(...)`, `visitRethrow(...)`, and `visitReturn(...)` own a terminal-name-removal family.
7. The official lit file's `no-merge-nameless` coverage contradicts the older local claim that unnamed tail blocks are a primary positive family.

## Starshine findings retained

The active Starshine implementation remains a different HOT-level proof:

- `src/passes/merge_blocks.mbt:2-17` declares the active HOT descriptor and invalidated analyses.
- `src/passes/merge_blocks.mbt:20-31` performs a cheap block-candidate scan.
- `src/passes/merge_blocks.mbt:34-80` scans all HOT branch-label use sites.
- `src/passes/merge_blocks.mbt:112-136` resolves typed block param counts against the module context.
- `src/passes/merge_blocks.mbt:141-184` rewrites dead values before an `unreachable` suffix into explicit drops before flattening.
- `src/passes/merge_blocks.mbt:187-284` recursively visits block, loop, if, try, and try-table regions.
- `src/passes/merge_blocks.mbt:287-333` is the root-block flattening helper: it refuses live labels, enforces typed-carrier guards, splices region roots, and clears the old body.
- `src/passes/merge_blocks.mbt:336-366` is the recursive region walk.
- `src/passes/merge_blocks.mbt:369-386` is the pass entry point and mutation marker.

This local pass is narrower than corrected Binaryen on branch-name retargeting but broader in one local way: it can flatten unlabeled branch-free HOT region-root blocks because it refuses live-label cases instead of trying to prove renames.

## Living wiki updates

Updated:

- `docs/wiki/binaryen/passes/merge-blocks/index.md`
- `docs/wiki/binaryen/passes/merge-blocks/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-blocks/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md`

Added:

- `docs/wiki/binaryen/passes/merge-blocks/implementation-structure-and-tests.md`

Updated catalogs and audit trail:

- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Supersession

Marked the older research notes as partially superseded for the Binaryen strategy interpretation:

- `docs/wiki/raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md`
- `docs/wiki/raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md`

They remain valid for historical context, scheduler slots, and the Starshine-status drift that was corrected on 2026-04-22.
