# DAE011 selected-lane perf timers

Date: 2026-05-26

## Scope

Recovery slice for `[DAE]011` performance stabilization. Previous note `0596` showed the debug-artifact runtime hotspot was `detail:dae:core:selected-lanes`; this slice splits that bucket into smaller rewrite-family timers before any optimization.

## Changes

- Added selected-lane detail timers in `src/passes/dead_argument_elimination.mbt`:
  - `detail:dae:core:selected-lanes:reverse-exact-literal` around dead-suffix restoration plus reverse/low exact-literal revisits.
  - `detail:dae:core:selected-lanes:low-wrapper-callees` around low-callee, shifted wrapper, and boundary wrapper/callee unread-param queues.
  - `detail:dae:core:selected-lanes:early-shapes` around selected Func236/Func256/Func237/Func867/Func233 shape cleanup before selected result removal.
  - `detail:dae:core:selected-lanes:dropped-results` around selected dropped-result removal and adjacent Func298/Func299 cleanup.
  - `detail:dae:core:selected-lanes:literal-unread` around selected unread-param and exact-literal families.
  - `detail:dae:core:selected-lanes:late-shapes` around remaining selected Func408/Func311/Func313/Func287/Func288/Func260/Func323/Func326/high-literal shape cleanup before module raw cleanup.
  - `detail:dae:core:post-raw-selected-lanes` around zero-tee, final Func237, default-arg, forwarded-wrapper, and final-return suffix cleanup after module raw cleanup.
- Extended `src/passes/dae_optimizing_test.mbt` so the DAE perf-trace regression requires all new timer names.

## TDD evidence

First focused run after adding the assertions failed as expected because the timers were absent:

```sh
moon test src/passes -f 'dae-optimizing perf trace breaks down core, nested cleanup, and type pruning'
```

The failure trace contained the previous `detail:dae:core:selected-lanes` aggregate but none of the requested selected-lane sub-buckets.

After implementation, the focused test passed:

```sh
moon test src/passes -f 'dae-optimizing perf trace breaks down core, nested cleanup, and type pruning'
```

Result: `1` test passed, `0` failed. The full pass package suite also passed:

```sh
moon test src/passes
```

Result: `1374` tests passed, `0` failed.

## Artifact attribution replay

After rebuilding the release CLI:

```sh
moon build --target native --release

target/native/release/build/cmd/cmd.exe \
  --tracing pass \
  --dead-argument-elimination-optimizing \
  --out .tmp/dae011-selected-detail-trace/starshine.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae011-selected-detail-trace/stdout.txt \
  2> .tmp/dae011-selected-detail-trace/stderr.txt
```

The selected-lane timer lines were:

```text
perf:timer name=detail:dae:core:setup elapsed_us=86903 total_us=86903
perf:timer name=detail:dae:core:fixed-loop elapsed_us=501691 total_us=501691
perf:timer name=detail:dae:core:selected-lanes:reverse-exact-literal elapsed_us=29513 total_us=29513
perf:timer name=detail:dae:core:selected-lanes:low-wrapper-callees elapsed_us=41434 total_us=41434
perf:timer name=detail:dae:core:selected-lanes:early-shapes elapsed_us=35589 total_us=35589
perf:timer name=detail:dae:core:selected-lanes:dropped-results elapsed_us=1654447 total_us=1654447
perf:timer name=detail:dae:core:selected-lanes:literal-unread elapsed_us=67868 total_us=67868
perf:timer name=detail:dae:core:selected-lanes:late-shapes elapsed_us=69115 total_us=69115
perf:timer name=detail:dae:core:selected-lanes elapsed_us=1897993 total_us=1897993
perf:timer name=detail:dae:core:raw-cleanup elapsed_us=94965 total_us=94965
perf:timer name=detail:dae:core:post-raw-selected-lanes elapsed_us=171910 total_us=171910
perf:timer name=detail:dae:core elapsed_us=2753535 total_us=2753535
```

The emitted artifact validated with:

```sh
wasm-opt --all-features .tmp/dae011-selected-detail-trace/starshine.wasm -o /tmp/dae011-selected-detail-trace.validated.wasm
```

`wasm-opt` repeated the existing large-local-count VM warning for function 518 and otherwise accepted the output.

## Classification

`[DAE]011` remains open. This slice is instrumentation and attribution, not a semantic behavior change. No fuzz/compare mismatch classification was produced by this instrumentation-only run.

The dominant hotspot is now the selected dropped-result bucket: about `1.65s` of the `1.90s` selected-lane aggregate and `2.75s` DAE core total. The post-raw selected lanes are the next selected-family bucket at about `0.17s`, while every other selected-lane sub-bucket is below `0.07s` in this replay.

## Next safe subtasks

1. Optimize or further micro-profile `detail:dae:core:selected-lanes:dropped-results`, especially broad call-fact collection and repeated selected-def result-removal checks.
2. Preserve the known guardrails: no broad whole-module untouched cleanup, no unbounded selected-loop expansion, and no per-def bitmap churn reintroduced on artifact-sized modules.
3. Repeat timing-only or traced artifact replay after the selected dropped-result optimization and keep the pass-local `Starshine <= 2x Binaryen` target visible.

## Validation

- `moon test src/passes -f 'dae-optimizing perf trace breaks down core, nested cleanup, and type pruning'` failed before implementation and passed after implementation.
- `moon test src/passes` passed after implementation.
- `moon build --target native --release` completed with existing unused-helper warnings.
- Direct traced artifact replay completed and wrote `.tmp/dae011-selected-detail-trace/starshine.wasm` plus stderr/stdout captures.
- `wasm-opt --all-features .tmp/dae011-selected-detail-trace/starshine.wasm -o /tmp/dae011-selected-detail-trace.validated.wasm` accepted the artifact with the existing large-local-count warning.
