---
kind: entity
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
---

# `merge-blocks`

## Role

- `merge-blocks` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, it is a late block-wrapper cleanup pass that flattens safe tail nested blocks.
- In current Starshine, it is a HOT-region-root cleanup pass that flattens branch-free block roots into their parent regions while preserving typed-carrier and writeback stability.

## Why this dossier needed a refresh

The older folder still had useful Binaryen research, but it had become stale in two important ways:

- it still described `merge-blocks` as unimplemented even though the pass is active in `src/passes/optimize.mbt`, presets, tests, and CLI coverage
- it still lacked both an immutable raw primary-source manifest and the required dedicated Starshine strategy/code-map page

This refresh fixes that status drift instead of pretending the Binaryen side had never been researched.

## Why it matters

- `merge-blocks` is a real late cleanup pass in both upstream Binaryen and current Starshine.
- Starshine schedules it twice in both public presets after `simplify-locals` and around later branch/name cleanup.
- That repeated placement makes it a structural enabler:
  - earlier passes create branch-free wrapper blocks and typed carriers
  - `merge-blocks` removes the wrappers that are already safe
  - `remove-unused-brs` and `remove-unused-names` then expose more follow-up opportunities
  - a second `merge-blocks` run catches the newly exposed wrappers

## Beginner summary

Think of the current local pass as:

- “If a HOT region contains a block root that is only acting as a safe wrapper,
- and no live branch still needs that block's label,
- and flattening will not break typed block/loop carrier lowering,
- then splice the block body directly into the parent region.”

For Binaryen, the beginner summary is slightly different:

- “If a block ends in another block,
- and flattening that tail child preserves branch targets, result types, and observable effects,
- then splice the child into the parent and delete the wrapper.”

Those are related strategies, but not the same proof surface.

## Current durable takeaways

- Upstream Binaryen and Starshine are in the same optimization family, but Starshine is **not** a direct AST clone of `MergeBlocks.cpp`.
- Binaryen is centered on tail-child block merges and same-name branch-retargeting safety.
- Starshine is centered on HOT region-root flattening guarded by whole-function label-use tracking and typed-carrier legality checks.
- Current Starshine deliberately refuses any block whose label is still referenced anywhere in the function.
- Current Starshine also rewrites dead value suffixes before `unreachable` to explicit `drop`s before flattening so writeback stays Binaryen-stable.
- The reviewed official Binaryen `version_129` release page on 2026-04-22 showed publish date **2026-04-01**.
- A narrow 2026-04-22 current-`main` spot check on `MergeBlocks.cpp`, `pass.cpp`, and `merge-blocks.wast` did not surface a new teaching-relevant Binaryen drift beyond the existing upstream pages.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation: `ProblemFinder`, tail-child-only matching, naming/type/effect gates, and why the pass stays intentionally narrow.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly before/after shapes for the merges Binaryen performs and the ones it deliberately refuses.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Exact MoonBit owner-file and helper map for the active HOT pass, including label-use gating, typed-carrier guards, dead-`unreachable` suffix repair, preset placement, tests, and CLI exposure.

## Current local status summary

- The explicit Starshine pass exists and is wired into the pass manager and CLI.
- `src/passes/registry_test.mbt` classifies it as an active hot pass.
- `src/passes/optimize_test.mbt` proves that both public presets replay it twice in the late cleanup cluster.
- `src/passes/merge_blocks_test.mbt` is already a substantial direct proof surface for branch-target safety, typed carriers, `unreachable` suffix repair, and Binaryen-stable lowering families.
- `src/ir/hot_lower_test.mbt` also acts as neighboring evidence because several writeback tests explicitly anchor their expected shape to “merge-blocks wants Binaryen-stable output.”

## Sources

- [`../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`](../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md)
- [`../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md`](../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md`](../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
