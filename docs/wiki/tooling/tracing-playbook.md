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
