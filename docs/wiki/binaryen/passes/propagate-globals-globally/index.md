---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
  - ../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
  - ../string-gathering/index.md
  - ../tracker.md
---

# `propagate-globals-globally`

## Role

- `propagate-globals-globally` is a real public Binaryen module pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path and it does **not** appear in the saved generated-artifact `-O4z` skip queue.
- This folder is therefore an explicit upstream-only registry dossier.

## Why this folder still mattered

The first dossier for this pass got the broad startup-only idea right, but it left one major source-structure gap open:

- it treated the pass as if it lived in a standalone `PropagateGlobals.cpp`
- the real `version_129` implementation lives inside **`src/passes/SimplifyGlobals.cpp`**
- `propagate-globals-globally` is therefore best understood as a **shared-engine sibling** of `simplify-globals*`, not merely as a vaguely related neighboring pass

`agent-todo.md` still has **no dedicated `propagate-globals-globally` slice**.

## Beginner summary

A good beginner mental model is:

- Binaryen learns which startup global expressions are already known
- it substitutes those known expressions into other startup-safe module expressions
- it rewrites defined global initializers and active data/elem offsets
- then it stops before ordinary function-body propagation begins

So this pass is best taught as:

- **startup-only shared-engine mode of the simplify-globals family**
- not generic whole-program propagation
- not dead global cleanup
- not the full `simplify-globals` or `simplify-globals-optimizing` pass

## Most important durable takeaways

- The reviewed implementation is in **`src/passes/SimplifyGlobals.cpp`**, not a standalone `PropagateGlobals.cpp`.
- Public registration in `pass.cpp` constructs the same `PropagateGlobals` engine with **`optimize = false`**.
- The pass accepts a curated startup-safe expression subset, not arbitrary IR.
- It tracks **known startup expressions**, not only direct scalar constants.
- It rewrites **defined globals plus active data/elem offsets**.
- It deliberately does **not** walk ordinary function bodies in this public mode.
- A current-main spot check found the same shared-engine family structure still in place on the reviewed surfaces.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract: the shared `SimplifyGlobals.cpp` engine, the `optimize` gate, the module-only rewrite surface, and the pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract, including the correction from the earlier wrong standalone-file claim.
- [`./shared-engine-and-startup-boundaries.md`](./shared-engine-and-startup-boundaries.md)
  Focused guide to the easiest thing to misunderstand: how the shared `PropagateGlobals` engine splits startup-only `propagate-globals-globally` from broader `simplify-globals*`, and what the startup-safe expression subset actually contains.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog for direct and expression-chain global propagation, active data/elem offsets, string startup expressions, and the major bailout families.

## Current maintenance rule

- Treat this folder as the canonical home for future `propagate-globals-globally` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from [`../simplify-globals/index.md`](../simplify-globals/index.md) and [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md) explicit.
- Also keep the shared-engine fact explicit: this is a separate public pass mode, but not a separate algorithm file.

## Sources

- [`../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md`](../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md)
- [`../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md`](../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` and current-main sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>
