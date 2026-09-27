---
kind: concept
status: supported
last_reviewed: 2026-09-27
sources:
  - ../../../src/ir/hot_source_order.mbt
  - ../../../src/passes/dead_argument_elimination2.mbt
  - ../../../src/passes/dead_argument_elimination.mbt
  - ../../../src/passes/coalesce_locals.mbt
  - ../../../src/passes/inlining.mbt
  - ../../../src/passes/pass_manager.mbt
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/lib/optimizer-runtime-executor.ts
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
  --wasm-opt-bin .tmp/binaryen-version_132/bin/wasm-opt \
  --timing-only --wall-attribution --<pass>
```

The tool runs one traced Starshine process, one no-trace Starshine control, and Binaryen `--debug`; it records process wall time, verifies that traced and no-trace Starshine outputs are byte-identical, and reports signed tracing overhead instead of charging trace emission to optimizer work. An explicit `--starshine-bin` is used as supplied without an implicit Moon rebuild, so build and hash it before the campaign. Use one warmup plus three serial measured pairs for durable medians.

For several direct passes, use the checked-in campaign wrapper rather than hand-assembling independent medians:

```text
flock -w 3600 /tmp/starshine-perf-sweep-heavy.lock \
  bun pass-performance-sweep \
  --input <input.wasm> \
  --passes <pass-a,pass-b,...> \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version_132/bin/wasm-opt \
  --warmup 1 --samples 3 --out-dir <artifact-dir>
