---
kind: entity
status: working
last_reviewed: 2026-09-26
sources:
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/ir/catch_payload_preflight_wbtest.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp
  - ../../../../../src/passes/dae2_module_env_wbtest.mbt
  - ../../../../../src/passes/lower_capture_cleanup.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - ../../../../../src/passes/dead_argument_elimination2.mbt
  - ../../../../../src/passes/dae2_repeated_solve_perf_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_types.mbt
  - ../../../../../src/passes/dead_argument_elimination2_legacy.mbt
  - ../../../../../src/passes/dead_argument_elimination2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
related:
  - ./index.md
  - ./fuzzing.md
  - ../../version-132-upgrade.md
---

# Starshine DAE2 implementation

This page describes the implemented Binaryen 132 port, superseding the earlier
proposal to leave `dae2` unknown or to add only parameter forwarding.

The module pass owns a short-lived usage graph. Each function parameter and
whole result tuple has a location; HOT expression values have locations too.
Type-family locations connect referenced functions to indirect calls. Observable
uses seed the graph, and a queue visits each live location at most once.

## September 26, 2026 skip unchanged rewrite lifts

The rewrite phase now reuses the first analysis phase's complete direct/indirect call summary. It rebuilds HOT only when a function or one of its callees changes signature, or when indexed control types require the existing preservation path. Legacy `Try` also retains that path. The rewrite decision is computed once; type-family identity, new function-type selection, names, final cleanup and validation still run. The bounded preflight leaves all analysis and fixed-point edges intact. [Binaryen 133's DAE2 optimizer](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) works on its retained IR and gates signature/local reconstruction on removed parameters or results; this change avoids Starshine's additional reconstruction of unaffected bodies.

A regression first failed with three rewrite lifts instead of two while successfully pruning the sibling's unused parameter. Two pass fixtures and one active command fixture verify the skip, retained indexed-control preparation, unchanged input/body preservation and the optimized call signature. All 74 focused DAE2 tests pass; `moon info` and `moon fmt` succeed without a public API change. The full wasm-gc suite passes 12466 tests with zero failures.

Fresh native `b084365e0bd4b2bc98457da7eb8773504b5cf2720665dea7ae5b961d30c41a06` is compared with baseline `8b7d8d8aa8de9342cf6148de10350ca9104217e18d2317cf92b2be7e7d08e0a1`. Isolated alternating pairs after one warmup preserve exact raw output on every fixture:

| Fixture | Samples | Before pipeline | After pipeline |
| --- | ---: | ---: | ---: |
| Small compiler | 7 | 19.135ms | 18.362ms |
| Large compiler | 3 | 8,394.226ms | 7,704.931ms |
| 100 unchanged functions | 3 | 14.341ms | 10.454ms |
| 500 unchanged functions | 3 | 73.810ms | 51.734ms |
| 1,000 unchanged functions | 3 | 152.037ms | 107.030ms |
| 1,000 functions requiring rewrites | 7 | 331.541ms | 335.645ms |

The large compiler improves **8.2%**, with command median `9,411.505ms → 8,622.409ms`. The 1,000-unchanged-function fixture improves **29.6%**. The all-changing synthetic fixture regresses **1.2% (4.104ms)**; this is a measured tradeoff, not a universal speedup. A preliminary implementation retained a duplicate rewrite check and was replaced before signoff; its interrupted oracle run does not establish final evidence.

Fresh v133 pass-local medians remain `18.699ms` versus `1.131ms` on the small compiler and `7,578.025ms` versus `396.714ms` on the large compiler. The remaining DAE2 performance gap stays open.

Evidence: `.tmp/dae2-relift-paired-{small,large,functions-1000,unchanged-100,unchanged-500,unchanged-1000}-final-20260926/`, `.tmp/dae2-relift-inputs/manifest.json`, and the [fuzzing renewal](./fuzzing.md). Source and fixtures: [`dead_argument_elimination2.mbt`](../../../../../src/passes/dead_argument_elimination2.mbt), [`dead_argument_elimination2_types.mbt`](../../../../../src/passes/dead_argument_elimination2_types.mbt), [`dae2_relift_wbtest.mbt`](../../../../../src/passes/dae2_relift_wbtest.mbt), and [command test](../../../../../src/cmd/dae2_relift_wbtest.mbt).

## September 26, 2026 catch-payload analysis preflight

