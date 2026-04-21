---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
related:
  - ./binaryen-strategy.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ../rse/index.md
  - ../local-cse/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `dae-optimizing`

## Role

- `dae-optimizing` is an upstream Binaryen late global optimizing pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Binaryen also exposes the related plain pass name `dead-argument-elimination`.
- The `dae-optimizing` variant is the same core dead-argument-elimination engine **plus** a nested cleanup helper that reruns useful function passes on the touched functions.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase starts with `dae-optimizing`.
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - top-level slot `48`
- The saved debug log also shows that this pass is much bigger than one top-level name suggests. Inside the log interval between top-level `dae-optimizing` and top-level `inlining-optimizing`, repo-local counting over [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log) finds:
  - `12` nested `ssa-nomerge` executions
  - `24` nested `local-cse` executions
  - `12` nested `code-folding` executions
  - `36` nested `precompute-propagate` executions
- The backlog already tracks this as slice `DAE` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is also the first missing pass in the current late boundary-only neighborhood:
  - `dae-optimizing`
  - `inlining-optimizing`
  - `duplicate-function-elimination`
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`

## Beginner summary

A safe beginner mental model is:

- find functions whose boundary still looks closed and direct,
- learn which parameters and results are actually needed,
- sometimes make those types more precise,
- push constant values into the callee,
- delete dead parameters or dead returns,
- then rerun cleanup on the functions that changed.

That is much closer to the real Binaryen pass than “just remove unused arguments.”

## Current durable takeaways

- `dae-optimizing` is a **module / boundary** pass, not a function-local cleanup pass.
- The pass only rewrites boundaries it can still reason about through **direct calls**.
- Exported functions and `ref.func`-escaped functions are treated as having unseen calls, so Binaryen refuses signature-changing rewrites there.
- The implementation can do more than dead-arg deletion:
  - unused-param removal
  - constant actual materialization into the callee
  - GC reference parameter LUB refinement
  - result-type refinement
  - dropped-return elimination
  - call-operand localization before removal when needed
- Tail calls are an important bailout family, especially for return-value removal.
- The `optimizing` part really matters: Binaryen reruns `precompute-propagate` plus the default function optimization pipeline on the touched functions after DAE changes.
- A future Starshine port must preserve both halves:
  - the signature-rewrite algorithm
  - the nested rerun scheduler behavior

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: data structures, phases, helper dependencies, safety checks, and scheduler placement.
- [`./signature-updates-and-nested-reruns.md`](./signature-updates-and-nested-reruns.md)
  Focused guide to the easiest parts of the pass to misunderstand: closed-world boundary checks, parameter and result rewrites, call localization, and why the optimizing helper is part of the contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, negative, bailout, and interaction families.

## Current maintenance rule

- Treat this folder as the canonical home for future `dae-optimizing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary pass plus nested rerun scheduler support.
- New `dae-optimizing` findings should update both the strategy page and the signature/rerun page so the boundary algorithm and the scheduler story stay aligned.

## Sources

- [`../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md`](../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>
