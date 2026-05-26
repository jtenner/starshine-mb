# DAE002 touched nested cleanup scheduler boundary closure

Date: 2026-05-26

## Scope

Recovery/completion slice for `[DAE]002` after the later DAE frontier and performance work landed. This does not claim full Binaryen `optimizeAfterInlining` parity. It closes the current touched nested cleanup scheduler task because the remaining leading debug-artifact evidence is no longer attributed to the guarded scheduler itself.

## Decision

Treat `[DAE]002` as closed for the v0.1.0 current scheduler boundary:

- the guarded DAE nested lane has focused order coverage and touched-only coverage;
- it preserves the `precompute-propagate` prefix intent through Starshine's private `precompute-propagate-prefix` helper;
- function-filtered behavior is explicit for `local-cse`, `coalesce-locals`, and `reorder-locals` adapters;
- later body-frontier work moved past the original scheduler/frontier families and classified the live Func509 `defined=509 abs=526` both-canonical diff as a lowerer/diagnostic boundary in note `0591`, not as a missed nested-cleanup pass;
- DAE pass-local timing is inside the repo `Starshine <= 2x Binaryen` target after the caller-filtered dropped-result work in note `0601`.

The full public upstream `precompute-propagate` pass and byte-for-byte Binaryen default-function-pipeline replay remain intentionally unclaimed. Future changes there should reopen a new scheduler or preset-integration slice with focused tests, artifact evidence, and pass-local timing.

## Evidence reused

- `src/passes/dae_optimizing_test.mbt` contains focused trace-order coverage for the DAE nested pass sequence and touched-only `precompute-propagate-prefix` behavior.
- `src/passes/pass_manager.mbt` documents and implements the current guarded touched scheduler sequence.
- Research notes `0559` through `0574` record the incremental scheduler, adapter, and artifact-frontier work that moved beyond the earliest DAE002 blockers.
- Research note `0591` closes the current both-canonical Func509 frontier as a lowerer/diagnostic boundary rather than a DAE final-hook or nested-scheduler miss.
- Research note `0601` records repeated timing-only artifact replays inside the pass-local target.

## Backlog effect

`[DAE]002` is no longer an active blocker. Broader DAE work remains active in:

- `[DAE]003` for constant-actual and unread-parameter generalization;
- `[DAE]004` for principled dropped-result/result-removal broadening;
- `[DAE]013` for preset / ordered-neighborhood integration after direct-pass evidence is strong enough.

## Validation

This is a docs/backlog closure slice. No pass behavior changed and no new fuzz mismatch classification was needed. Closure validation in this run: `moon info`, `moon fmt`, and `moon test` passed.