DAE2 invokes ordered catch-payload repair on each lifted function. The repair planner previously built its complete node-use graph before checking whether the function contained typed catch payloads. It now performs the existing live-node preflight first and returns the same empty plan when there are no payloads. Catch-all markers still reject; real typed payloads still build the graph and use the original complete, atomic repair plan. Public repairability and mutation results are unchanged. This follows the lazy-analysis principle in [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp), whose parameter-use visitor queries `LazyLocalGraph` only after confirming a read targets a parameter; Starshine's catch repair remains its own representation bridge.

The bounded regression first failed because a payload-free function built one use graph. It now preserves the original lowered body and revision with zero graph constructions. A positive typed-payload regression still builds one graph, inserts a typed capture and local read, and validates control. All 969 IR, DAE2 and Flatten tests pass on wasm-gc. The preceding 1,000-helper instruction profile attributed 6.40% of total instructions to catch-repair planning, including 5.36% in use-graph construction; these are instruction counts, not timings.

Paired native measurements retain identical output bytes on every sample:

| Fixture | Before pipeline | After pipeline | Sampling |
| --- | ---: | ---: | --- |
| Small compiler | 20.446ms | 19.107ms | One warmup, seven alternating pairs |
| 1,000 store-heavy helpers | 353.583ms | 333.762ms | One warmup, three alternating pairs |
| Large compiler | 8,731.602ms | 8,317.893ms | One warmup, three alternating pairs |

These are 6.5%, 5.6% and 4.7% pipeline reductions respectively. Large command median changes `9,759.045ms → 9,315.220ms`. Paired artifacts are `.tmp/catch-preflight-paired-{small,functions-1000,large}-20260926/`. Baseline native SHA-256 is `30dc535a657e2467aaf55d765ee9393e742144f97186b862c517c30e6a513a4c`; updated is `a6385c90382a7a2925d0b4e049a5bcd5ccac3fc8d4f473e7cf41a0411a5943ea`. `moon info`, formatting and native release build pass; no public API changes.

Fresh verified-v133 sweeps measure small pass-local medians `19.130ms` versus `1.130ms` and large medians `8,260.168ms` versus `400.926ms`; the substantial remaining oracle performance gap is still open. Artifacts: `.tmp/pass-sweep-v133-catch-preflight-{small,large}-20260926/`.

The explicit-native `dae2` aggregate renewal uses verified v133, seed `0x5eed`, eight subprocesses, both debris normalizers and Node-v2. Each world compares 10,000 cases: open has 2,879 normalized, 667 cleanup-normalized and 6,454 residuals; closed has zero normalized, 100 cleanup-normalized and 9,900 residuals, including 706 canonical size losses. Each world has 9,312 runtime matches, 688 original-runtime-blocked continuation cases and zero semantic mismatches. Both have zero validation/property/generator/command failures. Counts match the preceding module-environment signoff.

Flatten also calls the repair planner, so its `flatten-all` aggregate runs 10,000 cases with all three documented debris normalizers: 837 normalized, 5,057 cleanup-normalized and 4,106 residuals, zero canonical size losses and zero validation/property/generator/command failures. Runtime execution was not enabled for Flatten. Agent judgment keeps current residuals open as parity gaps, including closed DAE2's size-losing cases; no historical Flatten cleanup-win classification is extended to v133 here. All 60 saved raw residual outputs replay identically against the pre-change compiler. Artifacts: `.tmp/pass-fuzz-dae2-catch-preflight-{open,closed}-v133-10000-20260926/`, `.tmp/pass-fuzz-flatten-catch-preflight-v133-10000-20260926/`, and `.tmp/catch-preflight-replay.json`. The 12,456-test full default suite passed immediately before this unit; its current focused suite passes 969 tests.

## September 26, 2026 shared cleanup module facts

The final branchless-block cleanup built a complete validation environment for every defined function. It now builds one environment after signatures, control types and local-throw folding are finalized, then supplies it to each cleanup. The helper only reads module block-type facts; the candidate's declarations stay unchanged throughout this map. Existing callers retain their original environment construction when no shared snapshot is supplied. [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) likewise keeps one module object across analysis and rewriting and caches shared public-type facts.

The bounded regression prunes i32/i64 parameters, flattens typed result wrappers, preserves two live calls and their result, and limits cleanup environment construction to at most one. It first failed with three constructions; all 73 DAE2/shared-cleanup tests now pass on wasm-gc. `moon info`, formatting and the native release build pass; this unit adds no public API.

