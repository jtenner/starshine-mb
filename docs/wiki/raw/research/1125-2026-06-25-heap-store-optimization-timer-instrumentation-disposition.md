# Heap-store-optimization timer instrumentation disposition

## Question

Would lightweight HSO detail timers help attribute the remaining HSO-I allocation-heavy cost without distorting the timing lane?

## Answer

Not in the per-function form tested here. Adding `detail:hso:require-effects` and `detail:hso:process-root-region` timers inside `heap_store_optimization_run(...)` produced useful attribution for a single traced replay, but it also emitted two additional timing lines per function. On the 2000-function allocation-heavy fixture, that trace emission inflated the measured `pass:heap-store-optimization` total enough that the instrumentation itself would pollute the HSO-I timing target.

The timer patch was reverted before this note. Do not add per-function HSO detail timers to the committed pass-local timing lane unless the perf system gains an aggregate-only detail timer mode or the HSO-I target is measured without trace-output overhead.

## Trial shape

Temporary source-only experiment:

- wrapped `pass_require_effects(ctx, func)` with `detail:hso:require-effects`;
- wrapped the root `hso_process_region(...)` call with `detail:hso:process-root-region`;
- left behavior unchanged.

Focused behavior check:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `417/417` passed.

Native build:

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

## Attribution sample

Command:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-slice-b-detail-star-2000.wasm
```

Tail totals from `.tmp/hso-slice-b-detail-star-2000.stderr`:

| Timer | Total |
|---|---:|
| `detail:hso:require-effects` | `0.071ms` |
| `detail:hso:process-root-region` | `2.951ms` |
| `pass:heap-store-optimization` | `16.922ms` |

## Interpretation

The detail totals suggest the pure root-region body is not the whole traced pass-local wall cost, but the pass total is not comparable to the committed HSO-I medians because the two extra timer lines per function materially increase trace-output work.

This points to two next steps:

1. measure HSO internals with an aggregate-only mechanism, or a temporary local patch that is explicitly not compared against the normal traced target; and
2. continue treating committed HSO-I medians from `1122`/`1123` as the current reference until a non-distorting attribution method exists.

## Current status

- No source changes from the timer experiment were kept.
- HSO-I remains open at the committed `1122` best 2000-function median of `7.710ms` versus the `1120` Binaryen median of `1.28922ms`.
- HSO-J remains deferred until HSO-I is resolved, superseded with stronger evidence plus reopening criteria, or explicitly accepted by the user.
