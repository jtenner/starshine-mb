---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-souperify-primary-sources.md
  - ../../../raw/research/0338-2026-04-25-souperify-source-bridge.md
  - ../../../raw/research/0219-2026-04-21-souperify-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../tracker.md
  - ../index.md
  - ../../../../../agent-todo.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../dataflow-optimization/index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-dataflow-traces-and-single-use-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../dataflow-optimization/index.md
---

# `souperify`

## Role

- `souperify` is a real public upstream Binaryen pass in `version_129`.
- It has a public sibling, `souperify-single-use`.
- In this repo it is currently **upstream-only**.
- It is **not** in the local Starshine pass registry, not even as a boundary-only or removed name.
- In current Starshine an explicit request is therefore an **unknown pass**.
- It is **not** part of the current canonical no-DWARF `-O` / `-Os` path.
- It does **not** appear in the saved generated-artifact `-O4z` skipped-slot queue.
- `agent-todo.md` currently has **no dedicated `souperify` slice**.

So this folder is an explicit tracker expansion, not a hidden implementation backlog.

## Why this folder exists

The tracker no longer had an obvious remaining `none` target.
So this dossier is an explicit tracker expansion.

`souperify` deserved a canonical home because:

- the existing [`../flatten/index.md`](../flatten/index.md), [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md), and [`../dataflow-optimization/index.md`](../dataflow-optimization/index.md) folders already depend on teaching where Souper extraction fits,
- but the tracker and pass map did not yet give `souperify` its own canonical page,
- and the real `version_129` contract is different enough from ordinary optimization passes that leaving it as a side mention makes neighboring docs harder to trust.

The 2026-04-25 source bridge added an immutable raw Binaryen manifest and a Starshine status page, so the folder now has the full source-to-local chain rather than only the earlier direct-URL research note.

## Beginner summary

A good beginner mental model is:

- require already-flattened code,
- build Binaryen's small DataFlow IR plus a `LocalGraph`,
- pick a traceable integer expression,
- walk backward through a bounded slice of its dependencies,
- optionally add `if`-based path conditions,
- then print that slice as Souper text.

So `souperify` is **not** a normal rewrite pass.
It is an extraction / instrumentation pass.

The sibling `souperify-single-use` uses the same engine, but it truncates multi-use child slices to fresh unknown `var`s.

## Main durable takeaways

- The pass is a real public pass family registered in `pass.cpp` as:
  - `souperify`
  - `souperify-single-use`
- It hard-requires `Flat::verifyFlatness(func)` before doing anything else.
- It builds Binaryen's DataFlow IR, not Souper text directly from AST nesting.
- The main internal node kinds are:
  - `Var`
  - `Expr`
  - `Phi`
  - `Cond`
  - `Block`
  - `Zext`
  - `Bad`
- It uses `LocalGraph` influence data to find real uses and external escapes.
- Trace extraction is bounded by:
  - depth limit `10`
  - total node limit `30`
  - with env-var overrides for both
- When slices get too deep, too large, or hit excluded children, the pass replaces subtrees with fresh `Var`s.
- The printed opcode surface is intentionally narrow:
  - selected integer unary ops,
  - selected integer binary ops,
  - and `select`.
- Path conditions are real, but currently only sourced from `if` structure.
- Loop-carried values are intentionally cut off instead of building real loop phis.

## Why it matters next to nearby passes

This dossier keeps four splits explicit:

- unlike [`../flatten/index.md`](../flatten/index.md), `souperify` does not create flat IR; it requires it,
- unlike [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md), it is not a cleanup pass; it is a trace emitter,
- unlike [`../dataflow-optimization/index.md`](../dataflow-optimization/index.md), it prints DataFlow IR instead of rewriting Binaryen IR,
- unlike ordinary optimization passes, it is primarily output / instrumentation rather than transformation.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main walkthrough of the real `version_129` algorithm, pass boundaries, and nearby-pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map for the upstream implementation and public proof surface.
- [`./flat-dataflow-traces-and-single-use-boundaries.md`](./flat-dataflow-traces-and-single-use-boundaries.md)
  Focused guide to the hard part to misread: flatness, DataFlow nodes, bounded trace growth, use discovery, path conditions, and the exact sibling split.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after input-shape catalog for the main positive, preserved, and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: unknown-pass local behavior, exact registry / dispatcher / CLI / HOT-analysis prerequisite code locations, and the output-contract work a faithful trace-emission port would need.

## Current maintenance rule

- Treat this folder as the canonical home for future `souperify` research.
- Keep it explicitly marked as **upstream-only** unless Starshine ever adopts it.
- Keep the split from nearby passes explicit:
  - this is not `flatten`,
  - not `simplify-locals-nonesting`,
  - and not `dataflow-optimization`.

## Sources

- [`../../../raw/binaryen/2026-04-25-souperify-primary-sources.md`](../../../raw/binaryen/2026-04-25-souperify-primary-sources.md)
- [`../../../raw/research/0338-2026-04-25-souperify-source-bridge.md`](../../../raw/research/0338-2026-04-25-souperify-source-bridge.md)
- [`../../../raw/research/0219-2026-04-21-souperify-binaryen-research.md`](../../../raw/research/0219-2026-04-21-souperify-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Neighboring local docs:
  - [`../flatten/index.md`](../flatten/index.md)
  - [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md)
  - [`../dataflow-optimization/index.md`](../dataflow-optimization/index.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Souperify.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
  - current-main spot checks:
    - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Souperify.cpp>
    - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
    - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