| Fixture | Before pipeline | After pipeline | Sampling |
| --- | ---: | ---: | --- |
| 100 helpers, 64 ordered stores each | 35.626ms | 33.593ms | One warmup, three alternating pairs |
| 500 helpers, 64 ordered stores each | 227.985ms | 172.662ms | One warmup, three alternating pairs |
| 1,000 helpers, 64 ordered stores each | 566.952ms | 357.659ms | One warmup, three alternating pairs |
| 6,211,596-byte compiler fixture | 350,398.025ms | 8,849.366ms | **One pair, no warmup** |

The single large pair is a 39.6x pipeline improvement, with command time `351,398.852ms → 9,841.313ms`. Its limited sample count is explicit; it is not a three-sample median. Output remains exactly 6,114,805 bytes, SHA-256 `2b9031cbfa2fce3ed29abf783daef2774688941baea42d00499db575d0321696`. Every repeated synthetic pair is also byte-identical. The 192,893-byte compiler fixture changes only `20.755ms → 20.393ms`, which is not claimed as a material gain.

Paired artifacts are `.tmp/dae2-module-env-paired-{small,functions-100,functions-500,functions-1000,large}-20260926/`; synthetic inputs and their hashes are in `.tmp/dae2-module-env-inputs/manifest.json`. Baseline native SHA-256 is `3063c88915ccf04bdcbc8d85d4b134bc3860f24d3a19775336a411c9de416278`; updated SHA-256 is `a9bc998439325ef23dec3af201619d4e86991cfe46fc8bde920b5e8aaa159475`. New oracle measurements use verified Binaryen 133; older v132 port evidence below retains its historical scope.

Fresh verified-v133 sweeps (one warmup, three samples) put current pass-local time at `21.162ms` versus `1.155ms` on the small compiler fixture, `8,892.905ms` versus `397.330ms` on the large fixture, and `353.336ms` versus `8.039ms` on the 1,000-helper input. Large command medians are `9,806.644ms` versus `856.742ms`. This removes the repeated module construction but leaves a substantial DAE2 performance gap. Sweep artifacts are `.tmp/pass-sweep-v133-dae2-module-env-{small,large,functions-1000}-20260926/`.

The renewed aggregate `dae2` profile uses seed `0x5eed`, explicit prebuilt native binaries, eight subprocesses, both cleanup normalizers, and Node-v2. Each world completes 10,000 comparisons: open has 2,879 normalized matches, 667 cleanup-normalized matches and 6,454 residuals; closed has zero normalized matches, 100 cleanup-normalized matches and 9,900 residuals, including 706 canonical size losses. Each world has 9,312 runtime matches and 688 original-runtime-blocked continuation cases, with zero semantic mismatches, validation, property, generator or command failures. Counts match the preceding nearest-write signoff; all 40 saved raw residual outputs are byte-identical to the pre-change compiler. Residuals remain agent-classified open parity gaps, including the closed-world size-losing family; runtime sampling does not establish complete transform parity. Artifacts: `.tmp/pass-fuzz-dae2-module-env-{open,closed}-v133-10000-20260926/`. The previous full default suite passed 12,451 tests before this unit; this unit's focused suite passes 73.

## September 25, 2026 nearest-write indexing

The shared reverse-flow LocalGraph builder now records each get's nearest within-block write during its existing action walk. It resets only written local slots at block boundaries and retains the same predecessor/exception closure when no within-block write exists. This removes repeated backward prefix scans without changing reaching-definition facts. The [dedicated native benchmark](../../../../../src/passes_perf_long/dae2_local_graph_perf_test.mbt) improved from `4.15ms` to `403.57µs` at 1,024 distant reads and from `14.95ms` to `795.21µs` at 2,048; [bounded tests](../../../../../src/ir/local_graph_reverse_wbtest.mbt) cover overwrites and sibling-block isolation. All 407 IR tests and 70 DAE2 tests pass on wasm-gc. `moon info` and formatting pass with no public API change from this unit.

On the 189 KB fixture, DAE2 pass-local median improved from `25.862ms` to `23.189ms` (10.3%), with identical raw output SHA-256 `f8b4d5e5c7b6372ad8d6a2193df5f2db61ec4ce2462b40095a762dfe226a35f7`. Verified Binaryen 133 measured `1.347ms` in the new sweep, so the pass still loses by `17.21x`. [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) queries `LazyLocalGraph` only for parameter gets; Starshine still eagerly builds broader local liveness to support its expression-removal graph. That larger analysis difference remains an optimization target. Artifacts are `.tmp/dae2-localgraph-bench-{before,after}.log` and `.tmp/pass-sweep-v133-{dae2-localgraph-before,localgraph-after-small}-20260925/`.

