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
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
---

# `merge-blocks` Implementation Structure And Tests

## Purpose

This page maps the upstream Binaryen source structure and the current Starshine implementation/test surfaces for `merge-blocks`.

Use it when you need to answer:

- where does upstream Binaryen implement each pass surface?
- which official tests prove the important shape families?
- where does the active Starshine HOT pass live?
- which local tests are the fastest evidence path?

## Upstream Binaryen owner file

Primary owner:

- `src/passes/MergeBlocks.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>

Important source units inside the file:

| Unit | Role |
| --- | --- |
| `optimizeDroppedBlock(...)` | Handles `drop(block ...)` cleanup and break-value removal when the shape is safe. |
| `optimizeBlock(...)` | Main child-block and loop-tail merging walk. |
| `optimizeIf(...)` | Moves safe work out of `if` conditions. |
| `optimizeThrow(...)` | Moves safe work out of `throw` operands. |
| `visitFunction(...)` | Runs the pass and refinalizes when the function changed. |
| `ProblemFinder` | Protects the dropped-block / break-value cleanup path. |
| `BreakValueDropper` | Drops break values that would otherwise be lost during safe cleanup. |

## Upstream helper surfaces

| File | Why it matters |
| --- | --- |
| `src/ir/branch-utils.h` | Branch scope and branch-user helper surface used by the cleanup path. |
| `src/ir/effects.h` | Effect invalidation checks that block unsafe motion. |
| `src/wasm/wasm-traversal.h` | Walker and refinalization infrastructure. |
| `src/passes/pass.cpp` | Public pass registration and scheduler placement. |

## Upstream test surface

Primary lit test:

- `test/lit/passes/merge-blocks.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>

What the lit file proves:

- child blocks can be merged into a parent block list when safe;
- loop tails can be merged when safe;
- `drop(block ...)` cleanup is part of the pass;
- safe `if`-condition motion is part of the pass;
- safe `throw`-operand motion is part of the pass;
- `--remove-unused-names --merge-blocks` assumes blocks without names have no branch targets;
- current `main` matched the `version_129` contract on the reviewed surfaces.

## Current Starshine owner file

Primary owner:

- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)

Exact local code map:

| Lines | Surface | Role |
| --- | --- | --- |
| `src/passes/pass_common.mbt:2-45` | `pass_compute_label_used(...)` / `pass_label_is_used(...)` | Shared whole-function label-use collection and live-label bailout helper. |
| `src/passes/merge_blocks.mbt:2-13` | `merge_blocks_descriptor()` | Active HOT descriptor and invalidated analysis set. |
| `src/passes/merge_blocks.mbt:20-32` | `merge_blocks_has_candidate(...)` | Cheap live-`Block` scan before doing deeper work. |
| `src/passes/merge_blocks.mbt:34-45` | `merge_blocks_collect_region_roots(...)` | Region-root collection helper. |
| `src/passes/merge_blocks.mbt:47-57` | `merge_blocks_control_block_type(...)` | Block-result type extraction. |
| `src/passes/merge_blocks.mbt:59-77` | `merge_blocks_block_param_count(...)` | Typed block-param count through `HotModuleContext`. |
| `src/passes/merge_blocks.mbt:79-86` | `merge_blocks_block_has_params(...)` | Boolean typed-parameter gate. |
| `src/passes/merge_blocks.mbt:88-132` | `merge_blocks_rewrite_dead_unreachable_suffix_roots(...)` | Converts dead value roots before `unreachable` into explicit `drop`s before flattening. |
| `src/passes/merge_blocks.mbt:134-232` | `merge_blocks_visit_control_node(...)` | Recurses through block, loop, `if`, `try`, and `try-table` regions. |
| `src/passes/merge_blocks.mbt:234-281` | `merge_blocks_flatten_region_root_block(...)` | Main HOT root-block splice helper and typed-carrier guard. |
| `src/passes/merge_blocks.mbt:283-314` | `merge_blocks_visit_region(...)` | Region root traversal and repeated splice attempts. |
| `src/passes/merge_blocks.mbt:316-335` | `merge_blocks_run(...)` | Pass entry point, use-def construction, mutation marking, result reporting. |

