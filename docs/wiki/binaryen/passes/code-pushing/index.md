---
kind: entity
status: working
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `code-pushing`

## Role

- `code-pushing` is an upstream Binaryen early function-optimization pass.
- It now has an initial explicit HOT implementation in Starshine and is no longer a removed registry name in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Its real job is narrower than the name suggests: Binaryen uses it to sink a movable **suffix of block-local work** into later control-dependent regions when that is safe and worth the duplication.

## Why it matters

- The canonical Binaryen no-DWARF function pipeline runs `code-pushing` after `precompute` and before `tuple-optimization` plus `simplify-locals-nostructure`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `20`
- The saved Binaryen debug log also shows many repeated nested reruns of `precompute-propagate -> code-pushing -> tuple-optimization`, so this pass is not just a one-off top-level detail.
- The repo backlog still treats the broader Binaryen-compatible implementation and parity proof as real follow-up work under slice `CP` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It was one of the missing scheduler neighbors for the already-implemented `tuple-optimization` pass; after this initial activation, `simplify-locals-nostructure` and broader `code-pushing` parity proof remain the honest preset blockers.
- The dossier now also has an immutable raw primary-source manifest recording that the reviewed official Binaryen `version_129` release page on 2026-04-22 showed publish date **2026-04-01**, plus a dedicated Starshine status/port-map page tying the upstream story directly to the current local registry, tuple-slot gate, and backlog surfaces.

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

- Starshine now exposes `code-pushing` as an active explicit HOT pass, but the implemented rewrite is a conservative first slice: it replaces a const-like `local.set` root with `nop` and moves a cloned set into the single consuming `if` arm, and bails out on later local reads, multiple writes, else/condition reads, non-void `if`s, and trapping/non-const values.
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
  Deep dive into the actual Binaryen `version_129` implementation: block scanning, contiguous suffix selection, `BranchSeeker`, `Pusher`, the `if` special case, profitability gating, helper dependencies, scheduler placement, and explicit 2026-04-22 release/source provenance.
- [`./segment-selection-and-barriers.md`](./segment-selection-and-barriers.md)
  Focused explanation of the pass’s hidden core: how Binaryen chooses a movable suffix, how invalidation works, why one-arm and two-arm `if` sinking differ, and which effect / trap / EH families stop motion.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine implementation/status map: active HOT owner file, conservative single-consuming-arm local-set movement subset, tuple exact-slot gating, backlog slice `CP`, and the neighboring local pass dossiers the remaining port work must compose with.

## Current maintenance rule

- Treat this folder as the canonical home for future `code-pushing` research and port planning.
- Keep the page explicit that the current Starshine pass is an initial conservative subset, not the full Binaryen `CodePushing.cpp` port.
- New `code-pushing` findings should update both the strategy page and the shape/barrier pages so the algorithm explanation and the example catalog stay aligned.

## Sources

- [`../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md)
- [`../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md`](../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md`](../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
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
