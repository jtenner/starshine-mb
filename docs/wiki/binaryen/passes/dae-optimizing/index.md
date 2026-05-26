---
kind: entity
status: supported
last_reviewed: 2026-05-26
sources:
  - ../../../raw/research/0591-2026-05-26-dae-func509-lowering-boundary-closure.md
  - ../../../raw/research/0590-2026-05-26-dae-func509-inmemory-block-suffix-boundary.md
  - ../../../raw/research/0589-2026-05-26-dae-func509-final-cleanup-input-reduction.md
  - ../../../raw/research/0588-2026-05-26-dae-func509-outer-block-reduction.md
  - ../../../raw/research/0587-2026-05-26-dae-func509-return-suffix-cleanup-attempt.md
  - ../../../raw/research/0586-2026-05-26-dae-func509-dead-return-suffix-frontier.md
  - ../../../raw/research/0585-2026-05-26-dae-func505-diagnostic-normalizer.md
  - ../../../raw/research/0584-2026-05-26-dae-func505-loop-carrier-reduction.md
  - ../../../raw/research/0583-2026-05-26-dae-func505-overflow-temp-reduction.md
  - ../../../raw/research/0582-2026-05-25-dae-func505-underscore-guard-reduction.md
  - ../../../raw/research/0581-2026-05-25-dae-func505-bool-carrier-cleanup.md
  - ../../../raw/research/0580-2026-05-25-dae-func505-empty-count-branch-inversion.md
  - ../../../raw/research/0579-2026-05-25-dae-func505-successor-frontier.md
  - ../../../raw/research/0578-2026-05-25-dae-func505-default-zero-guard-cleanup.md
  - ../../../raw/research/0577-2026-05-25-dae-func505-reduction-attribution.md
  - ../../../raw/research/0576-2026-05-25-dae-func505-frontier-classification.md
  - ../../../raw/research/0575-2026-05-24-dae-func408-compare-layer-audit.md
  - ../../../raw/research/0574-2026-05-21-dae002-post-raw-cleanup-frontier-audit.md
  - ../../../raw/research/0570-2026-05-18-dae002-func237-frontier-classification.md
  - ../../../raw/research/0567-2026-05-14-dae002-reverse-exact-literal-frontier-still-misses-4558.md
  - ../../../raw/research/0566-2026-05-14-dae002-func42-forwarding-wrapper-chain.md
  - ../../../raw/research/0565-2026-05-14-dae002-check-range-frontier-moved-to-func42.md
  - ../../../raw/research/0564-2026-05-14-dae002-check-range-rewrite-and-nested-skip.md
  - ../../../raw/research/0563-2026-05-14-dae002-later-candidate-starvation.md
  - ../../../raw/research/0569-2026-05-15-dae002-func42-shape-fix-and-low-callee-prefix.md
  - ../../../raw/research/0562-2026-05-13-dae002-typeidx-block-carriers.md
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
  - ../../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../../src/passes/dead_argument_elimination_wbtest.mbt
  - ../../../../../src/passes/dae_optimizing_test.mbt
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
- The active Starshine port preserves a still-partial scalar signature subset: direct dead-parameter removal, a narrow exact-literal every-direct-caller-same-constant materialization slice on read-only params, adjacent self-recursive forwarding, no-param dropped/uncalled result removal, case-000690 escaped-result self-call operand parameter preservation, and dead-suffix cleanup around root `unreachable`; as of 2026-05-13 that exact-literal slice also recovers candidates when sibling call arguments use the scalar memory-load family and typed single-result `TypeIdxBlockType` wrappers, but the live debug-artifact `moonbit.check_range` miss at `defined=11 abs=28` still survives and points at another caller-carrier family beyond those narrower wrappers. The active port now also has a usefully shrinking raw-cleanup slice on DAE-touched functions that strips live integer identity tails, including guarded left-constant forms, with focused wbtest coverage. Complete result-removal scheduling and broader Binaryen families remain active backlog work.
- The saved 1000-case direct frontier after `1f81bbc7` is not currently showing another semantic/signature candidate: all 13 remaining `gen-valid` mismatches in `.tmp/pass-fuzz-dae-690-final2-1000` have exactly one diff hunk limited to unused local declarations, while the two `wasm-smith` failures are unchanged Binaryen/tool `binaryen-rec-group-zero` parser failures. See [`../../../raw/research/0558-2026-05-12-dae-local-declaration-frontier.md`](../../../raw/research/0558-2026-05-12-dae-local-declaration-frontier.md).
- The nested rerun scheduler behavior is still not complete: Starshine now has a small-module touched-function cleanup scheduler for `precompute-propagate-prefix -> dead-code-elimination -> optimize-instructions -> local-cse -> pick-load-signs -> heap-store-optimization -> heap2local -> optimize-casts -> code-pushing -> simplify-locals -> code-folding -> precompute -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> coalesce-locals -> reorder-locals -> vacuum`, but it remains a guarded slice rather than Binaryen's full public `precompute-propagate` plus default function pipeline. The private `precompute-propagate-prefix` helper currently folds SSA-backed default-init and direct local constant facts and then reruns plain `precompute`; it is a faithful touched-only prefix equivalent, not the public upstream sibling. The `local-cse` step now uses a function-filtered raw adapter, while `coalesce-locals` and `reorder-locals` use function-filtered adapters over existing module passes, so public direct `local-cse`, `coalesce-locals`, and `reorder-locals` remain module-shaped while DAE cleanup touches only DAE-mutated functions. The local-CSE adapter emits `pass[local-cse]:func/start/done` trace lines so focused regressions can pin its order before `simplify-locals`, and the DAE scheduler itself emits `pass[dae-optimizing]:nested-pass name=...` lines so order tests do not depend on incidental raw-skip/start noise; `precompute-propagate-prefix`, `optimize-instructions`, `pick-load-signs`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `code-pushing`, direct `precompute`, `code-folding`, `merge-blocks`, `remove-unused-brs`, and `remove-unused-names` run through the existing hot touched-function runner.
- The 2026-05-12 DAE002 runtime attribution found the post-scheduler artifact timeout was still inside the DAE core before the nested marker, caused by repeated per-callee module scans in original call and dead-suffix preservation facts. Starshine now uses a single original call summary plus dead-suffix target aggregation, so artifact replay completes again, but DAE remains slower than Binaryen on the debug artifact and the first functional diff is still `defined=11 abs=28`; the 2026-05-13 follow-up load-shape attribution confirmed all `370` observed direct `moonbit.check_range` callers still pass literal `0` for `lo`, fixed scalar memory-load sibling carriers for the exact-literal slice, and still left the same first diff in place. A second 2026-05-13 follow-up added typed single-result `TypeIdxBlockType` carrier support plus a focused regression, but `.tmp/dae002-typeidx-block-artifact` still stayed red at `defined=11 abs=28`. A 2026-05-14 reduced repro then showed that the current DAE core can simply starve a later exact-literal candidate after `8` earlier productive rewrites: in the focused 9-earlier-def case, Binaryen still rewrites the later `moonbit.check_range`-shaped callee to 2 params while Starshine leaves it at 3, and the new `pass[dae-optimizing]:core iter=... primary_def=...` trace locks the bounded frontier directly as `primary_def=0..7`. A later 2026-05-14 follow-up then fixed two real caller-rewrite blockers for the original artifact path itself: ambient typed-loop entry-value slices and same-caller multi-call undercount. With those in place, the debug artifact frontier started at `primary_def=11`, `dae_try_rewrite_candidate(...)` rewrote all `370` direct `moonbit.check_range` calls, and Func 28 matched Binaryen’s 2-param signature. A final 2026-05-14 touched-only control simplifier then folded the remaining Func 28 post-rewrite guard shape enough to move the live artifact frontier forward to `defined=25 abs=42`. A same-day follow-up then showed Func 42 is not another direct exact-literal or shape-recovery miss: it is blocked by a forwarding-wrapper chain `4558 -> 4559 -> 42`, where Func 4558 is already directly rewritable, Func 4559 becomes rewritable after 4558, and Func 42 becomes rewritable only after both higher-index wrappers fall. A second same-day follow-up then showed a cheap bounded reverse exact-literal lane is still insufficient on the real artifact: the first `20` reverse exact-literal frontier defs are `4593, 4592, 4591, 4589, 4588, 4587, 4586, 4584, 4582, 4562, 4580, 4561, 4579, 4560, 4559, 4558, 4577, 4557, 4556, 4555`, so `4559` and `4558` do not appear until reverse iterations `14` and `15`. A third 2026-05-14 follow-up then added narrow forwarded-const analysis through wrapper-local `local.get` chains plus a low-prefix exact-literal revisit over the first `64` defined functions. That moves the core frontier again — now `11, 25, 227, 233, ...`, so Func 42 is the second productive core rewrite on the original artifact — but the full `--dae-optimizing` compare still differs first at `defined=25 abs=42`. The 2026-05-15 follow-up then fixed the remaining direct Func 42 post-rewrite body drift (`+ 0` address adds plus nearby const/local add ordering) and added a low-callee core revisit over high callees selected from the first `64` defined callers. That moved the live compare forward again to `defined=64 abs=81`, but the retained slice was still far slower than Binaryen (`120946.581ms` vs `939.053ms` pass-local), and a wider `128`-caller experiment was intentionally not kept after it pushed the frontier to `defined=128 abs=145` at roughly `211635.689ms` pass-local. A later selected-frontier push reached `.tmp/dae-parity-selected236-locals-fast-artifact`, which first differs at `defined=237 abs=254` while staying barely inside the pass-local target (`1633.775ms` vs `854.468ms`). The observed Func237 shape in [`../../../raw/research/0570-2026-05-18-dae002-func237-frontier-classification.md`](../../../raw/research/0570-2026-05-18-dae002-func237-frontier-classification.md) is not another exact-literal/result-removal miss: Binaryen keeps an early side-effect/trap-preserving void block and later materializes the default-zero carrier before wrapper allocation, while Starshine still carries that default through a leading value block and many temp locals. That Binaryen-handling description is artifact-inferred; broad selected nested cleanup and coalescing probes did not advance parity and were too expensive, so the open blocker is a narrow local/control carrier normalization problem under tight runtime headroom.
- The 2026-05-05 current-main recheck found no teaching-relevant drift from the `version_129` contract and now has a dedicated readiness bridge for the port.
- The local naming decision is no longer open for the optimizing sibling: `dae-optimizing` is canonical and `dead-argument-elimination-optimizing` is a descriptive alias.
- As of 2026-05-26, `[DAE]005` is closed as a raw-helper policy decision: the default raw helper still stops on type-section/type-index drift at `defined=336 abs=353`, but that first diff is a documented diagnostic boundary rather than active DAE body work. The last completed both-canonical diagnostic helper stopped at `defined=509 abs=526` in `.tmp/dae006-next-frontier-20260526`. [`../../../raw/research/0576-2026-05-25-dae-func505-frontier-classification.md`](../../../raw/research/0576-2026-05-25-dae-func505-frontier-classification.md) initially classified the earlier Func505 frontier as unknown/risky loop/local output-shape drift, and [`../../../raw/research/0577-2026-05-25-dae-func505-reduction-attribution.md`](../../../raw/research/0577-2026-05-25-dae-func505-reduction-attribution.md) attributed the Starshine rewrite to `mid-exact-literal primary_def=505` plus broad module raw cleanup rather than a traced nested-pass replay. Follow-up notes then narrowed the body: [`0578`](../../../raw/research/0578-2026-05-25-dae-func505-default-zero-guard-cleanup.md), [`0580`](../../../raw/research/0580-2026-05-25-dae-func505-empty-count-branch-inversion.md), and [`0581`](../../../raw/research/0581-2026-05-25-dae-func505-bool-carrier-cleanup.md) landed guarded selected-Func505 cleanups for semantic-safe default-zero, branch-inversion, and bool-carrier subshapes; [`0582`](../../../raw/research/0582-2026-05-25-dae-func505-underscore-guard-reduction.md), [`0583`](../../../raw/research/0583-2026-05-26-dae-func505-overflow-temp-reduction.md), and [`0584`](../../../raw/research/0584-2026-05-26-dae-func505-loop-carrier-reduction.md) classify the remaining underscore guard, overflow/temp, and loop/exit-carrier regions as representation-only drift. [`0585`](../../../raw/research/0585-2026-05-26-dae-func505-diagnostic-normalizer.md) adds a marker-rich diagnostic-only canonical-function normalizer and fake-tool fixture for that parser-loop family, and [`0586`](../../../raw/research/0586-2026-05-26-dae-func509-dead-return-suffix-frontier.md) records the successor Func509 frontier as a semantic-safe, size-losing dead-return-suffix cleanup gap with valid outputs but over-target pass-local timing (`2923.619ms` Starshine versus `891.787ms` Binaryen). Follow-up notes [`0587`](../../../raw/research/0587-2026-05-26-dae-func509-return-suffix-cleanup-attempt.md), [`0588`](../../../raw/research/0588-2026-05-26-dae-func509-outer-block-reduction.md), and [`0589`](../../../raw/research/0589-2026-05-26-dae-func509-final-cleanup-input-reduction.md) add focused final-return/wrapper cleanup helpers and reductions; `0589` proves the printed `--print-func 526` wrapper shape is already covered. [`0590`](../../../raw/research/0590-2026-05-26-dae-func509-inmemory-block-suffix-boundary.md) then tests the exact function-level value-block suffix and records that broadening the final DAE hook to strip it makes the debug artifact invalid. [`0591`](../../../raw/research/0591-2026-05-26-dae-func509-lowering-boundary-closure.md) closes `[DAE]006` by documenting the remaining Func509 diff as a lowerer/diagnostic boundary rather than a DAE final-hook matcher miss; future cleanup belongs to a later post-lowering or writer-side dead-code cleanup investigation. See [`./starshine-strategy.md`](./starshine-strategy.md) for the active slice list.

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
