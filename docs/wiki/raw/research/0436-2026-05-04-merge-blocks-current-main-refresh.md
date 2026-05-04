---
kind: research
status: supported
last_reviewed: 2026-05-04
sources:
  - ../binaryen/2026-05-04-merge-blocks-current-main-refresh.md
  - ../binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../binaryen/passes/merge-blocks/index.md
  - ../../binaryen/passes/merge-blocks/binaryen-strategy.md
  - ../../binaryen/passes/merge-blocks/wat-shapes.md
  - ../../binaryen/passes/merge-blocks/implementation-structure-and-tests.md
  - ../../binaryen/passes/merge-blocks/starshine-strategy.md
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

# `merge-blocks` current-main refresh and dossier correction

## Why this note exists

The living `merge-blocks` pages had drifted into a named-block deblocking story. A fresh 2026-05-04 read of official Binaryen current-main source shows that the upstream pass is still the old block-merging / loop-tail-merging family, with `ProblemFinder` only as part of the dropped-block cleanup path.

## What was ingested

Added the immutable source manifest:

- [`../binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../binaryen/2026-05-04-merge-blocks-current-main-refresh.md)

That capture records the reviewed current-main and `version_129` sources for:

- `MergeBlocks.cpp`
- `pass.cpp`
- `merge-blocks.wast`
- helper surfaces in `branch-utils.h` and `effects.h`

## Durable findings

- The core upstream helpers are `optimizeDroppedBlock(...)`, `optimizeBlock(...)`, `optimizeIf(...)`, `optimizeThrow(...)`, and `visitFunction(...)`.
- The pass still merges block children into parent block lists when the shape is safe.
- The pass still has loop-tail handling.
- The pass still moves code out of `drop(block ...)`, `if` conditions, and `throw` operands when safe.
- The dedicated lit file still covers branch-free child merging, loop-tail cleanup, `if`-condition movement, top-level block-value movement, and the `remove-unused-names --merge-blocks` assumption that blocks without names have no branch targets.
- Current-main and `version_129` matched on the reviewed surfaces.

## Wiki updates made from this note

- refreshed the `merge-blocks` landing page
- rewrote the Binaryen strategy and WAT-shape pages
- added a dedicated Starshine strategy page
- kept the exact HOT code-map page as the implementation companion
- updated the shared index and tracker catalogs

## Supersession

This note supersedes the earlier 2026-04-25 named-block deblocking interpretation for teaching purposes.
