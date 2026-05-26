# DAE011 dropped-result helper timers

Date: 2026-05-26

## Scope

Continuation of open `[DAE]011` performance stabilization. Research note `0599` proved the selected dropped-result lane still misses the `Starshine <= 2x Binaryen` pass-local target after threading shared dropped-call facts. This slice adds deeper timers inside the selected-def dropped-result helper before attempting the next behavior-changing optimization.

## Change

`dae_try_remove_selected_defs_dropped_results_with_facts_once(...)` now accepts the active `HotPerfSession` and times each selected-def helper invocation as:

- `detail:dae:core:selected-lanes:dropped-results:selected-defs:helper`

`dae_try_remove_dropped_results(...)` now also emits sub-timers for the candidate work it performs after cheap direct/dropped-call prechecks pass:

- `...:helper:type-indices`
- `...:helper:section-copy`
- `...:helper:undropped-scan`
- `...:helper:self-call-count`
- `...:helper:rewrite-calls`
- `...:helper:remove-call-drops`
- `...:helper:dead-suffix-repair`
- `...:helper:callee-rewrite`
- `...:helper:type-update`

The timers are diagnostic-only and do not change DAE rewrite behavior.

## Regression

Extended the white-box selected dropped-result helper tests in `src/passes/pass_manager_wbtest.mbt`:

- the existing precomputed dropped-call-fact guard now asserts the helper-level timer is emitted even for a fast rejected candidate;
- a new positive candidate test asserts the type-index and call-rewrite sub-timers are emitted when the helper actually removes a dropped result.

TDD evidence:

- `moon test src/passes` failed before implementation because the selected helper had no `perf` parameter.
- `moon test src/passes` passed after implementation (`1376/1376`).

## Artifact timing and attribution

Rebuilt the native CLI and ran a traced debug-artifact pass:

```sh
moon build --target native --release src/cmd
STARSHINE_TRACING=pass target/native/release/build/cmd/cmd.exe \
  --dead-argument-elimination-optimizing \
  --out .tmp/dae011-helper-detail-trace/starshine.raw.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae011-helper-detail-trace/stdout.txt \
  2> .tmp/dae011-helper-detail-trace/stderr.txt
```

Latest trace totals:

- `detail:dae:core`: `2729841us`
- `detail:dae:core:selected-lanes`: `1882649us`
- `detail:dae:core:selected-lanes:dropped-results`: `1647810us`
- `detail:dae:core:selected-lanes:dropped-results:selected-defs`: `1634040us`
- `...:helper`: `1629234us`
- `...:helper:rewrite-calls`: `567297us`
- `...:helper:remove-call-drops`: `509930us`
- `...:helper:undropped-scan`: `233609us`
- `...:helper:dead-suffix-repair`: `10103us`
- `...:helper:section-copy`: `547us`
- `...:helper:type-indices`: `203us`
- `...:helper:type-update`: `146us`
- `...:helper:self-call-count`: `97us`
- `...:helper:callee-rewrite`: `8us`

A timing-only compare after the same rebuild completed:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing --timing-only \
  --out-dir .tmp/dae011-helper-timers-20260526
```

Result:

- Starshine runtime: `3139.096ms`
- Binaryen runtime: `1150.742ms`
- Starshine pass runtime: `2773.402ms`
- Binaryen pass runtime: `856.877ms`
- canonical wasm equal: `no`

## Classification and next step

`[DAE]011` remains open. The new profile makes the selected-def helper itself the clear owner of the dropped-result candidate-loop cost, and the dominant sub-buckets are repeated whole-module caller rewrites (`rewrite-calls` + `remove-call-drops`, about `1.077s`) plus the repeated undropped-call scan (`0.234s`). Type-index collection and section copying are negligible in the current artifact trace.

The next behavior-changing slice should avoid repeated whole-module scans by using `DaeCurrentCallFacts.direct_callers[callee]` or another candidate-to-caller queue to restrict both dropped-call rewrites and call-drop removal to actual caller bodies, while preserving the existing guards for self calls, dead suffix calls, and any precomputed-fact inconsistency.
