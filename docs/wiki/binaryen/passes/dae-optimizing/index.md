---
kind: entity
status: supported
last_reviewed: 2026-05-12
sources:
  - ../../../raw/research/0560-2026-05-12-dae002-call-summary-runtime-attribution.md
  - ../../../raw/research/0559-2026-05-12-dae002-nested-cleanup-scheduler-slice.md
  - ../../../raw/research/0558-2026-05-12-dae-local-declaration-frontier.md
  - ../../../raw/research/0557-2026-05-12-dae-case-000690-escaped-self-operand.md
  - ../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dead-argument-elimination/index.md
  - ../rse/index.md
  - ../local-cse/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `dae-optimizing`

## Role

- `dae-optimizing` is an upstream Binaryen late global optimizing pass.
- It is currently **partially implemented** in Starshine as an active module pass.
- The exact upstream spelling `dae-optimizing` appears in Binaryen, the saved generated-artifact audit, the canonical no-DWARF path, backlog language, and now the local active registry.
- The descriptive local name `dead-argument-elimination-optimizing` remains as an active compatibility alias for the same optimizing module pass; see [`./starshine-strategy.md`](./starshine-strategy.md) for the current scope and remaining parity caveats.
- Binaryen also exposes the related plain pass name `dae`, tracked locally and in the neighboring dossier as `dead-argument-elimination`.
- The `dae-optimizing` variant is the same core dead-argument-elimination engine **plus** a nested cleanup helper that reruns useful function passes on the touched functions.
- A 2026-05-05 current-main freshness layer now keeps the same reading visible in the source archive and adds a dedicated implementation-readiness bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase starts with `dae-optimizing`.
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - top-level slot `48`
- The saved debug log also shows that this pass is much bigger than one top-level name suggests. Inside the log interval between top-level `dae-optimizing` and top-level `inlining-optimizing`, repo-local counting over [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log) finds:
  - `12` nested `ssa-nomerge` executions
  - `24` nested `local-cse` executions
  - `12` nested `code-folding` executions
  - `36` nested `precompute-propagate` executions
- The backlog already tracks this as slice `DAE` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md), with explicit work for call-graph pruning / touched-function tracking and nested `optimizeAfterInlining` replay.
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
- The active Starshine port preserves a still-partial scalar signature subset: direct dead-parameter removal, adjacent self-recursive forwarding, no-param dropped/uncalled result removal, case-000690 escaped-result self-call operand parameter preservation, and dead-suffix cleanup around root `unreachable`; complete result-removal scheduling and broader Binaryen families remain active backlog work.
- The saved 1000-case direct frontier after `1f81bbc7` is not currently showing another semantic/signature candidate: all 13 remaining `gen-valid` mismatches in `.tmp/pass-fuzz-dae-690-final2-1000` have exactly one diff hunk limited to unused local declarations, while the two `wasm-smith` failures are unchanged Binaryen/tool `binaryen-rec-group-zero` parser failures. See [`../../../raw/research/0558-2026-05-12-dae-local-declaration-frontier.md`](../../../raw/research/0558-2026-05-12-dae-local-declaration-frontier.md).
- The nested rerun scheduler behavior is still not complete: Starshine now has a small-module touched-function cleanup scheduler for `dead-code-elimination -> optimize-instructions -> local-cse -> pick-load-signs -> heap-store-optimization -> heap2local -> code-pushing -> simplify-locals -> code-folding -> precompute -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> vacuum`, but it remains a guarded slice rather than Binaryen's full `precompute-propagate` plus default function pipeline. The `local-cse` step uses a function-filtered adapter over the existing raw local-CSE rewrite so public direct `local-cse` remains module-shaped while DAE cleanup touches only DAE-mutated functions, that adapter now emits `pass[local-cse]:func/start/done` trace lines so focused regressions can pin its order before `simplify-locals`, and the DAE scheduler itself now emits `pass[dae-optimizing]:nested-pass name=...` lines so order tests do not depend on incidental raw-skip/start noise; `optimize-instructions`, `pick-load-signs`, `heap-store-optimization`, `heap2local`, `code-pushing`, direct `precompute`, `code-folding`, `merge-blocks`, `remove-unused-brs`, and `remove-unused-names` run through the existing hot touched-function runner.
- The 2026-05-12 DAE002 runtime attribution found the post-scheduler artifact timeout was still inside the DAE core before the nested marker, caused by repeated per-callee module scans in original call and dead-suffix preservation facts. Starshine now uses a single original call summary plus dead-suffix target aggregation, so artifact replay completes again, but DAE remains slower than Binaryen on the debug artifact and the first functional diff is still `defined=11 abs=28`.
- The 2026-05-05 current-main recheck found no teaching-relevant drift from the `version_129` contract and now has a dedicated readiness bridge for the port.
- The local naming decision is no longer open for the optimizing sibling: `dae-optimizing` is canonical and `dead-argument-elimination-optimizing` is a descriptive alias.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main walkthrough of the real `version_129` algorithm: data structures, phases, helper dependencies, safety checks, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file and proof-surface map for `DeadArgumentElimination.cpp`, `pass.cpp`, `opt-utils.h`, DAE helper headers, and the distributed optimizing/shared lit-test family.
- [`./signature-updates-and-nested-reruns.md`](./signature-updates-and-nested-reruns.md)
  Focused guide to the easiest parts of the pass to misunderstand: closed-world boundary checks, parameter and result rewrites, call localization, and why the optimizing helper is part of the real contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and port-planning bridge: exact local registry spelling, request behavior, scheduler gap, backlog slices, code locations, and validation checklist.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Concrete implementation-readiness bridge: registry honesty, no-rewrite analyzer, scalar dead-param deletion, nested cleanup replay, and Binaryen oracle lanes.


## Current maintenance rule

- Treat this folder as the canonical home for future `dae-optimizing` research and port planning.
- Keep it explicitly marked as **partial** until direct compare-pass parity and the full touched-function nested rerun scheduler land.
- Describe `dae-optimizing` as an exact current Starshine registry spelling, but do not claim full Binaryen parity yet.
- New `dae-optimizing` findings should update the strategy page, implementation/test-map page, signature/rerun page, and readiness bridge so the source ownership, boundary algorithm, scheduler story, and implementation checklist stay aligned.
