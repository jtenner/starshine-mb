---
kind: concept
status: supported
last_reviewed: 2026-09-01
sources:
  - ../../../src/cmd/cmd.mbt
  - ../../../src/passes/perf.mbt
  - ../../../src/passes_perf_long/moon.pkg
  - ../../../src/passes_perf_long/directize_perf_test.mbt
  - ../../../src/passes_perf_long/heap_store_optimization_ordered_perf_test.mbt
  - ../../../src/passes_perf_long/merge_blocks_perf_test.mbt
  - ../../../src/passes_perf_long/remove_unused_brs_perf_test.mbt
  - ../../../src/passes_perf_long/reorder_globals_perf_test.mbt
  - ../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
  - ../../../src/passes_perf_long/tuple_optimization_perf_test.mbt
  - ../../../src/validate_trace/main.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/lib/util.mbt
  - ../../../scripts/lib/validate-task.ts
  - ../../../scripts/lib/self-optimize-compare-task.ts
related:
  - ./cli-command-and-dispatcher.md
  - ./validation-gates.md
  - ../validate/trace-benchmark-baseline.md
  - ../validate/module-validation-phases.md
  - ../../../src/passes/trace_golden_test.mbt
  - ../../../src/passes/optimize.mbt
---

# Tracing Playbook

## Overview

Starshine has three performance-observation surfaces that serve different jobs:

1. **Command / optimizer tracing** from the runtime CLI: `starshine --tracing <pass|phase|helper> ...`, `STARSHINE_TRACING`, or config `tracing` enable stderr lines prefixed with `[trace]`. This surface explains what the command read, which pass/debug steps it scheduled, what optimizer segment ran, and selected optimizer performance counters.
2. **Moon pass microbenchmarks** from `moon bench --release --target native src/passes_perf_long`. This surface uses MoonBit's calibrated `@bench.T` interface for stable synthetic pass workloads without putting long timing loops in `moon test`.
3. **Validator trace benchmarking** from `bun validate trace-benchmark ...` / `moon run src/validate_trace -- ...`. This surface runs fixed in-repo validator corpora and prints `phase_totals`, `helper_totals`, and `hotspots` blocks for regression triage.

