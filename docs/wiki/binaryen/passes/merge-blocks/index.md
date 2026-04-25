---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-hot-ir-strategy.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
supersedes:
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
---

# `merge-blocks`

## Role

- `merge-blocks` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, it is a named-block deblocking pass with branch-retargeting proof, `if`-arm cleanup, terminal wrapper-name cleanup, and post-edit refinalization.
- In current Starshine, it is a HOT-region-root cleanup pass that flattens branch-free block roots into their parent regions while preserving typed-carrier and writeback stability.

## 2026-04-25 correction

The previous Binaryen side of this dossier taught the wrong beginner model:

- tail-child-only flattening;
- unnamed child blocks as a positive family;
- same-name-only named child merging.

The official Binaryen sources and lit test contradict that model. The corrected source-backed model is:

- Binaryen targets named block layers;
- nameless wrappers are covered as a no-merge family in the official lit file;
- different child names can be removed when branch users can be recursively retargeted to the parent name without crossing invalidating effects;
- `visitIf(...)`, `visitThrow(...)`, `visitRethrow(...)`, and `visitReturn(...)` are part of the owner-file surface;
- the focused 2026-04-25 current-main check found no teaching-relevant drift from this corrected `version_129` interpretation.

This correction partially supersedes the older research notes for Binaryen strategy interpretation only. The older notes remain useful for historical scheduler context and for the 2026-04-22 Starshine-status correction.

## Why it matters

`merge-blocks` is a real late cleanup pass in both upstream Binaryen and current Starshine, but the proof obligations differ.

Binaryen needs a name-retargeting proof because removing a named block changes branch target names. Starshine avoids that class of proof by refusing every block whose label is still used anywhere in the function.

Starshine schedules `merge-blocks` twice in both public presets after `simplify-locals` and around later branch/name cleanup. That repeated placement makes it a structural enabler:

- earlier passes create wrappers and typed carriers;
- `merge-blocks` removes wrappers that are locally safe;
- `remove-unused-brs` and `remove-unused-names` expose more follow-up opportunities;
- a second `merge-blocks` run catches newly exposed branch-free wrappers.

## Beginner summary

For Binaryen:

- “If a named block wrapper can be removed and all branches using its name can safely be retargeted to the surrounding name, remove the wrapper, update name uses, and refinalize.”

For Starshine:

- “If a HOT region contains a branch-free block root whose label is unused, and flattening keeps typed carrier lowering stable, splice the block body into the parent region.”

Those are related strategies, but not the same implementation.

## Inputs, outputs, and invariants

### Binaryen inputs

- Function-local Binaryen AST expressions.
- Named block layers and branch-name users.
- Helper analysis from branch utilities and effect analysis.

### Binaryen outputs

- Fewer redundant named block layers.
- Updated scope-name uses when a child name is changed to a parent name.
- Refinalized rewritten expressions.

### Starshine inputs

- A lifted `HotFunc` with block, loop, if, try, and try-table regions.
- Whole-function label-use information.
- Module type context for typed block-param decisions.

### Starshine outputs

- Flattened branch-free HOT region roots.
- Preserved live-label blocks.
- Explicit `drop`s for dead value roots before `unreachable` suffixes.
- Changed-function marking only after an actual splice.

### Correctness constraints

- Do not retarget branches unless every branch user remains semantically safe. Binaryen proves this recursively; Starshine avoids it by bailing out on used labels.
- Do not erase effects by making a branch skip work it could not previously skip.
- Preserve type contracts. Binaryen refinalizes; Starshine uses typed-carrier guards and later writeback validation.
- Preserve terminal/unreachable semantics, including local dead-value materialization before `unreachable` in Starshine.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Corrected deep dive into Binaryen `version_129`: `ProblemFinder`, branch-user collection, `canChangeTo(...)`, block/if/terminal visitors, and refinalization.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering named block positives, different-name retargeting positives, `if`/terminal families, nameless no-merges, ambiguity bailouts, and effect barriers.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-confirmed owner-file, helper, lit-test, and exact Starshine line-range map.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Exact MoonBit owner-file and helper map for the active HOT pass, including label-use gating, typed-carrier guards, dead-`unreachable` suffix repair, preset placement, tests, and CLI exposure.

## Current local status summary

- The explicit Starshine pass exists and is wired into the pass manager and CLI.
- `src/passes/registry_test.mbt` classifies it as an active hot pass.
- `src/passes/optimize_test.mbt` proves that both public presets replay it twice in the late cleanup cluster.
- `src/passes/merge_blocks_test.mbt` is a substantial direct proof surface for branch-target safety, typed carriers, `unreachable` suffix repair, and Binaryen-stable lowering families.
- `src/ir/hot_lower_test.mbt` also acts as neighboring evidence because several writeback tests explicitly anchor their expected shape to “merge-blocks wants Binaryen-stable output.”

## Validation guidance

For documentation work, validate by cross-reading:

1. [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)
2. [`./binaryen-strategy.md`](./binaryen-strategy.md)
3. [`./wat-shapes.md`](./wat-shapes.md)
4. [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
5. [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)

For implementation work, run at minimum the pass and command test lanes, then a pass-targeted Binaryen comparison if behavior changes.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)
- [`../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md`](../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md)
- [`../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`](../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md)
- [`../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md`](../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md`](../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
