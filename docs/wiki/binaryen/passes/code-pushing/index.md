---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `code-pushing`

## Role

- `code-pushing` is an upstream Binaryen early function-optimization pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Its real job is narrower than the name suggests: Binaryen uses it to sink a movable **suffix of block-local work** into later control-dependent regions when that is safe and worth the duplication.

## Why it matters

- The canonical Binaryen no-DWARF function pipeline runs `code-pushing` after `precompute` and before `tuple-optimization` plus `simplify-locals-nostructure`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `20`
- The saved Binaryen debug log also shows many repeated nested reruns of `precompute-propagate -> code-pushing -> tuple-optimization`, so this pass is not just a one-off top-level detail.
- The repo backlog already treats it as a real parity blocker under slice `CP` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is also one of the missing scheduler neighbors that still block fully honest public-preset placement for the already-implemented `tuple-optimization` pass.

## Beginner summary

A safe beginner mental model is:

- look for work done in a common prefix
- check whether that work is only really needed after control flow splits
- if the work can move safely and profitably,
- duplicate it into the later branch-local regions and delete the old prefix copy

But two corrections matter immediately:

1. Binaryen does **not** search arbitrary CFG regions.
   - It works on a contiguous suffix of expressions in one block at a time.
2. Binaryen does **not** treat every pure expression as movable.
   - effect ordering, trap sensitivity, result use, and a code-size heuristic all matter.

## Current durable takeaways

- Binaryen `version_129` implements `code-pushing` as a function-parallel **post-walk** pass.
- The pass has two related but different rewrite families:
  1. generic control-flow segment sinking through the `optimizeSegment(...)` path
  2. direct sinking over `if` through the `optimizeIntoIf(...)` path
- The generic family is built around a **contiguous block suffix** plus target segments found by `BranchSeeker`.
- The strict two-arm `if` family is much narrower than the CLI name suggests:
  - no concrete `if` result type
  - no control-flow transfer in the candidate segment
  - no calls / side effects / throws
  - no mutable-global, memory, or table traffic
  - no default-mode trap-sensitive operations
- Binaryen is deliberately more permissive when one `if` arm is already `unreachable`, because then it can sink into the one reachable arm without duplicating into two live paths.
- The pass is heuristic-driven, not correctness-only. `CodePushing.cpp` computes a local `benefit > cost` test before it rewrites.
- `ReFinalize` is part of the rewrite contract after successful motion.
- The shipped tests cover several easy-to-miss subfamilies:
  - generic branchy blocks
  - `if`-specific one-arm and two-arm sinking
  - trap-relaxed option modes
  - GC ref operations
  - EH-sensitive bailout shapes

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: block scanning, contiguous suffix selection, `BranchSeeker`, `Pusher`, the `if` special case, profitability gating, helper dependencies, and scheduler placement.
- [`./segment-selection-and-barriers.md`](./segment-selection-and-barriers.md)
  Focused explanation of the pass’s hidden core: how Binaryen chooses a movable suffix, how invalidation works, why one-arm and two-arm `if` sinking differ, and which effect / trap / EH families stop motion.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.

## Current maintenance rule

- Treat this folder as the canonical home for future `code-pushing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `code-pushing` findings should update both the strategy page and the shape/barrier pages so the algorithm explanation and the example catalog stay aligned.

## Sources

- [`../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md`](../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` effects helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- Binaryen `version_129` lit tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>
