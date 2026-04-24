---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
  - ../inlining-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `simplify-globals-optimizing`

## Role

- `simplify-globals-optimizing` is an upstream Binaryen late global optimizing pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). The exact local status and future-port map now live in [`./starshine-strategy.md`](./starshine-strategy.md).
- Binaryen also exposes the related plain pass name `simplify-globals`.
- The `simplify-globals-optimizing` variant is the same core global pass **plus** a nested rerun of the default function optimization pipeline on changed functions.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `simplify-globals-optimizing` after `duplicate-import-elimination` and before `remove-unused-module-elements`.
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - top-level slot `52`
- The saved debug log also shows that this pass is bigger than one top-level name suggests. Between top-level `simplify-globals-optimizing` and the next top-level `remove-unused-module-elements`, repo-local counting over [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log) finds:
  - `3` nested pass batches
- The backlog already tracks this as slice `SGO` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is also the remaining late boundary/global cleanup dossier nearest the freshly documented late neighbors:
  - `dae-optimizing`
  - `inlining-optimizing`
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
  - `string-gathering`
  - `reorder-globals`

## Beginner summary

A safe beginner mental model is:

- scan the whole module to learn which globals are really observed,
- fold single-use globals into later global initializers when that is still one-time work,
- remove writes whose value never matters,
- canonicalize immutable copy chains,
- propagate known values through later global initializers and segment offsets,
- propagate known values through function code only when the current runtime trace is still simple,
- then rerun normal function cleanup on the functions that changed.

That is much closer to the real Binaryen pass than “replace constant `global.get`s.”

## Current durable takeaways

- The reviewed official Binaryen `version_129` release page on 2026-04-24 showed publish date **2026-04-01**, and the new raw manifest in [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md) records the exact source and lit-test URLs checked for this folder.
- `simplify-globals-optimizing` is a **module / boundary** pass, not a function-local peephole.
- The pass has several distinct algorithm families, not one:
  - practical-immutability discovery
  - single-use global-init folding
  - dead or redundant `global.set` removal
  - `read-only-to-write` elimination
  - immutable copy-chain canonicalization
  - startup-time constant propagation into later globals and offsets
  - runtime constant propagation into function code with a cheap linear-trace model
- The `optimizing` part really matters: Binaryen reruns the default function optimization pipeline on changed functions after constant replacement or removed writes.
- That nested rerun is **not** the same helper used by `dae-optimizing` and `inlining-optimizing`:
  - it does **not** prepend `precompute-propagate`
  - it reruns per changed function through a nested `PassRunner`
- Imports, exports, actual calls, nonlinear control flow, and type mismatches are major bailout or conservatism families.
- A future Starshine port must preserve both halves:
  - the multi-phase global rewrite algorithm
  - the no-extra-`precompute-propagate` nested rerun behavior of the optimizing variant
- Current Starshine tracks the pass as boundary-only, rejects explicit requests honestly, and has `SGO` backlog slices, but it has no owner file, no global-use fact table, and no nested-rerun scheduler yet.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: phases, helper dependencies, scheduler placement, safety rules, and nested-rerun behavior.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file, helper, and lit-test map for the shared `SimplifyGlobals.cpp` family and the optimizing-specific nested-rerun wrapper.
- [`./linear-traces-read-only-to-write-and-reruns.md`](./linear-traces-read-only-to-write-and-reruns.md)
  Focused guide to the easiest parts of the pass to misunderstand: startup versus runtime propagation, the exact `read-only-to-write` matcher, actual-node versus effect-summary conservatism, and the optimizing rerun contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: boundary-only registry tracking, honest request rejection, missing owner code, `SGO` backlog slices, and the exact neighboring late-tail pass dossiers to compose with.

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-globals-optimizing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real late boundary/global pass plus the correct nested rerun scheduler behavior.
- New `simplify-globals-optimizing` findings should update both the strategy page and the linear-trace / read-only-to-write page so the global algorithm story and the scheduler story stay aligned.

## Sources

- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
