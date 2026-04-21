---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./effects-loops-and-hoisting-rules.md
  - ./wat-shapes.md
  - ../tracker.md
---

# `loop-invariant-code-motion`

## Role

- `loop-invariant-code-motion` is a real Binaryen pass, but the upstream public pass name is the shorter alias **`licm`**.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **removed** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is also still listed in the local Batch 3 pass-port map in [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.

## Why this pass matters

- The original parity queue and the first tracker-expansion wave are already dossier-covered, so this folder is an explicit source-backed expansion for another real local removed-registry entry.
- `agent-todo.md` currently has **no dedicated `loop-invariant-code-motion` or `licm` slice**.
- The local full name hides the upstream public alias, which makes the pass harder to find in official Binaryen docs and tests.
- The pass sits close to already-documented neighbors like `code-pushing`, `precompute`, `local-cse`, and `simplify-locals`, so a future port will benefit from having its movement rules taught separately instead of smearing them across those folders.

## Beginner summary

A good beginner mental model is:

- if a loop keeps recomputing a value
- and that value depends only on inputs that do not change across iterations
- and computing it earlier would not change effects or trap timing
- Binaryen may compute it once before the loop and store it in a temp local

So this pass is best taught as:

- **conservative loop-header hoisting with helper locals**
- not generic code motion
- not constant folding
- and not generic local CSE

## Most important durable takeaways

- The reviewed implementation is a whole-function fixed-point pass centered on loops.
- The upstream public name is `licm`, while the local registry keeps the full descriptive name `loop-invariant-code-motion`.
- The real safety contract is **loop invariant + effect-safe + child-hoistable**, not just “pure expression.”
- Hoisted expressions are materialized with fresh temp locals before the loop.
- The pass reruns because hoisting one child can make its parent hoistable later.
- Calls, memory-sensitive loads, trap-timing changes, and control-structure nodes are important bailout families.
- A current-main spot check found the same public pass registration and materially the same implementation structure as `version_129` on the main pass file.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation, algorithmic phases, helper dependencies, and pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./effects-loops-and-hoisting-rules.md`](./effects-loops-and-hoisting-rules.md)
  Focused guide to the real proof obligation: loop membership, effect safety, trap timing, child hoistability, and helper-local insertion.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, mixed, and bailout WAT families.

## Current maintenance rule

- Treat this folder as the canonical home for future `loop-invariant-code-motion` / `licm` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real active pass for it.
- Keep the scheduler fact explicit too: this is a real public Binaryen pass, but it is outside the current no-DWARF default optimize path.
- Keep the naming fact explicit too: upstream docs and tests say `licm`, while the local registry currently says `loop-invariant-code-motion`.

## Sources

- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` and current-main sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/parents.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
