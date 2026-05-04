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
- compute whole-function label use;
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
| `src/passes/merge_blocks.mbt` | `2-17` | `merge_blocks_descriptor()` and invalidated analyses. |
| `src/passes/merge_blocks.mbt` | `20-31` | fast live-`Block` candidate scan. |
| `src/passes/merge_blocks.mbt` | `34-80` | whole-function label-use collection. |
| `src/passes/merge_blocks.mbt` | `85-90` | live-label bailout helper. |
| `src/passes/merge_blocks.mbt` | `93-136` | region-root and typed block-param helpers. |
| `src/passes/merge_blocks.mbt` | `141-184` | dead-before-`unreachable` root repair. |
| `src/passes/merge_blocks.mbt` | `187-284` | recursive region visitor for block, loop, `if`, `try`, and `try-table`. |
| `src/passes/merge_blocks.mbt` | `287-333` | root-block flattening helper. |
| `src/passes/merge_blocks.mbt` | `336-366` | repeated region traversal and splice attempts. |
| `src/passes/merge_blocks.mbt` | `369-386` | pass entry point and mutation marking. |
| `src/passes/optimize.mbt` | `232-234` | active hot-pass registry entry. |
| `src/passes/optimize.mbt` | `255-268` / `394-408` | repeated late preset placement. |
| `src/passes/pass_manager.mbt` | `7813` / `8704` | HOT lower/writeback options and dispatcher call. |
| `src/passes/registry_test.mbt` | `48` / `135-159` | active hot-pass category and descriptor coverage. |
| `src/passes/optimize_test.mbt` | `340-447` | preset replay evidence. |
| `src/cmd/cmd_wbtest.mbt` | `1959-1993` | direct CLI acceptance. |
| `src/ir/hot_lower_test.mbt` | `1861-2506` | neighboring Binaryen-stable lower/writeback evidence. |

## Reading order

1. [`./index.md`](./index.md)
2. [`./binaryen-strategy.md`](./binaryen-strategy.md)
3. [`./wat-shapes.md`](./wat-shapes.md)
4. [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
5. [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)

## Sources

- [`../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
