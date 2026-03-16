# SimplifyLocals Work Plan

## Purpose

This document turns the current `SimplifyLocals` investigation into a source-grounded work plan against the repository as it exists today. It is documentation-only: it does not assume missing infrastructure, and it treats the current Starshine pass as an already substantial implementation rather than a stub.

The task IDs in this file map one-to-one to the concise TODO items in `agent-todo.md`. Each task describes the intended finished state and acceptance conditions, not implementation steps.

Primary source anchors used for this plan:

- `src/passes/simplify_locals.mbt`
- `src/passes/optimize.mbt`
- `src/passes/local_cse.mbt`
- `docs/tracing.md`
- Binaryen `src/passes/SimplifyLocals.cpp`
- Binaryen `src/passes/pass.cpp`

## Current Situation

Starshine already has a featureful `SimplifyLocals` pass with five exposed variants: `SimplifyLocals`, `SimplifyLocalsNoTee`, `SimplifyLocalsNoStructure`, `SimplifyLocalsNoTeeNoStructure`, and `SimplifyLocalsNoNesting`.

The current implementation in `src/passes/simplify_locals.mbt` already includes:

- a first-cycle/no-tee policy plus repeated fixpoint cycles,
- a main phase, cleanup phase, and late equivalent-copy cleanup,
- block/if/loop structure rewrites,
- type-aware sink legality guards and typed-function validation,
- shared cached effect analysis via `LCSEffects`,
- tracing, helper timing, hotspot summaries, and rejection counters,
- pathological and wide-local guardrails with revert-to-original behavior,
- existing regression and performance tests, including `ID-C1`, `ID-C2`, `ID-P1`..`ID-P5`, and `ID-F1`..`ID-F4`.

This means the remaining work is not “implement SimplifyLocals.” The remaining work is to close specific correctness, parity, performance, and scheduler/signoff gaps without regressing the extra validation and observability Starshine already added.

## Binaryen Parity Notes

Binaryen’s `SimplifyLocals` establishes the baseline model this plan compares against:

- repeated cycles with a special first cycle that avoids teeing,
- sinkable-local tracking plus broad invalidation when control flow splits,
- structure rewrites for `if`, `block`, and `loop` results,
- late equivalent-copy cleanup and unneeded-set removal,
- default pipeline placement around `flatten`, `simplify-locals-notee-nostructure`, `local-cse`, later `simplify-locals-nostructure`, and later full `simplify-locals`.

Starshine already intentionally diverges in several useful ways, and those divergences should be preserved unless a task explicitly signs them off as unnecessary:

- typed local/result legality checks before committing rewrites,
- optional rewritten-function validation,
- helper timing snapshots, totals, and hotspot reporting,
- pathological budget guards and wide-local/deep-control fast exits,
- perf counters for effect collection, invalidation scans, get-count rescans, and late-state cloning.

The goal of this plan is therefore parity-plus-signoff: match Binaryen where the behavior should match, and make intentional Starshine differences explicit and test-locked where they should remain.

## Actionable Tasks

### `SL-01` / `ID-C1` — Preserve sinkables across destination-local reads only when sound

- Relevant current source: `sl_collect_sinkable_effects(...)`, `sl_invalidate_sinkables(...)`, and the `ID-C1` tests in `src/passes/simplify_locals.mbt`.
- Finished state: a sinkable `local.set` is invalidated whenever an intervening read of the destination local would observe the old value, and is not invalidated merely because the trace passed through a transparent boundary.
- Acceptance criteria: both `ID-C1` tests pass, adjacent transparent-block sinking still works, and no stale-value sink survives past an intermediate read of the written local.

### `SL-02` / `ID-C2` — Keep `local.get` counts exact after rewrite-created gets

- Relevant current source: `SLMainGetCounts`, `sl_run_main_phase(...)`, one-sided `if` structuring, and the `ID-C2` test.
- Finished state: whenever a rewrite introduces or removes `local.get` instructions, the next cycle sees exact counts rather than stale pre-rewrite counts.
- Acceptance criteria: `ID-C2` passes, later-cycle rewrites that depend on `get` counts remain sound, and `ID-F3` continues to pass alongside it.

### `SL-03` / `ID-P1` — Structure `if` results when one arm is unreachable

