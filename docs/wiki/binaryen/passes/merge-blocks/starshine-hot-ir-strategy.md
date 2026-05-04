---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md
  - ../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
---

# Starshine HOT-IR Code Map For `merge-blocks`

This page is the exact MoonBit line map for the current Starshine implementation. For the higher-level strategy summary, read [`./starshine-strategy.md`](./starshine-strategy.md) first.

## What the local pass does

Current Starshine `merge-blocks` is a HOT-region cleanup pass.

It flattens branch-free region-root `Block` nodes into their parent regions, but only when the label is dead and the typed-carrier / writeback rules stay stable.

## Exact local code map

| Lines | Surface | Role |
| --- | --- | --- |
| `src/passes/merge_blocks.mbt:2-17` | `merge_blocks_descriptor()` | Active HOT descriptor and invalidated analyses. |
| `src/passes/merge_blocks.mbt:20-31` | `merge_blocks_has_candidate(...)` | Cheap live-`Block` scan before deeper work. |
| `src/passes/merge_blocks.mbt:34-80` | `merge_blocks_compute_label_used(...)` | Whole-function label-use scan across `br`, `br_if`, `br_table`, `delegate`, `br_on_*`, and `try_table` catch targets. |
| `src/passes/merge_blocks.mbt:85-90` | `merge_blocks_label_is_used(...)` | Hard bailout for live labels. |
| `src/passes/merge_blocks.mbt:93-136` | region and typed-block helpers | Region root collection and block-param counting through `HotModuleContext`. |
| `src/passes/merge_blocks.mbt:141-184` | `merge_blocks_rewrite_dead_unreachable_suffix_roots(...)` | Preserves dead value roots before `unreachable` as explicit `drop`s. |
| `src/passes/merge_blocks.mbt:187-284` | `merge_blocks_visit_control_node(...)` | Recurses through block, loop, `if`, `try`, and `try-table` regions. |
| `src/passes/merge_blocks.mbt:287-333` | `merge_blocks_flatten_region_root_block(...)` | Main HOT root-block splice helper. |
| `src/passes/merge_blocks.mbt:336-366` | `merge_blocks_visit_region(...)` | Region traversal and repeated flattening. |
| `src/passes/merge_blocks.mbt:369-386` | `merge_blocks_run(...)` | Entry point, use-def construction, mutation marking, changed/unchanged result. |
| `src/passes/optimize.mbt:232-234` | registry entry | Active hot-pass registration. |
| `src/passes/optimize.mbt:255-268` / `394-408` | preset arrays | Repeated late `merge-blocks` placement in `optimize` and `shrink`. |
| `src/passes/pass_manager.mbt:7813` / `8704` | manager/dispatcher | HOT lower/writeback options and call to `merge_blocks_run(ctx, func)`. |

## Local strategy in one sentence

Flatten only branch-free HOT region roots, keep live-label blocks, and repair dead-before-`unreachable` values before splicing.

## What to notice while reading the code

- The pass is label-first, not name-retargeting-first.
- The safety proof is a dead-label check plus typed-carrier gating, not a recursive branch-user rewrite.
- The dead-value repair exists because HOT writeback must keep Binaryen-stable output shapes.
- The pass runs twice in the late preset cluster so neighboring cleanup passes can expose more easy merges.

## Validation surfaces

- `src/passes/merge_blocks_test.mbt:21-1709`
  - direct flattening positives, live-label negatives, typed carrier matrix, dead-`unreachable` repair, externref/funcref/multi-result cases.
- `src/passes/optimize_test.mbt:340-447`
  - repeated preset-slot exposure and `simplify-locals -> merge-blocks` handoff.
- `src/passes/registry_test.mbt:48` and `135-159`
  - active hot-pass category, descriptor, and preset expansion coverage.
- `src/cmd/cmd_wbtest.mbt:1959-1993`
  - direct `--merge-blocks` CLI surface.
- `src/ir/hot_lower_test.mbt:1861-2506`
  - neighboring lower/writeback tests for Binaryen-stable typed carrier output.

## Sources

- [`../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