```

`pass-performance-sweep` brackets every requested-pass round with leading and trailing reference-pass commands, reversing requested-pass order on alternating rounds to reduce thermal and order bias. It rejects campaigns with fewer than one warmup or three measured rounds, refuses a pre-existing artifact directory, requires explicit Starshine and Binaryen binaries, verifies that the oracle reports version 132, and rejects a native binary older than current compiler sources. It pins both executable SHA-256 identities, the input, and a production-compiler source fingerprint before sampling; rechecks them at the end; preserves every underlying `self-optimize-compare` result; rejects traced/no-trace byte drift and cross-round Starshine or Binaryen raw-output drift, including the reference; and writes machine-readable `result.json` plus `summary.md` with raw samples, median±MAD command and bracket-adjusted measurements, pass-local and phase attribution, sizes, and canonical equality. A bracket-adjusted increment subtracts the mean of that round's two references and is noise context rather than a substitute for pass-local attribution or a causal before/after binary comparison. Use the default `strip-debug` reference only when the input is known not to carry debug payloads. The wrapper is serial internally; the outer `flock` prevents separate worktrees, builds, or campaigns from sharing the measured host interval. A timing set that overlapped an untracked heavy process is invalid and must be rerun in a fresh artifact directory.

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

## September 13, 2026 pass opportunity review

Four reporting-only agents each supplied one source-level candidate. The root
agent reviewed them, wrote bounded smoke checks, and ran all performance work
serially. The candidate inventory and decisions are:

| Candidate | Correctness argument | Decision |
| --- | --- | --- |
| Empty-label shortcut in `pass_compute_label_used` | With zero declared labels every target already fails the existing bounds check, so the result is the same empty bitset. | Retain. |
| Fewer-than-two-function-import shortcut in `die_run_module_pass` | A duplicate needs two function imports; this pass intentionally leaves non-function imports alone. The old unchanged path returns the original module. | Retain. |
| Lazy MergeLocals influence buckets | Share an immutable empty sentinel, replace it with a private nonempty bucket on its first get, then append in the original order. Source identities, candidate order, bucket contents, and rewrite decisions are unchanged. | Retain. |
| Skip impossible MergeBlocks local-dependency scans | Fewer than two roots or zero locals makes the existing predicate false. | **Not retained:** no attributable pipeline improvement established on the tested fixtures. |

The initial empty-label guard inside the scan regressed its nonempty-label
control by 12–14% across both paired campaigns. That placement failed the
control gate; the retained fast path belongs in the public wrapper, with the
private scan kept separate.

The rejected MergeBlocks prototype moved the 1,000-pair wide-block median from
3,155.97 to 3,044.52 microseconds (3.5%), while its unused-local control moved by
4.4%; the 100/4,000-pair cases moved by only 1.4%/1.0%. These results miss the
predeclared 5% acceptance target and do not isolate a useful effect. They do not
prove that the shortcut could never help a different workload. The original
MergeBlocks implementation is retained; its smoke check and benchmark remain
available for future investigations.

The [seventeen-case benchmark fixture](../../../src/passes_perf_long/opportunities_perf_test.mbt)
covers increasing sizes, structured-label and duplicate-import controls, dense
local reads, and MergeBlocks with/without an unused local. Each fixture is built
outside timing, validated in setup, checked for reuse, and consumed with
`Bench::keep`; pass pipeline timings explicitly exclude repeated final-module
validation. Benchmarks run only in the dedicated native-release benchmark lane.
A sibling-block exploratory fixture was discarded as an attribution probe
because its superlinear pipeline cost obscured the local scan; the retained fixture uses one wide block.

The [shared-helper](../../../src/passes/pass_common_test.mbt),
[import](../../../src/passes/duplicate_import_elimination_test.mbt),
[locals](../../../src/passes/merge_locals_test.mbt), and
[blocks](../../../src/passes/merge_blocks_test.mbt) smoke files passed all 110
checks both before and after the prototype. New checks cover mixed used/unused
labels, implicit returns, arithmetic folding, single-import references alongside
duplicate globals, sparse/repeated reads, target overwrites, and local-free or
singleton block roots. The host-local 5% performance acceptance test failed for
all four unchanged baseline cases before implementation.

Evidence uses Moon 0.1.20260904 / moonc v0.10.12+1634b282e, native release, on an
AMD Ryzen 7 8845HS. Three alternating baseline/candidate rounds each contain ten
calibrated Moon samples; reported values are medians of round medians. The
benchmark campaign holds `/tmp/starshine-perf-sweep-heavy.lock` and checks for
concurrent compiler/fuzzer jobs. It is synthetic pass/helper evidence, not a
whole-command or large-artifact throughput claim. The starting revision is
`3b2ceed92b2a5df754347add7f3ddbe70eb8aa82`; local commands, raw benchmark outputs, executable
hashes, the rejected patch, and the baseline executable are preserved under
`.tmp/pass-perf-opportunities-20260913/`.

### Final retained-change measurements

All three primary cases clear the predeclared 5% improvement target; both
unchanged-path controls clear the 10% regression limit. The nonempty-label
control is now within 0.05% of baseline after moving the guard to the wrapper.

| Workload | Baseline median (µs) | Final median (µs) | Speedup |
| --- | ---: | ---: | ---: |
| Label-free helper, 128 dropped constants | 0.96587 | 0.01494 | 64.65× |
| Label-free helper, 2,048 dropped constants | 15.13635 | 0.01534 | 986.99× |
| Label-free helper, 32,768 dropped constants | 247.52798 | 0.01651 | 14995.72× |
| Structured-label control, 2,048 dropped constants | 15.14893 | 15.15517 | 1.00× |
| No function imports, 32 definitions | 3.34611 | 0.01051 | 318.51× |
| No function imports, 512 definitions | 38.06136 | 0.01082 | 3517.25× |
| No function imports, 4,096 definitions | 292.00491 | 0.01066 | 27402.68× |
| One function import, 4,096 definitions | 346.41965 | 0.01109 | 31230.36× |
| Two duplicate imports, 4,096 definitions | 448.74521 | 446.97347 | 1.00× |
| MergeLocals, 100 padding pairs | 9.00469 | 5.02299 | 1.79× |
| MergeLocals, 1,000 padding pairs | 69.66936 | 31.30303 | 2.23× |
| MergeLocals, 10,000 padding pairs | 726.29316 | 312.21371 | 2.33× |
| MergeLocals dense-read control, 1,000 pairs | 76.55509 | 38.95978 | 1.96× |

The enormous ratios are confined to helpers/no-op module cases whose scans and
setup disappear entirely; they are not predictions for whole optimizer runs.
The final native benchmark binary and baseline hashes, all 78 paired sample
summaries, and acceptance checks are in `final-paired-results.json`,
`final-pairs/`, and `final-acceptance.json` under the local evidence directory.
Reproduce fixture measurements with:

```sh
moon bench --release --target native --package jtenner/starshine/passes_perf_long --file opportunities_perf_test.mbt
```

### Test validation

The final source passes `moon info`, `moon fmt`, all **110** focused default-target
checks, and the full **11,573-test Wasm-GC suite**. No `.mbti` public API changed.
Two preliminary broad default-target runs were interrupted while refining the
benchmark/guard placement; they are not claimed as completed full-suite checks.
The completed full-suite evidence is `final-wasm-gc-tests.log`.

### Generated regression evidence — verified Binaryen 132

Each lane requests and compares 10,000 GenValid cases at seed `0x5eed`, using its
existing dedicated aggregate, a freshly built explicit native CLI/generator,
`--jobs auto --max-subprocesses 8` (eight workers), and at most 20 mismatch
bundles. No wasm-smith lane or cleanup normalizer was enabled. The exact argument
arrays are in `fuzz-commands.json`; each lane retains its manifest and result.

| Pass / profile | Compared | Normalized | Cleanup-normalized | Residual mismatches | Baseline/current byte matches | Binaryen cache hits/misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `duplicate-import-elimination` / `duplicate-import-elimination` | 10000 | 8368 | 0 | 1632 | 10000 | 9983/17 |
| `merge-locals` / `merge-locals-all` | 10000 | 9353 | 0 | 647 | 10000 | 8739/1261 |
| `merge-blocks` / `merge-blocks-all` | 10000 | 7007 | 0 | 2993 | 10000 | 9992/8 |
| `precompute` / `precompute-all` | 10000 | 3238 | 0 | 6762 | 10000 | 10000/0 |

All four configured lanes have zero generator, command, output-validation, and
property failures; command-failure classes and Binaryen failure caches are empty.
Optional runtime/property execution was not enabled. A separate eight-worker
replay proves **40,000/40,000 baseline/current outputs byte-identical**; Starshine
outputs were freshly generated, not cached. This establishes no output regression
on these corpora; it does not by itself prove equivalence to Binaryen.

The three non-Precompute lanes use independent `wasm-tools` validation.
Precompute uses Binaryen validation for all 10,000 cases. A separate fresh-output
check with `wasm-tools 1.251.0` independently accepts **9,551**, and all **449**
rejections say `invalid atomic consistency ordering 2`. This is the existing
[validator capability limitation](../ir2/architecture-rules.md#september-13-generated-verification),
not a new output difference. Binaryen validation is not independent validation.
The exact rejected cases remain in `precompute-independent-validation.json`.

Agent judgment from inspected retained diffs: the observed canonical cleanup
families are existing Starshine wins—DIE removes a loop with no backedge around
one call; MergeLocals removes a write to a local that is never read while keeping
the branch condition; MergeBlocks removes empty-arm `nop`s; Precompute removes
`nop`s or replaces `drop(local.tee x value)` with `local.set x value`. These
contracts preserve execution/effect order and remove redundant operations. The
canonical size deltas below support those inspected-family judgments; size alone
is not their semantic justification. Uninspected residuals receive no new
semantic-safety approval here and remain parity work unless separately resolved
in the pass dossiers. This performance review does not reclose pass parity.
Raw encoding differences also remain separate, unchanged parity work.

| Pass | Raw bytes Starshine / Binaryen | Canonical bytes Starshine / Binaryen |
| --- | ---: | ---: |
| `duplicate-import-elimination` | 1072354 / 995744 | 990848 / 995744 |
| `merge-locals` | 470740 / 467324 | 466030 / 467324 |
| `merge-blocks` | 547320 / 541342 | 535356 / 541342 |
| `precompute` | 972416 / 979178 | 972416 / 979178 |

Every lane has zero canonical size-losing cases. Selected leaf counts follow;
leaf names below omit the explicitly stated common prefix:

- `duplicate-import-elimination` (prefix `duplicate-import-elimination-`): `functions` 1632, `identity` 1684, `legacy-eh` 3361, `module-code` 1678, `nonfunction` 1645.
- `merge-locals-all` (prefix `merge-locals-`): `control` 640, `forward` 674, `forward-multiple` 653, `legacy-eh` 709, `merge-boundary` 681, `nested-copies` 717, `partial-influence` 683, `reverse` 638, `reverse-boundary` 646, `reverse-rollback` 665, `rollback` 688, `tee` 624, `trivial-confusion` 647, `type-boundary` 652, `unreachable` 683.
- `merge-blocks-all` (prefix `merge-blocks-`): `effect-order` 1998, `eh-atomic` 1990, `expression` 2993, `structural` 3019.
- `precompute-all` (prefix `precompute-`): `control` 880, `direct-prefix-watch` 472, `drop-cleanup` 912, `effect-boundary` 883, `effectful-values` 868, `gc-atomic-boundary` 449, `gc-values` 959, `global` 946, `propagate-local-facts` 1354, `scalar` 919, `scalar-values` 1358.

Baseline CLI SHA-256:
`02a8c0257b262d3f1a81bc1ccaffe6da72a0f641de58345aa7953fa2ea3a138d`.
Final CLI SHA-256:
`e45d0d041b13277f4df49cde607d0d78ca86a9b97e4c4804f587676a9cdefda4`.
The verified oracle is `.tmp/binaryen-version_132/bin/wasm-opt`; its hash and the
fresh generator hash are recorded in `final-tools.sha256` and lane toolchains.

## September 13, 2026 second pass opportunity review

Four reporting-only reviewers inspected shared scheduling, module passes,
locals/control, and expression passes. They made no changes and ran no tests,
builds, benchmarks, or fuzzers. The root agent selected and evaluated the
following four candidates serially against the starting dirty worktree; the
first review's three retained optimizations above remain part of both baselines.

| Candidate | Mechanism and preservation argument | Decision |
| --- | --- | --- |
| Vacuum constant-if guard order | Reject nonconstant conditions before scanning all nodes for label uses. Both predicates are read-only; retain child-count and branch-target checks. | Retain. |
| MemoryPacking parameter-count index | Flatten only the referenced type prefix once, including nonfunction slots; preserve singleton lookup and zero fallback for absent, recursive, or invalid indices. | Retain. |
| Untee declaration-run scan | Inspect each nonempty run once and stop at the first nonnullable reference. Zero-count runs must not enable initialization preservation. | Retain. |
| LocalCSE stable window compaction | Replace temporary survivor arrays with ordered in-place compaction. | Reject: no demonstrated pass-local gain. |

The LocalCSE review initially proposed 128–512-expression windows, but
`lcse_raw_rewrite_instrs` returns unchanged above 16 instructions. Root review
corrected that unreachable experiment to 16/128/512 functions containing
10-instruction windows with reuse across an unrelated local write. Three paired
rounds measured 27.981→26.991 µs, 218.414→218.501 µs, and 870.349→879.328 µs.
The largest primary case regressed 1.0%, missing the predeclared 5% improvement
gate. Its production change was removed; its smoke coverage, benchmark fixtures,
and local rejected patch remain available. No claim is made that compaction
cannot help another workload.

Other reviewer hypotheses—DAE callee membership tracking, ReorderGlobals name
sorting, SSA write-target lookup, and OptimizeCasts child-span iteration—were
not selected or benchmarked. They remain source hypotheses, not measured wins.

The dedicated [benchmark file](../../../src/passes_perf_long/review2_perf_test.mbt)
constructs fixtures outside timing, validates public-pipeline preflight results,
asserts transformations where expected, and checks reuse and determinism.
Module-pass measurements exclude repeated final validation. Vacuum measures
repeated direct HOT execution on an unchanged function, excluding lift/lower;
it does not claim scheduler or whole-command speedups. Large ratios are specific
to removing quadratic declaration/type scans and repeated negative label scans.
The benchmark suite remains outside default `moon test`.

Smoke tests guard [filter survivor order](../../../src/passes/local_cse_filter_wbtest.mbt),
[mixed recursive type flattening](../../../src/passes/memory_packing_wbtest.mbt),
[zero/nonzero nonnullable declaration groups](../../../src/passes/untee_test.mbt),
and [dynamic versus constant branch effects](../../../src/passes/pass_manager_wbtest.mbt).
All four checks passed before and after the prototype; the host-local 5%
performance gate failed on the unchanged baseline before implementation.

The retained source passes `moon info`, `moon fmt`, and all **11,577 tests** in
`moon test --target wasm-gc`, with no public `.mbti` change. The preceding default
linear-Wasm test run was interrupted during the passes package and is not claimed
as a completed check; `final-wasm-gc-tests.log` is the completed full-suite evidence.

All local evidence is under `.tmp/pass-perf-review2-20260913/`: the starting dirty
patch and four original sources, baseline CLI, calibrated benchmark executables,
three alternating rounds with ten samples each, gate results, rejected LocalCSE
patch, validation logs, runtime fixtures, and exact fuzz argument arrays. Timings
use native release, Moon 0.1.20260904 / moonc v0.10.12+1634b282e, and an AMD Ryzen 7
8845HS. The paired runner holds `/tmp/starshine-perf-sweep-heavy.lock` and refuses
samples alongside compiler/fuzzer jobs. They are synthetic local measurements,
not Binaryen pass-local or production-artifact throughput claims.

### Final retained-change measurements

Medians below are medians of three round medians. All three primary cases clear
the 5% improvement gate; small cases and all three unchanged LocalCSE controls
clear the 10% regression limit.

| Workload | Baseline (µs) | Retained (µs) | Speedup |
| --- | ---: | ---: | ---: |
| untee runs count=16 | 0.414 | 0.214 | 1.93× |
| untee runs count=1024 | 511.351 | 2.402 | 212.84× |
| untee runs count=4096 | 7534.503 | 8.714 | 864.61× |
| untee grouped count=100000 | 634.592 | 0.184 | 3446.21× |
| memory-packing count=16 | 2.414 | 2.199 | 1.10× |
| memory-packing count=1024 | 1010.927 | 109.576 | 9.23× |
| memory-packing count=4096 | 14874.387 | 462.489 | 32.16× |
| local-cse count=16 | 27.890 | 28.194 | 0.99× |
| local-cse count=128 | 213.847 | 215.484 | 0.99× |
| local-cse count=512 | 872.981 | 854.520 | 1.02× |
| vacuum dynamic ifs=16 (direct HOT) | 12.940 | 8.654 | 1.50× |
| vacuum dynamic ifs=128 (direct HOT) | 336.320 | 63.519 | 5.29× |
| vacuum dynamic ifs=512 (direct HOT) | 4597.365 | 247.560 | 18.57× |

Reproduce with `moon bench --release --target native --package jtenner/starshine/passes_perf_long --file review2_perf_test.mbt`. The paired artifact includes executable SHA-256 identities and every underlying sample.

### Runtime smoke evidence

Three Node 26.8.2 fixtures validate and execute original, baseline, and retained
outputs. Untee preserves results for zero, positive, and negative inputs; Vacuum
preserves dynamic and constant-branch import-call counts; MemoryPacking preserves
all 34 copied bytes and an out-of-bounds destination trap. All observations and
baseline/current output bytes match. `runtime-smoke.mjs`, `.json`, and the WAT /
Wasm fixtures are preserved in the local evidence directory. These are bounded
runtime checks, separate from the generated structural comparisons below.

### Generated regression evidence — verified Binaryen 132

Four separate 10,000-case GenValid lanes use seed `0x5eed`, a freshly built
explicit native Starshine CLI, the pinned prebuilt native generator, and the
verified `.tmp/binaryen-version_132/bin/wasm-opt` oracle. Each uses
`--jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20`, with eight case
workers; lanes and all performance work are serial. No wasm-smith lane, cleanup
normalizer, or optional generated runtime/property execution was enabled.
Independent `wasm-tools 1.251.0` validation passes every generated output.

| Pass / profile | Compared | Normalized | Cleanup-normalized | Residuals | Baseline/current byte matches | Binaryen cache hits/misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `vacuum` / `vacuum` | 10000 | 7830 | 0 | 2170 | 10000 | 10000/0 |
| `memory-packing` / `memory-packing-all` | 10000 | 7288 | 0 | 2712 | 10000 | 6557/3443 |
| `untee` / `ordinary GenValid` | 10000 | 10000 | 0 | 0 | 10000 | 2/9998 |
| `local-cse` / `ordinary GenValid` | 10000 | 10000 | 0 | 0 | 10000 | 10000/0 |

All four lanes have zero generator, output-validation, command, and configured
property failures, with empty command-failure classes and zero Binaryen failure
cache hits/misses. Separate fresh-output replay proves **40,000/40,000 exact
baseline/current byte matches**. Starshine outputs were not cached. This is
regression evidence against the starting worktree, not pass-wide Binaryen parity
closeout or execution of all 40,000 generated modules.

Residual classifications are agent judgments, not harness conclusions:

- The 20 retained Vacuum diffs contain only removal of one or two inert `nop`s,
  saving one or two canonical bytes; those inspected specimens are size wins.
  The complete lane is 2,170 smaller and 7,830 equal canonical outputs, saving
  3,250 bytes overall. Uninspected residuals receive no new blanket semantic
  approval here; existing pass-dossier classifications remain separate.
- MemoryPacking reproduces the exact documented [September 12 v132 counts and
  sizes](../binaryen/passes/memory-packing/fuzzing.md#september-12-2026-size-parity-follow-up):
  1,382 smaller active-segment checks (-8,292 canonical bytes), 7,288 equal
  outputs, and 1,330 larger Memory64 preflights (+57,190 bytes). The retained
  samples match those families. These are the dossier's existing correctness
  wins, including a size cost: its source/runtime evidence establishes that
  dropping the complete destination preflight allows partial writes before a
  trap. Validation or size alone is not the classification basis. The new
  parameter-count index changes none of these outputs.
- Untee and the unchanged LocalCSE control both normalize all 10,000 cases.

Selected leaf counts are recorded here for reproducibility:

- `vacuum`: `vacuum-terminal-unreachable` 1160, `vacuum-constant-result-if` 1161, `vacuum-call-prefix-continuation` 1138, `vacuum-dropped-parent-effects` 1124, `vacuum-core` 2179, `vacuum-structural-wrappers` 1068, `vacuum-hazard-boundary` 1080, `vacuum-localset-prefix-preserve` 1090.

- `memory-packing`: `memory-packing-segment-ops` 1382, `memory-packing-boundaries` 709, `memory-packing-active-ranges` 2010, `memory-packing-active-traps` 1284, `memory-packing-passive-splits` 2021, `memory-packing-defined-overlap` 1264, `memory-packing-memory64` 1330.

- `untee`: `binaryen-oracle-portable` 10000.

- `local-cse`: `binaryen-oracle-portable` 10000.

Baseline CLI SHA-256: `e45d0d041b13277f4df49cde607d0d78ca86a9b97e4c4804f587676a9cdefda4`.

Retained CLI SHA-256: `fd8c2c644d0fd1f845233b1d34d5ce00d2acac6e20c9dad2d2b23753d623bf82`.

Exact arguments, tool identities, manifests, raw results, cache counters, and byte
replays are preserved in `fuzz-commands.json`, `final-tools.json`, `fuzz-summary.json`,
and the four lane directories under the local evidence root.


## September 26, 2026 pass-time allocation and indexing renewal

This renewal addresses the active pass-time backlog with eleven separately committed
changes. Each was developed with a bounded failing cost regression, behavior
assertions and focused native benchmarks; full generated campaigns were deferred
until implementation was complete. Long benchmark workloads remain outside the
default suite. The starting and final binaries include the same pre-existing
uncommitted work; those unrelated changes are excluded from these commits.

| Unit | Change and preserved contract | Focused native evidence |
| --- | --- | --- |
| `40a5a58ad` | Reuse source-order dependency scratch and clear touched nodes; preserve consumer order. | 4,096-node fixture: 128.75 → 9.54 µs. |
| `49856fe7c` | Cache DAE2 local-flow queries by actual block/local queries, index last writes and reuse solver workspaces; preserve joins, loops and exception flow. | 256 cross-block queries: 2.81 ms → 1.47 ms. |
| `35f258934` | Summarize structured call-result lifetimes once per subtree; retain overwrite capture and independent immediate `if` arms. | 256 captures: 881.46 → 37.14 µs. |
| `ac076cd17` | Collect inlining body shape and size in one traversal; retain tail-under-try decisions. | 512 blocks: 12.98 → 2.66 µs. |
| `fc759d546` | Index exact DAE forwarding edges and reuse resolved signatures; preserve edge order and tail-call flags. | 256-callee construction: 324.94 → 284.07 µs; 128-callee control essentially flat. |
| `586d84f6b` | Reuse stable operand evidence inside a DAE parameter-analysis batch; still prove each constant independently. | 128 calls / 16 parameter queries: 591.97 → 178.80 µs. |
| `1bc4f3ebc` | Index future source roots by subtree minimum; keep suffix rejection, two consumer phases and the dense direct path. | 64 queries / 1,024 roots: 3.63 ms → 13.69 µs; dense control flat. |
| `5457fbd8b` | Scatter Coalesce interference and copy weights into assigned slots; preserve parameter slots, type checks and first-slot ties. | 2,048 sparse locals: 5.92 ms → 77.41 µs; 128-local clique 59.63 → 42.19 µs. |
| `dde57cee2` | Reuse DAE dependencies within one boundary snapshot; invalidate on every full/lightweight snapshot adoption. | Three warm 128-callee queries: 378.18 µs rebuilding → 27.90 ns cached, excluding the initial build. |
| `b599af087` | Prefer current DAE callsite facts for uniform proofs; retain body-scan fallback for shifted active paths and share reference-constant materialization. | 512 calls: 258.93 → 95.20 µs. |
| `5e8666521` | Build structured lifetime summaries only when a preceding capture needs them; preserve nested hazards and overwrite captures. | 512 capture-free bodies: 72.86 → 4.05 µs; same-binary late-hazard control 71.84 → 4.20 µs. |

These are helper measurements, not whole-pass speedup claims. Implementation,
red-first fixtures, controls and command-entrypoint coverage are linked from the
[Coalesce strategy](../binaryen/passes/coalesce-locals/starshine-strategy.md),
[DAE strategy](../binaryen/passes/dead-argument-elimination/starshine-strategy.md),
[DAE2 strategy](../binaryen/passes/dae2/starshine-strategy.md),
[inlining strategy](../binaryen/passes/inlining/starshine-strategy.md),
[optimizing-inlining strategy](../binaryen/passes/inlining-optimizing/starshine-strategy.md),
[SimplifyGlobals strategy](../binaryen/passes/simplify-globals-optimizing/starshine-strategy.md)
and [SimplifyLocals frontier](../binaryen/passes/simplify-locals/performance-and-artifact-frontiers.md).

Final `moon info` and `moon fmt` succeed; `moon test` passes **12,504/12,504** tests.
The public `.mbti` snapshot is unchanged relative to the starting worktree.
The measurement-tool checks pass **15/15** tests with 49 assertions.
Local evidence is under `.tmp/pass-perf-work-20260926/`; the completed full-suite
log is `final4-tests.log`. Intermediate or contended timing runs are not final
performance evidence.

### Fixed-artifact measurements

Native release on an AMD Ryzen 7 8845HS, Moon 0.1.20260920 / moonc
v0.10.14+7d59c7ec9. Small input: 192,893 bytes / 45 functions; large:
6,211,596 bytes / 12,904 functions. Each lane uses one warmup and three
measured rounds. Paired starting/current executions alternate order and compare
pipeline timers; the separate verified-v133 sweep brackets references and records
command, pass, phase, median/MAD and canonical-size evidence. Detected competing
CPU activity invalidates an attempt; rejected attempts remain in the local ledger.

All **27 paired pass/fixture combinations** have identical starting/current and
untraced/traced output bytes; outputs validate with `wasm-tools 1.251.0`.
Pipeline timing includes the surrounding optimizer work. The pass-local columns
are inner pass timers from a separate run, not the paired pipeline samples.
For HOT passes they exclude lift/lower and other function processing; a zero
precompute inner timer does not mean a zero-cost pipeline. Do not use these
inner ratios alone to claim a whole-pipeline win.

#### Small input

| Pass | Starting pipeline ms | Current pipeline ms | Change | Current inner pass ms | Binaryen 133 pass ms | Inner ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `coalesce-locals` | 14.309 | 13.474 | -5.8% | 13.747 | 5.260 | 2.61× |
| `dae2` | 18.306 | 18.409 | +0.6% | 18.347 | 1.145 | 16.02× |
| `dae` | 72.269 | 60.532 | -16.2% | 53.659 | 0.658 | 81.50× |
| `dae-optimizing` | 161.606 | 151.215 | -6.4% | 150.122 | 7.631 | 19.67× |
| `inlining` | 14.309 | 14.022 | -2.0% | 13.316 | 2.443 | 5.45× |
| `inlining-optimizing` | 132.981 | 134.017 | +0.8% | 134.366 | 44.749 | 3.00× |
| `simplify-globals-optimizing` | 23.612 | 23.758 | +0.6% | 26.021 | 1.391 | 18.71× |
| `simplify-locals` | 6.926 | 7.268 | +4.9% | 0.466 | 1.779 | 0.26× |
| `simplify-locals-notee` | 3.433 | 3.449 | +0.5% | 0.903 | 1.679 | 0.54× |
| `simplify-locals-nonesting` | 8.139 | 7.125 | -12.5% | 2.357 | 1.639 | 1.44× |
| `simplify-locals-nostructure` | 3.406 | 3.312 | -2.8% | 0.338 | 1.777 | 0.19× |
| `simplify-locals-notee-nostructure` | 2.365 | 2.026 | -14.3% | 0.164 | 1.605 | 0.10× |
| `precompute` | 1.987 | 1.909 | -3.9% | 0.000 | 1.316 | 0.00× |
| `precompute-propagate` | 6.701 | 6.684 | -0.3% | 2.451 | 2.419 | 1.01× |
| `code-pushing` | 3.992 | 3.475 | -13.0% | 1.532 | 0.264 | 5.80× |

#### Large input

| Pass | Starting pipeline ms | Current pipeline ms | Change | Current inner pass ms | Binaryen 133 pass ms | Inner ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `coalesce-locals` | 7,729.913 | 6,579.083 | -14.9% | 6,481.083 | 1,111.400 | 5.83× |
| `dae2` | 6,509.114 | 6,199.251 | -4.8% | 6,188.786 | 396.240 | 15.62× |
| `dae` | 809.602 | 813.780 | +0.5% | 792.980 | 379.708 | 2.09× |
| `dae-optimizing` | 1,015.607 | 1,020.295 | +0.5% | 1,009.805 | 1,603.930 | 0.63× |
| `inlining` | 3,726.517 | 3,529.230 | -5.3% | 3,502.376 | 811.036 | 4.32× |
| `inlining-optimizing` | 687.485 | 599.857 | -12.7% | 581.038 | 14,101.400 | 0.04× |
| `simplify-globals-optimizing` | 56.012 | 56.293 | +0.5% | 38.536 | 1,046.870 | 0.04× |
| `simplify-locals` | 2,165.455 | 2,182.827 | +0.8% | 93.465 | 1,060.360 | 0.09× |
| `simplify-locals-notee` | 2,605.392 | 2,576.374 | -1.1% | 890.732 | 792.178 | 1.12× |
| `simplify-locals-nonesting` | 3,551.611 | 3,511.752 | -1.1% | 607.333 | 782.110 | 0.78× |
| `simplify-locals-nostructure` | 747.228 | 754.059 | +0.9% | 46.427 | 960.342 | 0.05× |
| `simplify-locals-notee-nostructure` | 347.491 | 339.428 | -2.3% | 27.473 | 772.212 | 0.04× |

The optional large precompute control exceeded two minutes during its first
baseline warmup and was stopped. Large precompute, precompute-propagate and
CodePushing oracle/control timings are therefore unmeasured in this renewal;
all three retain focused helper/small-input coverage and final aggregate fuzzing.
The interrupted control and earlier checkpoint or contended runs are excluded
from the tables above.

Large Coalesce improves **14.9%** (7,729.913 → 6,579.083 ms), large optimizing
inlining **12.7%** (687.485 → 599.857 ms), and small DAE **16.2%**
(72.269 → 60.532 ms) in these final paired medians. Small optimizing DAE
improves 6.4%; large DAE2 and plain inlining improve 4.8% and 5.3%.
Other owners remain flat or slower: small full SimplifyLocals is +4.9%, and
large no-structure is +0.9% (the earlier confirmation was +3.7%). These are
open timing follow-ups, not accepted speedups.

Changes of only a few percent are not claimed as material wins. Focused helper
gains establish benefits for their specific shapes; they do not establish an
across-the-board artifact improvement. The pass-time backlog remains open.

#### Remaining large SimplifyLocals cost

Component medians below come from the v133 sweep. They need not sum exactly
because each component has its own median. The function-overhead column exposes
work outside the inner HOT pass, including unattributed function processing.

| Variant | Pipeline ms | Inner pass ms | Lift ms | Lower ms | Function overhead ms | Writeback ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `simplify-locals` | 2,200.047 | 93.465 | 46.738 | 65.972 | 1,780.340 | 133.698 |
| `simplify-locals-notee` | 2,619.119 | 890.732 | 170.842 | 935.683 | 464.307 | 117.900 |
| `simplify-locals-nonesting` | 3,507.021 | 607.333 | 2,271.501 | 234.153 | 311.144 | 59.659 |
| `simplify-locals-nostructure` | 775.558 | 46.427 | 40.331 | 34.656 | 503.835 | 76.936 |
| `simplify-locals-notee-nostructure` | 365.844 | 27.473 | 21.774 | 14.212 | 197.187 | 33.616 |

The timing backlog remains open: initial lifting, required local-flow/CFG work,
Coalesce interference construction, DAE call facts, inlining profitability/body
copying and unchanged-function processing still need work. Recovering guarded
cleanup breadth requires path-sensitive lifetime proof; skipping useful cleanup
is not accepted as a performance improvement. Canonical size deficits remain:

| Input | Pass | Canonical bytes above Binaryen 133 |
| --- | --- | ---: |
| small | `inlining-optimizing` | +461 |
| small | `simplify-locals` | +19 |
| small | `simplify-locals-notee` | +163 |
| small | `simplify-locals-nonesting` | +123 |
| small | `simplify-locals-nostructure` | +240 |
| small | `simplify-locals-notee-nostructure` | +253 |
| large | `coalesce-locals` | +90,915 |
| large | `dae-optimizing` | +41,427 |
| large | `inlining-optimizing` | +933,016 |
| large | `simplify-globals-optimizing` | +173,229 |
| large | `simplify-locals` | +428,416 |
| large | `simplify-locals-notee` | +424,183 |
| large | `simplify-locals-nonesting` | +330,873 |
| large | `simplify-locals-nostructure` | +508,709 |
| large | `simplify-locals-notee-nostructure` | +519,913 |

All these fixed-artifact deficits predate the retained changes, because the
paired raw outputs are identical. Faster guarded optimizing modes do not close
output-quality gaps; a smaller output alone also does not prove semantic parity.

Paired reports: `final4-pairs-{small,large}/result.json`. Accepted oracle paths
and rejected attempts: `final4-sweeps.json`; each accepted directory has full
`result.json`, per-sample results and `summary.md`. Input and binary identities:
`final4-tool-identities.json`, the paired reports and `final4-cli-hash.txt`.
`final4-artifact-audit.json` confirms every accepted oracle sample matches
its paired raw output and the frozen tool hashes. The interrupted large
attempts in `final4-pairs-large-interrupted/` are excluded from final medians.

Starting CLI SHA-256: `f7fb87fb1a66416d87a018b78fcd8fddf2f58a110d77f982c56434cd1a3bbaf9`.

Retained CLI SHA-256: `da5f112b6bbf092476d2d6ac6694128e19adca3d288003526ab01c3e0b0bfcbb`.

Native generator SHA-256: `550b7952755eab745cd43dd78b8ec1a106a88200bc13f8e225480634e50c5a37`.

Verified Binaryen 133 SHA-256:
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.

### Final generated correctness campaign

The frozen final CLI completes **170,000 comparisons: 17 lanes of 10,000**
at seed `0x5eed`, including DAE2 open/closed worlds and its optimizing mode.
Every lane uses its documented GenValid aggregate, explicit freshly built native
CLI/generator binaries, verified Binaryen 133, `--jobs auto`, at most eight
subprocesses and at most 20 retained mismatch artifacts. Inputs and Starshine
outputs receive independent `wasm-tools` validation; Node-v2 supplies the
runtime observations. GenValid supplies all inputs. The campaign keeps existing
residuals visible while continuing to the full comparison count; mismatch
reduction is disabled.

| Lane | GenValid profile | Canonical matches | Cleanup-normalized | Residuals | Canonically larger | Star/original runtime matches | Original-runtime blocked |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `coalesce-locals` | `coalesce-locals-all` | 3,750 | 5,000 | 1,250 | 0 | 8,750 | 1,250 |
| `dae2` | `dae2` | 2,879 | 667 | 6,454 | 0 | 9,312 | 688 |
| `dae2-closed` | `dae2` | 0 | 100 | 9,900 | 706 | 9,312 | 688 |
| `dae2-optimizing` | `dae2` | 2,233 | 0 | 7,767 | 0 | 9,312 | 688 |
| `dae` | `dead-argument-elimination` | 3,750 | 0 | 6,250 | 0 | 10,000 | 0 |
| `dae-optimizing` | `dae-optimizing` | 5,153 | 0 | 4,847 | 0 | 10,000 | 0 |
| `inlining` | `pass-inlining` | 10,000 | 0 | 0 | 0 | 10,000 | 0 |
| `inlining-optimizing` | `inlining-optimizing-all` | 10,000 | 0 | 0 | 0 | 10,000 | 0 |
| `simplify-globals-optimizing` | `simplify-globals-optimizing-all` | 5,055 | 0 | 4,945 | 0 | 10,000 | 0 |
| `simplify-locals` | `simplify-locals-all` | 380 | 0 | 9,620 | 0 | 10,000 | 0 |
| `simplify-locals-notee` | `simplify-locals-notee-all` | 0 | 0 | 10,000 | 0 | 10,000 | 0 |
| `simplify-locals-nonesting` | `simplify-locals-nonesting-all` | 5,026 | 0 | 4,974 | 0 | 10,000 | 0 |
| `simplify-locals-nostructure` | `simplify-locals-nostructure-all` | 0 | 0 | 10,000 | 1,662 | 10,000 | 0 |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure-all` | 0 | 0 | 10,000 | 0 | 10,000 | 0 |
| `precompute` | `precompute-all` | 3,238 | 6,762 | 0 | 0 | 9,551 | 449 |
| `precompute-propagate` | `precompute-all` | 2,766 | 7,234 | 0 | 0 | 9,551 | 449 |
| `code-pushing` | `code-pushing-all` | 4,493 | 5,507 | 0 | 513 | 10,000 | 0 |