- Relevant current source: `sl_try_structure_if(...)`, result-`if` tests, and Binaryen’s `optimizeIfElseReturn(...)` behavior.
- Finished state: `if` expressions with one unreachable arm can still be rewritten into result-valued forms when the surviving arm makes that legal and useful.
- Acceptance criteria: `ID-P1` passes, the nested branchy result-`if` coverage remains valid, and typed-local validation still rejects void-branch or type-invalid candidates.

### `SL-04` / `ID-P2` — Preserve fixpoint-cycle convergence for chained opportunities

- Relevant current source: `sl_simplify_function(...)`, first-cycle tee policy, cleanup/late reruns, and the `ID-P2` plus adjacent-boundary convergence tests.
- Finished state: opportunities that only appear after earlier sinks, cleanup, or late canonicalization are reached by later cycles without entering rewrite oscillation.
- Acceptance criteria: `ID-P2` passes, tee-profitability tests still describe the chosen policy, and repeated runs converge without changing the final rewritten body.

### `SL-05` / `ID-P3` — Keep loop-result structuring parity and legality

- Relevant current source: `sl_try_structure_loop_sink(...)`, the loop-result tests, and Binaryen’s loop-return optimization.
- Finished state: eligible loops become result-valued outer `local.set` forms, while loops whose control flow still branches to the loop header stay unstructured.
- Acceptance criteria: `ID-P3` passes, `does not make loop result when loop has br 0` stays locked, and validation succeeds on the rewritten function shape.

### `SL-06` / `ID-P4` — Support subtype-safe single-use sinking

- Relevant current source: `sl_sink_value_preserves_local_get_type(...)`, `sl_can_emit_rewritten_instr(...)`, and the subtype/narrowing tests.
- Finished state: one-use sinks may substitute a more refined value where it is type-safe, but never silently widen or change the required type of the consuming site.
- Acceptance criteria: `ID-P4` passes, narrowing-ref sink tests remain valid, and the untyped-select exact-type preservation test still passes.

### `SL-07` / `ID-P5` — Keep subtype-aware late canonicalization correct and scalable

- Relevant current source: `sl_run_late_optimizations_with_counts(...)`, equivalent-copy cleanup tests, and the large-local-array `ID-P5` stress case.
- Finished state: late canonicalization consistently prefers the best equivalent local by type/usefulness and does so for both small and large local arrays.
- Acceptance criteria: both `ID-P5` tests pass, equivalent-set removal behavior remains consistent with the structure option, and no type-refinement regression appears in late cleanup.

### `SL-08` — Keep conditional `br_if` value structuring legal, typed, and effect-order-safe

- Relevant current source: block-exit collectors, conditional-break structuring tests, and the effect-order/type-guard tests around carried values.
- Finished state: conditional branch-value coalescing is available for the supported safe shapes and explicitly skipped for cases where moving the carried value would reorder effects or break typing.
- Acceptance criteria: the positive `br_if` coalescing tests pass, the effect-order-failure and type-invalid skip tests stay green, and tee-disabled variants still refuse tee-dependent rewrites.

### `SL-09` — Keep supported single-target `br_table` subsets optimizable and reject the rest

- Relevant current source: block-exit collection for `br_table` and the four current `br_table` tests.
- Finished state: supported single-target `br_table` shapes participate in block-return optimization, while mixed-target or value-arity-mismatch shapes remain explicitly unoptimizable.
- Acceptance criteria: the single-target collector and structure tests pass, the mixed-target and arity-mismatch tests remain negative, and no unsupported `br_table` shape is partially rewritten.

### `SL-10` — Preserve typed rewrite validation, repair, and rejection accounting

- Relevant current source: `sl_validate_rewritten_function(...)`, typed-function candidate validation, rewrite finalizer salvage, and validation counter tests.
- Finished state: any rewrite that changes typed local/result behavior is either accepted, safely repaired, or rejected with an explicit reason bucket; an invalid rewritten function must never escape the pass.
- Acceptance criteria: the typed-function validator tests, finalizer salvage tests, and validation-counter tests all pass; verbose tracing still reports accepted/rejected candidate counts coherently.

### `SL-11` / `ID-F1` — Bound effect recomputation in the main phase

- Relevant current source: `sl_collect_effects_cached(...)`, `SLPerfSnapshot`, `SLMainRewriteHelperSnapshot`, and the `ID-F1` stress test.
- Finished state: main-phase effect analysis is shared aggressively enough that repeated rewrite/invalidation queries do not re-collect effects at near-naive rates on representative hot paths.
- Acceptance criteria: `ID-F1` passes, cached-hit/miss accounting remains meaningful in traces, and effect-sensitive correctness tests remain unchanged.