Current tracing and benchmark ownership is grounded in the local command, optimizer-perf, Moon benchmark, validator-trace, wrapper, and test sources listed below. Use [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md) for runtime CLI precedence and debug-limit behavior, [`validation-gates.md`](./validation-gates.md) for `bun validate trace-benchmark` command syntax, and [`../validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md) for the fixed validator corpus map and baseline policy.

## Durable Rules

- Tracing must stay cheap when disabled. Timing reads, counters, dumps, and per-function trace setup stay behind local gates.
- Trace output is diagnostic evidence, not a stable public API. Keep it compact and machine-scannable, but do not promise exact wording beyond tests that intentionally pin command or pass contracts.
- Prefer `key=value` fields and short typed prefixes over prose. Existing prefixes include command/input lines, `pass[...]` lifecycle lines, `perf:*` optimizer lines, and validator `phase_totals` / `helper_totals` / `hotspots` lines.
- Wall-clock timings are host-local. Durable docs should cite phase movement, call counts, helper buckets, corpus shape, or pass-local comparisons before citing raw elapsed time; recorded Moon benchmark deltas must include the fixture shape, release target, Moon version, and host CPU.
- Build benchmark fixtures outside `it.bench(...)`, validate one preflight result, and prove the fixture remains reusable. A pass-local benchmark may disable repeated final-module validation only when its name and docs say so. Shared-IR benchmark optimizations must retain an exact fallback when an index is not built, and production attribution must check baseline/current output bytes before claiming a win.
- Do not add telemetry-only tests. If trace shape matters, extend an existing command, pass, benchmark, or golden-contract test that already proves behavior.
- Suppress or bound repeated failures instead of flooding output; trace should make repros easier to isolate, not hide the first useful signal.

## Command And Optimizer Trace Surface

`src/cmd/cmd.mbt` accepts only three trace levels:

| Level | Intended use | Current behavior |
| --- | --- | --- |
| `pass` | Pass queue and pass-local timing. | Good default for pass signoff, self-opt compare parsing, and `STARSHINE_OPTIMIZE_MAX_PASSES` prefix debugging. |
| `phase` | Compact optimizer progress checkpoints. | Emits pipeline checkpoints and one deduplicated `phase pass=<name>` line whenever the active pass changes; suppresses per-function lifecycle, skip, detail, and timer floods. This is the default self-opt watchdog channel. |
| `helper` | Helper-level detail. | Use sparingly for deep optimizer investigation; it can be noisy. |

Precedence follows the CLI dispatcher contract: explicit `--tracing` wins, then `STARSHINE_TRACING`, then config `tracing`. `STARSHINE_OPTIMIZE_MAX_PASSES=<n>` is a separate debug limiter that truncates the scheduled pass queue by prefix length, including `0` for decode/encode baselines, and emits a `pass_limit` trace line when active.

Command trace lines are written to stderr as:

```text
[trace] <message>
```

Current high-value command messages include:

- run setup: input count, explicit flags, optimize flags, scheduled/effective scheduled flag count, resolved options, trace mode, and effective pass flags;
- per-input flow: `start`, `read bytes=<n>`, `lowered bytes=<n>`, `decode done`, pass count, optimize start/done, encode byte count, and output write lines;
- debug steps: extract-functions, dump, print, and explicit validate start/done markers;
- validation safety: final validate and debug-serial post-encode validation markers.

Optimizer performance traces come from `src/passes/perf.mbt` through `HotPerfSession`:

```text
perf:timer name=<name> elapsed_us=<n> total_us=<n>
perf:checkpoint name=<name>
perf:counters label=<label> node_allocs=<n> child_span_allocs=<n> side_table_allocs=<n> region_splices=<n> cfg_builds=<n> dataflow_builds=<n> traversal_visits=<n>
perf:dump hot-func label=<label> ...
perf:dump cfg label=<label> entry=<id> exit=<id> exceptional=<id-or-> blocks=<n>
```

Timer lines are the pass-local timing source parsed by self-opt and compare tooling. Counter and dump lines are investigation aids; do not turn them into broad CI failure criteria without a focused contract.

### Paired wall-time attribution

Use the direct comparison tool's opt-in paired mode for `[WALL]001` work:

```text
bun scripts/self-optimize-compare.ts <input.wasm> \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --timing-only --wall-attribution --<pass>
```

The tool runs one traced Starshine process, one no-trace Starshine control, and Binaryen `--debug`; it records process wall time, verifies that traced and no-trace Starshine outputs are byte-identical, and reports signed tracing overhead instead of charging trace emission to optimizer work. Use one warmup plus three serial measured pairs for durable medians.

The attribution hierarchy is nested. **Do not sum parents and children together.** The useful boundaries are:

- process wall time contains process startup plus all input work;
- `cmd:input-total` contains exclusive command phases: read, text lowering, decode, pipeline setup, main pipeline, final validation, reuse check, encode, size portfolio, candidate selection, optional post-encode validation, and write;
- `cmd:main-pipeline` contains optimizer `pipeline` plus only a small command-dispatch remainder;
- optimizer `pipeline` contains hot code sections, module-pass stages, module rebuild, batch writeback, optional optimizer-owned final validation, and a residual scheduler bucket;
- `stage:hot-pass:code-section` contains `stage:hot-pass:function-total` plus outer-loop scheduling/result handling;
- `stage:hot-pass:function-total` contains raw admission, lift, `pass:<name>`, lower, pre-pass setup, post-pass bookkeeping, and the remaining unclassified function envelope;
- `stage:module-pass` owns successful module-pass execution including its pass-local timer and post-pass verification.

Aggregate `stage:hot-pass:pre-pass` and `stage:hot-pass:post-pass` lines use cumulative `total_us`; the parser consumes the latest total rather than summing repeated cumulative lines. Disabled tracing still avoids clock reads because command and optimizer timer starts remain behind existing trace/perf gates.

## Moon Pass Microbenchmark Surface

Run the dedicated long-performance package in native release mode:

```text
moon bench --release --target native src/passes_perf_long
```

For iteration speed, select one file:

```text
moon bench --release --target native \
  --package jtenner/starshine/passes_perf_long \
  --file directize_perf_test.mbt
```

The benchmark block receives `it : @bench.T` and calls `it.bench(fn() { ... })`. Setup outside that closure owns fixture construction and one validated trigger check. Current pass-local cases reuse immutable fixtures and disable only repeated final-module validation; they still execute registry dispatch and the pass implementation. The thirty-six-case suite covers Directize select lowering, ordered HeapStoreOptimization fail-closed candidates, HeapStoreOptimization allocation-only constructor sinking, MergeBlocks multivalue drop-parent indexing, RemoveUnusedBrs literal multivalue accounting, imported/dependency-chain ReorderGlobals ordering, SimplifyLocals raw multivalue and module-breadth paths, component HOT lift/lower attribution around the RUB, HSO, and 2,000-pair TupleOptimization fixtures, plus fourteen Vacuum cases. HSO measures lift plus direct descriptor execution for both ordered and allocation-sinking workloads. Vacuum separately measures flat guarded-hazard lift/direct-pass/lower/raw dispatch, depth-512 and depth-1024 singleton-wrapper raw cleanup, HOT lift/pass/lower plus registry dispatch for 4,096 dropped binary parents, candidate-free raw admission, 2,048-function constant result-`if` selection, and 2,048 unreachable-arm drop sinks; every registry lane proves its trace reason and output shape before timing.

These synthetic cases answer whether a specific algorithmic path improved. They do not replace the production-artifact/Binaryen wall-attribution lane, semantic parity, external validation, or runtime evidence. Keep benchmarks in `src/passes_perf_long`, not the default suite, and prefer framework statistics over handwritten warmup/median loops for new lanes.

## Validator Trace Benchmark Surface

The validation benchmark command is documented in [`validation-gates.md`](./validation-gates.md):

```text
bun validate trace-benchmark [--repeat n] [--corpus name]... [--target target] [--list-corpora]
```

The Bun wrapper forwards to:

```text
moon run --target <target> src/validate_trace -- --repeat <n> --corpus <name> ...
```

`src/validate_trace` defaults to all fixed corpora, deduplicates repeated corpus names, rejects unknown corpus names, and requires `phase_totals` plus `helper_totals` from `validate_module_with_trace(..., trace_all_funcs=true)`. Each corpus block is:

```text
corpus=<name> repeats=<n> elapsed_ms=<host-local total>
phase_totals <phase>_ms=<n> <phase>_calls=<n> ...
helper_totals body_ms=<n> body_calls=<n>
hotspots f<ordinal>:body=<us>:locals=<n>:top=<n> ...
```

Interpret `elapsed_ms` as operator context. Treat `phase_totals`, `helper_totals`, and hotspot shape as the durable regression signals. The fixed corpus definitions and refresh rules live in [`../validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md).

