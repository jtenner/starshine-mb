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
related:
  - ./index.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `merge-blocks` Strategy

## Correct source-backed model

Binaryen `merge-blocks` is a block-merging and loop-tail-merging pass.

It does **not** implement the named-block deblocking story that older local notes drifted toward. The source-backed contract is:

- merge safe child block content into the parent block list;
- merge safe loop-tail block content into the loop body;
- move safe code out of `drop(block ...)`, `if` conditions, and `throw` operands;
- preserve break semantics with the break-value cleanup helper path;
- refinalize after edits.

## One-table overview

| Source helper | Job |
| --- | --- |
| `optimizeDroppedBlock(...)` | Clean up `(drop (block ...))` shapes and remove dead break values when the branch structure allows it. |
| `optimizeBlock(...)` | Main recursive block/loop merger that splices eligible child roots into their parent. |
| `optimizeIf(...)` | Move safe work out of `if` conditions. |
| `optimizeThrow(...)` | Move safe work out of `throw` operands. |
| `visitFunction(...)` | Run the pass and refinalize when the body changed. |
| `ProblemFinder` | Guard the dropped-block / break-value cleanup path, not a named-block retargeting engine. |

## How the main block merge works

The core walk scans a block's root list and looks for child blocks that can be safely absorbed into the parent.

Typical safe cases are:

- an unnamed child block whose roots can be spliced into the parent;
- a child block at the end of a loop body whose tail can be merged without changing the loop backedge;
- a child whose leading or trailing work can be moved upward while preserving the final value shape.

The important point is that Binaryen is not just deleting wrappers blindly. It checks the surrounding shape, keeps branch semantics intact, and preserves the block's final expression behavior.

## Dropped-block cleanup is a separate surface

`optimizeDroppedBlock(...)` handles `drop(block ...)`-style shapes.

That path can remove break-value work only when the pass can prove the transformed shape is still safe. This is where `ProblemFinder` participates: it protects the break-value cleanup path from unsafe branch interactions.

## `if` and `throw` are real pass surfaces

The upstream owner file also moves safe work out of:

- `if` conditions;
- `throw` operands.

Those surfaces matter because they show the pass is broader than “merge adjacent blocks.” It is a small local motion pass over several control shapes, not just one syntax pattern.

## Correctness constraints

- Do not change branch targets unless the source helper already proved the move is safe.
- Do not treat `ProblemFinder` as a whole-pass named-label guard; it is a helper in one cleanup path.
- Do not assume every child block can be absorbed. Shape, effect, and backedge safety all matter.
- Do not skip refinalization after structural edits.

## What this means for Starshine

Current Starshine `merge-blocks` is related but intentionally different:

- it operates on HOT regions, not Binaryen AST nodes;
- it refuses live labels instead of retargeting them;
- it repairs dead-before-`unreachable` values before splicing;
- it keeps the local contract centered on branch-free region-root cleanup.

Read [`./starshine-strategy.md`](./starshine-strategy.md) for the local strategy and [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for the exact code map.

## Sources

- [`../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)
- [`../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`](../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md)
- Binaryen current-main `MergeBlocks.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- Binaryen current-main `merge-blocks.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>
- Binaryen `version_129` `MergeBlocks.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
