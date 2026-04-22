---
kind: entity
status: working
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./basic-block-windows-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `local-cse`

## Role

- `local-cse` is an upstream Binaryen local-cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Despite the name, Binaryen `version_129` does **not** use it as a whole-function or CFG-wide common-subexpression pass.
- The real job is narrower: find repeated whole expression trees inside one local execution window, save the first result in a fresh temp local, and reuse that value later with `local.get`.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `local-cse` in the late local-cleanup cluster:
  - after `coalesce-locals`
  - before full `simplify-locals`
- The saved generated-artifact `-O4z` audit records two real skipped top-level upstream slots:
  - top-level slot `11`
  - top-level slot `31`
- Slot `11` matters because it captures the extra aggressive upstream prelude:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- The saved Binaryen debug log shows `36` `local-cse` executions in one full `-O4z` run, which means the pass is also part of the nested optimizing-rerun story, not just the obvious top-level slots.
- The repo backlog already treats it as a real parity blocker under slice `LCSE` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It also sits between several already-documented neighbors whose behavior is easier to understand once `local-cse` is documented clearly:
  - `simplify-locals-notee-nostructure`
  - `coalesce-locals`
  - `simplify-locals`
  - late `rse`

## Beginner summary

A safe beginner mental model is:

- look for the **same whole tree** twice,
- keep the first computation,
- store it in a temp local,
- replace later repeats with `local.get`,
- but only when effects and nondeterminism say that reuse is still safe.

That is smaller and more local than “Binaryen does generic CSE here.”

## Current durable takeaways

- The reviewed official Binaryen `version_129` release page rechecked on 2026-04-22 showed publish date **2026-04-01**, and the dossier now has an immutable raw primary-source manifest at [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md).
- A narrow 2026-04-22 current-`main` spot check on `LocalCSE.cpp`, `pass.cpp`, `opt-utils.h`, and `local-cse.wast` did not surface a new teaching-relevant drift beyond the existing living Binaryen pages.
- The pass really is a three-stage algorithm:
  - `scan`
  - `check`
  - `apply`
- It reuses only **whole repeated trees**, not arbitrary shared subtrees.
- Parent repeats can cancel child-level reuse requests, so the pass prefers to reuse the bigger matching tree when it can.
- It is mostly window-local, but the `LinearExecutionWalker` helper lets some cheap adjacent dominated cases count too, such as before-`if` into the `then` arm.
- Repeated loads may optimize even though loads can trap; ordinary repeated calls do not.
- Calls to functions annotated idempotent are a narrow source-level exception.
- Constants and tiny size-1 roots like `global.get` are intentionally left alone.
- The early `-O4` slot depends on `flatten` plus a little simplify-locals cleanup to expose more identical whole trees.
- The pass adds locals, so Binaryen marks it as DWARF-invalidating.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: data structures, scan/check/apply phases, helper dependencies, profitability rules, and scheduler placement.
- [`./basic-block-windows-and-barriers.md`](./basic-block-windows-and-barriers.md)
  Focused guide to the easiest parts of the pass to misunderstand: what “inside basic blocks” really means here, which control-flow boundaries reset the window, and why effects, traps, generativity, and idempotent calls matter.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Dedicated Starshine status/port map for this still-unimplemented pass: exact registry/backlog/scheduler surfaces, concrete neighboring MoonBit files and test lanes, and the main honesty rule that preset placement should stay blocked until the missing Binaryen-neighbor equivalents land locally.

## Current maintenance rule

- Treat this folder as the canonical home for future `local-cse` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `local-cse` findings should update both the strategy page and the windows/barriers page so the algorithm explanation and the control-flow safety story stay aligned.

## Sources

- [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md)
- [`../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md`](../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md)
- [`../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md`](../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>
