---
kind: entity
status: supported
last_reviewed: 2026-06-08
sources:
  - ../../../raw/research/0720-2026-06-08-merge-blocks-o4z-behavior-audit.md
  - ../../../raw/research/0514-2026-05-06-merge-blocks-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md
  - ../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md
  - ../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md
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
  - ./starshine-strategy.md
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
- In upstream Binaryen `version_129`, it is a block-merging and loop-tail-merging pass with helper-driven cleanup for `drop(block ...)`, `if` conditions, and `throw` operands.
- In current Starshine, it is a HOT-region cleanup pass that flattens branch-free block roots into their parent regions while preserving typed-carrier and writeback stability.

## 2026-05-04 correction

The previous Binaryen side of this dossier taught the wrong beginner model:

- named-block deblocking;
- branch retargeting as the core proof;
- `if`-arm and terminal-name cleanup as the main contract.

The refreshed current-main source shows a different contract:

- Binaryen merges safe child blocks into parent block lists;
- Binaryen merges safe loop tails;
- Binaryen moves safe work out of `drop(block ...)`, `if` conditions, and `throw` operands;
- `ProblemFinder` is part of the dropped-block cleanup path, not a named-label retargeting engine;
- the focused 2026-05-04 current-main refresh matched `version_129` on the reviewed surfaces.

This correction partially supersedes the older research notes for Binaryen strategy interpretation only. The older notes remain useful for historical scheduler context and for the local Starshine status story.

## Why it matters

`merge-blocks` is a real late cleanup pass in both upstream Binaryen and current Starshine, but the proof obligations differ.

Binaryen uses helper-driven local motion over AST expressions. Starshine avoids branch-name retargeting entirely by refusing every block whose label is still used anywhere in the function.

Starshine schedules `merge-blocks` twice in both public presets after `simplify-locals` and around later branch/name cleanup. That repeated placement makes it a structural enabler:

- earlier passes create wrappers and typed carriers;
- `merge-blocks` removes wrappers that are locally safe;
- `remove-unused-brs` and `remove-unused-names` expose more follow-up opportunities;
- a second `merge-blocks` run catches newly exposed branch-free wrappers.

## Beginner summary

For Binaryen:

- “Merge safe child blocks upward, clean up safe loop tails, and move safe work out of `drop(block ...)`, `if`, and `throw` shapes.”

For Starshine:

- “If a HOT region contains a branch-free block root whose label is unused, and flattening keeps typed carrier lowering stable, splice the block body into the parent region.”

Those are related strategies, but not the same implementation.

## Inputs, outputs, and invariants

### Binaryen inputs

- Function-local Binaryen AST expressions.
- Child blocks, loop tails, and branch-free motion candidates.
- Helper analysis from branch utilities and effect analysis.

### Binaryen outputs

- Fewer redundant child blocks.
- Simpler loop bodies.
- Safer `drop(block ...)`, `if`, and `throw` shapes.
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

- Do not move code across a boundary if it changes effect order.
- Do not assume every child block can be absorbed.
- Do not skip refinalization after edits.
- Do not erase local dead values before `unreachable` in Starshine.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Corrected deep dive into the current upstream helper-driven motion pass.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering block splicing, loop tails, `drop(block ...)`, `if`-condition motion, `throw` motion, and negative families.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-confirmed owner-file, helper, lit-test, and exact Starshine line-range map.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - High-level Starshine strategy overview with exact code locations.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Exact MoonBit owner-file and helper map for the active HOT pass.

## Current local status summary

- The explicit Starshine pass exists and is wired into the pass manager and CLI.
- The 2026-05-06 direct revalidation closed the post-fuzzer-change `merge-blocks` backlog slice: `.tmp/pass-fuzz-merge-blocks` compared `9975/10000` cases with `9975` normalized matches, `0` mismatches, and `25` Binaryen/tool command failures, all from wasm-smith lanes.
- The same run kept all `5000` `gen-valid` cases comparable and matching.
- The 2026-05-06 debug-artifact `--merge-blocks` compare on `tests/node/dist/starshine-debug-wasi.wasm` had normalized WAT equality and canonical function equality; raw/canonical wasm and normalized WAT text still differ, but not at the normalized/function compare level used for this direct pass.
- `src/passes/registry_test.mbt` classifies it as an active hot pass.
- `src/passes/optimize_test.mbt` proves that both public presets replay it twice in the late cleanup cluster.
- `src/passes/merge_blocks_test.mbt` is a substantial direct proof surface for live-label gating, typed carriers, `unreachable` suffix repair, Binaryen-stable lowering families, and the 2026-06-08 expression-child block-prefix motion fixtures for `drop(block ...)`, `if` conditions, stores, and `throw` operands.
- `src/ir/hot_lower_test.mbt` also acts as neighboring evidence because several writeback tests explicitly anchor their expected shape to “merge-blocks wants Binaryen-stable output.”

## Validation guidance

For documentation work, validate by cross-reading:

1. [`../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md)
2. [`../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md)
3. [`../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md)
4. [`./binaryen-strategy.md`](./binaryen-strategy.md)
5. [`./wat-shapes.md`](./wat-shapes.md)
6. [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
7. [`./starshine-strategy.md`](./starshine-strategy.md)
8. [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)

For implementation work, run at minimum the pass and command test lanes, then a pass-targeted Binaryen comparison if behavior changes. The 2026-05-06 direct revalidation is captured in [`../../../raw/research/0514-2026-05-06-merge-blocks-direct-revalidation.md`](../../../raw/research/0514-2026-05-06-merge-blocks-direct-revalidation.md). The latest 2026-06-08 behavior audit and expression-child block-motion slice is captured in [`../../../raw/research/0720-2026-06-08-merge-blocks-o4z-behavior-audit.md`](../../../raw/research/0720-2026-06-08-merge-blocks-o4z-behavior-audit.md); its final behavior-normalized 100000-case compare is zero-mismatch, with three raw unnormalized debris mismatches classified as non-semantic.

## Sources

- [`../../../raw/research/0720-2026-06-08-merge-blocks-o4z-behavior-audit.md`](../../../raw/research/0720-2026-06-08-merge-blocks-o4z-behavior-audit.md)
- [`../../../raw/research/0514-2026-05-06-merge-blocks-direct-revalidation.md`](../../../raw/research/0514-2026-05-06-merge-blocks-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md)
- [`../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md)
- [`../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)
- [`../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`](../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md)
- [`../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md`](../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md)
- [`../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md`](../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md`](../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