The fresh open-world `dae2` aggregate compares 10,000 cases against verified v133 with the explicit native binary and eight subprocesses: 2,879 normalized matches, 667 cleanup-normalized matches, and 6,454 residual output differences. Node-v2 observes equal original/Starshine/Binaryen results in 9,312 cases; all 688 continuation cases remain blocked by the original runtime. There are no semantic mismatches or validation/property/generator/command failures. All residuals are canonically smaller, but size alone does not close parity: reviewed unused-local removal is an exact cleanup benefit; the remaining families remain parity gaps or runtime-blocked uncertainty. Evidence: `.tmp/pass-fuzz-dae2-localgraph-open-v133-10000/result.json` and its persisted diffs/runtime observations.

The closed-world companion also completes 10,000 cases: 100 cleanup-normalized matches and 9,900 residual differences, with the same 9,312 runtime matches, 688 runtime-blocked continuations, and zero semantic/validation/property/generator/command failures. Its 706 canonically larger indirect-call cases remain size-losing parity gaps: Starshine retains the indirect type family's parameter and dropped result where Binaryen removes them (saved case 5 is 83 versus 82 canonical bytes). The other residual families remain open unless individually justified. Both lanes use native SHA-256 `72b55be2e092167030dccf79d6e48f646d338c16791852a9a9171d73b41b9894`; closed-world evidence is `.tmp/pass-fuzz-dae2-localgraph-closed-v133-10000/result.json`. These results validate the indexing change without claiming complete DAE2 parity.

## September 24, 2026 repeated-solve measurement

Type-identity conflict handling can observe more graph locations and call `solve` again. The graph now retains its queue cursor between solves, so earlier locations are not scanned again; edges must be complete before the first solve. The native release white-box benchmark in [`dae2_repeated_solve_perf_wbtest.mbt`](../../../../../src/passes/dae2_repeated_solve_perf_wbtest.mbt) measured 128 incremental observations/solves at `10.11 → 2.29 µs` (4.41×) and 256 at `34.80 → 4.43 µs` (7.86×). A second-solve propagation test and 64 existing DAE2 tests pass. This isolates graph behavior; pass-level impact on real identity conflicts remains unmeasured.

Direct call arguments depend on the corresponding callee parameter. A used call
value depends on the callee result. Returns connect to the enclosing result.
Tail calls connect caller and callee result liveness in both directions. Local
flow distinguishes entry parameters from overwritten locals; branch payloads
and the result types of their targets remain valid.

Each HOT body is released after analysis. A second lift is limited to changed
function/call signatures or indexed-control preservation; other bodies are
reused directly. LocalGraph
uses symbolic block-entry sources and sparse changed-local summaries when a
linear reverse scan cannot represent nested control. It resolves complete
predecessor closures before caching, preserving loops and exception paths.
The new solver matches the converged forward reference on 5,000 GenValid modules.

After solving, the pass builds new signatures, preserves argument evaluation
order with typed temporary locals when necessary, removes unused pure values,
and keeps their effectful or trapping descendants. It rewrites functions,
call sites, returns and eligible type families as one candidate module, verifies
HOT and validates the completed module. The dispatcher rebuilds module analyses.

Referenced type families retain subtype/recursion metadata. Open-world type
exposure pins signatures; a private unreferenced sibling can receive a distinct
signature even when its former type also describes a continuation or export.
The intrinsic `binaryen-intrinsics` / `call.without.effects` pins its target's
signature. Ordinary DAE remains available for independent comparison.

Legacy catch payloads are captured at handler entry before call-argument wrappers
can change their stack position. Multiple handlers are represented through
`try_table` with explicit handler labels. Ordinary catches retain only payloads;
functions with a rethrow use `catch_ref` and capture exception identity, including
rethrows that target an outer handler. A handler executes outside its protected body, so a throw
inside one handler is not accidentally caught by its sibling.

This is implementation evidence, not a claim that every upstream output shape
or every proposal already matches. The [validation page](starshine-port-readiness-and-validation.md)
and [upgrade ledger](../../version-132-upgrade.md) track the remaining signoff.