All lanes report **zero validation, generator or command failures** and
**zero observed Starshine-versus-original semantic mismatches**.
These completed comparisons retain open parity gaps. Runtime matches above compare Starshine
with the original module; they do not all imply agreement with Binaryen.
These checks cover the deterministic observations that Node-v2 could execute;
original-runtime blocks remain unverified and cannot be counted as matches.

Normalization: DAE/DAE2 and optimizing SimplifyGlobals use `drop-consts` plus
`unreachable-control-debris`; Coalesce uses `local-cleanup-debris` plus
`unreachable-control-debris`; both precompute variants use all three; CodePushing
uses `local-cleanup-debris`; inlining and SimplifyLocals variants use none.
The `dae2-optimizing` oracle expands to `--dae2 --simplify-locals --vacuum`.

#### Replay and residual classification

Classifications here are reviewer judgments, not labels supplied by the harness.
Every saved residual and every canonically larger generated case was replayed
against the starting binary using the same optimizer/pass flags:

| Lane | Saved residuals byte-identical to starting CLI | All size-losing cases byte-identical |
| --- | ---: | ---: |
| `coalesce-locals` | 20/20 | 0/0 |
| `dae2` | 20/20 | 0/0 |
| `dae2-closed` | 20/20 | 706/706 |
| `dae2-optimizing` | 20/20 | 0/0 |
| `dae` | 20/20 | 0/0 |
| `dae-optimizing` | 20/20 | 0/0 |
| `simplify-globals-optimizing` | 20/20 | 0/0 |
| `simplify-locals` | 20/20 | 0/0 |
| `simplify-locals-notee` | 20/20 | 0/0 |
| `simplify-locals-nonesting` | 20/20 | 0/0 |
| `simplify-locals-nostructure` | 20/20 | 1662/1662 |
| `simplify-locals-notee-nostructure` | 20/20 | 0/0 |
| `code-pushing` | 0/0 | 513/513 |

