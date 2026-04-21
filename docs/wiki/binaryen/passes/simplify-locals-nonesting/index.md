---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../simplify-locals/index.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
  - ../flatten/index.md
  - ../dataflow-optimization/index.md
  - ../tracker.md
---

# `simplify-locals-nonesting`

## Role

- `simplify-locals-nonesting` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **removed** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) under the alias `simplify-locals-no-nesting`.
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `simplify-locals-nonesting` or `simplify-locals-no-nesting` slice**.
- Official Binaryen `pass.cpp` describes it as a locals pass with **no nesting at all** that **preserves flatness**.

## Why this pass matters

The main no-DWARF queue, the saved `-O4z` queue, and the first widened upstream-only wave are already dossier-covered.
So this folder is a deliberate second-wave expansion for a real local registry pass that still lacked a canonical landing page.

This pass is worth teaching because it is easy to mis-handle in three different ways:

- silently collapse it into `simplify-locals-notee-nostructure`
- silently collapse it into `flatten`
- dismiss it as an implementation flag instead of a real public pass

The source-backed correction is:

- this is a public `SimplifyLocals` family variant with exact identity `SimplifyLocals<false, false, false>`
- it still performs real locals cleanup
- but it preserves flatness by refusing any sink that would create new nesting

## Main beginner correction

The easy wrong summary is:

- "`simplify-locals-nonesting` just means no tee and no structure."

The source-backed summary is:

- Binaryen builds this pass from the same shared locals engine as the rest of the family
- its exact identity is `SimplifyLocals<false, false, false>`
- so it forbids:
  - new tees
  - new structure
  - new nesting
- but it still allows:
  - flat copy-chain cleanup
  - equivalent-local canonicalization
  - dead-set cleanup
  - limited flat sinking that stays in set-value positions

So `-nonesting` is **not**:

- just `-notee-nostructure` with different wording
- just `flatten`
- a no-op cleanup pass

## Why the dedicated folder was needed

The existing `simplify-locals` family docs already mentioned the nonesting variant.
That was not enough.
A dedicated folder was still justified because:

- the local registry tracks it as its own pass name
- upstream Binaryen registers it as its own public pass name
- it has its own dedicated pass test pair
- multiple neighboring dossiers (`flatten`, `dfo`, `simplify-locals-notee-nostructure`) depend on understanding its exact flatness contract

## Most important durable takeaways

- `simplify-locals-nonesting` is a **real public Binaryen pass**, not a hidden test mode.
- Its exact implementation identity is:
  - `allowTee = false`
  - `allowStructure = false`
  - `allowNesting = false`
- It still shares the same multi-cycle `SimplifyLocals` engine, the late `EquivalentOptimizer`, and the final `UnneededSetRemover` cleanup.
- Its defining promise is stricter than the other reduced variants:
  - it preserves flatness by rejecting sinks that would create new expression nesting.
- It is an important aggressive-pipeline neighbor:
  - official combo tests use `flatten -> simplify-locals-nonesting -> dfo`
  - and similar pre-analysis pipelines before `souperify`
- The local Starshine alias `simplify-locals-no-nesting` should stay explicit instead of being silently treated as the upstream name.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: the shared `SimplifyLocals` engine, the nonesting gate in `optimizeLocalGet(...)`, the remaining late cleanup phases, and the real pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./flatness-variant-boundaries.md`](./flatness-variant-boundaries.md)
  Focused guide to the hardest part to misread: what “preserves flatness” really means, how this differs from `-notee-nostructure`, and why it is not the same thing as `flatten`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, preserved, and bailout families.

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-locals-nonesting` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the alias split explicit:
  - upstream Binaryen: `simplify-locals-nonesting`
  - local registry: `simplify-locals-no-nesting`
- Keep the biggest correction explicit:
  - this variant is stricter than `simplify-locals-notee-nostructure` because it also forbids new nesting.

## Sources

- [`../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md`](../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../simplify-locals/index.md`](../simplify-locals/index.md)
- [`../simplify-locals/variant-matrix-and-scheduler.md`](../simplify-locals/variant-matrix-and-scheduler.md)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
