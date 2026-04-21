---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../tracker.md
related:
  - ../monomorphize/index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./usefulness-gate-and-sibling-split.md
  - ./wat-shapes.md
  - ../tracker.md
---

# `monomorphize-always`

## Role

- `monomorphize-always` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `monomorphize-always` slice**.
- It is the official public sibling of [`../monomorphize/index.md`](../monomorphize/index.md), not a different specialization algorithm.

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered, so this folder is an explicit tracker expansion for another real local-registry pass.
- The local registry still exposes `monomorphize-always` as its own boundary-only name, but before this thread there was no dedicated landing folder explaining why that sibling exists.
- It is easy to blur this pass into either:
  - ordinary `monomorphize`
  - or just `--pass-arg=monomorphize-min-benefit@0`
- The real teaching boundary is simpler and stronger: Binaryen publishes `monomorphize-always` as the sibling that keeps legal nontrivial specializations even when the default measured-benefit policy would reject them.

## Beginner summary

A good beginner mental model is:

- Binaryen sees a direct call that tells it something extra about a callee
- it builds a specialized clone using the same context machinery as ordinary `monomorphize`
- but instead of asking “did this help enough?” it asks only “was this legal and nontrivial?”
- if yes, it keeps the specialized clone

So this pass is best taught as:

- **contextual specialization without the normal usefulness gate**
- not a separate cloning algorithm
- not ordinary inlining
- not "specialize literally everything"

## Most important durable takeaways

- The pass shares the same core `Monomorphize.cpp` engine as ordinary `monomorphize`.
- The same legality boundaries still apply:
  - direct calls only
  - no imported or recursive self-calls
  - no trivial passthrough contexts
  - no illegal effect/order movement
  - no over-budget specialized signatures
- The main public split is policy, not mechanics:
  - `monomorphize` = usefulness-gated
  - `monomorphize-always` = keep legal nontrivial specializations even when the measured payoff is too weak for the default pass
- The official lit family uses this sibling to expose weak-benefit but still-real specialization shapes, especially in refined-reference and type-driven cases.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation structure and the exact split from ordinary `monomorphize`.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the sibling's contract.
- [`./usefulness-gate-and-sibling-split.md`](./usefulness-gate-and-sibling-split.md)
  Focused guide to what the sibling removes, what it keeps, and why it is not just an alias for careless specialization.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, mixed, and bailout WAT families.

## Current maintenance rule

- Treat this folder as the canonical home for future `monomorphize-always` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from [`../monomorphize/index.md`](../monomorphize/index.md) explicit: the default pass measures usefulness, while this sibling keeps legal nontrivial specializations without that extra rejection step.
- Keep the split from ordinary `inlining` explicit too: `monomorphize*` clones the callee and pulls caller context inward.

## Sources

- [`../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md`](../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- [`../monomorphize/index.md`](../monomorphize/index.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
