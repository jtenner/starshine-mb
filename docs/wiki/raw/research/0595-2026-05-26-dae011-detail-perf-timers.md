# DAE011 detail perf timers

Date: 2026-05-26

## Scope

Recovery slice for `[DAE]011` performance stabilization. The previous recovery note `0594` proved the current `--tracing pass` release binary only emitted the aggregate `pass:dead-argument-elimination-optimizing` timer, so this slice added DAE-owned detail timers before attempting pass logic changes.

## Changes

- Added perf detail timing around the DAE optimizing module-pass phases:
  - `detail:dae:core` for `dae_run_core`,
  - `detail:dae:nested-total` for the guarded nested cleanup scheduler, including skip paths,
  - `detail:dae:nested:<pass-name>` for each nested cleanup pass when the guarded nested lane actually runs,
  - `detail:dae:prune-unused-simple-func-types` for the final type-pruning helper.
- Added a focused `src/passes/dae_optimizing_test.mbt` regression proving a perf session emits the core, nested-total, representative nested-pass, and type-pruning timer names on a small touched DAE fixture.

## TDD evidence

First focused test run after adding the regression failed as expected because the new detail timers were absent:

```sh
moon test src/passes
```

The failing trace contained only existing pass/nested trace lines plus aggregate hot-pass timers such as `pass:dae-optimizing`; it did not contain `detail:dae:core`, `detail:dae:nested-total`, `detail:dae:nested:vacuum`, or `detail:dae:prune-unused-simple-func-types`.

After implementation, the focused pass test suite passed:

```sh
moon test src/passes
```

Result: `1374` tests passed, `0` failed. Existing unused-helper warnings in `pass_manager_wbtest.mbt` remained.

## Artifact attribution replay

After rebuilding the release CLI:

```sh
moon build --target native --release

target/native/release/build/cmd/cmd.exe \
  --tracing pass \
  --dead-argument-elimination-optimizing \
  --out .tmp/dae011-detail-trace.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae011-detail-trace.stdout \
  2> .tmp/dae011-detail-trace.stderr
```

The detail timer lines were:

```text
perf:timer name=detail:dae:core elapsed_us=2748777 total_us=2748777
perf:timer name=detail:dae:nested-total elapsed_us=4 total_us=4
perf:timer name=detail:dae:prune-unused-simple-func-types elapsed_us=47855 total_us=47855
```

The artifact touched `506` functions and hit the existing `large-touched-set` nested cleanup guard, so no per-nested-pass detail timer was expected on the artifact run. The focused small-module regression covers per-nested-pass emission when the nested lane runs.

## Classification

`[DAE]011` remains open. This slice is instrumentation and attribution, not a semantic behavior change. The current debug-artifact runtime blocker is dominated by `dae_run_core` itself: about `2.75s` of the aggregate pass time is core, about `0.05s` is type pruning, and nested cleanup is skipped in about `4us` on the artifact. No fuzz/compare mismatch classification was produced by this instrumentation-only run.

## Next safe subtasks

1. Add deeper `detail:dae:core:*` timers around the expensive core setup/scanner families inside `dae_run_core` before changing logic.
2. Use those core-family timers to choose one targeted optimization.
3. Avoid the known cliffs: broad rescans, per-def bitmap churn, whole-module untouched cleanup, and selected-loop expansions.

## Validation

- `moon test src/passes` passed after the implementation.
- `moon build --target native --release` completed with existing unused-helper warnings.
- Direct traced artifact replay completed and wrote `.tmp/dae011-detail-trace.wasm` plus stderr/stdout captures.