Byte identity establishes that these replayed outputs predate the performance
changes. It does not prove equivalence to Binaryen or classify unsaved cases.
Residual output differences remain **open parity gaps**; canonically larger
cases remain **size-losing quality gaps**. CodePushing has 513 such cases in
`code-pushing-br-if-value` despite cleanup-normalized equality; normalization
does not erase the canonical size cost. No residual is accepted solely because
both outputs validate, because it is smaller, or because a bounded runtime
observation matches. The existing owner dossiers retain transform contracts and
detailed family investigations; no blanket Starshine-win classification is added.

#### Binaryen-side runtime coverage limits

Of **165,788 Starshine/original runtime matches**, **155,660** also match the
Binaryen observation. The other **10,128** cannot execute the Binaryen output
under the selected Node configuration. A complete scan of those saved reports
confirms complete Starshine/original matches and blocked Binaryen comparisons;
none records a differing Binaryen result. The harness labels these secondary
outcomes `binaryen-discrepancy` while its primary counter remains `semantic-match`.

| Lane | Binaryen-side runtime blocks | Recorded limit |
| --- | ---: | --- |
| `dae` | 1,250 | `exact-heap-types-disabled` |
| `simplify-locals` | 1,829 | `unsupported-import-encoding-0x7f` |
| `simplify-locals-notee` | 1,875 | `unsupported-import-encoding-0x7f` |
| `simplify-locals-nonesting` | 1,616 | `unsupported-import-encoding-0x7f` |
| `simplify-locals-nostructure` | 1,683 | `unsupported-import-encoding-0x7f` |
| `simplify-locals-notee-nostructure` | 1,875 | `unsupported-import-encoding-0x7f` |