## Maintenance Checklist

When tracing changes:

1. Identify the lane: runtime CLI/optimizer trace, Moon pass microbenchmark, validator trace benchmark, or a deliberate combination.
2. Update source owners first: `src/cmd/cmd.mbt`, `src/passes/perf.mbt`, `src/validate_trace/main.mbt`, `src/validate/validate.mbt`, and wrapper tests as applicable.
3. Keep trace lines compact and grep-friendly; add new prefixes only when an existing one cannot carry the signal.
4. If the benchmark output contract changes, update [`../validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md), and [`validation-gates.md`](./validation-gates.md) together.
5. If `--tracing`, `STARSHINE_TRACING`, config precedence, or `STARSHINE_OPTIMIZE_MAX_PASSES` changes, update [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md) and command tests together.
6. If a pass begins relying on trace for parity evidence, cite the pass's functional tests and compare/signoff run first; cite trace as timing or triage support.

## Sources

- Archived tracing research: research note 0001
- Runtime command tracing: [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt), [`./cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md)
- Optimizer perf tracing: [`../../../src/passes/perf.mbt`](../../../src/passes/perf.mbt), [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Moon pass benchmarks: [`../../../src/passes_perf_long/moon.pkg`](../../../src/passes_perf_long/moon.pkg), [`../../../src/passes_perf_long/directize_perf_test.mbt`](../../../src/passes_perf_long/directize_perf_test.mbt), [`../../../src/passes_perf_long/heap_store_optimization_ordered_perf_test.mbt`](../../../src/passes_perf_long/heap_store_optimization_ordered_perf_test.mbt), [`../../../src/passes_perf_long/merge_blocks_perf_test.mbt`](../../../src/passes_perf_long/merge_blocks_perf_test.mbt), [`../../../src/passes_perf_long/remove_unused_brs_perf_test.mbt`](../../../src/passes_perf_long/remove_unused_brs_perf_test.mbt), [`../../../src/passes_perf_long/reorder_globals_perf_test.mbt`](../../../src/passes_perf_long/reorder_globals_perf_test.mbt), [`../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`](../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt), [`../../../src/passes_perf_long/tuple_optimization_perf_test.mbt`](../../../src/passes_perf_long/tuple_optimization_perf_test.mbt)
- Validator benchmark tracing: [`../../../src/validate_trace/main.mbt`](../../../src/validate_trace/main.mbt), [`../validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md)
- Shared timing helpers: [`../../../src/lib/util.mbt`](../../../src/lib/util.mbt)
