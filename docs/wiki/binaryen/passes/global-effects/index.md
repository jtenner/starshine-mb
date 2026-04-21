---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./metadata-naming-and-consumers.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
  - ../tracker.md
---

# `global-effects` / upstream `generate-global-effects`

## Role

- `global-effects` is the local Starshine registry name for the upstream Binaryen pass published as `generate-global-effects`.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is a real public upstream pass in Binaryen `version_129`, but it is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` default top-level path.
- Its job is to compute per-function global-effect summaries that later passes can consult across calls.

## Why this pass matters

- The main parity queue and first expansion queue are already dossier-covered, so this folder is an explicit source-backed tracker expansion for another real local registry entry.
- `agent-todo.md` currently has **no dedicated `global-effects` slice**.
- The pass already matters in neighboring living docs:
  - `simplify-locals` uses generated global-effect summaries to distinguish call readers from call writers.
  - `vacuum` can remove more unused calls after those summaries exist.
- The pass is easy to underestimate because it does not rewrite WAT directly, but downstream optimizer behavior can still change materially when the metadata is present or absent.

## Beginner summary

A good beginner mental model is:

- Binaryen first asks “what globals does each function itself read or write?”
- then it keeps propagating that information backward through call chains
- and finally later passes use those stored summaries when deciding whether calls are barriers or removable

So the pass is best taught as:

- **metadata-producing interprocedural global-effect analysis**
- not as a direct code-rewriting optimizer

## Most important durable takeaways

- The official upstream public name is `generate-global-effects`.
- The local Starshine registry currently shortens that to `global-effects`.
- Binaryen `version_129` does **not** schedule this in the default optimize pipeline.
- The pass computes shallow per-function summaries first, then runs a reverse-call-graph fixed point.
- The result is stored in `Function.effects` metadata.
- Later `EffectAnalyzer` queries on `Call` can consult those stored summaries.
- The pass therefore changes later optimizer precision without directly rewriting the current function's WAT.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation, scheduler placement, helper dependencies, and fixed-point algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./metadata-naming-and-consumers.md`](./metadata-naming-and-consumers.md)
  Focused guide to the easy-to-misread part: local-vs-upstream naming, metadata-only behavior, invalidation, and downstream consumers.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing which call/global patterns gain precision, which stay conservative, and why the WAT often stays textually unchanged.

## Current maintenance rule

- Treat this folder as the canonical home for future `global-effects` / `generate-global-effects` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the naming split explicit:
  - local registry: `global-effects`
  - upstream public pass: `generate-global-effects`
- Keep the scheduler fact explicit too: this is a real pass, but not part of the current no-DWARF default optimize path.

## Sources

- [`../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md`](../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../simplify-locals/index.md`](../simplify-locals/index.md)
- [`../vacuum/index.md`](../vacuum/index.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
