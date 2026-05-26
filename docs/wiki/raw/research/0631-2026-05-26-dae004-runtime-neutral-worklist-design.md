# DAE004 runtime-neutral dropped-result worklist design

Date: 2026-05-26

## Scope

Recovery continuation for open `[DAE]004` selected result-removal broadening. This slice closes `[DAE004-C]` as a design/evidence slice: it defines the runtime-neutral large-module worklist shape that should replace the handpicked selected dropped-result fallback before any broad cap increase or fallback deletion.

No optimizer behavior changed. The goal is to prevent the next implementation slice from repeating the rejected note `0607` experiment, where a naive large ascending queue starved high candidates, still needed the selected fallback, and failed artifact validation.

## Starting evidence

Current implementation anchor: `src/passes/dead_argument_elimination.mbt` runs fact-driven dropped-result removal before the handpicked fallback.

Current bounds:

- `defined <= 4096`: ascending fact-discovered candidate lane, capped at `32` productive attempts.
- `4096 < defined <= 4608`: descending fact-discovered candidate lane, capped at `14` productive attempts.
- `4608 < defined <= 8192`: descending fact-discovered candidate lane, capped at `8` productive attempts.

Research notes `0628` and `0629` show that the latest debug artifact still needs the selected fallback for `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, and `4249`; the first blocker is ordering plus productive-attempt cap after the descending lane spends its large-artifact budget on `4651..4644`. Note `0630` adds a regression guard proving the current implementation can still cover a lower-index fact-discovered target when the high descending budget is consumed.

## Proposed runtime-neutral worklist

Use a bounded, caller-filtered, bucketed worklist rather than a single full ascending or descending scan:

1. Build current call facts once per outer worklist round with `dae_collect_current_call_facts(...)`.
2. Derive `dae_collect_fact_dropped_result_candidate_defs(...)` from those facts.
3. Partition candidates into stable buckets:
   - high descending bucket: highest indices first, preserving the proven `4651..4644` reach;
   - fallback-neighborhood bucket: fact-discovered candidates whose definition index is in or near the still-productive selected fallback set from notes `0628`/`0629`;
   - low ascending bucket: lowest indices first, preserving the lower-candidate guard from note `0630`.
4. Interleave buckets with small per-round quotas instead of exhausting one order. Initial artifact-safe proposal: high `4`, fallback-neighborhood `4`, low `2`, then refresh facts. Keep the existing total productive cap for broad `4608 < defined <= 8192` modules at `8` until measurement proves a higher total is safe; only redistribute which candidates get tried inside that cap.
5. After each successful result-removal rewrite, refresh call facts before trying more candidates unless a focused proof shows the rewritten signature cannot change later candidate eligibility. This preserves the caller-filtered result-rewrite safety from DAE011 and avoids stale-fact assumptions.
6. Continue to call `dae_try_remove_dropped_result_def_with_facts(...)` so mixed dropped/undropped calls, tail calls, escapes, type liveness, signature repair, and caller-filtered cleanup remain centralized in the existing helper.
7. Emit trace metadata for implementation slices, e.g. `pass[dae-optimizing]:fact-dropped-result bucket=<high|fallback|low> iter=... primary_def=...`, so artifact runs can prove which bucket retired a selected fallback family.

This design is runtime-neutral by default because it does not raise the broad productive cap, does not reintroduce whole-module rewrite scans, and preserves caller-filtered rewriting. Its expected benefit is better candidate ordering inside the same budget: high candidates keep coverage, low candidates stay guarded, and selected fallback neighborhoods become reachable without a handpicked post-pass.

## Required implementation subtasks

`[DAE004-D]` should implement this design incrementally, not all at once:

1. Add a white-box unit for bucket construction and interleaving order using synthetic candidate sets that include high candidates, low candidates, and selected-fallback neighborhoods.
2. Add a focused black-box DAE regression where a fallback-neighborhood candidate is fact-discovered but not reached by the current high-first cap.
3. Implement the bucketed candidate collector only; prove existing outputs unchanged if quotas match current order.
4. Switch the large-module fact lane to the interleaved order under the existing broad cap.
5. Replay the debug artifact with tracing and validate output with `wasm-opt --all-features`.
6. Record pass-local timing; keep `Starshine pass <= 2x Binaryen pass` before deleting any fallback entry.
7. Delete or gate one selected fallback entry only after the trace proves the fact-driven worklist covered that family and direct compare evidence has no new semantic or validation regression.

## Rejected alternatives

- Broad ascending `defined <= 8192` retry: rejected by note `0607` because it starved high candidates and failed artifact validation.
- Simply raising the broad descending productive cap: rejected for now because notes `0608` through `0626` were deliberately capped to preserve the DAE011 runtime target.
- Removing the selected fallback immediately: rejected because notes `0628` and `0629` still show productive fallback entries that the current fact lane does not reach.

## Exit criteria for the later behavior-changing slice

A behavior-changing implementation of this design should not be accepted until it has:

- focused failing tests first for the ordering/fallback-neighborhood gap;
- passing focused and full `src/passes` Moon tests;
- debug-artifact trace evidence showing at least one formerly selected-only dropped-result family reached by the fact-driven worklist;
- `wasm-opt --all-features` validation for artifact output;
- pass-local timing inside the `Starshine <= 2x Binaryen` target;
- direct `dae-optimizing` compare evidence with mismatch classification.

## Validation

Docs/backlog design slice only. No pass behavior changed and no fuzz/compare run was required. Validation for this commit used `git diff --check`, `moon info`, `moon fmt`, and `moon test`.
