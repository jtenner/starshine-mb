---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./terminating-tails.md
  - ./wat-shapes.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
---

# `code-folding`

## Role

- `code-folding` is an upstream Binaryen late function-cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Its job is not generic CSE. Binaryen uses it to merge identical **tails** of code when multiple paths already reach the same semantic exit.

## Why it matters

- The canonical Binaryen no-DWARF function pipeline runs `code-folding` late, right before `merge-blocks` and the late branch-cleanup cluster.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `38`
- The saved Binaryen debug log also shows repeated nested reruns of the same late cluster under optimizing passes, so `code-folding` is not just a one-off top-level detail.
- The repo backlog already treats it as a real parity blocker under slice `CF` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).

## Beginner summary

A safe beginner mental model is:

- find two or more paths that already end in the same place
- check whether the last few instructions are identical
- if moving that identical suffix to one shared place is still safe,
- keep only one copy of the suffix

Binaryen does that in **two** different families:

1. **expression exits**
   - named block exits
   - `if-else` arms
2. **function-ending terminators**
   - `return`
   - `return_call*`
   - `unreachable`

That split is important. The pass is not one generic “merge any duplicate region” algorithm.

## Current durable takeaways

- Binaryen only records block-exit branch tails when the branch is **unconditional** and is the **last child** of its parent block.
- Unsupported branch forms deliberately poison label-based folding. The source comment and tests both call out `br_on_*` as a current bailout family.
- `if` folding only works on unnamed block arms, or on a one-block/one-non-block case where Binaryen can safely wrap the non-block arm in a synthetic block first.
- Binaryen uses a real movement-safety check before hoisting shared code:
  - branch-target scope must remain valid
  - EH-specific `pop` / `throw` movement hazards must remain valid
- The pass is willing to add helper blocks and helper branches when the size heuristic says the fold is worth it.
- After successful rewrites Binaryen may need EH-specific repair through `EHUtils::handleBlockNestedPops(...)`.
- The pass runs to a per-function **fixpoint** because one fold can expose another.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: candidate collection, movement safety, expression-tail folding, function-ending tail folding, profitability rules, and scheduler placement.
- [`./terminating-tails.md`](./terminating-tails.md)
  Dedicated guide to the easiest part of the pass to misunderstand: how Binaryen folds duplicated `return` / `return_call*` / `unreachable` tails at the end of a function body.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.

## Current maintenance rule

- Treat this folder as the canonical home for future `code-folding` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `code-folding` findings should update both the strategy page and the WAT-shape page so the algorithm explanation and the example catalog stay aligned.

## Sources

- [`../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md`](../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>
