---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
related:
  - ./binaryen-strategy.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ../dae-optimizing/index.md
  - ../duplicate-function-elimination/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `inlining-optimizing`

## Role

- `inlining-optimizing` is an upstream Binaryen late global optimizing pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Binaryen also exposes the related plain pass name `inlining`.
- The `inlining-optimizing` variant is the same core inliner **plus** the nested cleanup helper that reruns `precompute-propagate` and the default function optimization pipeline on touched functions.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `inlining-optimizing` immediately after `dae-optimizing`.
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - top-level slot `49`
- The saved debug log shows that this pass is much bigger than one top-level name suggests. Between top-level `inlining-optimizing` and the next top-level `duplicate-function-elimination`, repo-local counting over [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log) finds:
  - `5` nested `ssa-nomerge` executions
  - `5` nested `code-folding` executions
  - `10` nested `local-cse` executions
  - `15` nested `precompute-propagate` executions
- The backlog already tracks this as slice `INL` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is also the next missing pass in the current late boundary-only neighborhood:
  - `dae-optimizing`
  - `inlining-optimizing`
  - `duplicate-function-elimination`
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`

## Beginner summary

A safe beginner mental model is:

- scan the whole module to learn which helpers are tiny, rooted, escaping, recursive, or still worth keeping,
- pick the direct or ref-based callsites that really pay off,
- sometimes split one conditional region out into a helper first,
- inline the chosen helper bodies,
- delete only the helpers that are now truly dead,
- then rerun cleanup on the functions that changed.

That is much closer to the real Binaryen pass than “inline all small functions.”

## Current durable takeaways

- `inlining-optimizing` is a **module / boundary** pass, not a function-local cleanup pass.
- The pass uses whole-module summaries such as:
  - call counts
  - root/export/start status
  - escaping or uninlineable uses
  - loop, tail-call, and `try_delegate` flags
  - estimated size from `CostAnalyzer`
- The implementation has several action families, not one:
  - inline directly and remove the callee when possible
  - inline directly but keep the callee alive
  - partially inline by splitting a structured region first
  - do nothing
- Some `call_ref` and `return_call_ref` sites are eligible when `PossibleContents` can prove a precise enough internal target set.
- Imports, roots, escaping references, tail calls, recursive growth, and `try_delegate` are major bailout or conservatism families.
- The `optimizing` part really matters: Binaryen runs `precompute-propagate` plus the default function optimization pipeline on touched functions after the inline rewrite.
- A future Starshine port must preserve both halves:
  - the whole-module planning and rewrite algorithm
  - the nested rerun scheduler behavior

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: data structures, phases, helper dependencies, safety checks, and scheduler placement.
- [`./planning-partial-inlining-and-reruns.md`](./planning-partial-inlining-and-reruns.md)
  Focused guide to the easiest parts of the pass to misunderstand: root and escape conservatism, size heuristics, partial inlining, ref-based callsites, and why the optimizing helper is part of the contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, negative, bailout, and interaction families.

## Current maintenance rule

- Treat this folder as the canonical home for future `inlining-optimizing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary pass plus nested rerun scheduler support.
- New `inlining-optimizing` findings should update both the strategy page and the planning/rerun page so the module-planning story and the scheduler story stay aligned.

## Sources

- [`../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md`](../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/FunctionSplitter.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining.wast>
