# DAE011 dropped-result detail timers

Date: 2026-05-26

## Scope

Recovery slice for `[DAE]011` performance stabilization. Previous note `0597` showed the debug-artifact runtime hotspot was `detail:dae:core:selected-lanes:dropped-results`; this slice splits that bucket before changing result-removal behavior.

## Changes

- Added dropped-result detail timers in `src/passes/dead_argument_elimination.mbt`:
  - `detail:dae:core:selected-lanes:dropped-results:call-facts` around the shared current-call-fact collection.
  - `detail:dae:core:selected-lanes:dropped-results:selected-defs` around the handpicked selected dropped-result candidate loop plus adjacent Func298 cleanup.
  - `detail:dae:core:selected-lanes:dropped-results:func299-if` around the adjacent Func299 inverted-result-if cleanup.
- Extended `src/passes/dae_optimizing_test.mbt` so the DAE perf-trace regression requires the new dropped-result timer names.

## TDD evidence

After adding the assertions first, the focused package run failed as expected because the timers were absent:

```sh
moon test src/passes
```

The failure was in `dae-optimizing perf trace breaks down core, nested cleanup, and type pruning`; the trace contained the old `detail:dae:core:selected-lanes:dropped-results` aggregate but none of the new sub-buckets.

After implementation, the pass package suite passed:

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
  --out .tmp/dae011-dropped-result-detail-trace/starshine.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae011-dropped-result-detail-trace/stdout.txt \
  2> .tmp/dae011-dropped-result-detail-trace/stderr.txt
```

The relevant timer lines were:

```text
perf:timer name=detail:dae:core:setup elapsed_us=89475 total_us=89475
perf:timer name=detail:dae:core:fixed-loop elapsed_us=555778 total_us=555778
perf:timer name=detail:dae:core:selected-lanes:reverse-exact-literal elapsed_us=27822 total_us=27822
perf:timer name=detail:dae:core:selected-lanes:low-wrapper-callees elapsed_us=41130 total_us=41130
perf:timer name=detail:dae:core:selected-lanes:early-shapes elapsed_us=34826 total_us=34826
perf:timer name=detail:dae:core:selected-lanes:dropped-results:call-facts elapsed_us=14279 total_us=14279
perf:timer name=detail:dae:core:selected-lanes:dropped-results:selected-defs elapsed_us=1662875 total_us=1662875
perf:timer name=detail:dae:core:selected-lanes:dropped-results:func299-if elapsed_us=25 total_us=25
perf:timer name=detail:dae:core:selected-lanes:dropped-results elapsed_us=1677201 total_us=1677201
perf:timer name=detail:dae:core:selected-lanes:literal-unread elapsed_us=73409 total_us=73409
perf:timer name=detail:dae:core:selected-lanes:late-shapes elapsed_us=70280 total_us=70280
perf:timer name=detail:dae:core:selected-lanes elapsed_us=1924691 total_us=1924691
perf:timer name=detail:dae:core:raw-cleanup elapsed_us=94085 total_us=94085
perf:timer name=detail:dae:core:post-raw-selected-lanes elapsed_us=163800 total_us=163800
perf:timer name=detail:dae:core elapsed_us=2827887 total_us=2827887
```

The emitted artifact validated with:

```sh
wasm-opt --all-features .tmp/dae011-dropped-result-detail-trace/starshine.wasm -o /tmp/dae011-dropped-result-detail-trace.validated.wasm
```

`wasm-opt` repeated the existing large-local-count VM warning for function 518 and otherwise accepted the output.

## Classification

`[DAE]011` remains open. This slice is instrumentation and attribution, not a semantic behavior change. No fuzz/compare mismatch classification was produced by this instrumentation-only run.

The dropped-result hotspot is not broad call-fact collection in this replay: shared call facts cost about `14ms`, and the adjacent Func299 cleanup is negligible. The selected-def candidate loop costs about `1.66s` of the `1.68s` dropped-result bucket and remains the next optimization target.

## Next safe subtasks

1. Optimize or further micro-profile the selected-def candidate loop itself, especially broad per-candidate scans inside `dae_try_remove_dropped_results(...)`, repeated `dae_module_has_undropped_direct_call_to_except(...)`, and repeated caller-body rewrites over artifact-sized modules.
2. Preserve the existing selected-list semantics until a fact-driven queue proves equivalence; avoid using stale current-call facts to skip candidates that may become eligible after earlier selected rewrites.
3. Repeat traced artifact replay after any selected-def optimization and keep the pass-local `Starshine <= 2x Binaryen` target visible.

## Validation

- `moon test src/passes` failed before implementation and passed after implementation.
- `moon build --target native --release` completed with existing unused-helper warnings.
- Direct traced artifact replay completed and wrote `.tmp/dae011-dropped-result-detail-trace/starshine.wasm` plus stderr/stdout captures.
- `wasm-opt --all-features .tmp/dae011-dropped-result-detail-trace/starshine.wasm -o /tmp/dae011-dropped-result-detail-trace.validated.wasm` accepted the artifact with the existing large-local-count warning.