The DAE cases report disabled exact heap types. The SimplifyLocals cases report
`unknown import kind 0x7f` when Node reads the Binaryen import encoding.
All 11 freshly reproduced representatives (one per affected lane/profile)
validate with `wasm-tools validate --features all`; their raw sizes also match the
campaign records. This focused check supplements the campaign’s input/Starshine
validation rather than claiming independent validation of every Binaryen output.
These are **tool/runtime coverage gaps**, not evidence of wrong Binaryen
results or a Starshine semantic win. Keep full three-way runtime
signoff open until a compatible runtime can execute these oracle outputs.

Evidence: `final4-binaryen-runtime-limits.json`,
`final4-oracle-runtime-validation.json`, the per-case observation
reports, and the original/Starshine/Binaryen comparison flow in
[`optimizer-runtime-executor.ts`](../../../scripts/lib/optimizer-runtime-executor.ts).

Original runtime limits and profile counts:

- `coalesce-locals`: `coalesce-locals-unreachable`: 625, `coalesce-locals-legacy-eh`: 625. Recorded reason categories: `instantiation-failure`: 1,250.
- `dae2`: `dae2-continuations`: 688. Recorded reason categories: `compile-failure`: 688.
- `dae2-closed`: `dae2-continuations`: 688. Recorded reason categories: `compile-failure`: 688.
- `dae2-optimizing`: `dae2-continuations`: 688. Recorded reason categories: `compile-failure`: 688.
- `precompute`: `precompute-gc-atomic-boundary`: 449. Recorded reason categories: `compile-failure`: 449.
- `precompute-propagate`: `precompute-gc-atomic-boundary`: 449. Recorded reason categories: `compile-failure`: 449.

