---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-dataflow-ir-and-boundaries.md
  - ./wat-shapes.md
  - ../flatten/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals/index.md
  - ../tracker.md
---

# `dataflow-optimization` / `dfo`

## Role

- `dfo` is a real public Binaryen pass.
- Starshine's local removed-name registry currently spells it `dataflow-optimization` in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is currently **unimplemented** in Starshine's active optimizer.
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `dataflow-optimization` / `dfo` slice**.

## Why this pass matters

The original parity queue and the first widened upstream-only queue are already dossier-covered.
So this folder is an explicit tracker expansion for another real local registry pass that still lacked a canonical home.

This pass is worth teaching because its name is misleading.
A beginner may hear `dataflow-optimization` and imagine a huge generic optimizer.
The real `version_129` contract is much smaller:

- run only on already **flat** code
- build a separate **DataFlow SSA IR**
- focus mainly on **integer local traffic**
- collapse identical constant phi inputs
- constant-fold supported expressions whose DataFlow inputs are all constant
- reuse nested `precompute` for actual evaluation
- rely on later ordinary cleanup afterwards

## Beginner summary

A good mental model is:

1. `flatten` turns nested structured code into explicit local traffic.
2. `dfo` converts that flattened code into a small SSA-like graph.
3. It only knows a narrow supported subset well.
4. If it can prove an expression is constant in that graph, it rewrites the flattened wasm to use the constant.
5. Later optimization passes clean up the flattened shape.

So this is best taught as:

- **a flat-IR side-graph constant simplifier**
- not Binaryen's main optimizer
- not generic full-program dataflow
- not a replacement for `flatten`

## Most important durable takeaways

- Upstream public CLI name is `dfo`; local Starshine registry name is `dataflow-optimization`.
- The implementation begins with `Flat::verifyFlatness(func)`, so flat input is a hard precondition.
- The helper IR is a small SSA-like graph with nodes such as `Var`, `Expr`, `Phi`, `Cond`, `Block`, `Zext`, and `Bad`.
- Only **integer** local/value traffic is treated as relevant in the reviewed `version_129` implementation.
- Unsupported instructions usually degrade to unknown `Var` / `Bad` values instead of being optimized directly.
- Loop precision is intentionally cut off: real loop-varying values become fresh unknown vars rather than rich loop phis.
- The actual optimizer logic is small:
  - collapse a phi when all incoming values are the same constant-equivalent node
  - fold an expression when all DataFlow inputs are constant and nested `precompute` reduces it to a `Const`
- The pass explicitly expects ordinary cleanup after flatten-era graph simplification.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: flatness precondition, graph construction, worklist loop, actual rewrite families, and neighboring-pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-surface map for the upstream implementation and the checked current-main drift.
- [`./flat-ir-dataflow-ir-and-boundaries.md`](./flat-ir-dataflow-ir-and-boundaries.md)
  Focused guide to the real teaching problem: Flat IR versus DataFlow IR, integer-local scope, loop precision cutoff, nested `precompute`, and the important bailout families.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog covering the main positive, preserved, and bailout families.

## Current maintenance rule

- Treat this folder as the canonical home for future `dataflow-optimization` / `dfo` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the split from [`../flatten/index.md`](../flatten/index.md) explicit: `flatten` creates the required input shape, while `dfo` consumes it.
- Keep the split from [`../simplify-locals/index.md`](../simplify-locals/index.md) explicit too: `dfo` is a flat-IR side-graph pass, not another locals-sinking variant.

## Sources

- [`../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md`](../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/users.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
  - current-main spot checks:
    - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DataFlowOpts.cpp>
    - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
