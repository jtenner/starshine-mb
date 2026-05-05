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
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-hot-ir-strategy.md
  - ../simplify-locals/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
---

# Starshine Strategy For `merge-blocks`

Current Starshine `merge-blocks` is a HOT-region cleanup pass, not a direct port of Binaryen's `MergeBlocks.cpp` contract.

Use this page as the strategy overview, then follow [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for the exact MoonBit line map.

## What Starshine does

Starshine flattens branch-free HOT region-root `Block` nodes into their parent regions.

In practice that means:

- scan for live `Block` nodes cheaply;
- compute whole-function label use through the shared `pass_common.mbt` helper;
- recurse through block, loop, `if`, `try`, and `try-table` regions;
- refuse any region-root block whose label is referenced anywhere in the function;
- flatten only the branch-free cases that keep typed-carrier lowering stable;
- rewrite dead values before `unreachable` as explicit `drop`s before splicing;
- mark the function mutated only after a real splice.

## How that differs from Binaryen

Binaryen's upstream pass still merges nested block children, loop tails, `if` conditions, and some `drop(block ...)` / `throw` shapes inside `MergeBlocks.cpp`.

Starshine does **not** try to retarget branch names or emulate Binaryen's AST-level helper proof. Instead, it uses a much simpler HOT rule:

- if the label is live, keep the block;
- if the label is dead and the carrier shape is safe, splice the roots upward.

That makes Starshine intentionally narrower in one direction and broader in another:

- narrower: no recursive branch-target rename proof;
- broader: it can flatten unlabeled HOT region-root blocks because it is not tied to Binaryen's AST naming contract.

## Exact code locations

| File | Lines | Role |
| --- | --- | --- |
| `src/passes/pass_common.mbt` | `2-45` | Shared whole-function label-use collection and live-label bailout helper. |
| `src/passes/merge_blocks.mbt` | `2-13` | `merge_blocks_descriptor()` and invalidated analyses. |
| `src/passes/merge_blocks.mbt` | `15-17` | `merge_blocks_summary()`. |
| `src/passes/merge_blocks.mbt` | `20-32` | fast live-`Block` candidate scan. |
| `src/passes/merge_blocks.mbt` | `34-45` | region-root collection helper. |
| `src/passes/merge_blocks.mbt` | `47-57` | block-result type extraction. |
| `src/passes/merge_blocks.mbt` | `59-77` | typed block-param counting through `HotModuleContext`. |
| `src/passes/merge_blocks.mbt` | `79-86` | boolean typed-parameter gate. |
| `src/passes/merge_blocks.mbt` | `88-132` | dead-before-`unreachable` root repair. |
| `src/passes/merge_blocks.mbt` | `134-232` | recursive region visitor for block, loop, `if`, `try`, and `try-table`. |
| `src/passes/merge_blocks.mbt` | `234-281` | root-block flattening helper. |
| `src/passes/merge_blocks.mbt` | `283-314` | repeated region traversal and splice attempts. |
| `src/passes/merge_blocks.mbt` | `316-335` | pass entry point and mutation marking. |
| `src/passes/optimize.mbt` | `249-251` | active hot-pass registry entry. |
| `src/passes/optimize.mbt` | `288-291` / `300-303` | repeated late preset placement in `optimize` and `shrink`. |
| `src/passes/optimize.mbt` | `444-447` / `458-461` | static preset arrays with the same repeated placement. |
| `src/passes/pass_manager.mbt` | `9002` | dispatcher call to `merge_blocks_run(ctx, func)`. |
| `src/passes/registry_test.mbt` | `64` / `189-190` / `206-207` / `214-215` | registry category, descriptor, and preset-expansion coverage. |
| `src/passes/optimize_test.mbt` | `382-403` / `407-428` / `469-512` | repeated preset-slot exposure and `simplify-locals -> merge-blocks` handoff. |
| `src/cmd/cmd_wbtest.mbt` | `1959-1993` | direct `--merge-blocks` CLI surface. |
| `src/ir/hot_lower_test.mbt` | `1861-2506` | neighboring lower/writeback tests for Binaryen-stable typed carrier output. |

## Reading order

1. [`./index.md`](./index.md)
2. [`./binaryen-strategy.md`](./binaryen-strategy.md)
3. [`./wat-shapes.md`](./wat-shapes.md)
4. [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
5. [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)

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