Coalesce’s original instantiation traps prevent the export observation plan.
The DAE2 continuation and precompute GC-atomic cases require runtime features
not enabled in this campaign. These **4,212 original-runtime blocks** are
separate from the 10,128 Binaryen-side compilation blocks above.

Persistent cache counts (hits / misses):

| Lane | Binaryen output cache | Node-v2 observation cache |
| --- | ---: | ---: |
| `coalesce-locals` | 10,000 / 0 | 10,000 / 0 |
| `dae2` | 10,000 / 0 | 10,000 / 0 |
| `dae2-closed` | 10,000 / 0 | 10,000 / 0 |
| `dae2-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `dae` | 10,000 / 0 | 11 / 9,989 |
| `dae-optimizing` | 10,000 / 0 | 0 / 10,000 |
| `inlining` | 0 / 10,000 | 0 / 10,000 |
| `inlining-optimizing` | 10,000 / 0 | 0 / 10,000 |
| `simplify-globals-optimizing` | 10,000 / 0 | 0 / 10,000 |
| `simplify-locals` | 10,000 / 0 | 0 / 10,000 |
| `simplify-locals-notee` | 10,000 / 0 | 713 / 9,287 |
| `simplify-locals-nonesting` | 10,000 / 0 | 267 / 9,733 |
| `simplify-locals-nostructure` | 10,000 / 0 | 32 / 9,968 |
| `simplify-locals-notee-nostructure` | 10,000 / 0 | 5,128 / 4,872 |
| `precompute` | 10,000 / 0 | 0 / 10,000 |
| `precompute-propagate` | 10,000 / 0 | 8,174 / 1,826 |
| `code-pushing` | 10,000 / 0 | 0 / 10,000 |

Starshine outputs are always regenerated. Cached Node-v2 observations require
identical original/Starshine/Binaryen bytes, seed, policy and runtime identity.
Exact lane commands, exit status, elapsed time and report paths are in
`final4-fuzz-campaign.json`; each lane keeps
`result.json`, `cases.jsonl`, `toolchain.json`, selected-profile counts and runtime
observations under `final4-fuzz-<lane>/`. Baseline replay evidence is in
`final4-fuzz-retained-replay.json` and `final4-fuzz-size-replay.json`; runtime-block
reasons, profile counts and retained case classifications are summarized in
`final4-fuzz-details.json`. These local artifacts are under the evidence root
listed above; durable counts and limits are recorded here.

## September 27, 2026: precompute cleanup and pass allocation campaign

This checkpoint supersedes September 26 timing claims for the remeasured passes;
older oracle versions and measurements retain their original scope. Ten atomic
optimizations were developed with bounded red-first invariants and focused native
benchmarks before the final generated campaign. No external-generator lane ran.

### Changes and invariants

- `e4ba48a9b`: Precompute cleanup reuses the snapshot-scoped validation environment.
  Four stack samples placed the old large-input stall in repeated whole-module
  custom-descriptor feature scans, outside the inner precompute timer. Raw,
  unchanged HOT, lowered and stacked cleanup paths share the environment; stacked
  type-section adoption clears both cached contexts in the source. Bounded sharing,
  distinct-snapshot block-type tests and dispatcher fixtures check valid output.
- `d64a5bee0`: Inlining scans read-before-write state once for all copied locals.
  Child writes are rolled back at region boundaries, parameters are excluded,
  `local.tee` writes are recognized, and the single-local shortcut remains.
  The 64-local fixture fell from 16,384 visits to at most 256 while preserving
  initialization decisions. Native reference/current comparisons measured
  20.22 µs / 428.04 ns at 64 locals and 314.29 µs / 1.49 µs at 256.
- `c51d703bc`: DAE recognizes identical immutable snapshots before structural
  comparisons. Distinct bodies and locals still compare structurally. Unchanged
  NaN bodies no longer spuriously advance the body epoch; exact payload and
  dispatcher tests cover both DAE modes. The 512/4096-instruction guard benchmark
  fell from 1.59/12.22 µs to 6.60/7.47 ns. This helper improvement did not produce
  a material large-artifact DAE gain; call facts and slicing remain open.
- `476d77170`: Inlining helper removal skips signature work without positive
  retention quotas and builds shared type information at most once otherwise.
  Stable first-retained selection, structural signature grouping and remapping
  are asserted. Native removal at 256/512 helpers improved from 51.94/166.43 µs
  to 2.33/4.15 µs without quotas, and 53.10/170.03 µs to 10.56/20.24 µs with quotas.
- `a4cca9a70`: DAE2 stores dependency edges in flat arrays instead of allocating
  an empty array for every location. Tail links preserve dependency and workqueue
  order; cycles, duplicate edges, incremental solving and negative sentinels keep
  their contract. Sparse 8,192/32,768-location reference/current controls measured
  114.69/454.05 µs versus 32.27/127.55 µs; a dense 4,096-location control measured
  117.19 versus 79.24 µs.
- `2ad1ab9dc`: The final retention follow-up formats only eligible candidate signatures,
  memoized by type slot. Its bounded 64-type/two-candidate fixture first formatted
  64 keys, then at most two, while preserving the exact surviving functions.
  Grouped types and invalid-index fallback keys still match the old resolver.
- `e10bec2f0`: Expanded-CFG LocalGraph transfers no longer allocate and clear
  a function-sized tuple flag array for every block. The recursive unexpanded
  path retains its flags; transfer/merge order and source facts are unchanged.
  The red test allocated four unused slots and now requires zero, alongside
  exact reaching-source/influence assertions. All 36 focused IR/dispatcher
  tests pass. Complete-graph native controls improved **35.20 → 3.08 ms** at
  64 regions and **1.94 s → 46.75 ms** at 256; the unexpanded control did not
  regress. OptimizeInstructions and MergeLocals share this path and receive
  their own final aggregate comparisons.
- `1676f93ed`: The forward LocalGraph solver executes every block initially,
  then reuses its output until the incoming state changes. Merges, exceptional
  edges and final source recording retain their rules. The bounded regression
  first counted nine redundant transfers. Exact-state native reference/current
  controls improved **2.57 ms → 484.08 µs** at 64 expanded regions,
  **44.78 → 6.82 ms** at 256, and **22.12 → 1.05 ms** unexpanded. Thirty-seven
  focused flow/dispatcher tests pass, including equal branch writes.
- `c45b36ba8`: OptimizeInstructions tuple-wrapper cleanup now obtains its validation
  environment through a lazy snapshot provider. The multivalue-producer guard
  remains ahead of the provider; ordinary scalar cleanup does not request it.
  Six active single/stacked lowering call sites share the existing cache and its
  type-snapshot invalidation. Ordered effectful lanes, at-most-one construction
  and unused-provider behavior are covered alongside the command dispatcher.
  Same-binary native cleanup batches improved **1.08 ms → 53.72 µs** at 128
  functions and **15.85 ms → 215.06 µs** at 512, with exact output checks.
- `9e7cf0ad7`: The raw-return follow-up passes the lazy provider through OI's separate direct
  tuple-cleanup call. The nine-unit checkpoint still spent roughly 11 seconds
  in the large pipeline: five fresh samples again hit descriptor scans, now
  showing the raw tuple-helper caller explicitly. A bounded valid try_table
  fixture first left the environment cache empty; the corrected raw route
  constructs it once across functions while preserving carried numeric/call
  lanes and the intentionally unchanged try_table. This completes both callers.
  Native raw-guard/cleanup batches improve **786.18 → 44.40 µs** at 128
  functions and **11.28 ms → 175.15 µs** at 512, with exact output controls.

Sources: owner strategies for [Precompute](../binaryen/passes/precompute/starshine-hot-ir-strategy.md),
[propagation](../binaryen/passes/precompute-propagate/starshine-strategy.md),
[Inlining](../binaryen/passes/inlining/starshine-strategy.md),
[DAE](../binaryen/passes/dead-argument-elimination/starshine-strategy.md),
[DAE2](../binaryen/passes/dae2/starshine-strategy.md),
[OptimizeInstructions](../binaryen/passes/optimize-instructions/starshine-strategy.md),
[MergeLocals](../binaryen/passes/merge-locals/starshine-strategy.md) and the
[local-flow invariants](../ir2/local-ssa-policy.md), which link the implementing
sources, bounded invariants, dispatcher fixtures and benchmarks.

### Measurement contract

Evidence is local under `.tmp/pass-perf-campaign-20260927/`. The starting native
CLI is `da5f112b6bbf092476d2d6ac6694128e19adca3d288003526ab01c3e0b0bfcbb`.
Small input: 192,893 bytes, 45 functions, SHA-256
`06a9dd57ade8a4fd7c60cba2d1c97845b61e115a54f49ec484fd5a2d73b9f69c`.
Large input: 6,211,596 bytes, 12,904 functions, SHA-256
`98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
The verified oracle reports `wasm-opt version 133 (version_133)` and hashes to
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.

Artifact pairs alternate baseline/current order, with one warmup and three
measured rounds. The table uses the sum of pipeline timers; oracle comparisons
separately report inner pass medians. Observed overlaps with competing heavy processes are discarded. Every paired output is byte-identical to the starting compiler,
traced/untraced bytes agree, and independent validation passes. Small percentage
movements are noise context, not automatic evidence of a material improvement.

