---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md
  - ../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md
  - ../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md
  - ../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/pass_common.mbt
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
| `src/passes/pass_common.mbt:2-45` | `pass_compute_label_used(...)` / `pass_label_is_used(...)` | Shared whole-function label-use scan and live-label bailout helper. |
| `src/passes/merge_blocks.mbt:2-13` | `merge_blocks_descriptor()` | Active HOT descriptor and invalidated analyses. |
| `src/passes/merge_blocks.mbt:15-17` | `merge_blocks_summary()` | Summary string for the pass registry. |
| `src/passes/merge_blocks.mbt:20-32` | `merge_blocks_has_candidate(...)` | Cheap live-`Block` scan before deeper work. |
| `src/passes/merge_blocks.mbt:34-45` | `merge_blocks_collect_region_roots(...)` | Region-root collection helper. |
| `src/passes/merge_blocks.mbt:47-57` | `merge_blocks_control_block_type(...)` | Block-result type extraction. |
| `src/passes/merge_blocks.mbt:59-77` | `merge_blocks_block_param_count(...)` | Typed block-param counting through `HotModuleContext`. |
| `src/passes/merge_blocks.mbt:79-86` | `merge_blocks_block_has_params(...)` | Boolean typed-parameter gate. |
| `src/passes/merge_blocks.mbt:88-132` | `merge_blocks_rewrite_dead_unreachable_suffix_roots(...)` | Preserves dead value roots before `unreachable` as explicit `drop`s. |
| `src/passes/merge_blocks.mbt:134-232` | `merge_blocks_visit_control_node(...)` | Recurses through block, loop, `if`, `try`, and `try-table` regions. |
| `src/passes/merge_blocks.mbt:234-281` | `merge_blocks_flatten_region_root_block(...)` | Main HOT root-block splice helper. |
| `src/passes/merge_blocks.mbt:283-314` | `merge_blocks_visit_region(...)` | Region traversal and repeated flattening. |
| `src/passes/merge_blocks.mbt:316-335` | `merge_blocks_run(...)` | Entry point, use-def construction, mutation marking, changed/unchanged result. |
| `src/passes/optimize.mbt:249-251` | registry entry | Active hot-pass registration. |
| `src/passes/optimize.mbt:288-291` / `300-303` | preset arrays | Repeated late `merge-blocks` placement in `optimize` and `shrink`. |
| `src/passes/optimize.mbt:444-447` / `458-461` | preset arrays | Static preset arrays with the same repeated placement. |
| `src/passes/pass_manager.mbt:9002` | manager/dispatcher | `merge_blocks_run(ctx, func)` call site. |

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
- `src/passes/optimize_test.mbt:382-403` / `407-428` / `469-512`
  - repeated preset-slot exposure and `simplify-locals -> merge-blocks` handoff.
- `src/passes/registry_test.mbt:64` / `189-190` / `206-207` / `214-215`
  - active hot-pass category, descriptor, and preset expansion coverage.
- `src/cmd/cmd_wbtest.mbt:1959-1993`
  - direct `--merge-blocks` CLI acceptance and output validation.
- `src/ir/hot_lower_test.mbt:1861-2506`
  - neighboring lower/writeback tests for Binaryen-stable typed carrier output.

## Sources

- [`../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md)
- [`../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md)
- [`../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/pass_common.mbt`](../../../../../src/passes/pass_common.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
