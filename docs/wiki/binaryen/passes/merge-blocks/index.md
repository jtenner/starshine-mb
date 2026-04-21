---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
---

# `merge-blocks`

## Role

- `merge-blocks` is an upstream Binaryen late function-cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Its job is narrow but important: flatten a parent block's trailing child block when doing so preserves branch behavior, typed block results, and observable effects.

## Why it matters

- The saved generated-artifact `-O4z` audit records `merge-blocks` as a real skipped top-level upstream slot twice:
  - top-level slot `39`
  - top-level slot `42`
- The pass is deliberately late. In the saved `-O4z` path it sits after `code-folding`, then later again after `remove-unused-brs` and `remove-unused-names`.
- That placement makes `merge-blocks` a structural enabler: earlier passes create redundant block wrappers, and later passes profit once those wrappers disappear.

## Beginner summary

Think of the pass as:

- “If a block ends in another block,
- and the child block is just a safe wrapper around the tail,
- then copy the child's contents into the parent and delete the wrapper.”

Binaryen only does that when all of these stay true:

- branches still land in the right semantic place
- parent and child have the same block result type
- no named-child side effects disappear because a retargeted branch now skips them

## Current durable takeaways

- This is **not** a general block flattener. It only looks at a block whose **last** child is also a block.
- Binaryen only accepts two naming families:
  - the child block is unnamed, or
  - the child block has the same name as the parent
- Named children get an extra effect barrier through `EffectAnalyzer::invalidates(child)`.
- Binaryen also runs a dedicated same-name shadow hazard prescan before the real walk; if it sees the dangerous descendant-branch family anywhere in the function, it skips merging for that **entire function**.
- After every successful merge, Binaryen reruns `ReFinalize` on the rewritten block so result types stay correct.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: prescan, safety gates, rewrite sequence, and why the file is small only because it leans on branch/effect/type helpers.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shapes for the merges Binaryen performs and the ones it deliberately refuses.

## Current maintenance rule

- Treat this folder as the canonical home for future `merge-blocks` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `merge-blocks` findings should update both the strategy page and the WAT-shape page so the algorithm and its examples stay aligned.

## Sources

- [`../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md`](../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