The original large Precompute and propagation commands completed in 287.6 and
304.1 seconds, but their tails overlapped an outside TinyGo build and resumed
local work. Those elapsed values are excluded from speedup ratios. Plain
Precompute had already run for over four minutes before outside contention was
observed. Its old output and propagation's old output exactly match the new
outputs. The synthetic 128/512-function plain control measured 930.97 µs/11.35 ms
before and 239.82/962.34 µs after; propagation measured 4.00/22.52 ms before and
2.67/10.66 ms after. These controls establish the cleanup-scan improvement
without treating contended artifact tails as precise timing evidence.

The sparse retention follow-up measured **33.95 → 14.99 µs** at 256 functions
and **63.80 → 28.66 µs** at 512, with no regression in dense, no-quota or
full-table controls.

Final native CLI SHA-256: `5d009c4396b65d613acdc187e443f6c2cee843c7bfbc48ee726ba633de2aac54`.
Generator SHA-256: `7d2c662cdb63183acfdbfb61bc8492568eeaeaa29f843ca6294b1e80cd1f0901`.

`moon info`, `moon fmt`, all **12,527 default wasm-gc tests**, both release
native builds and **13 measurement-tool tests (47 assertions)** pass. Public
interfaces match the initial worktree snapshot; pre-existing edits were preserved.

### Final artifact measurements

Pipeline and inner-pass times are milliseconds. The inner timer excludes some
cleanup/lift work; especially, zero on small plain Precompute is not a zero-cost
pipeline. These are isolated serial measurements, not fuzz-campaign timings.

| Input | Pass | Pipeline before → after | Inner Starshine / v133 | Inner ratio | Canonical byte delta vs v133 |
| --- | --- | ---: | ---: | ---: | ---: |
| small | `dae2` | 18.213 → 17.648 | 18.333 / 1.104 | 16.61× | -97 |
| small | `dae` | 52.474 → 50.793 | 52.512 / 0.631 | 83.25× | -134 |
| small | `dae-optimizing` | 141.571 → 141.420 | 144.171 / 7.773 | 18.55× | -1,373 |
| small | `inlining` | 13.098 → 5.865 | 5.479 / 2.401 | 2.28× | -6,504 |
| small | `inlining-optimizing` | 126.099 → 112.212 | 121.265 / 45.041 | 2.69× | +461 |
| small | `simplify-globals-optimizing` | 22.405 → 20.941 | 24.598 / 1.280 | 19.22× | -372 |
| small | `precompute` | 1.753 → 1.278 | 0.000 / 1.381 | 0.00× | -70 |
| small | `precompute-propagate` | 6.551 → 5.436 | 2.214 / 2.495 | 0.89× | -84 |
| small | `optimize-instructions` | 3.525 → 3.781 | 0.604 / 0.716 | 0.84× | -28 |
| small | `merge-locals` | 1.583 → 1.509 | 0.436 / 0.378 | 1.15× | -35 |
| large | `dae2` | 6,147.207 → 5,831.058 | 5,794.346 / 399.615 | 14.50× | -100,655 |
| large | `dae` | 801.913 → 803.115 | 790.054 / 377.549 | 2.09× | -3,626 |
| large | `dae-optimizing` | 1,020.347 → 1,011.409 | 996.543 / 1,597.160 | 0.62× | +41,427 |
| large | `inlining` | 3,533.973 → 1,755.741 | 1,728.190 / 822.553 | 2.10× | -1,369,483 |
| large | `inlining-optimizing` | 597.501 → 618.662 | 602.976 / 14,070.900 | 0.04× | +933,016 |
| large | `simplify-globals-optimizing` | 55.747 → 55.362 | 38.310 / 1,047.330 | 0.04× | +173,229 |
| large | `precompute` | excluded → 690.882 | 63.900 / 183.681 | 0.35× | -5,153 |
| large | `precompute-propagate` | excluded → 1,829.854 | 936.822 / 679.563 | 1.38× | -9,535 |
| large | `optimize-instructions` | 11,383.770 → 3,222.607 | 113.803 / 234.892 | 0.48× | +47,825 |
| large | `merge-locals` | 37.301 → 37.058 | unavailable: guarded no-op | — | — |

The large MergeLocals fixture reports `fallback-noop` with reason
`large-typed-loop-module-interference`, and emits no inner-pass timer. Its
pipeline row measures admission overhead only; it is an open coverage gap,
not a throughput win. Nineteen rows have verified-v133 inner measurements.

Large untraced Precompute command medians (one warmup, three accepted samples):
`precompute` **1,461.339 ms**; `precompute-propagate` **2,513.823 ms**.

All 18 baseline/current pipeline pairs preserve output bytes. The earlier five-unit
checkpoint remains in `final-*`; the accepted ten-unit renewal is `final5-*`.
The intervening `final2-*` checkpoint exposed a paired 31.7% propagation slowdown
(3,012.418 → 3,968.413 ms pipeline) after retention-cache changes. GDB samples
repeatedly hit the unused tuple-array clear loop; no Precompute function sizes
changed. Code-layout sensitivity is an inference. Removing that allocation
addresses the measured work, with recovery checked against both frozen checkpoints.
Large optimizing-inlining/DAE/SGO ratios below one do not close their guarded
cleanup or canonical-size deficits. DAE snapshot microbenchmarks do not justify
a whole-pass speedup claim. DAE2 still needs substantial lifting/flow work.

Raw-return follow-up control (previous nine-unit binary → final binary):

- `precompute-propagate` pipeline: **1,807.171 → 1,800.386 ms**.

- `optimize-instructions` pipeline: **11,536.881 → 3,255.425 ms**.

- `inlining-optimizing` pipeline: **626.214 → 617.446 ms**.

The nine-unit checkpoint improved tuple cleanup only on lowered paths and left
the large OI pipeline near 11 seconds. Fresh GDB samples identified a separate
raw-return caller. The final follow-up shares the same environment there; its
artifact row above measures that additional route, not just the helper microbenchmark.

A seven-sample small-input control repeated the initially noisy OI result:
`optimize-instructions` **3.802 → 3.702 ms**; `merge-locals` **1.533 → 1.508 ms**. The first three-sample OI increase did not reproduce.

### Final generated comparison campaign

Every row completed **10,000** comparisons with verified v133, seed `0x5eed`,
explicit native CLI/generator, `--jobs auto --max-subprocesses 8`, at most 20
retained mismatches, independent `wasm-tools` validation and Node-v2 observations.
Starshine outputs are regenerated; exact-byte/runtime/policy-keyed Node-v2
observations and Binaryen outputs may be reused from the default cache.

| Lane | Aggregate profile | Canonical / cleanup matches | Residuals | Canonically larger | Star/original runtime matches / blocked |
| --- | --- | ---: | ---: | ---: | ---: |
| `dae2` | `dae2` | 2,879 / 667 | 6,454 | 0 | 9,312 / 688 |
| `dae2-closed` | `dae2` | 0 / 100 | 9,900 | 706 | 9,312 / 688 |
| `dae2-optimizing` | `dae2` | 2,233 / 0 | 7,767 | 0 | 9,312 / 688 |
| `precompute` | `precompute-all` | 3,238 / 6,762 | 0 | 0 | 9,551 / 449 |
| `precompute-propagate` | `precompute-all` | 2,766 / 7,234 | 0 | 0 | 9,551 / 449 |
| `inlining` | `pass-inlining` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |
| `inlining-optimizing` | `inlining-optimizing-all` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |
| `inline-main` | `pass-inlining` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |
| `dae` | `dead-argument-elimination` | 3,750 / 0 | 6,250 | 0 | 10,000 / 0 |
| `dae-optimizing` | `dae-optimizing` | 5,153 / 0 | 4,847 | 0 | 10,000 / 0 |
| `simplify-globals-optimizing` | `simplify-globals-optimizing-all` | 5,055 / 0 | 4,945 | 0 | 10,000 / 0 |
| `optimize-instructions` | `pass-oi-all` | 8,920 / 403 | 677 | 0 | 8,910 / 1,090 |
| `merge-locals` | `merge-locals-all` | 9,353 / 0 | 647 | 0 | 10,000 / 0 |

Across **130,000 comparisons**, validation, generator, property, command and observed
Starshine/original semantic failures are all zero. Original-runtime-blocked
cases remain unverified. Primary runtime matches do not automatically imply
three-way agreement with Binaryen. Observation coverage depends on generated
exports; a matching unexported fixture does not demonstrate execution of every
function. No separate determinism, idempotence or
metamorphic property lane ran; the reported zero property-failure counter does
not imply that additional coverage.

DAE/DAE2 and optimizing SimplifyGlobals use `drop-consts` and
`unreachable-control-debris`; Precompute variants additionally use
`local-cleanup-debris`; OI uses `drop-consts` and `local-cleanup-debris`.
Inlining and MergeLocals lanes use no cleanup normalizers. Closed DAE2
adds `--closed-world`; `dae2-optimizing` compares the matching upstream DAE2,
SimplifyLocals and Vacuum sequence. No external generator or randomized work
was added to the default test suite.