## Starshine registry and dispatcher map

| File/lines | Role |
| --- | --- |
| `src/passes/optimize.mbt:249-251` | Active hot-pass registry entry for `merge-blocks`. |
| `src/passes/optimize.mbt:288-291` / `300-303` | Public preset expansions schedule `merge-blocks` twice in the late cleanup cluster. |
| `src/passes/optimize.mbt:444-447` / `458-461` | Static preset arrays keep the same repeated placement. |
| `src/passes/pass_manager.mbt:9002` | Dispatcher calls `merge_blocks_run(ctx, func)`. |


## Starshine direct tests

Primary local proof file:

- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)

Important lanes:

| Lines | Test family |
| --- | --- |
| `src/passes/merge_blocks_test.mbt:21-52` | Basic nested-root and loop-root flattening. |
| `src/passes/merge_blocks_test.mbt:54-136` | Typed single-param loop and multi-result carrier stability. |
| `src/passes/merge_blocks_test.mbt:138-162` | Dead values before `unreachable` become explicit drops. |
| `src/passes/merge_blocks_test.mbt:164-415` | Typed loop / if-arm carrier families. |
| `src/passes/merge_blocks_test.mbt:417-435` | Incoming branch targets preserve blocks. |
| `src/passes/merge_blocks_test.mbt:437-598` | Lowered local/drop and externref carrier stability. |
| `src/passes/merge_blocks_test.mbt:599-887` | Void typed block/loop carrier keep/drop matrix. |
| `src/passes/merge_blocks_test.mbt:894-1709` | Multi-result, externref, funcref, if-arm, and block lowering stability families. |

## Starshine integration tests

| File/lines | Evidence |
| --- | --- |
| `src/passes/registry_test.mbt:64` | `merge-blocks` is classified as an active hot pass. |
| `src/passes/registry_test.mbt:189-190` | Descriptor coverage. |
| `src/passes/registry_test.mbt:206-207` / `214-215` | Preset-array coverage for repeated `merge-blocks` slots. |
| `src/passes/optimize_test.mbt:382-403` / `407-428` | `optimize` and `shrink` replay both late `merge-blocks` slots. |
| `src/passes/optimize_test.mbt:469-512` | `simplify-locals` output reaches the late `merge-blocks` cleanup cluster. |
| `src/cmd/cmd_wbtest.mbt:1959-1993` | Direct `--merge-blocks` CLI acceptance and output validation. |
| `src/ir/hot_lower_test.mbt:1861-2506` | Neighboring lower/writeback tests that explicitly preserve Binaryen-stable shapes for the local pass. |

## Binaryen-vs-Starshine implementation split

| Topic | Binaryen | Starshine |
| --- | --- | --- |
| IR level | Binaryen AST expressions. | HOT regions and control nodes. |
| Main positive surface | Safe child/loop-tail/block motion. | Branch-free region-root `Block` nodes whose labels are unused. |
| Label handling | Helper-driven cleanup path, not branch retargeting as the main story. | Hard live-label bailout. |
| Type repair | `visitFunction(...)` refinalization. | HOT mutation plus typed-carrier guards and later writeback validation. |
| Extra local concern | Not applicable. | Dead value roots before `unreachable` are materialized as explicit `drop`s. |

## Validation guidance

For docs-only updates, this page's evidence is source and test-map based. For future implementation changes, the minimum practical signoff remains:

1. `moon test src/passes`
2. `moon test src/cmd`
3. focused Binaryen parity with `bun scripts/pass-fuzz-compare.ts --pass merge-blocks ...` once the harness lane is being modified
4. debug-artifact replay if pass placement or HOT lower/writeback behavior changes

## Sources

- [`../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../../../raw/binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md)
- [`../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../../../raw/research/0472-2026-05-05-merge-blocks-current-main-anchor-recheck.md)
- [`../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)
- [`../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`](../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md)
- [`../../../../../src/passes/pass_common.mbt`](../../../../../src/passes/pass_common.mbt)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
