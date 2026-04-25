---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
  - ../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
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
- The folder now also has immutable raw primary-source manifests, a dedicated implementation/test-map page, and a dedicated Starshine status/port-strategy page, so readers no longer need to reconstruct provenance, proof surface, or the local landing zone from older notes.

## Beginner summary

A safe beginner mental model is:

- scan the whole module to learn which helpers are tiny, rooted, recursive, loop-heavy, or still worth keeping,
- pick the reachable **direct** callsites that really pay off,
- sometimes split one narrow top-of-function `if` family first,
- inline the chosen helper bodies,
- delete only the helpers that are now truly dead,
- then rerun cleanup on the functions that changed.

That is much closer to the real Binaryen pass than “inline all small functions.”

## Current durable takeaways

- `inlining-optimizing` is a **module / boundary** pass, not a function-local cleanup pass.
- The pass uses whole-module summaries such as:
  - ref and direct-call counts
  - root/export/start status
  - loop and `try_delegate` flags
  - size heuristics and trivial-wrapper classes
  - no-inline controls and recursive-growth guards
- The implementation has several action families, not one:
  - inline directly and remove the callee when possible
  - inline directly but keep the callee alive
  - partially inline by splitting one of two narrow top-of-function `if` families first
  - do nothing
- In reviewed Binaryen `version_129`, chosen inline actions still come from reachable direct `call` / `return_call` sites. `call_ref` and `call_indirect` remain part of repair and surrounding helper surfaces, not the main chosen-action planner contract.
- The 2026-04-25 current-main implementation/test-map bridge found no teaching-relevant drift from that contract; it adds owner/test-map precision rather than a new strategy correction.
- Imports, roots, `ref.func` uses, tail calls, recursive growth, and `try_delegate` are major bailout or conservatism families.
- The `optimizing` part really matters: Binaryen runs `precompute-propagate` plus the default function optimization pipeline on touched functions after the inline rewrite.
- A future Starshine port must preserve both halves:
  - the whole-module planning and rewrite algorithm
  - the nested rerun scheduler behavior

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: shared-engine split from plain `inlining`, direct-call planning, layered heuristics, partial-inlining shapes, and the filtered `optimizeAfterInlining` rerun contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map for `inlining-optimizing`: shared `Inlining.cpp` owner, `opt-utils.h` optimizing suffix, no-inline policy inputs, official lit proof split, current-main no-drift bridge, and exact Starshine status touchpoints.
- [`./planning-partial-inlining-and-reruns.md`](./planning-partial-inlining-and-reruns.md)
  Focused guide to the easiest parts of the pass to misunderstand: root and escape conservatism, direct-call-only planner scope in `version_129`, partial inlining, and why the optimizing helper is part of the contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, root-survivor, tail-call, recursion, and optimizing-rerun payoff families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and future port map: boundary-only registry tracking, `INL` backlog slice, canonical scheduler slot, nested-rerun dependency story, and the neighboring dossiers a future local port must compose with.

## Current maintenance rule

- Treat this folder as the canonical home for future `inlining-optimizing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary pass plus nested rerun scheduler support.
- New `inlining-optimizing` findings should update the implementation/test-map, strategy, planning/rerun, WAT-shape, and Starshine pages together so the upstream proof surface, planner contract, nested-helper story, and local landing zone stay aligned.

## Sources

- [`../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md)
- [`../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md`](../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md)
- [`../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md`](../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md)
- [`../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
