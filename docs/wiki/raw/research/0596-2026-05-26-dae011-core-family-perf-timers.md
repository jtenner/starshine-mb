# DAE011 core-family perf timers

Date: 2026-05-26

## Scope

Recovery slice for `[DAE]011` performance stabilization. Previous note `0595` attributed the debug-artifact runtime almost entirely to `detail:dae:core`; this slice adds the requested deeper `detail:dae:core:*` timers before attempting any optimization.

## Changes

- Threaded the existing `HotPerfSession` into `dae_run_core(...)` from the DAE optimizing module-pass runner.
- Added core-family timers inside `dae_run_core`:
  - `detail:dae:core:setup` around original module facts and call/dead-suffix summaries.
  - `detail:dae:core:fixed-loop` around the bounded primary `dae_run_core_once` loop.
  - `detail:dae:core:selected-lanes` around the selected artifact-specific rewrite lanes before module raw cleanup.
  - `detail:dae:core:raw-cleanup` around `dae_strip_module_nops_and_dropped_pure_leaf_once(...)`.
- Extended the focused perf regression in `src/passes/dae_optimizing_test.mbt` so the top-level DAE perf test now requires these core-family timer names in addition to the existing core, nested, nested-pass, and type-pruning timers.

## TDD evidence

First focused test run after adding the new assertions failed as expected because the core-family timers were absent:

```sh
moon test src/passes
```

The failure trace contained `detail:dae:core`, `detail:dae:nested:*`, and `detail:dae:prune-unused-simple-func-types`, but not `detail:dae:core:setup`, `detail:dae:core:fixed-loop`, `detail:dae:core:selected-lanes`, or `detail:dae:core:raw-cleanup`.

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
  --out .tmp/dae011-core-detail-trace.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae011-core-detail-trace.stdout \
  2> .tmp/dae011-core-detail-trace.stderr
```

The core-family timer lines were:

```text
perf:timer name=detail:dae:core:setup elapsed_us=85798 total_us=85798
perf:timer name=detail:dae:core:fixed-loop elapsed_us=486741 total_us=486741
perf:timer name=detail:dae:core:selected-lanes elapsed_us=1917924 total_us=1917924
perf:timer name=detail:dae:core:raw-cleanup elapsed_us=96963 total_us=96963
perf:timer name=detail:dae:core elapsed_us=2762312 total_us=2762312
```

The emitted artifact validated with:

```sh
wasm-opt --all-features .tmp/dae011-core-detail-trace.wasm -o /tmp/dae011-core-detail-trace.validated.wasm
```

`wasm-opt` repeated the existing large-local-count VM warning for function 518 and otherwise accepted the output.

## Classification

`[DAE]011` remains open. This slice is instrumentation and attribution, not a semantic behavior change. No fuzz/compare mismatch classification was produced by this instrumentation-only run.

The current debug-artifact DAE core hotspot is the selected artifact-specific lanes: about `1.92s` of the `2.76s` core time. The bounded primary loop is the next-largest bucket at about `0.49s`; setup and module raw cleanup are much smaller at about `0.09s` each.

## Next safe subtasks

1. Split `detail:dae:core:selected-lanes` into smaller groups around selected result removal, selected exact-literal/unread-param families, selected Func237/Func408/Func505 families, and final-return/zero-tee/post-raw families.
2. Use that selected-lane profile to choose one targeted optimization.
3. Keep avoiding the known cliffs: broad rescans, per-def bitmap churn, whole-module untouched cleanup, and selected-loop expansions.

## Validation

- `moon test src/passes` passed after implementation.
- `moon build --target native --release` completed with existing unused-helper warnings.
- Direct traced artifact replay completed and wrote `.tmp/dae011-core-detail-trace.wasm` plus stderr/stdout captures.
- `wasm-opt --all-features .tmp/dae011-core-detail-trace.wasm -o /tmp/dae011-core-detail-trace.validated.wasm` accepted the artifact with the existing large-local-count warning.
