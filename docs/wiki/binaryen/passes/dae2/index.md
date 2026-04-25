---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-dae2-primary-sources.md
  - ../../../raw/research/0337-2026-04-25-dae2-source-bridge.md
  - ../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./fixed-point-forwarding-type-trees-and-expression-removal.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/index.md
  - ../dae-optimizing/index.md
  - ../tracker.md
---

# `dae2`

## Role

- `dae2` is an upstream Binaryen pass.
- It is registered publicly in Binaryen `version_129` as `dae2`.
- It is currently **upstream-only** in this repo:
  - not on the local no-DWARF default optimize path,
  - not in the saved generated-artifact `-O4z` skipped-slot queue,
  - and not named in the local Starshine pass registry.
- Upstream describes it as an **experimental reimplementation of DAE**.
- As of the 2026-04-25 source bridge, this folder is anchored to an immutable raw primary-source manifest and a dedicated Starshine status page: [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md), [`./starshine-strategy.md`](./starshine-strategy.md).

## Why this folder exists

The tracker no longer had an obvious remaining `none` target.
So this dossier is an explicit tracker expansion.

`dae2` deserved a canonical home because:

- the existing plain-`dae` dossier already had to warn that `dae2.wast` is **not** the oracle for normal DAE,
- the pass is a real public upstream name rather than an internal experiment,
- and the design is different enough from both `dead-argument-elimination` and `dae-optimizing` that keeping it only as a footnote would make the neighboring docs harder to trust.

`agent-todo.md` currently has **no dedicated `dae2` slice**.
That is expected: this is upstream-only research, not a current Starshine implementation task.

## Beginner summary

A good beginner mental model is:

- mark parameters that are truly used,
- also notice parameters that are only **forwarded** into other calls,
- propagate “used” backward through those forwarding edges until a fixed point,
- then delete the dead params and matching arguments,
- and, when Binaryen is allowed to rewrite referenced function types, also repair the relevant function-type trees globally.

That makes `dae2` feel more like:

- call-graph and function-type-tree analysis,

than like:

- plain direct-call boundary cleanup.

## Current durable takeaways

- `dae2` is **not** just plain `dae` with different scheduling.
- It is built around a **smallest fixed-point backward analysis** of used parameters and forwarded parameters.
- The pass understands:
  - direct calls,
  - `call_ref`,
  - and `call_indirect` through root function-type trees.
- It can optimize parameter-forwarding cycles away when nothing outside the cycle uses them.
- It has a major mode split:
  - without `--closed-world` + GC, it mainly optimizes unreferenced functions;
  - with `--closed-world` + GC, it can also rewrite referenced function types globally.
- It is still openly incomplete compared with plain `dae`:
  - no dropped-return elimination yet,
  - no result optimization yet,
  - no constant actual propagation yet,
  - no param/result type propagation yet.
- Public types, continuation/tag-related roots, `call.without.effects`, and several other referenced surfaces remain important conservative boundaries.

## Why it matters next to `dae`

The neighboring `dead-argument-elimination` and `dae-optimizing` dossiers teach:

- direct-call ownership,
- iterative localization,
- constant actuals,
- dropped-return cleanup,
- and the optimizing rerun contract.

`dae2` teaches a different set of ideas:

- fixed-point forwarding,
- indirect/reference-call participation,
- referenced-vs-unreferenced function-type handling,
- replacement types,
- and expression-tree removal that preserves effect/control structure.

So this folder should stay separate instead of being collapsed into the plain-`dae` pages.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main walkthrough of the real `version_129` algorithm: graph building, blockers, fixed point, optimization phases, and the exact split from plain `dae`.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File map for `DeadArgumentElimination2.cpp`, `pass.cpp`, and the main helper/test surfaces.
- [`./fixed-point-forwarding-type-trees-and-expression-removal.md`](./fixed-point-forwarding-type-trees-and-expression-removal.md)
  Focused guide to the hardest part of the pass: forwarding edges, reverse-graph propagation, referenced function-type trees, replacement types, and removal boundaries.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, and corner-case IR families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: unknown-pass registry behavior, no owner/dispatcher/backlog status, prerequisite function/type/call/reference surfaces, and why full parity requires module/type-graph infrastructure.

## Current maintenance rule

- Treat this folder as the canonical home for future `dae2` research.
- Keep it explicitly marked as **upstream-only** unless Starshine ever decides to track or port it.
- Keep the contrast with [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md) and [`../dae-optimizing/index.md`](../dae-optimizing/index.md) explicit.

## Sources

- [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md)
- [`../../../raw/research/0337-2026-04-25-dae2-source-bridge.md`](../../../raw/research/0337-2026-04-25-dae2-source-bridge.md)
- [`../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md`](../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination2.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast>