Classifications below are agent judgments. All retained residual outputs and
all canonically larger cases were replayed against the starting compiler:

| Lane | Retained outputs identical to baseline | All size-losing outputs identical |
| --- | ---: | ---: |
| `dae2` | 20/20 | 0/0 |
| `dae2-closed` | 20/20 | 706/706 |
| `dae2-optimizing` | 20/20 | 0/0 |
| `dae` | 20/20 | 0/0 |
| `dae-optimizing` | 20/20 | 0/0 |
| `simplify-globals-optimizing` | 20/20 | 0/0 |
| `optimize-instructions` | 20/20 | 0/0 |
| `merge-locals` | 20/20 | 0/0 |

Byte identity shows that the replayed outputs predate these optimizations; it
does not prove full equivalence or classify unretained cases. DAE/DAE2 and
optimizing SimplifyGlobals residuals remain open **parity gaps**. The 706 closed
DAE2 indirect-call cases are also **size-losing quality gaps**. Validation or a
bounded runtime match alone does not close them.

OI and MergeLocals receive additional family review, using all residual inputs,
not only the 20 retained mismatch directories:

- **OI: 677 scoped Starshine wins across 14 tuple labels.** Inspected samples
  collapse redundant tuple copy/tee scaffolding while preserving lane producers
  and effect order, under the existing [tuple strategy](../binaryen/passes/optimize-instructions/starshine-strategy.md).
  Every residual is 26–104 canonical bytes smaller (27,497 bytes total), all
  677 outputs equal the starting compiler byte-for-byte, and a common verified
  v133 `-Oz --all-features --strip-debug` produces **identical bytes** on both
  sides for every case. Representative local-operation counts also decrease.
  These are measured intermediate-size wins with no downstream-size loss in
  this campaign, not a claim about every OI shape.
- The older v132 reopening for `runtime-multi-selected-effectful-lanes` does
  **not reproduce under this current compiler/v133 pair**: all 41 members are
  53 canonical bytes smaller immediately and byte-identical after common `-Oz`.
  This supersedes that family's current-baseline classification only; the
  historical +4-byte v132 result remains valid under its original scope.
- **MergeLocals: 647 scoped Starshine wins**, all `trivial-confusion`. The
  inspected diff removes an unread `local.tee` write while leaving the same
  branch-condition value, as documented in the [owner contract](../binaryen/passes/merge-locals/starshine-strategy.md#residual-classifications).
  All 647 outputs are two canonical bytes smaller, equal the starting compiler
  byte-for-byte, and converge to identical bytes after common v133 `-Oz`.

Both sides' downstream outputs independently validate. The exhaustive census,
replays and byte-equality evidence are in `final-all-shapes-replay.json`;
representative WAT and operation counts are in `final-fuzz-shape-review.json`.

Runtime limits from the saved observations:

- `dae2` original-runtime blocks: `dae2-continuations`: 688.

- `dae2-closed` original-runtime blocks: `dae2-continuations`: 688.

- `dae2-optimizing` original-runtime blocks: `dae2-continuations`: 688.

- `precompute` original-runtime blocks: `precompute-gc-atomic-boundary`: 449.

- `precompute-propagate` original-runtime blocks: `precompute-gc-atomic-boundary`: 449.

- `dae` Binaryen-side runtime limits: `dae-arg-type-refinement`: 625, `dae-return-type-refinement`: 625; inspect `final-fuzz-details.json` for exact reasons.

- `optimize-instructions` original-runtime blocks: `pass-oi-descriptor-gc`: 1,090.

Continuation, GC-atomic and descriptor-GC compilation limits remain separate from Binaryen-only
exact-heap-type compilation limits. These are runtime coverage gaps, not evidence
of wrong Binaryen results.

The generic `inline-main` aggregate is mainly protocol/no-op coverage. A separate
**512-case active named-wrapper campaign** changes every main body,
retains every named helper, preserves baseline/current bytes and independently
validates all 512 Starshine outputs. Fresh instances per case pass
**1,920 original/Starshine/v133 call comparisons** plus
**640 original/Starshine checks** with zero mismatches.

Verified v133 fails on the 128 tail-call fixtures with
`all break targets must be valid` after emitting a branch to `__original_body`.
These are **Binaryen/tool failures**, outside the zero-command-failure aggregate
rows above. Their stderr is retained; no Binaryen runtime result is claimed.
The remaining 384 Binaryen outputs independently validate. Tail-call correctness
therefore has baseline-byte, Starshine validation and original-runtime evidence,
but lacks this oracle's three-way result.

The active fixtures vary 2–16 numeric locals, conditional and region-local writes,
read-before-write, ordinary/tail calls and block/if placement. This does not claim
coverage of every exception, reference or continuation shape. Existing cleanup
simplifies 485 retained helper bodies
(for example, removing a branchless loop). An initial input/helper byte-identity
assertion was invalid; baseline/current whole-output identity remains required.

Persistent cache counts (hits / misses):

| Lane | Binaryen output cache | Node-v2 observation cache |
| --- | ---: | ---: |
| `dae2` | 10,000 / 0 | 10,000 / 0 |
| `dae2-closed` | 10,000 / 0 | 10,000 / 0 |
| `dae2-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `precompute` | 10,000 / 0 | 10,000 / 0 |
| `precompute-propagate` | 10,000 / 0 | 10,000 / 0 |
| `inlining` | 10,000 / 0 | 10,000 / 0 |
| `inlining-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `inline-main` | 0 / 10,000 | 9,860 / 140 |
| `dae` | 10,000 / 0 | 10,000 / 0 |
| `dae-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `simplify-globals-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `optimize-instructions` | 10,000 / 0 | 0 / 10,000 |
| `merge-locals` | 8,742 / 1,258 | 0 / 10,000 |

Exact commands, profiles, normalizers, statuses and paths are in
`final-fuzz-campaign.json`; each lane retains its `toolchain.json`, `cases.jsonl`,
`result.json`, manifest and observations. Replay details are in
`final-fuzz-retained-replay.json` and `final-fuzz-size-replay.json`; runtime/profile
counts are in `final-fuzz-details.json`. Active-wrapper results and oracle errors
are under `inline-main-runtime/`. Timing evidence is in
`final5-pairs-{small,large}/result.json`, `final5-sweeps.json` and
`final5-precompute-large.json`; validation and pinned tools are in
`final5-validation.json` and `final5-tool-identities.json`.

### Remaining work

Precompute propagation still needs pass-local analysis on the large fixture;
plain cleanup's repeated module scan is resolved. Keep DAE call facts/slicing,
DAE2 initial lifting and flow solving, Coalesce CFG/interference construction,
Inlining body processing/nested cleanup, and SimplifyLocals raw/lift/lower work
open. OI still has substantial work outside function processing: one accepted
trace records 3,195.086 ms pipeline versus 833.195 ms in the code-section phase
(`final5-oi-phase-census.json`). Profile the surrounding module work before
attributing that remaining cost to the 114 ms inner rewrite timer. Preserve
output-quality and guarded-cleanup gaps alongside timing targets;
the large OI output is still 47,825 canonical bytes larger than v133.

Control-initialization masks remain an investigated hotspot, with no validator
change retained. `TcState` exposes mutable arrays; naive copy-on-first-write
would copy the entire mask for each non-defaultable local's first assignment,
creating quadratic work on wide initializers. A future fix needs explicit region
ownership or a persistent representation, with wide non-defaultable-local and
handler invariants before adoption. The current campaign preserves those paths.

## September 27, 2026: nested timing scope correction

Optimizing DAE2 runs a nested SimplifyLocals/Vacuum pipeline under its own pass
and pipeline timers. Summing every emitted timer double-counts that cleanup;
the resulting pipeline total can even exceed the command wall time. The
comparison parser now counts enclosing named scopes once, sums serial scopes,
retains measured children when a wrapper is untimed, and preserves legacy
unscoped traces. A completion without a corresponding named start cannot close
its caller. Fine-grained phase counters remain inclusive diagnostic attribution,
not an additive wall-time ledger.

Six bounded parser regressions include red-first nested and unmatched-completion
cases; all 21 timing-harness tests (60 assertions) pass. Compiler binaries and
outputs are unchanged. Saved traces under `.tmp/pass-perf-next-20260927/` are
reparsed into `corrected-timing-summary.json` and `final-pairs-*-corrected.json`;
original reports remain available. This is an accounting correction, not a
compiler performance gain. The follow-up campaign uses corrected durations.

Sources: [parser](../../../scripts/lib/self-optimize-compare-task.ts),
[scope regressions](../../../scripts/lib/self-optimize-nested-timing.test.ts),
and [DAE2 child-span correction](../binaryen/passes/dae2/starshine-strategy.md#september-27-2026-retain-identical-child-spans-during-rewriting).