### `SL-12` — Keep pathological and wide-local guardrails explicit and non-destructive

- Relevant current source: `SL_PATHOLOGICAL_*` and wide-local thresholds, `sl_main_is_pathological_deep_control_candidate(...)`, no-local-get skip logic, and the pathological tests.
- Finished state: pathological functions either take a cheap skip/revert path or a bounded single-cycle path, while normal functions do not lose standard simplification opportunities due to over-broad guarding.
- Acceptance criteria: the no-local-get skip test, both deep-control pathological tests, and the budget-revert trace semantics remain valid and explicitly documented.

### `SL-13` / `ID-F2` — Reduce invalidation-scan asymptotics

- Relevant current source: `sl_invalidate_sinkables(...)`, `invalidation_entry_checks`, and the `ID-F2` stress test.
- Finished state: invalidation work is materially below naive “scan every active sinkable at every instruction” behavior on wide stress cases without weakening legality guarantees.
- Acceptance criteria: `ID-F2` passes, invalidation counters still expose the cost center in traces, and no additional invalid sink slips through effect barriers.

### `SL-14` / `ID-F3` — Reuse `local.get` counts across fixpoint cycles

- Relevant current source: `SLMainGetCounts`, dense/sparse count helpers, `sl_run_main_phase(...)`, and the `ID-F3` stress test.
- Finished state: fixpoint cycles reuse or incrementally refresh count state where possible instead of rescanning the whole body after every cycle.
- Acceptance criteria: `ID-F3` passes, `ID-C2` still passes, and wide-local sparse-count paths remain covered by tests.

### `SL-15` / `ID-F4` — Avoid unnecessary late-phase state cloning on nested control

- Relevant current source: `late_state_clones`, late cleanup helpers, and the `ID-F4` nested-branch stress test.
- Finished state: late equivalent-copy cleanup keeps branch-heavy functions from paying avoidable state-cloning costs while preserving canonicalization quality.
- Acceptance criteria: `ID-F4` passes, late equivalent-set cleanup tests still pass, and traces/counters continue to show the late-phase cost separately from main-phase rewrite cost.

### `SL-16` — Sign off pipeline placement and five-variant scheduler parity

- Relevant current source: `src/passes/optimize.mbt`, existing scheduler tests, and Binaryen `pass.cpp` default function-optimization ordering.
- Finished state: the Starshine pipeline placement for `SimplifyLocalsNoTeeNoStructure`, `SimplifyLocalsNoStructure`, and full `SimplifyLocals` remains intentionally aligned with Binaryen, and all five Starshine variants stay scheduler-visible and tested.
- Acceptance criteria: the existing optimize-scheduler tests pass, `optimize_module runs SimplifyLocals pass` remains green, and any remaining scheduler divergence is documented as intentional instead of implicit.

### `SL-17` — Close the parity/performance matrix and make follow-up work self-serve

- Relevant current source: this document, `agent-todo.md`, existing regression IDs, and the repo’s standard MoonBit validation commands.
- Finished state: every remaining `SimplifyLocals` gap is classified as implemented work or intentional divergence, the locking tests are identified, and a future agent can pick any single task without extra hidden context.
- Acceptance criteria: each `SL-*` item has matching docs and tests/relevant source anchors, the local rerun commands are recorded, and the `SimplifyLocals` section can eventually be retired from `agent-todo.md` without ambiguity.

## Recommended Execution Order

Use this order unless a newly discovered bug forces reprioritization:

1. `SL-01`, `SL-02`, `SL-10` — correctness and validation foundations.
2. `SL-03`, `SL-05`, `SL-08`, `SL-09` — control-structure parity that depends on the correctness layer.
3. `SL-04`, `SL-06`, `SL-07` — convergence and subtype-aware parity follow-through.
4. `SL-11`, `SL-13`, `SL-14`, `SL-15`, `SL-12` — hot-path and pathological performance work after behavior is stable.
5. `SL-16`, `SL-17` — scheduler signoff and final parity/performance closure.

## Local Verification Expectations For Follow-up Work

For future implementation work on any `SL-*` item, the minimum rerun sequence should stay:

- targeted `simplify_locals` tests first,
- then `moon info && moon fmt`,
- then `moon test`.

If the change touches scheduling or pass exposure, also rerun the relevant `optimize.mbt` scheduler tests before treating the task as complete.