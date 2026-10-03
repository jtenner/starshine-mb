---
kind: concept
status: supported
last_reviewed: 2026-10-03
sources:
  - ./index.md
  - ../../../../../src/passes/coalesce_locals.mbt
  - ../../../../../src/passes/coalesce_locals_resume_handler_test.mbt
  - ../../../../../src/cmd/coalesce_locals_resume_handler_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../local-subtyping/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./interference-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../local-subtyping/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
---

# Starshine Strategy For `coalesce-locals`

## September 27 follow-up allocation campaign renewal

The [final follow-up campaign](../../../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
supersedes pending-renewal notes for its allocation changes below. The frozen
source passes 12,583 default tests. Its 220,000 comparisons across 22 affected
lanes report no validation, generator, property-counter, command or observed
Starshine/original semantic failures. The report retains exact tool identities,
all artifact timings, active fixtures, residual/size replays and runtime limits.
Per-change measurements are historical isolated pairs, not additive gains.
Remaining timing, output-quality and runtime-coverage gaps stay open; rejected
prototypes remain rejected.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

Use this page together with the [`coalesce-locals` landing page](./index.md)'s tagged source list, the retained 2026-05-05 research recheck, and the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that track the pass, and the remaining validation/placement constraints.

## September 27, 2026 numeric default identities

Structured value analysis caches the five numeric/vector default identities in
its own append-only value interner. The first query retains the existing debug
key and index assignment; subsequent implicit defaults and explicit zero writes
reuse that index. The small cache is allocated only when a numeric default is
encountered. Parameters and non-defaultable references keep their fresh-value
path; nullable references retain their original formatting and interning.
The cache never crosses interner instances. Existing liveness safety edges and
the fresh/interned ID schedule are unchanged.

A red-first test formatted 40 repeated defaults and now formats five while
preserving every key, returned ID and fresh counter. Isolation, parameter and
reference initialization checks pass, together with 148 focused Coalesce tests
and the added reference-default invariant. Dispatcher execution retains live
parameters beside implicit and explicit defaults. Full-helper native controls
measure 3.11 µs → 706.33 ns at eight locals and 997.37 µs → 17.82 µs at
2,048 locals; fixture/liveness setup is outside timing and output matrices agree.

| Input | Pass | Before pipeline ms | After pipeline ms |
| --- | --- | ---: | ---: |
| defaults-32 | coalesce-locals | 2.910 | 1.975 |
| defaults-512 | coalesce-locals | 180.314 | 166.730 |
| large | coalesce-locals | 4944.998 | 4929.752 |
| large | inlining-optimizing | 621.709 | 598.876 |
| large | dae-optimizing | 983.499 | 1007.168 |
| large | simplify-globals-optimizing | 58.656 | 56.475 |
| small | coalesce-locals | 11.816 | 10.840 |
| small | inlining-optimizing | 104.290 | 107.245 |
| small | dae-optimizing | 134.627 | 135.791 |
| small | simplify-globals-optimizing | 19.448 | 19.560 |
| wide-128 | coalesce-locals | 1.659 | 1.585 |
| wide-512 | coalesce-locals | 18.827 | 18.768 |

One warmup and three uncontended alternating samples preserve identical raw
bytes, traced/untraced agreement and independent validation. The wide structured
fixtures also pass thirty original/before/after boundary runtime checks. Guarded
optimizing paths remain guard evidence; final aggregate renewal and remaining
compiler budgets stay open. The additional default-heavy fixtures contain 64
exported functions with 32/512 initialized numeric locals each; 90 boundary
checks preserve their zero results through both branch choices. Evidence:
`.tmp/pass-perf-next-20260927/coalesce-defaults-*`; CLI SHA-256 `6610a792ef8d07151ee38bd6c6fbfe82097086e4f50f6dfd3902eecacb00320e`.
Sources: [interference builder](../../../../../src/passes/coalesce_locals.mbt),
[cache](../../../../../src/passes/coalesce_value_defaults.mbt),
[invariants](../../../../../src/passes/coalesce_default_identity_wbtest.mbt),
[reference](../../../../../src/passes/coalesce_default_identity_reference_wbtest.mbt),
[native controls](../../../../../src/passes/coalesce_default_identity_perf_wbtest.mbt),
and [dispatcher check](../../../../../src/cmd/perf_coalesce_default_identity_wbtest.mbt).

## September 27, 2026 structured interference live-member iteration

Structured interference construction now uses the existing indexed live set
instead of scanning every declared local for each read or effective write.
Entry parameter/default-value edges, remaining-get counts, value identities,
effective-write handling and the exact interference matrix are unchanged.
Swap removal affects iteration order only; edge insertion is commutative and
membership does not change during the edge loop.

The bounded red test previously visited 1,088 candidate locals; actual-live
iteration stays within 72 and preserves every reference matrix bit. Default
entry reads, ineffective writes and dispatcher execution through block/if
control are covered. All 145 focused Coalesce tests pass. Native full-helper
reference/current controls measure 3.81 µs / 3.77 µs with eight locals
and 1.73 ms / 1.06 ms with 2,048 locals. Inputs and liveness facts are
outside timing; each iteration constructs its own output matrix.

New full-pipeline fixtures have 128/512 sequential temporary locals and repeated
if arms, keeping only a few values live at once. Thirty original/before/after
runtime checks preserve results at boundary inputs. Compiler and optimizing
consumers are also measured; guarded cleanup paths remain guard evidence.

| Input | Pass | Before pipeline ms | After pipeline ms |
| --- | --- | ---: | ---: |
| large | coalesce-locals | 5032.304 | 4958.244 |
| large | inlining-optimizing | 621.666 | 623.490 |
| large | dae-optimizing | 981.633 | 988.513 |
| large | simplify-globals-optimizing | 57.049 | 55.814 |
| small | coalesce-locals | 13.582 | 11.334 |
| small | inlining-optimizing | 110.623 | 104.848 |
| small | dae-optimizing | 136.631 | 139.510 |
| small | simplify-globals-optimizing | 19.149 | 19.474 |
| wide-128 | coalesce-locals | 1.794 | 1.867 |
| wide-512 | coalesce-locals | 20.708 | 19.041 |

One warmup and three uncontended alternating pairs retain identical raw bytes,
traced/untraced agreement and independent validation. Overall compiler budgets
and parity/size gaps remain open; final aggregate renewal is pending.
Evidence: `.tmp/pass-perf-next-20260927/coalesce-structured-live-*`;
CLI SHA-256 `72332ba9757b0b1166841e9234faf119510be99237fb4b94ac4c903464c03815`. Sources:
[implementation](../../../../../src/passes/coalesce_locals.mbt),
[invariants](../../../../../src/passes/coalesce_structured_live_wbtest.mbt),
[reference](../../../../../src/passes/coalesce_structured_live_reference_wbtest.mbt),
[native controls](../../../../../src/passes/coalesce_structured_live_perf_wbtest.mbt),
and [dispatcher execution](../../../../../src/cmd/perf_coalesce_structured_live_wbtest.mbt).

## September 27, 2026 word-wise live cliques

CFG interference cliques with at least 16 live entries build a valid-member
bitset and OR only its nonempty words into the existing row bitsets. Smaller
sets retain direct pair insertion. This preserves the matrix representation,
member filtering, duplicate handling, empty diagonal and padding bits. It does
not change coloring, liveness, capture handling or the 4,096-local guard.

The red-first 32-member fixture previously inserted 496 pairs; the new path
inserts none individually and produces every identical row. All 142 focused
Coalesce/dispatcher tests pass. Native reference/current controls are
13.22 µs / 392.43 ns for 64 dense members in 128 locals, 15.40 / 3.64 µs for
64 spaced members in 4,096 locals, and 155.35 / 2.06 µs for 256 dense members
in 512 locals. Fixture allocation is outside timing; each path repeatedly
applies the same idempotent clique to its own matrix.

Full pipeline controls include compiler inputs and new 64-live-local fixtures
with 128/512 loop regions. Original and both outputs agree for five boundary
inputs per wide fixture (30 checks). One warmup and three uncontended alternating
pairs retain identical raw bytes, traced/untraced agreement and independent
validation. Guarded optimizing compiler paths remain guard evidence, not active
cleanup wins. Remaining compiler costs and parity/size gaps stay open.

| Input | Pass | Before pipeline ms | After pipeline ms |
| --- | --- | ---: | ---: |
| large | coalesce-locals | 5131.579 | 5064.714 |
| large | inlining-optimizing | 605.104 | 623.509 |
| large | dae-optimizing | 1014.277 | 987.804 |
| large | simplify-globals-optimizing | 56.171 | 56.347 |
| small | coalesce-locals | 14.034 | 13.671 |
| small | inlining-optimizing | 105.757 | 106.393 |
| small | dae-optimizing | 135.612 | 138.038 |
| small | simplify-globals-optimizing | 19.070 | 19.819 |
| wide-128 | coalesce-locals | 24.045 | 21.671 |
| wide-512 | coalesce-locals | 93.463 | 83.890 |

Final aggregate renewal is pending. Local evidence:
`.tmp/pass-perf-next-20260927/coalesce-clique-*`; CLI SHA-256 `7107be93763118b45ee19e84801aa7504af90ef0a376841de58f22c7f8c72fc3`.
Sources: [implementation](../../../../../src/passes/coalesce_locals.mbt),
[edge invariants](../../../../../src/passes/coalesce_clique_wbtest.mbt),
[reference](../../../../../src/passes/coalesce_clique_reference_wbtest.mbt),
[native controls](../../../../../src/passes/coalesce_clique_perf_wbtest.mbt),
and [dispatcher execution](../../../../../src/cmd/perf_coalesce_clique_wbtest.mbt).

## September 26, 2026 indexed coloring slots

For at least 64 locals, CFG coloring now marks conflicting assigned slots from
each interference row's set bits and accumulates copy weights by assigned slot.
It preserves parameter slots, type compatibility, ascending slot order and the
first-slot tie break. Small functions retain the member-based path. The search
can stop once it reaches the maximum available copy score; zero-weight rows
therefore stop at the first legal slot. No interference matrix or coloring
heuristic was removed or weakened.

The bounded regression fell from 8,128 member probes to at most 512 query steps
and agrees with the previous algorithm for mixed types, parameters, weights and
both local orders. The native sparse coloring controls improve
`378.15 → 10.06 µs` at 512 locals and `5.92 ms → 77.41 µs` at 2,048;
the 128-local clique improves `59.63 → 42.19 µs`. These isolate coloring, with
fixture construction outside timing. The command regression preserves all 128
ordered call arguments while reducing local declarations.

Sources: `src/passes/coalesce_locals.mbt`,
`src/passes/coalesce_slot_queries_{wbtest,perf_wbtest}.mbt`,
`src/cmd/perf_coalesce_slots_wbtest.mbt`, and
`.tmp/pass-perf-work-20260926/coalesce-slot-bench.log`.
Final artifact and fuzz results are in the [shared renewal](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal).

## September 26, 2026 future-root minimum index

The shared source-order query now indexes per-root dependency minima for the
existing large-root admission path. A left-to-right minimum tree skips future
roots that cannot contain an earlier dependency; the original suffix rejection,
two consumer phases and conflict checks remain intact. A dense all-eligible
query retains the direct traversal. The bounded regression reduced collector
root visits from 65 to one while preserving the carried call. Indexed/reference
queries agree across root offsets and consumer-order cutoffs; all five focused
source-order tests pass.

For 64 queries, irrelevant-root benchmarks improve `945.99 → 12.63 µs` at
256 roots and `3.63 ms → 13.69 µs` at 1,024. The dense 256-root control measures
`584.93 µs` direct versus `582.60 µs` indexed, effectively flat. Setup is outside
these query benchmarks; full artifact comparison must include index construction.
Sources: `src/ir/hot_source_order.mbt`, `src/ir/hot_lower.mbt`,
`src/ir/hot_source_order_roots_{wbtest,perf_wbtest}.mbt`, and local logs
`.tmp/pass-perf-work-20260926/source-roots-{before,final-bench}.log`.
This shared lift/lower improvement also reaches DAE2 and other HOT users without
changing coloring, liveness or transformation coverage.

## September 26, 2026 dependency-query scratch reuse

Source-order dependency discovery now allocates its consumer bounds, visited
consumers and anti-dependency bits lazily once per immutable function snapshot.
Each query clears only nodes it visited. Repeated queries retain independent
consumer bounds and call ordering; the bounded regression first failed with
nine workspace builds instead of one. The existing two-stage collection and
strict source-order conflict predicates are unchanged.

The focused native benchmark performs 64 queries over the same carried call.
At 1,024 surrounding nodes it improves `40.80 → 8.83 µs`; at 4,096 nodes,
`128.75 → 9.54 µs`. These are helper measurements, not whole-pass speedups.
Evidence: `src/ir/hot_source_order_scratch_wbtest.mbt`,
`src/ir/hot_source_order_scratch_perf_wbtest.mbt`,
`src/cmd/perf_call_order_wbtest.mbt`, and
`.tmp/pass-perf-work-20260926/source-scratch-{before,after}.log`.

Three isolated alternating large-compiler pairs after one warmup reduce
CoalesceLocals pipeline median `8,272.009 → 7,366.607 ms` (11.0%) and DAE2
`7,127.363 → 6,648.325 ms` (6.7%). Every output is byte-identical to the saved
starting-worktree native executable, matches its untraced output, and validates
with wasm-tools. Seven-pair small confirmations measure DAE2
`19.341 → 19.597 ms` and DAEO `162.912 → 163.065 ms`; no small-input speedup is
claimed. Small CoalesceLocals is unchanged at `14.490 → 14.487 ms` over three
pairs. These are causal Starshine comparisons, not new Binaryen ratios.
Inputs/executable hashes and every sample are recorded in
`.tmp/pass-perf-work-20260926/source-scratch-{large,small,small-confirm}/result.json`.
Focused tests cover the source-order cache and active CoalesceLocals/DAE2
dispatchers. The [completed final campaign](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal) records aggregate
coverage and the remaining parity gaps.

## September 26, 2026 source-order local-access index

The renewed large-input profile identifies `hot_lower_impl_carried_local_write_conflicts` inside expanded CFG construction. Its nested scan compared every qualifying write with every access in another root. A lazy sparse index now caches that root's minimum access order for each local. The write filter and both strict interval bounds are unchanged; missing entries retain the node-count sentinel, and the earliest access must win even when a later access falls inside the requested interval. Queries with at most four accesses or a single carried access keep their direct scan. The cache shares the lifetime of the existing immutable source-order snapshot; memory grows with distinct locals in indexed roots, without allocating a function-sized local array for every query.

[Binaryen 133 CoalesceLocals](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/CoalesceLocals.cpp) processes indexed local actions from its CFG. Starshine additionally reconciles HOT operand dependencies with emitted stack order; this optimization retains that proof while indexing its repeated queries. It does not claim that Binaryen implements this Starshine-specific ordering cache. The [ordering contract](./interference-and-ordering.md#carried-control-must-use-emitted-source-order) remains authoritative.

A red-first 32-write/32-read regression measured 1,024 access visits instead of 32. The index needs 32 on first use and zero access-array visits on reuse; qualifying writes are still examined. Tests cover duplicate accesses, local writes as accesses, disjoint locals, filtered writes and strict minimum bounds, plus command dispatch preserving a default-initialized body local separately from an arbitrary parameter. All 292 focused and 12,476 full wasm-gc tests pass; `moon info`, `moon fmt` and the native release build pass without a public API change.

Native `f7fb87fb1a66416d87a018b78fcd8fddf2f58a110d77f982c56434cd1a3bbaf9` versus pre-change `dd1746825fca4894469fc07309835381c434b0b347d730496ffeacb320b6a177`, one warmup and seven isolated alternating pairs:

| Input / pass | Before pipeline | After pipeline | Change |
| --- | ---: | ---: | ---: |
| Large / coalesce-locals | 7,821.570ms | 7,542.937ms | 3.6% faster |
| Large / dae2 | 7,633.494ms | 6,438.548ms | 15.7% faster |
| Small / coalesce-locals | 13.611ms | 13.669ms | effectively unchanged |
| Small / inlining-optimizing | 121.256ms | 121.008ms | effectively unchanged |
| Small / dae-optimizing | 149.506ms | 152.781ms | 3.275ms / 2.2% slower |

Every large Coalesce pair improves, saving 182.784–430.886ms. All paired raw outputs are identical. Three-pair checks also retain exact outputs for both compiler inputs across optimizing inlining, DAE and SimplifyGlobals and on the dedicated wide-local fixtures. The small DAEO tradeoff is explicit: a separate seven-pair comparison against the pre-forwarding-guard CLI (`0925e7e8ae15e1e06d4fa171fdcf5b251e42f68f627ef7955a10bf032570748f`) still shows a **26.9% combined gain**, `210.095ms → 153.542ms`.

The final verified-v133 sweep on this same CLI measures large pass-local Coalesce `7,548.790ms` versus `1,100.470ms` (**6.86x slower**) and DAE2 `6,446.246ms` versus `398.444ms` (**16.18x slower**). Small DAEO remains `155.511ms` versus `7.315ms` (**21.26x slower**). Large DAEO is faster on timing (`1,001.411ms` versus `1,578.710ms`) but remains 41,427 canonical bytes larger; that is an open cleanup/size gap, not a complete pass win. Coalesce retains its existing 90,915-byte canonical size deficit. Performance and parity gaps stay open. Sweep artifacts: `.tmp/pass-sweep-v133-coalesce-source-order-{small,large}-20260926/`.

Evidence: `.tmp/coalesce-source-order-confirm-{small,large}-20260926/`, `.tmp/coalesce-source-order-paired-<fixture>-20260926/`, `.tmp/dae-optimizing-combined-confirm-small-20260926/`, [`hot_source_order.mbt`](../../../../../src/ir/hot_source_order.mbt), [`hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt), [bounded regressions](../../../../../src/ir/hot_source_order_index_wbtest.mbt), [command test](../../../../../src/cmd/coalesce_source_order_wbtest.mbt), and [fuzzing renewal](./fuzzing.md). Initial lifting, preceding-dependency discovery and required local-flow solving remain performance targets.

### Rejected canonical matrix prototype

Binaryen stores an interference pair under canonical `(min, max)` indices. A prototype reused Starshine's existing triangular bit matrix for CFG interferences, reducing a 96-local fixture from 96 bitset allocations to one while preserving every pair. Full-pass results did not justify retaining it: three large compiler pairs measured only `7,844.650ms → 7,798.995ms`, while the 2,048-local 128/512/1,024-loop fixtures slowed `25.085 → 28.398ms`, `32.967 → 35.050ms`, and `47.367 → 48.437ms`. The code and matrix tests were fully reverted; no matrix performance win or oracle signoff is claimed. Artifacts: `.tmp/coalesce-canonical-matrix-paired-<fixture>-20260926/`, `.tmp/coalesce-canonical-matrix-prototype{,-test}.mbt`; rejected native hash `b1c6e1a964d4eb7e5242fb277657d46fbc689ee7578d502a73eed2c0806a49de`.

## September 26, 2026 CFG live-set reuse

CFG interference construction now reuses one live-set workspace across both scans of every block. Initialization visits set members from the existing liveness bitset instead of querying every declared local; resetting clears only the previous members and their positions. Each forward scan still reloads the authoritative live-in facts, retaining member order, ineffective-write interference and parameter/default-value interference. This follows the live-set reuse in [Binaryen 133 CoalesceLocals](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/CoalesceLocals.cpp). Binaryen carries the reverse scan's set directly into its forward scan; Starshine reloads its existing analysis facts. The bitset iterator still scans nonzero words, so this is not a claim of strictly constant work per set member.

Three bounded regressions first failed on 96 membership queries, stale reused membership and six workspace allocations. Four final pass tests cover membership/position reset, one-workspace construction and unused-parameter interference; a command test covers loop-copy coalescing. All 1,100 focused tests pass, as do `moon info` and `moon fmt`; the full wasm-gc suite passes 12463 tests with zero failures. There is no public API change.

Native `8b7d8d8aa8de9342cf6148de10350ca9104217e18d2317cf92b2be7e7d08e0a1` is compared with pre-change `a6385c90382a7a2925d0b4e049a5bcd5ccac3fc8d4f473e7cf41a0411a5943ea`. One warmup and seven alternating large-fixture pairs reduce pipeline median **8,225.246ms → 7,743.340ms (5.9%)**, and command median **9,267.065ms → 8,779.731ms**. Every pair improves, by 359.558–590.659ms pipeline time. All raw outputs remain identical, including three-pair small/large runs of optimizing inlining, DAE and SimplifyGlobals. Small CoalesceLocals is unchanged within noise (`13.843ms → 13.958ms`). Dedicated 2,048-local fixtures with 128/512/1,024 loop blocks improve seven-pair pipeline medians `26.584 → 23.920ms`, `41.526 → 30.288ms`, and `67.823 → 45.549ms`; these synthetic fixtures stay outside the default suite.

Fresh Binaryen 133 pass-local medians remain `13.555ms` Starshine versus `5.123ms` Binaryen on the small fixture and `7,655.209ms` versus `1,091.350ms` on the large fixture. The performance gap remains open. Large canonical output is unchanged at 5,718,540 bytes versus Binaryen's 5,627,625; this pre-existing size gap is not closed by the speedup.

Evidence: `.tmp/coalesce-live-set-confirm-large-20260926/result.json`, `.tmp/coalesce-live-set-paired-{small,large,wide-blocks-128,wide-blocks-512,wide-blocks-1024}-20260926/`, and `.tmp/coalesce-live-set-inputs/manifest.json`. Implementation and regressions: [`coalesce_locals.mbt`](../../../../../src/passes/coalesce_locals.mbt), [`coalesce_live_set_wbtest.mbt`](../../../../../src/passes/coalesce_live_set_wbtest.mbt), and [command fixture](../../../../../src/cmd/coalesce_live_set_wbtest.mbt). Oracle renewal is recorded in the [fuzzing page](./fuzzing.md).

## September 26, 2026 rejected copy/remap fusion

A prototype combined the deep-copy and local-index rewrite traversals in the CFG, structured-interval and single-body-local paths. A bounded control fixture reduced traversal visits from 34 to 17, and tests covered source-array isolation, legacy handler bodies and the active dispatcher; 1,098 focused tests passed. This follows the single index-application phase in [Binaryen 133 `CoalesceLocals::applyIndices`](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/CoalesceLocals.cpp), but Starshine still needs independent output arrays.

The native full-pass evidence did **not** establish a meaningful gain. Three large-fixture pairs after one warmup measured pipeline medians `8,222.178ms → 8,149.123ms`; a seven-pair repeat measured `8,165.653ms → 8,148.049ms`, with per-pair savings ranging from `-194.063ms` to `135.365ms`. Repeat command medians were `9,205.201ms → 9,199.482ms`. Small pipeline medians were `13.919ms → 13.869ms`. Before/after outputs were identical across CoalesceLocals and its three optimizing callers on both compiler fixtures. The candidate was fully reverted and received no new oracle signoff; these timings must not be reported as a committed performance improvement.

Artifacts: `.tmp/coalesce-copy-remap-paired-{small,large}-20260926/`, `.tmp/coalesce-copy-remap-confirm-large-20260926/`, and local prototype snapshots `.tmp/coalesce-copy-remap-experiment{,_wbtest}.mbt`. Baseline native SHA-256 was `a6385c90382a7a2925d0b4e049a5bcd5ccac3fc8d4f473e7cf41a0411a5943ea`; discarded candidate SHA-256 was `016955b1d23dd74709184f36de2695583852c945dc8b5152eb92425c0b41672b`. Remaining profile owners are CFG/source-order work and interference construction, including repeated live-set allocation and dense liveness probing.

## September 25, 2026 sparse copy-score measurement

The verified Binaryen v133 large-input sweep found `coalesce-locals` at `13,358.995ms` versus `1,237.730ms` pass-local on the 6,211,596-byte, 12,904-function input. A snapshot-hazard preflight now bypasses the per-region local-read table when a parameterized function has no `memory.size`; this preserves the existing hazard check whenever that opcode is present, including nested bodies. With the same input, oracle, one warmup, and three measured rounds, Starshine's pass median fell to `12,976.490ms` versus Binaryen's `1,240.950ms`. The approximately 2.9% Starshine improvement leaves a `10.46x` pass-local loss and the same 78,878-byte raw output gap. The next work is per-function phase attribution, shared safety-scan facts, and a scalable sparse coloring path for functions over 4,096 locals. Evidence: `.tmp/pass-sweep-v133-large-coalesce-20260925/result.json`, `.tmp/pass-sweep-v133-large-coalesce-preflight-20260925/result.json`, and `src/passes/coalesce_locals_wbtest.mbt`.

A subsequent control-escape fix checks boundary escape before the more general no-fallthrough query at an `unreachable` sentinel. Both queries previously revisited each nested subtree, causing exponential work on a 24-level `if` fixture: the native benchmark fell from `1.01s` to `3.20µs`. The final v133 large-input coalesce pass median is `8,536.194ms` versus Binaryen's `1,193.200ms`, a 36.1% reduction from the original Starshine run with byte-identical Starshine output across all three samples. The pass still loses `7.15x`; phase probes attribute roughly seven seconds to CFG work, including a 1.4-second HOT lift on one multivalue function. The raw size gap remains 78,878 bytes. Evidence: `.tmp/pass-sweep-v133-large-coalesce-sentinel-final-20260925/result.json`, `src/passes/coalesce_locals_copy_score_perf_wbtest.mbt`, and `src/passes/coalesce_locals_wbtest.mbt`. The explicit-v133 GenValid lane `.tmp/pass-fuzz-coalesce-sentinel-v133-10000-full/result.json` compared `10000/10000` with zero validation, property, generator, or command failures. It reports 157 normalized matches and 9,843 raw mismatches; every mismatching Starshine canonical output is smaller, but those differences remain open for semantic/size classification rather than being accepted on size alone.

The copy-weight builder now creates an integer partner-to-row index only when a row reaches eight entries. Short rows keep linear lookup, while dense rows update existing weights without scanning every preceding partner. In the [native white-box construction benchmark](../../../../../src/passes/coalesce_locals_copy_score_perf_wbtest.mbt), a complete 64-local copy graph improved from `85.32` to `55.38 µs`, and a 128-local graph from `546.67` to `221.60 µs`. The existing coloring benchmark stayed near its previous timing. The extra index uses memory proportional to the local count for each indexed row; full-pass impact remains unmeasured.

CFG coloring now scatters each local's sparse copy weights into reusable indexed arrays before scoring compatible slots. A generation mark by local ID avoids clearing the arrays between locals. The [native white-box coloring benchmark](../../../../../src/passes/coalesce_locals_copy_score_perf_wbtest.mbt) with dense copy weights improved from `28.79` to `13.45 µs` (2.14×) at 64 locals and from `195.23` to `52.08 µs` (3.75×) at 128. A weighted slot-choice regression and 91 existing Coalesce tests pass. Fixture construction is outside timing; full-pass impact remains unmeasured.

## The honest current status

`coalesce-locals` is now an active Starshine module pass with owner file [`../../../../../src/passes/coalesce_locals.mbt`](../../../../../src/passes/coalesce_locals.mbt).

The 2026-07-18 DAEO Func-`41` audit adds one exact structured cleanup family: after branch-aware dead-write rewriting, a void block whose direct tail is `unreachable` may be flattened only when no nested or direct branch targets that block label. Dead tails are truncated only when such a flatten actually occurs. The reduced 625-byte fixture now matches Binaryen v130 byte-for-byte without changing branch-targeted or non-`unreachable` terminal blocks.

The 2026-09-22 correctness audit adds resume-handler targets to structured liveness. `resume`, `resume_throw`, and `resume_throw_ref` now union every `on_label` successor before effective-write cleanup and interference construction, preventing a later fallthrough write from making a handler-observed earlier value appear dead. Valid direct and active-dispatch Core AST fixtures retain both writes around a handled resume.

The current local strategy is direct-pass parity plus exact-slot proof:

- keep the upstream pass spelling active in the registry and CLI surfaces
- keep direct Binaryen parity evidence grounded in fuzz-generated inputs and compatible Binaryen 128 self-opt artifact lanes
- keep the public `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` slot explicit and regression-covered
- keep the focused `reorder-locals -> coalesce-locals -> reorder-locals` replay proven without over-claiming broader public `reorder-locals` scheduling

See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the condensed readiness matrix and validation ladder.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass owner
  - `src/passes/coalesce_locals.mbt`
    - value-aware local action scan, liveness/interference analysis, greedy slot coloring, effective-copy weighting and copy-connected-first coloring order, bounded structured copy-chain forwarding, derived branch-carrier consume-forwarding with destination-read-after-source-write rejection, source-write/destination-read interference restoration after copy/consume relaxation, path-disjoint branch-result slot reuse with same-path clobber-read guards, branch-aware structured effective-write marking for cleanup, local-index rewrite, redundant-copy cleanup, structured ineffective-write cleanup, immediate `nop; drop` debris cleanup after ineffective tee rewriting, dead-set cleanup, loop unread/write-only scratch coalescing, loop adjacent and non-adjacent single-use copy-through coalescing, a 4096-flattened-local guard around dense non-loop coloring matrices, local-name-section invalidation, and the `[AUDIT006-D]` TypeIdx/RecIdx invariant comment
- pass-specific generator profile
  - `src/validate/gen_valid.mbt`
    - `coalesce-locals-all` aggregate plus straight-line, structured, and loop-copy-through leaves for dedicated closeout fuzzing
  - `src/validate/gen_valid_wbtest.mbt`
    - profile-name/alias and emitted-trigger coverage
- active pass-name status
  - `src/passes/optimize.mbt:277`
    - `coalesce-locals` is an active module pass, not a removed-name entry
- direct-pass tests
  - `src/passes/coalesce_locals_test.mbt`
    - registration, non-overlap merge, different-value overlap, later reread liveness, structured param reuse, loop unused-local, unread-local scratch, adjacent copy-chain coalescing, and non-adjacent copy-through coalescing, non-loop structured `local.tee` coalescing, structured self-copy cleanup, bounded structured branch copy-chain forwarding, derived branch-carrier consume-forwarding, branch-aware side-carrier effective writes, effective-copy/copy-connected side-carrier coloring, destination-read-after-source-write guarding, source-write/destination-read interference restoration, path-disjoint branch-result param-slot reuse, structured ineffective copy-set cleanup, ineffective tee debris before immediate drop, the 4097-local dense-coloring boundary, redundant-copy cleanup, ineffective-write cleanup, the exact `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` neighborhood, and the exact `reorder-locals -> coalesce-locals -> reorder-locals` neighborhood
- dispatch and CLI surfaces
  - `src/passes/pass_manager.mbt:8936`
    - explicit `coalesce-locals` module-pass dispatch
  - `src/cmd/cmd_wbtest.mbt:4376-4407`
    - CLI adapter coverage for `--coalesce-locals`
- ordered-slot delivery evidence
  - `docs/wiki/binaryen/passes/coalesce-locals/index.md`
    - new exact-neighborhood regressions
    - refreshed 10k direct parity lane
    - debug-artifact reorder-sandwich replay
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the two top-level no-DWARF slots where `coalesce-locals` belongs:
      - `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
      - `reorder-locals -> coalesce-locals -> reorder-locals`
- exact neighboring local implementation files already worth reading
  - `src/passes/reorder_locals.mbt:2`
    - `reorder_locals_summary()`
  - `src/passes/reorder_locals.mbt:118`
    - `rl_scan_instruction(...)`
  - `src/passes/reorder_locals.mbt:183`
    - `rl_rewrite_instrs_in_place(...)`
  - `src/passes/reorder_locals.mbt:544`
    - `reorder_locals_run_module_pass(...)`
  - `src/passes/reorder_locals_test.mbt`
    - `test "reorder-locals rewrites local names for changed defined functions and clears raw payload"`
  - `src/passes/simplify_locals.mbt:15`
    - `simplify_locals_summary()`
  - `src/passes/simplify_locals.mbt:2`
    - `simplify_locals_descriptor()`
  - `src/passes/simplify_locals.mbt:70`
    - `simplify_locals_new_sinkables(...)`
- exact neighboring living dossiers that define the future slot and local landing zone
  - [`../local-subtyping/index.md`](../local-subtyping/index.md)
  - [`../local-cse/index.md`](../local-cse/index.md)
  - [`../reorder-locals/index.md`](../reorder-locals/index.md)
  - [`../simplify-locals/index.md`](../simplify-locals/index.md)

That code-and-doc map is the practical read-along path: readers can jump directly from the upstream algorithm and source/test map to the exact local status and the future landing zone.

## Freshness note

The 2026-05-05 current-`main` recheck found no teaching-relevant drift in Binaryen's checked owner, scheduler, helper, and dedicated-test surfaces. The Starshine port should therefore be treated as a direct-pass implementation against that documented Binaryen contract, with ordered-pipeline placement still reserved for a separate neighborhood replay.

## What Starshine currently does for this pass name

Today Starshine's behavior for `coalesce-locals` is an active explicit-pass implementation.

### 1. The name is active, not merely tracked

`src/passes/optimize.mbt` keeps the upstream spelling `coalesce-locals` in the active module-pass registry, and `src/passes/pass_manager.mbt` dispatches it to `coalesce_locals_run_module_pass`.
That means:

- the project treats `coalesce-locals` as a real runnable pass
- the spelling is preserved in the registry-level compatibility surface
- the pass is covered by direct registry, dispatcher, CLI, and pass-fuzz harness tests

That is the right current behavior for a direct-pass implementation whose public preset placement still needs ordered-neighborhood replay.

### 2. The work is tracked as a landed parity slice, not an orphan idea

The landed deliverables now cover:

- compatibility and lifetime analysis
- exact type-compatibility rules
- value-aware interference for overlapping same-value locals
- local-index rewrite, declaration compaction, redundant-copy cleanup, structured self-copy cleanup, structured `local.tee` coalescing under the non-loop conservative overlay, bounded structured copy-chain forwarding and derived branch-carrier consume-forwarding into dead slots with destination-read-after-source-write rejection, source-write/destination-read interference restoration after copy/consume relaxation, path-disjoint branch-result slot reuse with same-path clobber-read guards, branch-aware structured effective-write marking for cleanup, effective-copy weighting/copy-connected coloring order, loop unread-local scratch coalescing, loop adjacent/non-adjacent copy-through coalescing, structured ineffective-write cleanup, ineffective-set cleanup, and a finite dense-coloring boundary for huge non-loop functions
- explicit registry, dispatcher, CLI, and harness wiring

The current docs should keep that slice connected to the exact Binaryen contract:

- exact-type-only coalescing, not subtype merging
- value-aware interference, not plain lifetime overlap
- parameter freezing and zero-init entry rules as correctness facts
- copy-removal profitability, not only local-count reduction
- repeated scheduler placement, not a one-shot standalone pass

### 3. The scheduler slot is already documented, and the missing neighbors matter

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places `coalesce-locals` in two deliberate late cleanup slots.
That matters because `coalesce-locals` is not meant to run in isolation.
Upstream Binaryen expects other passes to expose the right shapes first:

- `local-subtyping` should narrow declarations before exact-type-only coalescing freezes the slot choices
- `local-cse` and full `simplify-locals` profit from the simpler post-coalescing local traffic
- the later `reorder-locals -> coalesce-locals -> reorder-locals` cluster shows that declaration compaction and slot sharing are meant to interact, not compete

Current Starshine now has the declaration/index rewrite neighbor (`reorder-locals`), the type-tightening neighbor (`local-subtyping`), the downstream cleanup neighbors (`local-cse` and `simplify-locals`), and focused proof for both exact `coalesce-locals` neighborhoods.
The 2026-07-30 closeout expands the pass-owned generator to eleven families and completes the required explicit-v131 matrix: regular `100000/100000`, dedicated `10000/10000`, all `9956` comparable wasm-smith cases after one established cleanup normalization, and random-all with every one of the `1250` direct cleanup-shape differences converging byte-for-byte after common downstream cleanup. Label-depth-aware dead-tail handling closes the eleven former downstream losses and removes a real local-branch truncation hazard. Safe loop wrapper flattening, loop-backedge preference, and same-source fanout coloring close the remaining lit transform gaps; the official input is now `22` bytes smaller, with only equal-size numbering drift beyond seven measured smaller bodies. The ordered suffix is exact, its apparent fixpoint issue reproduces identically in Binaryen, and the byte-identical retained performance probe is now materially faster than Binaryen. Direct owner slice `[COALESCE-LOCALS]001` is closed; broader preset work proceeds under `[O4Z-PRESET]001`.

The July 19 DAEO loop-coloring experiment confirms that the current exact loop subsets are still the correct production boundary. Generic loop-aware coloring first admitted externally invalid definite-initialization shapes; after a nondefaultable-local barrier made the standalone output valid, integrated DAEO still regressed raw size by `432` bytes, canonical size by `806`, canonical gross-positive bodies by `916`, and pass time by about `794.501s`. That widening was reverted. A future expansion must carry exact initialization state and be selected by measured per-function profitability instead of replaying dense coloring across the broad changed-boundary batch.

## The right future Starshine implementation shape

For a checklist-style implementation and validation ladder, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The current docs and neighboring code strongly suggest that a future local `coalesce-locals` port should be taught as a **late local-slot sharing pass that composes with existing declaration rewrite and cleanup machinery**, not as an isolated textbook register allocator.

Why:

- Binaryen runs it in deliberate neighbor clusters, not alone
- the upstream pass is centered on exact-type local-slot reuse plus copy deletion
- Starshine already has module-side local index and name-section rewrite machinery in `reorder-locals`
- Starshine already has a later cleanup consumer in `simplify-locals`
- the remaining broader optimize-path work now lives outside direct `coalesce-locals` parity itself

So the local strategy should be thought of as:

1. identify a MoonBit-side representation of the real upstream compatibility rules
   - exact type equality
   - value-aware overlap rejection
   - parameter and zero-init entry rules
   - locals that must never be coalesced
2. preserve the same conservative boundaries locally
   - no subtype-based merging inside this pass
   - no fake wins from dead/unreachable traffic
   - copy-removal profitability should stay part of the objective
   - later name/index repair must remain explicit
3. compose it with the surrounding local cleanup ecosystem
   - `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
   - `reorder-locals -> coalesce-locals -> reorder-locals`
   - existing local metadata rewrite and later cleanup surfaces already maintained in-tree

In other words, the active direct pass now slots into a cleanup ecosystem that exists in-tree and has exact-neighborhood proof; the remaining work is broader preset and neighboring-pass policy, not direct `coalesce-locals` uncertainty.

## The most important local dependency map

### Upstream `coalesce-locals` depends on prior local type tightening

See [`../local-subtyping/index.md`](../local-subtyping/index.md).

Why it matters locally:

- Binaryen coalesces only exact-equal local types
- the reviewed upstream scheduler places `local-subtyping` immediately before `coalesce-locals`
- if Starshine later narrows locals in the same way, `coalesce-locals` can inherit those cleaner exact-type opportunities instead of trying to widen its own scope

The active Starshine port should preserve that lesson instead of broadening `coalesce-locals` into a type-changing pass.

### The ordinary late run feeds directly into upstream `local-cse` and full `simplify-locals`

See [`../local-cse/index.md`](../local-cse/index.md) and [`../simplify-locals/index.md`](../simplify-locals/index.md).

Why:

- Binaryen runs `local-cse` after `coalesce-locals`
- full `simplify-locals` then cleans up the resulting local traffic again
- the pass therefore belongs to a late local-traffic simplification cluster, not a disconnected declaration-only phase

So a future Starshine implementation should treat those consumers as real neighbors, not afterthoughts.

### Existing Starshine `reorder-locals` code is the nearest landed local-index and metadata rewrite surface

See [`../reorder-locals/index.md`](../reorder-locals/index.md), `src/passes/reorder_locals.mbt`, and `src/passes/reorder_locals_test.mbt`.

Why:

- a future `coalesce-locals` port will have to rewrite local indices honestly
- `reorder-locals` already owns the module-side scan/rewrite machinery for local users and grouped-local-run rebuilding
- the landed name-section regression proves the repo already has one canonical place that keeps function-local names and `raw_name_sec_payload` stable after local index changes

That does not make `reorder-locals` an implementation of `coalesce-locals`, but it does make it an important local read-along file.

### Existing Starshine `simplify-locals` code is the nearest landed later cleanup consumer

See [`../simplify-locals/index.md`](../simplify-locals/index.md) and `src/passes/simplify_locals.mbt`.

Why:

- the current local `simplify-locals` pass already owns later local-traffic cleanup and structured result lifting in HOT form
- the upstream scheduler expects `coalesce-locals` to hand simpler local traffic into that neighborhood
- the active `coalesce-locals` port should therefore stay bounded to coalescing-specific cleanup instead of absorbing every simplify-locals family itself

## What Starshine does **not** claim yet

A future contributor should be careful not to overread the current local surface.
Starshine now has direct-pass implementation and evidence, and it now **does** claim exact-neighborhood proof for:

- `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
- `reorder-locals -> coalesce-locals -> reorder-locals`

What it still does **not** claim is that every broader neighboring-pass or public preset policy question is closed. The current repo status is best summarized as:

- active direct pass
- direct 10k parity refreshed on 2026-07-04 after fixing structured param-slot reuse, loop unused-local coalescing, and branch-aware structured effective-write marking
- both exact scheduler neighborhoods replayed
- first public slot kept explicit, second slot still focused because public `reorder-locals` scheduling is tracked elsewhere

## Validation plan for preset placement

The existing backlog plus neighboring pass docs imply the remaining validation ladder.
Future preset placement should validate in this order:

1. reduced shape tests for the real upstream families
   - exact-type positives
   - equal-value overlap positives
   - differing-value overlap negatives
   - zero-init and param-entry cases
   - redundant-copy wins and dead-set cleanup cases
2. negative correctness tests
   - subtype-only near misses
   - dead/unreachable traffic not creating fake wins
   - locals that must stay uncoalesced
   - loop-backedge and greedy-order sensitivity cases
3. cluster interaction tests
   - `local-subtyping -> coalesce-locals`
   - `coalesce-locals -> local-cse -> simplify-locals`
   - `reorder-locals -> coalesce-locals -> reorder-locals`
   - local-name and raw-name-section stability checks after rewrites
4. artifact and oracle comparison
   - the canonical no-DWARF debug-artifact replay path for the exact neighborhoods that own `coalesce-locals`
   - any broader preset or neighboring-pass artifact lane once the surrounding slices explicitly call for it

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact surrounding code surfaces.

## Bottom line

Current Starshine `coalesce-locals` strategy is direct-pass parity plus exact-slot proof:

- the upstream spelling is intentionally active in `src/passes/optimize.mbt`
- the canonical two-slot no-DWARF story is now regression-covered and backed by a current-head reorder-sandwich artifact replay
- the direct pass has focused tests, CLI coverage, full `moon test`, refreshed 2026-07-04 10k regular GenValid parity evidence, older 10k mixed-generator parity evidence, debug/optimized artifact self-opt canonical-function equality for the direct pass, and a green debug-artifact reorder-sandwich compare on normalized WAT plus canonical functions
- total optimized-artifact wall time for the direct pass is still slightly above Binaryen, but the pass-local runtime issue is retired
- the docs keep one important honesty rule explicit: proving `coalesce-locals` itself does not automatically settle every broader `reorder-locals` or preset scheduling question

So the right mental model today is “active direct pass, exact slots proven, broader neighbor policy still explicit.”
It is:

- **active direct transform**
- **current-head direct parity refreshed after the 2026-07-04 structured/loop unused-local and branch-aware structured effective-write fixes**
- **both exact scheduler neighborhoods replayed**
- **clear neighboring implementation map for broader preset follow-up**
- **clear warning not to over-claim unrelated neighboring-pass policy as part of direct `coalesce-locals` signoff**

## September 27, 2026: fuse lowered-body copying and remapping

The loop CFG rewrite now copies its analyzed, lowered instruction body and maps
local indices in one recursive traversal. It still rewrites the capture-aware
lowered body: remapping the original raw body would lose required temporary and
capture handling. Parameter entries and slot types use the existing coloring.
Every mutable structured child array is copied, including legacy catch bodies;
unchanged scalar instructions retain their original values.

[Ownership and reference-equivalence tests](../../../../../src/passes/coalesce_copy_remap_wbtest.mbt)
cover nested controls, legacy catches and parameter slots. The
[dispatcher test](../../../../../src/cmd/perf_coalesce_copy_remap_wbtest.mbt)
checks a live loop's results. [Native controls](../../../../../src/passes/coalesce_copy_remap_perf_wbtest.mbt)
compare the former copy-then-remap path with the fused path at 32 and 512 regions.
Sources: [copy/remap](../../../../../src/passes/coalesce_copy_remap.mbt) and
[CFG rewrite](../../../../../src/passes/coalesce_locals.mbt).
The historical claim above that the pass-local gap was retired applies to its
older fixture/oracle; the current large-compiler performance gap remains open.

Uncontended native controls improve **4.40 → 3.78 µs** at 32 regions and
**72.88 → 60.28 µs** at 512. These isolate copying/remapping and do not claim
that the whole pass improves by the same percentage. Evidence:
`.tmp/pass-perf-reuse-20260927/accepted-bench-coalesce_copy_remap_perf_wbtest-1.log`.

## September 28, 2026 performance reuse contracts

Raw source-hazard steps are compiled once for an immutable body and replayed for each candidate source. Barriers, copy exceptions, control joins and deterministic remapping retain the reference behavior. This removes repeated raw instruction classification; expanded CFG construction, interference and lowering remain separate measured owners.

Tests and native controls: [coalesce_source_hazards_wbtest.mbt](../../../../../src/passes/coalesce_source_hazards_wbtest.mbt), [coalesce_source_hazards_perf_wbtest.mbt](../../../../../src/passes/coalesce_source_hazards_perf_wbtest.mbt). The [campaign report](../../../tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign) owns frozen-binary artifact timings, verified-v133 evidence and final correctness outcomes; helper timings alone do not close the remaining pipeline or parity gaps.

## September 28, 2026 follow-up performance contracts

One immutable preorder control index serves action collection, depth collection
and local-only rewriting. Its packed fallthrough/escape facts preserve catch-label
depths, unreachable sentinels and loop/legacy boundaries; dead subtrees skip via
preorder end offsets. Extra interference kernels enumerate occupied matrix bits
and maintained live members while retaining type, parameter and source-order
rules. Bounded reference tests cover all three kernels.

The renewed artifact matrix and dedicated correctness lanes are recorded in the
[follow-up report](../../../tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign).


## October 2, 2026 — Shared reachability for cleanup and backward liveness

The large native profile confirms repeated nested control proofs in
`cl_remove_ineffective_tees` and `cl_mark_structured_liveness_backward`.
Both previously computed a recursive reachable prefix at every child body.
The structured rewriter now builds one immutable `CLControlIndex` and shares
it with action collection, backward liveness, local remapping and tee cleanup.
Reverse liveness records only reachable sibling starts; then/else offsets
include dead tails, while dead instructions consume no action ordinals.
Local-only edits cannot change control transfer. Existing catch/branch/loop
facts, suffix-read tee checks, final validation and tiny/flat fallback remain.
No public API changes.

On the fixed 6,211,596-byte compiler fixture, one warmup and five alternating
untraced pairs give **5,182.892 ± 36.137 → 5,043.683 ± 16.215 ms** (median ±
MAD). The paired median change is **−3.81%**; the difference of medians is
139.209 ms. Matched Binaryen 133 is **1,989.742 ± 32.610 ms**; the remaining
full-command ratio is **2.53×**. Three separate traced pairs give inner CL
**4,099.385 ± 20.466 → 3,891.449 ± 14.895 ms**. These timer scopes are not
additive. Foreign CPU activity occurs in some rows; retain their flags.
The small paired change is −.15%, within noise, and traced inner increases
9.041→9.157 ms. Do not claim a small-module gain.

The first tee-only trial did not prove a large-command gain (paired +1.11%);
it is superseded by the shared-index trial, not counted as another saving.
Native ten-batch tee controls remove the quadratic trend: depth 64 is
29.75→5.53 µs and depth 256 is 460.63→20.60 µs; depth 0/8 overhead remains
explicit (80.45→87.17 ns and .985→1.31 µs). These first-trial helper numbers
are not the final shared-index command timings or allocation evidence.

Large raw output remains **5,706,503 bytes**, small **191,046**, with exact
predecessor/candidate hashes in every traced and untraced row. This preserves
existing quality but does not close the canonical gap. Two work-bound
regressions first fail after output, ownership and action assertions pass.
All **13,290 bounded default wasm-gc tests**, info/fmt/check and native release
build pass. A dispatcher regression retains imported calls and a nested trap.
All 14 final native controls pass: tee depth 64/256 improves
27.85→5.05 / 435.25→20.20 µs; backward liveness improves
38.72→20.11 / 653.14→212.75 µs (ten-batch mean). Tiny costs remain:
tee depth 0/8 is 76.64→86.51 ns / .938→1.17 µs; backward depth 8 is
1.42→1.73 µs. The reverse sibling rows add bounded per-body storage, and
remaining label-live copies mean the entire liveness walk is not claimed
linear. A bounded original/predecessor/candidate/v133 execution matrix
independently validates 24 modules and compares 72 observations of returns,
state/memory, effects and trap occurrence, with no mismatch and exact
predecessor/candidate bytes. Aggregate fuzz/coverage/full release signoff
remain deferred; no independent agent/human review is available.

Evidence: local `.tmp/large-pass-hotspots-20261001/{cl-v2-pairs/result.json,
cl-liveness-red.log,cl-red.log,cl-v2-suite.log,cl-v2-candidate-manifest.json}`.
Frozen before SHA `71046b0c50308aea3dc15a8599d21bfe86602cf6bca1d2f7d57ec650be7f8269`,
after `199d293ba755f14cd0e94b82f8d018cb8dc4ed71ee63c87432e906d53023efe1`.
Sources: [implementation](../../../../../src/passes/coalesce_locals.mbt),
[regressions](../../../../../src/passes/cl_tee_control_wbtest.mbt),
[native controls](../../../../../src/passes/cl_tee_control_perf_wbtest.mbt),
[dispatcher](../../../../../src/cmd/cmd.mbt). CFG/lift/lower, interference,
other repeated source queries and canonical parity remain P04 work.


## October 2, 2026: complete main module-pass attribution

The frozen main699648988 CLI366ed01c… profiles the unchanged6,211,596-byte
compiler under CPU6. Instrumentation starts at `run_hot_pipeline_apply_module_pass`
before its first child; collection covers one complete
`coalesce_locals_run_module_pass`, including internal guards. Parsing and final
CLI validation/encoding remain outside this scope. The debugger driver has a300s
deadline, completes and validates exact output5706503B, SHA256
`de0757b5f756efcad9ffccaa5dcc575fd11647820dcca09eb721bd61f63162ca`.
This replaces no historical partial profile: earlier parts/scopes keep their
original source/version. The matched normal v133 matrix remains a separate run.

Root49,112,542,755 instructions. Source-backed nonrecursive entry edges:

| Owner / edge | Inclusive instructions |
| --- | ---: |
| Module→CFG loop lane |35,333,371,034|
| Module→ordinary function lane |10,264,331,735|
| CFG lane→HOT lower |10,895,209,932|
| CFG lane→interferences |3,273,565,935|
| Lift capture→local-access conflicts |3,437,443,491|
| CFG build→region builder |2,231,127,567|
| Safe copy interference→forward scan |1,111,227,302|
| Control index→body boundary |368,112,118|
| Tee cleanup→worker |135,936,789|

These edges overlap; neither summing them nor using recursively inflated
inclusive totals is a phase breakdown. `moonbit_drop_object` exclusive work
6,645,403,035 (13.53% root) indicates significant destruction work; it is not
an allocation count or byte/RSS measurement. **Attribution correction:** the
original getter self0 row matched the wrong symbol (`get__hot__node` instead of
`hot__node__get`); it was not evidence of inlining or free copies. The subsequent
[checked arena read checkpoint](#october-2-2026-checked-arena-reads-for-lift-local-conflicts)
records corrected getter attribution and actual native call boundaries. [Lowering](../../../../../src/ir/hot_lower.mbt),
[lift masks/capture](../../../../../src/ir/hot_lift.mbt) and
[interference](../../../../../src/passes/coalesce_locals.mbt) remain the larger
source-backed targets, ahead of already repaired reachability/tee admission.

Inspect unchanged canonicalization/row ownership and exact masked conflict
traversal before choosing an optimization. Existing64-bit masks, full typing,
side-effect/trap ordering, handlers, valid coloring and deterministic bytes
remain required. Do not widen masks solely because collisions are possible;
measure the consumer and storage tradeoff. The rejected per-flat SL cache
shows large synthetic gains can leave the compiler worse. The separate
optimizing command baseline's138MiB peakRSS deficit requires phase attribution,
not a guessed cause. Speed, canonical quality and aggregate gates remain open.

Artifacts: `.tmp/large-pass-hotspots-20261001/main-cl-scope-candidate.*`,
`main-cl-scope-costs.json`, `profile-main-cl-scope.py`, original manifests/hash.


## October 2, 2026: retain unchanged lowering cleanup rows

The private [lower strip worker](../../../../../src/ir/hot_lower.mbt) now returns
its read-only input when the complete scan makes no edit. On the first and later
edits, a scalar cursor emits disjoint unchanged prefixes and the final tail.
It retains all preservation options, later-local-read queries and unreachable
behavior. No new collection/cache/API or verification shortcut; the existing
empty scratch row remains. Public lowering's preceding emitted/canonicalized
rows are owned: direct root/arm mutation preserves the input and later lowering.
The root-identity regression genuinely failed before implementation.

Exact main45df918c9 baseline CLI366ed01c… versus candidatefd2abde6… on the fixed
6,211,596 B compiler: complete CL module-pass instructions
**49,112,542,755→48,469,710,862 (−1.309%)**, complete optimizing cleanup
**20,126,748,368→20,107,910,056 (−.094%)**. CL strip exclusive instructions
237,890,824→124,740,504 are nested, not another additive saving. Parsing/final
CLI validation/encoding are excluded; both bounded profiles complete with exact
validated outputs. A stale verifier artifact path failed after CL completion;
normal-exit logs and the actual paired output recover verification without
rerunning or treating a partial capture as complete.

One warmup/five alternating normal pairs, median±MAD ms:

| Command | Starshine before | After | Binaryen133 | Paired change |
| --- | ---: | ---: | ---: | ---: |
| CL |4595.264±46.602|4763.210±84.057|1763.781±9.522|+.715%|
| DAE2-O |7495.994±120.762|7162.457±266.091|2521.723±62.640|−2.459%|

All rows flag foreign activity; CL has no command win, and the optimizing gain
has broad overlapping spread. Three separate traced inner diagnostics are
inconclusive for CL. Do not claim quiet-host speed parity or add unlike scopes.
Exact wait4 peakRSS KiB(n5) is CL244824±136→244912±16, B217556±24;
optimizing294328±72→294248±44, B155140±8: no peak-memory win. Full ranges,
commands, CPU/version/source/input hashes and rows remain in the local report.

Twelve native controls include wide unchanged1.17µs→184.59ns and preserved
nops2.05µs→353.17ns. Active tee16 instead costs809.44→840.34ns (+30.90ns);
a noisy repeat does not dismiss this tradeoff. Existing suffix queries can
still be quadratic. Four [direct regressions](../../../../../src/ir/hot_lower_strip_storage_wbtest.mbt),
[frozen controls](../../../../../src/ir/hot_lower_strip_storage_perf_wbtest.mbt),
dispatcher fixture,13,338 bounded wasm-gc tests, info/fmt/check/native build,
README/API sync and234 validated modules/672 fixed differential observations
pass. Scalar/i64/GC/traps/order and public root/nested ownership are covered.
No public interface diff; full aggregate fuzz/coverage/CI and independent
review remain open. Output hashes stay exact: CL5706503 B, optimizing5563501 B.
This preserves existing byte improvements, not canonical parity.

Artifacts: `.tmp/large-pass-hotspots-20261001/main-lower-strip-performance-20261002.md`,
`lower-strip-*-pairs/result.json`, `lower-strip-*-manifest.json`,
`lower-strip-cl-costs.json`, `lower-strip-optimizing-costs.json`, original logs.
The next measured targets are CFG/lift/capture and interference/coloring;
already-retained unchanged strip rows need no repeat implementation.


## October 2, 2026: stop weightless member searches after the first valid slot

Below64 locals, [member coloring](../../../../../src/passes/coalesce_locals.mbt)
kept searching after its first valid zero-score choice even with an empty
immutable copy-weight row. All later scores are zero and earliest slots win
strict-greater ties. Five lines stop only that case; every nonempty weighted row
retains the complete search. Types/interferences/parameters, source hazards,
captures, coloring/remap, dense path and complete verification remain. No new
storage, helper/cache/API or assumptions about positive weights/overflow.

Actual red: exact output/input assertions pass before22 !=10 work-bound failure.
The [regressions](../../../../../src/passes/coalesce_member_zero_score_wbtest.mbt)
retain weighted later-slot preference, type/conflict checks, ties and reverse
order. The existing slot reference exactly matches predecessor ef3e10438's
worker; no duplicate reference is added. Dispatcher fixture transforms an
ordered, imported-effect loop with a carried copy and later independent value.

Frozen nativefd2abde6…→f111fea4…, same6,211,596 B compiler: complete CL
module-pass instructions48,469,710,862→48,327,939,076 (−.2925%). Nonrecursive
color-with-order→member edge714,957,651→571,703,733 (−20.04%); nested
interference339,264,760→265,272,920 and score51,342,670→33,686,308 overlap.
Never sum these or translate instruction savings into wall/allocated bytes.
Across both lowering/search changes CL root falls1.598% from49,112,542,755.
Complete bounded profile exits normally with validated identical bytes.

Five normal alternating pairs, one warmup, CPU6, all foreign-activity flagged:
median±MAD S5043.340±208.991→5108.202±71.587ms, v1332023.686±29.593ms,
paired+2.706%. No large command win. Separate three traced inner diagnostics
3997.629±140.450→4036.230±44.300ms are inconclusive. PeakRSS KiB n5
244648±256→244760±120, B217560±16 is flat. Eight
[native controls](../../../../../src/passes/coalesce_member_zero_score_perf_wbtest.mbt)
show weightless32/63 3.83→1.51 /9.60→6.05µs; weighted63 instead costs
9.12→9.26µs, repeat8.61→8.95µs (+.34µs,+3.95%). This observed weighted cost
stays open. Remaining member queries are bounded below64; no global linearity
claim. Score-zero accumulation still runs, with no second saving counted.

Info/fmt/check/native build,13,341 bounded wasm-gc tests, eight native controls
plus two weighted repeats, README/API sync and121 validated modules/348 fixed
runtime observations pass. No interface diff; exact output5706503 B preserves
all existing byte quality, not canonical parity. Build-only/tmp exhaustion is
recovered using ignored repository-local compiler TMPDIR, with failed logs kept
and no foreign data/process touched. Full aggregate fuzz/CI/coverage and
independent review remain open. Larger CFG/lift/interference/command owners take
priority over ratios or guard microtuning; quiet-host evidence is still needed.

Artifacts: `.tmp/large-pass-hotspots-20261001/main-member-zero-performance-20261002.md`,
`member-zero-*-manifest.json`, `member-zero-*-costs.json`,
`member-zero-coalesce-locals-pairs/result.json`, original gate/control/runtime logs.
[Current four-pass command matrix](../../../tooling/tracing-playbook.md#october-2-2026-main-weightless-member-checkpoint)
keeps all host flags and the broad Binaryen CL spread explicit.


## October 2, 2026: scalar words for small single-word cliques

`cl_cfg_sparse_add_live_member_interferences` now handles3–15 live entries in
at-most64 rows using one scalar UInt64 word. Precheck all selected valid row
shapes before mutation, then OR the mask excluding each diagonal into its row.
Duplicates, invalid-member filtering, preexisting diagonals/unrelated edges and
selected noncanonical-row fallback are preserved. Tiny/wide/16+ paths remain
complete. No new heap container/cache/helper/API or verification shortcut;
generated native code uses uint64_t and the same two-argument ABI. The original
small path allocated no scratch either; no allocated-byte/RSS saving is claimed.

Complete baseline profile finds7,156,158 checked-pair calls/744,240,432 nested
instructions versus32,956 mask constructors/4,408,350: repeated pair work is the
confirmed target, not mask allocations alone. Exact main1c8485122/f111fea4… versus
candidate ddc2b774…: complete CL instructions48,327,939,076→48,137,746,501
(−.39355%); nonrecursive compute→clique entry1,068,151,059→877,462,663 (−17.85%).
Nested pair/interference edges overlap. Collection completes normally under300s,
validates exact output, and excludes parsing/final CLI validation/encoding.
Three accepted CL fixes together reduce49,112,542,755→48,137,746,501 (−1.985%).

One warmup/five alternating CPU6 normal CL commands, median±MAD ms:
S5044.567±55.049→5053.472±109.127, B1332036.637±15.455; paired+1.282%.
Every row flags foreign activity; the range reaches10.427s amid unrelated Go
compilation. No full-command speedup is established. Three separate traced inner
rows3953.689±20.478→3950.424±47.251ms are inconclusive. Exact wait4 peakRSS
KiB244800±72→244836±96, B217472±8: no peak win.

Twelve initial unpinned native controls plus eight CPU6 repeats pass. Repeat
row32/live8 improves166.56→34.34ns and row64/live15 592.08→48.09ns;
wide65/live8 costs159.52→169.99ns (+10.47ns), tiny2 21.29→22.38ns. Keep these
fallback tradeoffs visible; the measured complete-consumer reduction supports
this bounded branch, not a universal shape win. Four [direct regressions](../../../../../src/passes/coalesce_scalar_clique_wbtest.mbt),
[frozen predecessor](../../../../../src/passes/coalesce_scalar_clique_reference_wbtest.mbt),
[controls](../../../../../src/passes/coalesce_scalar_clique_perf_wbtest.mbt), active
dispatcher loop fixture,13,346 wasm-gc tests, info/fmt/check/build/API sync and
125 validated modules/360 fixed observations pass with byte-exact CL5706503 B.
No public interface changes; ordered effects/traps/GC and input ownership covered.
Manual review completes; independent review/full aggregate fuzz/CI/coverage stay
open. Binaryen133 and runtime-only compact-import expansion retain prior protocol.

Artifacts: `.tmp/large-pass-hotspots-20261001/main-scalar-clique-performance-20261002.md`,
`scalar-clique-*-manifest.json`, `scalar-clique-costs-{before,after}.json`, native
storage/source reviews, command pairs and runtime rows. Other passes keep the
preceding1c/f111 matrix provenance. Larger shared CFG/lift/lower/verification,
CL capture/conflict traversal, weighted/wider work and size gaps remain active.


## October 2, 2026: retain unchanged binary-constant spill cleanup storage

The private lowering spill cleanup keeps all recursive visits, original later-read/
type/control checks and exact five-entry permutations. Unchanged rows/control
shells are retained; copy the parent on its first child change and the complete
nested row before its first flat edit. Scan guards keep reading original nested
input. No new helper/cache/API, mandatory-check removal or skipped optimization.
Public lowering owns preceding emitted/canonicalized rows and performs recursive
final canonicalization; root/nested mutation preserves input and later lowering.
Native code has two change-guarded Array.copy sites and no unconditional array
constructor. This is not an allocated-byte or peak-memory percentage claim.

Main db1412a75/ddc2b774… versus08382360… candidate, same fixed compiler and
complete normally finished300s-bounded module profile: CL root
**48,137,746,501→47,745,254,152 (−.81535%)**. Nonrecursive lowering→spill entry
493,491,749→190,043,937 (−61.49%); lower-body entry9.454b→9.061b overlaps it.
Recursive edges are not added to phases; parsing/final CLI validation/encoding
are outside scope. Last four CL fixes together reduce49.113b→47.745b (−2.784%).

One warmup/five alternating CPU6 normal commands, median±MAD ms:

| Command | Starshine before | After | Binaryen133 | Paired change |
| --- | ---: | ---: | ---: | ---: |
| CL |5289.570±115.064|4980.679±60.348|1990.480±16.113|−3.457%|
| DAE2-O |7301.133±116.990|7379.340±56.890|2559.307±34.185|+.868%|

All samples flag foreign activity. CL shows an observed paired gain with lower
complete instruction work; quiet-host signoff is open. Optimizing has no command
win: older ef3 optimizing cleanup attributes only20.845m at this entry, and many
preserve-flat paths skip it. That historical scope is a lead, not a new phase
measurement. Separate traced CL inner3963.465→4038.779ms has broad spread and is
inconclusive. Exact wait4 peakRSS KiB CL244752±32→244648±60/B217600±0;
optimizing294296±16→294192±76/B153100±0: no peak win, phase cause unknown.

Twelve CPU6 native controls improve tiny73.68→16.62ns, wide1283.28→1.62µs,
nested1283.67→1.67µs, all16 active permutations2.84→2.19µs, fully guarded128
12.05→6.45µs and changed-arm/unchanged-sibling3.50→1.78µs. Later-read query
scaling stays open. Five [direct regressions](../../../../../src/ir/hot_lower_spill_storage_wbtest.mbt),
[frozen predecessor](../../../../../src/ir/hot_lower_spill_storage_reference_wbtest.mbt),
[controls](../../../../../src/ir/hot_lower_spill_storage_perf_wbtest.mbt), dispatcher,
13,352 wasm-gc tests, info/fmt/check/build/API sync pass. Three fixed lanes validate423 modules/compare1224 observations with exact
CL/plain/optimizing bytes. Scalar/i64/f64, GC/effects/traps and
public ownership covered. An unfinished default-WASM run is archived as incomplete;
the replacement wasm-gc suite fully passes. No public API change; independent
review/aggregate fuzz/full CI/coverage remain open. Byte-quality gaps are unchanged.

Artifacts: `.tmp/large-pass-hotspots-20261001/main-spill-storage-performance-20261002.md`,
`spill-storage-*-pairs/result.json`, manifests, completed CL costs, native-storage
review, fixed runtime rows and original logs. Source/binary/input/v133 hashes,
flags/backend/CPU, spreads and raw/canonical protocols remain explicit. Next
measured candidate: lift conflict/mask full-header reads; neither their removal
nor a performance benefit has been implemented or assumed yet.


## October 2, 2026: checked arena reads for lift local conflicts

Source: [lift workers](../../../../../src/ir/hot_lift.mbt),
[shared checked admission](../../../../../src/ir/hot_mutate.mbt),
[bounded regressions](../../../../../src/ir/hot_lift_access_fields_wbtest.mbt),
[frozen predecessor](../../../../../src/ir/hot_lift_access_fields_reference_wbtest.mbt),
[native controls](../../../../../src/ir/hot_lift_access_fields_perf_wbtest.mbt),
[dispatcher](../../../../../src/cmd/cmd.mbt). Local full evidence:
`.tmp/large-pass-hotspots-20261001/main-lift-access-fields-performance-20261002.md`
and `lift-access-fields-*` manifests/results/profile/machine-code artifacts.

Main c2aec5040 baseline native08382360…; candidate e57d9b45…;
same 6,211,596 B compiler SHA98189860… and verified v133 SHA8f25e9fd….
Two private reads now use the same checked admission followed by the existing
arena record, rather than returning all eight fields through a native 32-byte
HotNode boundary. Actual baseline machine code has one full-header getter call
per worker; the candidate has zero public/private complete-header calls in both.
The Unit admission call remains. No new view object, helper, cache, allocation,
API or IR representation; wasm-gc still reads the existing object.

Every early return, visit, liveness/error/fallback check, recursive child query,
mask/readiness operation and exact collision fallback is retained. No positive
mask shortcut or verification omission. New tests compare every mask/ready row
and traversal count against the frozen worker, including fresh facts after
mutation, incomplete deletion-index fallback and local0/64 collisions. The
canonical dispatcher covers pending local values across writes. Actual native
boundary assertions fail on the predecessor before implementation and pass on
candidate machine code; the change does not repair a semantic behavior gap.

Corrected baseline exclusive getter work is1,718,793,946 instructions across
all CL consumers; candidate1,186,522,179. Conflict→getter inclusive523,890,855
is nested and cannot be added to conflict/root. Earlier getter self0 used a
wrong-name filter and is superseded, not evidence of compiler elimination.
Complete CL scope47,745,254,152→47,506,930,728 instructions (−0.49916%);
nonrecursive capture→conflict3,437,447,864→3,207,090,539 (−6.7014%).
Bounded delayed Callgrind exits normally with exact validated output;
parse/final CLI validation/encoding excluded. Recursive inclusive totals overlap.
These instructions justify the narrow change; they are not allocation bytes or
an equivalent percentage command-speed gain.

CPU6, GCC14.2/O2/mimalloc, build outside timing; one warmup/n5 alternating
normal fresh processes with warm filesystem. Median±MAD milliseconds:

| Pass | Before | After | Binaryen133 | Paired change |
| --- | ---: | ---: | ---: | ---: |
| dae2 | 3826.450±33.139 | 3816.061±7.324 | 1120.057±8.250 | −0.216% |
| coalesce-locals | 4484.109±7.269 | 4486.629±9.747 | 1778.481±7.655 | +0.190% |
| dae2-optimizing | 6862.454±377.852 | 6589.943±199.950 | 2440.277±121.585 | +0.853% |

All rows flag foreign CPU activity. DAE2/CL differences are within spread;
optimizing median reduction is not a causal win given paired change/contention.
Normal ranges/raw rows are in the local report/results. Separately traced n3
S inner medians: plain3082.533→3066.548ms; CL3512.402→3501.260;
optimizing5581.497→5563.897. These are diagnostics, not a matched B inner matrix.

Normal peakRSS KiB: CL244892±44→244752±100/B217568±28;
optimizing294464±48→294396±108/B153096±0. Plain n5 initially shows
255740±9900→265476±464; retain this apparent9736KiB median rise. A separate
one-warmup/n3 alternating CPU6 repeat gives268160±84→268196±76,
ranges266364–268244 versus248080–268272. Lower memory modes appear on either
binary; no consistent regression or peak-memory win established. Phase/lifetime
cause remains open, as does optimizing's about138MiB excess.

Twelve CPU6 native controls (ten-batch means, setup/equality outside timing):
uncached negative32 520.40→471.23ns, cold negative32 including masks1.18→1.10µs,
collision negative32 558.71→520.68ns and warm positive32 326.39→294.00ns;
leaf17.73→17.01ns, warm negative20.05→19.81ns (within spread). Full batch spread
is retained. Local gains do not establish whole-command/Binaryen parity.

Full wasm-gc13,355/13,355 passes before the late dispatcher is compiled; that
new test then passes separately1/1. Do not report a single full13,356 run.
moon info/fmt/check, native release build, twelve native controls and API sync
pass; no .mbti change. Three fixed runtime lanes validate447 modules/check1296
observations total, original/before/after/v133, including effects/traps, state,
memory, GC and permitted floating-point behavior. Node26's compact-import
rejection uses the documented runtime-only v133 text expansion; raw outputs
remain exact. Manual source/frozen review; independent agents unavailable.
No long fuzz campaign. Final aggregate/CI/coverage and quiet timings remain open.

Raw plain/CL/optimizing bytes remain6,115,221/5,706,503/5,563,501, preserving
V83 and previous fixes. Raw optimizing−9,949 B does not close separately bounded
canonical+99,251 B. Larger DAE2 dependency/CFG work, cleanup setup, exact positive
mask traversal, shared validation/lowering and OI command envelope remain next;
retain earlier tiny/tee/weighted/wide controls as active tradeoffs.


## October 2, 2026: use compact counts throughout lowering

[Lowering](../../../../../src/ir/hot_lower.mbt) only reads exact use counts at
its two count-query sites. Replace its full use-site/local graph with existing
`HotNodeUseCounts`; pass it through eleven private workers, without changing
public analyses, transforms, IR, API or mandatory verification. The complete
reachable live root/child walk counts every reference and visits each producer
once. Site kind/user/slot and local/block overlays are unused by lowering.
Region-root and child references retain identical multiplicities. Fresh counts
remain required after mutation; orphan/deleted nodes stay zero.

[Three bounded regressions](../../../../../src/ir/hot_lower_use_counts_wbtest.mbt)
compare all counts with full use sites, including block/loop/if/TryTable, typed
parameters/results, GC, shared operands, repeated roots and snapshot independence.
The [dispatcher](../../../../../src/cmd/cmd.mbt) retains nested results while
both DAE2 modes actively remove an unused helper parameter; CL also validates.
[Six native controls](../../../../../src/ir/hot_lower_use_counts_perf_wbtest.mbt)
exclude construction/equality from timing. Actual native regression is red first:
predecessor lowering calls the full builder once; candidate calls it zero times
and the compact builder exactly once. No annotation/C-only inference.

Main86fc89961/e57d9b45… baseline, candidate c93901ee…;
same6,211,596 B compiler SHA98189860… and verified v133 SHA8f25e9fd….
Complete CL module profile, bounded300s/normal exit/exact validated hash:
47,506,930,728→45,745,669,624 instructions (−3.7074%). Direct lowering entry
9,059,207,915→7,283,301,643 (−19.6033%); nested analysis construction
1,354,964,981→275,647,919 (−79.6565%). Lowering's direct object destruction
1,169,138,988→479,207,794 is nested too, not an additional phase. Neither sum
nested edges nor infer allocated bytes/RSS from instructions/shared call counts.
Parse/final CLI validation/encoding are excluded from this profile.

CPU6/GCC14.2/O2/mimalloc release, build outside timing, one warmup/n5 alternating
normal fresh-process/warm-filesystem commands. Median±MAD milliseconds:

| Pass | Before | After | Binaryen133 | Paired change | After/B |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3845.083±7.476 | 3768.526±15.606 | 1121.804±1.798 | −2.181% | 3.36× |
| dae2-optimizing | 6422.674±34.933 | 6320.913±8.961 | 2410.442±21.913 | −1.584% | 2.62× |
| coalesce-locals | 4579.288±7.001 | 4459.136±34.020 | 1790.915±9.380 | −2.692% | 2.49× |
| optimize-instructions | 2348.396±52.903 | 2278.473±71.614 | 1028.363±61.973 | −2.996% | 2.22× |

All normal rows flag foreign CPU activity; work reduction corroborates the
observed paired gains, without establishing quiet-host1× parity. Raw ranges,
exact commands/input/tool hashes/flags and wait4 CPU/RSS remain in local results.
Traced diagnostics are separate: n3 plain, n1 CL/OO/OI, not matched B inner scopes.
Explicit native release repeat (ten-batch means): tiny853.86→71.71ns,
medium3.69µs→530.14ns, wide60.92±12.65→10.88±1.71µs. Larger wide spread is retained;
initial controls47.20±.445→7.94±.087µs corroborate, not whole-pass ratios.

PeakRSS KiB median±MAD n5: plain266268±1832→266744±1084;
OO294572±24→294528±64; CL244740±112→244744±140; OI156412±176→156356±80.
No material peak-memory win. Fewer constructed site/local objects follow the
source/native contract; allocation-byte counts are not measured. Plain memory
modes and optimizing's≈138MiB excess remain. Raw hashes stay exact:
plain6,115,221/B6,232,586; OO5,563,501/B5,573,450;
CL5,706,503/B5,627,625; OI6,205,998/B6,172,971 B. V83 retained;
raw OO−9,949 B does not close separately bounded canonical+99,251 B.

All13,360 default wasm-gc tests, info/fmt/check/native release/API sync pass;
no .mbti change. Four fixed original/before/after/v133 lanes validate628 modules
and check1824 runtime observations: state, memory, GC, ordered effects/trap
occurrence and finite FP, including nested helper results/typed loops. Compact
import expansion is runtime-only; raw evidence untouched. Manual source/consumer/
native review; independent agents unavailable. No long fuzz. Final aggregates,
CI/coverage, canonical gaps and the1× pass/command target remain active.

Next direct lower owners: emitted roots2,964,843,620 and label/source setup
1,329,439,032 instructions, both within the7.283b entry. Measure deferred facts
and temporary result arrays with full ordering/effect/buried-value checks before
retaining another cache. Existing DAE2 CFG/read-source and cleanup/validation/OI
owners remain. Local report and all exact manifests/results:
`.tmp/large-pass-hotspots-20261001/main-lower-use-counts-performance-20261002.md`,
`lower-use-counts-*`. Completed mechanisms move here; active tasks stay in backlog.


## October 2, 2026: avoid temporary arrays in lower result stacks

[`hot_lower_impl_push_results`](../../../../../src/ir/hot_lower.mbt) reads stored
result shapes directly, preserving scalar/tuple lane order, all checks, the
unresolved-block error and independently writable public `hot_type_results`.
No new object/cache/API/IR representation; stack-value objects still allocate.
[Field/ownership tests](../../../../../src/ir/hot_lower_result_stack_wbtest.mbt),
[dedicated controls](../../../../../src/ir/hot_lower_result_stack_perf_wbtest.mbt)
and the mixed-tuple dispatcher fixture cover repeated pushes, void/scalar/GC,
resolved blocks and active DAE2 removal. Actual native owned-query call1→0
fails on the predecessor and passes on the candidate.

Main43da34011/c93901ee… baseline, candidate c4165396…; same compiler
SHA98189860…/verified v133 SHA8f25e9fd…, CPU6/GCC14.2/O2/mimalloc.
Accepted bounded300s full CL capture exits normally with exact validated output:
root45,745,669,624→45,477,394,646 (−.586449%); nested lower7,283,301,643→
7,013,368,094 (−3.706198%); nested result-push574,473,589→301,119,321
(−47.583435%). Do not sum nested costs or use off-scope allocator counts.
Explicit release native controls, ten-batch mean±σ ns: void16.19±.16→11.64±.06;
scalar32.43±.13→21.53±.20; tuple73.43±.26→50.63±.09.

Normal one-warmup/n5 alternating CLI medians±MAD ms:

| Pass | Before | After | B133 | Paired change |
| --- | ---: | ---: | ---: | ---: |
| DAE2 | 3911.495±121.598 | 4000.468±71.176 | 1174.730±32.875 | +2.102% |
| DAE2-O | 6325.451±17.035 | 6351.003±35.572 | 2335.604±8.912 | +.792% |
| CL | 4400.999±20.867 | 4691.291±92.225 | 1801.694±18.412 | +2.996% |
| OI | 2205.672±3.265 | 2215.836±6.229 | 928.787±3.496 | +.274% |

Every row flags foreign CPU activity; this cohort has no consistent clock win.
One justified bounded CL repeat retains all original data:4398.143±25.927→
4351.828±26.160ms/B1787.193±4.291, paired−1.042%; reduced instructions
corroborate a small consumer gain, not quiet-host1× signoff. RSS is not a win:
repeat median244744±732→248820±408KiB (+4076KiB); both binaries reach≈249MB
in the initial cohort. Phase/lifetime/pool-mode cause remains unresolved.

Independent one-warmup/n3 alternating traced/debug timers, all hashes equal
normal artifacts: DAE2 S3005.985±23.209/B431.100±.522ms;
CL3359.694±3.030/B1137.040±2.870; OI79.059±.011/B239.510±2.282.
OO S5480.129±6.657ms; v133 runs explicit DAE2/SL/Vacuum. Binaryen debug1
runs function passes serially and verifies outside timers; Starshine module
DAE2/CL include lift/lower/checks, while OI narrow timer excludes substantial
raw setup/cleanup. These scopes are not equivalent total-work ratios or normal
command walls. Exact OO per-row sums and all spread/phase rows live in the report.
OI's narrow gain does not close its≈2.39× normal CLI gap.

All13,362 default wasm-gc tests, six native controls, info/fmt/check/native
release build and README/API sync pass; no .mbti changes. Four fixed v133 lanes
validate660 modules/check1920 observations, including mixed numeric/GC tuples,
effects/state/memory/traps/finite FP. Before/after raw hashes remain exact; V83
and all size improvements preserved. Canonical gaps, memory modes and final
aggregate/CI/coverage remain open; no long fuzz. Manual review, no independent
agent. Local exact report:
`.tmp/large-pass-hotspots-20261001/main-lower-result-stack-performance-20261002.md`.

Next larger CL lead is unnecessary full use-def construction: baseline c939
attributes1.384b instructions to node/local-use discovery inside the2.094b
builder, though liveness consumes only block sets. A narrow actual constructor
must reuse the complete block scanner/shape validation/solver and retain full
HotUseDef APIs, fresh-snapshot and exceptional-edge behavior. Do not disguise an
incomplete overlay as a complete graph. DAE2 dependency/lift and optimizing
cleanup remain larger campaign owners;1× parity is not achieved.


## October 2, 2026: build Coalesce liveness without unused use-site graphs

Coalesce's CFG path used full `HotUseDef` solely to build liveness. The old
builder collected node/local use sites that this consumer never read. Main
`d4541bb83` / native `c4165396…` is the frozen baseline; candidate `02637b4c…`.
[`liveness_build_from_func`](../../../../../src/ir/liveness.mbt) now invokes the
same complete block scanner, shape checks and fixed-point solver directly.
The old full graph and owned liveness APIs remain complete. No persistent cache,
new view or verification shortcut is introduced. The CFG must represent the same
current function snapshot, rebuilt after mutation. Existing block scanning still
constructs unused local-write-block scratch; that is a remaining measured lead.

The actual native Coalesce CFG rewrite's full-builder call goes from one to zero,
replaced by exactly one new constructor call: the native work contract fails on
the frozen baseline and passes on the candidate. Added bounded
[liveness regressions](../../../../../src/ir/liveness_from_func_wbtest.mbt) compare
all live-in/out rows with the full path in both operand/exceptional-edge modes:
no-op, branch, loop, typed control, GC, exception edges, shared operands, 96 locals
and fresh facts after mutation while retaining old facts. Implementing-file and
active dispatcher tests validate GC and loop carrier cleanup. These behavioral
controls protect equivalence; they do not demonstrate a prior semantic defect.

Same6,211,596B /12,904-function compiler SHA98189860…, verified Binaryen133
SHA8f25e9fd…, CPU6 Ryzen78845HS, native GCC14.2/O2/mimalloc. Build excluded.
One warmup/n5 alternating normal fresh-process CLI commands, warm filesystem;
median±MAD and range in milliseconds:

| CL command | Median±MAD ms | Range ms |
| --- | ---: | ---: |
| Before | 4431.467±34.244 | 4353.523–4814.550 |
| After | 4214.653±25.652 | 4186.341–5013.043 |
| Binaryen133 | 1789.610±17.290 | 1772.320–1879.403 |

Paired median−4.8926%; current command ratio2.36×, so1× remains open. Every row
flags foreign CPU activity. Independent traced n1 is diagnostic only: CL module
pass3390.306→3212.553ms, including lift/lower/checks, not an equivalent Binaryen
inner comparison. The complete matched CL Callgrind scope exits normally within
300s with exact validated output:45,477,394,646→43,436,953,845 instructions
(−4.4869%). Direct old builder2,094,065,353 plus liveness1,188,734,059 becomes
new constructor2,203,269,455; its nested block scan707,357,481 and solver
1,187,411,377 are included, not additional costs. No allocation-byte/count claim
from off-scope allocator instrumentation. Native controls, ten-batch mean±σ:
tiny4.49µs±73.42ns→1.82µs±17.92ns; medium8.16µs±102.12ns→2.52µs±54.04ns;
wide64.02µs±747.08ns→14.61µs±94.68ns. Helper ratios do not sign the full pass.

PeakRSS KiB median±MAD245012±128→249212±52; ranges244808–249556 versus
244576–249488 overlap. The observed median+4200KiB is unresolved; both native
binaries show low/high modes. No RSS win or causal explanation is established.
Raw CL output remains exactly5,706,503B/SHAde0757b5… versus B5,627,625B;
all predecessor hashes and V83 savings stay intact. The78,800B canonical CL gap
and99,251B optimizing gap remain distinct, active quality work.

`moon info/fmt/check`,13,367/13,367 default wasm-gc tests, native release CLI,
six explicit release controls and README/API sync pass. Fixed v133 runtime lane:
169 validated modules,492 observations across41 fixtures (state/memory/GC,
effect order, trap occurrence and finite FP). Runtime-only v133 text expansion
handles Node's unsupported compact imports without changing timed raw artifacts.
`.mbti` adds only the narrow constructor. Manual source/API review completed;
independent agent unavailable. Aggregate fuzz/full CI/coverage remain deferred
under the bounded performance campaign; default coverage gates stay unchanged.
Other pass timings are still the frozen c416 checkpoint, not renewed by this CL
cohort. DAE2 dependencies/lift, optimizing cleanup, shared lower label/source
facts and OI envelope are the next larger owners; parity is not achieved.
Exact commands, hashes, source manifest, normal/traced rows and bounded profile:
`.tmp/large-pass-hotspots-20261001/main-cl-block-liveness-performance-20261002.md`.


## October 2, 2026: separate effect-only lowering from ordering demand

Main5ec1e3556/native02637b4c… is the baseline; candidatee7529ee2…. Lowering
previously built all source-order/local-query rows eagerly. A first lazy-factory
trial skipped only225/4565 factories and saved merely.114528% CL instructions:
scalar stack reuse still constructed full facts to read only `node_effects[id]`.
Its plain CLI paired+.650% and carried native controls regressed; that trial
was not committed independently. Frozen7861595d… and exact evidence remain in
`.tmp/large-pass-hotspots-20261001/lower-lazy-order-v1-diagnosis.md`.

[`hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt) now separates private
immutable effect-mask demand from complete ordering demand. It uses the existing
complete mask builder, memoized CFG operand-order proof and full source-order
fallback. An explicit per-region dependency plan records proved empty selection;
a `None` suffix index alone never means empty. All unproved regions construct
complete facts and retain the same dependency selection/emission. Buried scalar
reuse still checks the complete composed effects; it does not rescan the stack
for pure values. Result arity is read once; impossible buried-scalar cases and
final roots avoid irrelevant queries. No transform or verification is removed.

[`HotSourceOrderFacts::new`](../../../../../src/ir/hot_source_order.mbt) can adopt
already-composed private masks from the same immutable lower. The sole optional
caller passes its existing mask row, checked for arena length; ordinary callers
keep the default complete construction. No public borrowed view escapes.
Minima retire before full facts are built; transferred masks retire from the
frame after adoption. Facts/masks never survive semantic mutation or another
function/lower. The small native plan uses `#valtype`; no replacement IR,
persistent cache or broad pipeline refactor is introduced. New scratch is
bounded by one function's nodes and shared operand minima are visited once.

TDD: eager single/forward-root field regressions fail before the initial change;
the buried scalar regression then fails on v1 while retaining exact emitted
instructions/stack checks. Revised
[tests](../../../../../src/ir/hot_lower_lazy_order_wbtest.mbt) compare lazy/eager
instruction and extra-local arrays for no-op, nested/typed control, loops, GC,
traps/memory and exception edges; verify cold siblings, fresh analysis after
mutation, single construction, complete mask equivalence and physical adoption
without copying. Active DAE2 and command-dispatcher tests prune an unused call
parameter while retaining the pre-write argument snapshot. All13,374 default
wasm-gc tests, info/fmt/check/native release CLI, eight native controls and
README/API sync pass, with no public `.mbti` change. Four v133 runtime lanes
validate692 modules/check2016 observations across42 fixtures. Runtime-only
compact-import expansion remains separate from raw timed/size artifacts.

Same6,211,596B /12,904-function compiler SHA98189860…, verified v133
SHA8f25e9fd…, CPU6 Ryzen78845HS/GCC14.2/O2/mimalloc. Build excluded; one warmup,
n5 alternating normal fresh-process CLI commands with warm filesystem.
Median±MAD milliseconds, with all ranges/raw rows retained locally:

| Pass | Before ms | After ms | B133 ms | Paired change | After/B |
| --- | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 4300.668±36.596 | 4244.746±50.739 | 1291.718±16.741 | −.533% | 3.29× |
| DAE2-O | 7562.007±23.739 | 7299.012±80.794 | 2594.935±29.086 | −2.380% | 2.81× |
| CL | 4773.114±22.751 | 4601.658±62.996 | 2083.079±6.779 | −4.372% | 2.21× |
| OI | 2690.061±100.418 | 2633.724±30.778 | 1034.079±3.749 | −2.785% | 2.55× |

Every row flags foreign activity. Host conditions differ from prior checkpoints;
retain them under their own cohorts rather than treating absolute cross-cohort
changes as regressions/gains. Small plain clock gain is within spread; no quiet
host or1× signoff. Independent traced n1 before→after module timers:
DAE23468.551→3274.795ms, OO6322.982→6104.684, CL3600.958→3407.232;
OI narrow86.429→88.850 while its pipeline1738.538→1734.833. These are diagnostic
scopes, not renewed matched B inner comparisons. OI's envelope remains a priority.

Complete matched CL profile exits normally within300s with exact validated hash:
43,436,953,845→42,377,392,745 instructions (−2.439308%); nested lower
7,014,296,576→5,956,325,888 (−15.083062%). Actual lower full-fact factories
4565→297 (79,147,192 instructions);4083 effect-only builds cost596,655,907.
CFG retains its297 complete factories; its default wrapper and inner edges
are nested, not separate calls. Forty lower full builds adopt existing masks.
Do not sum nested costs or derive scoped allocation bytes from shared allocators.

Native controls, ten-batch mean±σ: forward tiny1.45µs±37.95ns→985.20ns±9.03ns;
forward wide236.33µs±6.18µs→164.18µs±357.55ns. Carried full fallback costs remain
open: tiny1.15µs±4.51ns→1.29µs±3.67ns; wide117.21µs±239.51ns→124.14µs±181.83ns.
The reference/selected component lanes share final-root handling and exclude
fixture/verification setup; they do not sign a whole-pass ratio.

PeakRSS KiB medians: DAE2265752→255680 (−10072, ranges overlap),
OO294192→294244, CL244776→244676, OI156232→156380. Lower private source rows
are avoided by construction, but no causal whole-command RSS win is established;
plain/CL low/high modes and optimizing≈138MiB excess remain open. All raw
predecessor hashes and V83 savings remain exact: OO5,563,501B versus B5,573,450B
is distinct from bounded canonical5,686,688B versus5,587,437B (+99,251B).
CL/SL/OI canonical gaps and broader release signoff remain active.

Manual source/API review, independent agent unavailable; no long fuzz. Aggregate
GenValid/full CI/coverage stay deferred under the performance campaign with gates
unchanged. Next measured targets are DAE2 dependencies/lift/reverse-query
lifetimes, optimizing cleanup and OI envelope, plus exact-payload header copies.
Native IDs are already unboxed: do not manufacture a boxed-ID heap fix. The
remaining descending prefix search is quadratic on repeated-lane final mismatch,
but current CL direct entry work25,405,350 instructions (~.0585%) makes it a lower
compiler priority; prove a wide active consumer before adding linear-fallback
scratch. Exact report/protocols/hashes/ranges:
`.tmp/large-pass-hotspots-20261001/main-lower-demand-effects-performance-20261002.md`.


## October 2, 2026: checked scalar reads for exact payload queries

Mainbc6f6ea3b/nativee7529ee2…→6e22e72f…. All three exact-instruction payload
queries returned a complete32-byte node to select only opcode/immediates.
[`hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt) keeps the
same checked live-node admission and puts the unchanged lane/opcode selection
in that arena query. The unused private by-value selector is removed; public
queries, invalid/deleted/incomplete-node paths and verification stay complete.
No cache/view/allocation is added. IDs were already unboxed: this removes
header traffic rather than node/ID heap objects. Native work contract fails
before the change and passes for all three actual readers after it.

[Bounded regressions](../../../../../src/ir/hot_payload_fields_wbtest.mbt)
cover every payload family/both lanes, absent payloads, bounds, mutation,
incomplete deletion metadata and ownership. Implementing DAE2/active command
fixtures prune an unused argument through numeric/GC/trapping-memory operations.
All13,379 default tests, info/fmt/check/native build/README API sync and
[24 native controls](../../../../../src/ir/hot_payload_fields_perf_wbtest.mbt)
pass; no public API changes. Four verified-v133 runtime lanes validate708 modules
and2064 observations across43 fixtures. Raw output and V83 savings are exact.

Matched complete CL instructions42,377,392,745→42,321,757,023 (−.131286%);
nested payload verification224,611,363→174,745,573 (-22.200920%). Do not sum
these nested costs. An initial separate scalar-helper trial saved only.089675%
and added a wrapper boundary; its combined controls omitted the original
selector and were diagnostic, not a faithful before benchmark. The selected
controls retain the original by-value selector and isolate each query. Tiny
present ID13.36±.37→10.09±.43ns, instruction19.70±.33→13.61±.42ns,
verification13.76±.44→11.75±1.64ns (ten-batch mean±σ); all wide lanes improve.

Normal n5 one-warmup alternating CPU6 fresh CLI/warm filesystem, median±MADms:

| Pass | Before | After | B133 | Paired % | After/B |
| --- | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 4023.598±27.745 | 4081.539±83.697 | 1226.426±27.000 | +1.440 | 3.328× |
| DAE2-O | 6895.288±80.055 | 6993.348±74.721 | 2508.565±40.995 | −1.342 | 2.788× |
| CL | 4512.422±101.983 | 4535.650±60.614 | 1978.689±32.228 | −1.715 | 2.292× |
| OI | 2399.182±6.421 | 2443.540±37.293 | 979.768±2.775 | +1.650 | 2.494× |

Every row flags foreign CPU; command gains are not established and1× remains
open. PeakRSS before→after mediansKiB:258520→256276,294364→294404,
244692→244760,155920→156252; no causal memory win. B normal timings differ from
historical cohorts; retain each source/date/scope. Fresh matched n3 named timers
are DAE23190.564/B491.551ms, OO6026.947/B explicit row-sum1778.100ms,
CL3423.120/B1270.190ms and OI90.380/B253.911ms. B debug serializes function
passes/validates outside timers; Starshine module scopes include setup/lift/lower
and validation, while OI excludes its large envelope. Debug output hashes equal
normal artifacts; do not compare debug command wall to normal wall or sum
medians/nested stages. Scope details and remaining byte/memory/release blockers:
[checkpoint](../../../tooling/tracing-playbook.md#october-2-2026-main-checked-payload-query-checkpoint).

Manual review, independent agent unavailable. Full CI/coverage/aggregate GenValid
remain deferred under the focused performance campaign with gates unchanged.
Next pilot: repeated lift conflict walks,1.529b exclusive CL instructions.
Trial a bounded Byte extent in the existing uint8 readiness row, with saturation
retaining full recursion; prove it avoids work in complete consumers and keeps
cold/wide fallbacks, mutation/append/collision safety and allocations/bytes.
Exact source/binary/input hashes, commands, all ranges/RSS/raw rows and
trial failures are in local
`.tmp/large-pass-hotspots-20261001/main-payload-direct-match-performance-20261002.md`.


## October 2, 2026: completed local-band proofs in lift

Supersedes the unimplemented Byte pilot above; main177be8505/native6e22e72f…
→d08c0fdb…. The old modulo64 masks recurse for every positive or colliding bit.
[The private lift cache](../../../../../src/ir/hot_lift.mbt) replaces its
readiness byte with complete single-band/mixed-maximum proofs.0 cold,1 empty,
2..129 single bands0..127,130..254 mixed max bands0..124,255 unknown. A single
band makes low-six-bit identities unique, proving positives or cross-band
negatives. A known mixed maximum rejects queries above it; all other positive
queries keep full recursive checks. Read/write masks, checked Unit admission,
negative/deleted/incomplete-index behavior and immutable operand lifetime stay
complete. Append-only reuse is permitted; semantic mutation needs fresh masks.
No new cache arrays, public API, graph view or verification omission. Native
Bool uint8_t and Byte moonbit_bytes_t elements share width; their allocator
headers may differ, so this is not allocated-byte or peak-memory evidence.

[Red-first bounded regressions](../../../../../src/ir/hot_lift_byte_extent_wbtest.mbt)
fail on repeated warm positive/high-id walks, including the first max-only
prototype's high-local positive failure. Selected coverage includes read/write
queries, band collisions, mixed/shared DAGs, append, mutation freshness and
intentionally invalid negative-local fallback. Historical field controls keep
the original Bool cache separately. Active DAE2 and command fixtures actually
prune a callee argument while preserving held pre-write imported-call values.
13,386 default tests, info/fmt/check/native build/API sync and32 native controls
pass. Four original/before/after/v133 runtime lanes validate724 modules/check2112
observations across44 fixed fixtures; calls/state/memory/traps/finite FP agree.
Raw compiler hashes, public API and V83 size improvements remain exact.

Complete CL instructions42,321,757,023→42,055,017,035 (−.630267%). Nested conflict
wrapper3,207,151,555→2,941,538,817 (−8.281889%), recursive visits16,899,160→
14,418,574. Never sum overlapping recursive/parent edges or infer cause from
counts alone; complete matched work and bounded exact-answer regressions support
this gain. Significant mixed/unknown repeated walks remain. Native ten-batch
mean±σ warm positive32 333.60±14.28→21.52±.50ns, collision32
547.46±3.57→20.65±.83ns; cold positive1.47→1.25µs and collision1.65→1.29µs.
Saturated positive307.41→316.96ns and collision534.75→626.79ns regress; warm
negative20.58→21.32ns remains visible. Wide512 positives5.45µs→24.27ns and
collisions10.38µs→23.37ns. These helper gains do not close enclosing parity.

Normal n5 alternating CPU6, one warmup, fresh CLI/warm filesystem, median±MADms:

| Pass | Before | After | B133 | Paired % | After/B |
| --- | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 4213.773±73.882 | 4426.975±213.283 | 1301.502±14.096 | +4.736 | 3.401× |
| DAE2-O | 7238.873±479.252 | 7108.224±176.857 | 2526.604±25.495 | +2.541 | 2.813× |
| CL | 4448.593±24.922 | 4599.278±72.573 | 1949.186±45.078 | −.022 | 2.360× |
| OI | 2485.738±35.372 | 2427.675±38.118 | 969.681±2.776 | −3.490 | 2.504× |

Every row flags foreign activity, including concurrent external compilation.
Mixed clock changes establish neither a command win nor quiet-host1× signoff.
RSS medians before→afterKiB:265092→264928,294364→294412,244232→244744,
157108→157884; modes and optimizing excess remain unexplained. Independent
traced n1 is diagnostic, not a refreshed B inner comparison. The prior n3
named checkpoint retains its original source/scopes; do not equate it with
current normal wall. Exact commands/sources/input/binary hashes, ranges/all
samples, layout proof and failures:
`.tmp/large-pass-hotspots-20261001/main-lift-byte-extent-performance-20261002.md`.
Manual review; independent agent unavailable. Full CI/coverage/aggregate GenValid
remain deferred by the focused campaign; gates unchanged. Canonical OO+99,251B
remains separate from raw−9949B. Remaining priorities: DAE2 dependency/cleanup,
OI envelope, Coalesce copy-pair structural scans and unused block-write rows.
The prior complete CL profile attributes1.255b inclusive instructions/81,738
initial scans to safe copy forwarding: its existing global-barrier proof can
potentially eliminate repeated guaranteed-false scans without changing answers.
That next pilot is unimplemented here and needs complete consumer evidence.


### DAE2 consumer attribution follow-up

The same frozen6e22→d08c complete DAE2 profiles both exit normally with exact
validated output:34,604,264,255→34,604,091,968 instructions (−.000498%),
effectively unchanged. The band proof addresses CL conflict walks; it does not
establish DAE2 throughput gains. DAE2's current lift costs11.397b across10,422
calls, dependency analysis9.881b, rewrite lower4.647b across2468 functions and
mandatory final validation3.639b. Nested dependency CFG5.186b/read sources2.019b/
entry proof.790b overlap analysis; never sum these costs. Source locations:
[analysis and relift](../../../../../src/passes/dead_argument_elimination2.mbt),
[CFG](../../../../../src/ir/cfg.mbt), [read solver](../../../../../src/ir/local_graph.mbt).
Exact complete profiles/parent edges are local
`lift-byte-extent-dae2-{baseline,candidate}-costs.json` and
`lift-byte-extent-dae2-exclusive-costs.json` in the existing evidence root.
Prioritize those actual DAE2 owners, including immutable scalar CFG object churn;
retaining all first-lift functions would add memory and is not justified.


## October 2, 2026: reject globally blocked copy pairs once

Main7a5676ba9/natived08c0fdb…→dbbaefbe….
[Safe-copy forwarding](../../../../../src/passes/coalesce_locals.mbt) previously
repeated a complete structural scan for each reachable source/destination pair.
Every scan unconditionally rejects Br/BrIf/BrTable/Return/Loop/TryTable in
traversed Block/If arms. Reuse the existing exact global-barrier predicate once
at the first nonempty source row; functions without candidates keep their
source-row-only path. Barrier-free pairs retain the original full proof,
recursion depth, candidate discovery, type checks and matrix mutations. Opaque
shells follow the same existing predicate/scanner policy. No new allocation,
cache, public API, admission widening or verification omission.

Native actual-consumer work contract fails before (zero guard calls) and passes
after (one static call; private flag permits at most one execution).
[Bounded matrix/chain/ownership regressions](../../../../../src/passes/coalesce_copy_barrier_wbtest.mbt)
compare a faithful pre-fix consumer over direct/nested/either-arm barriers,
positive chained forwarding, pending failures and type/parameter boundaries.
Active implementing/dispatcher fixtures reduce locals while retaining imported
call effects behind a branch. All13,391 default tests/info/fmt/check/native
build/API sync and10 dedicated native controls pass;185 modules/540 original/
before/after/v133 observations across45 fixed fixtures agree. Public API and
large raw bytes/hashes remain exact; canonical CL+78,800B stays open.

Complete matched CL instructions42,055,017,035→40,822,716,968 (−2.930209%).
Nested safe-copy owner1,254,988,260→22,083,059 (−98.240377%), initial pair scans
81,738→5917, recursive structural visits12,218,641→12209. Costs are nested,
not additive; counts alone are not a causal timing proof. Full work reduction,
exact matrix answers and actual native consumer corroborate the removed scans.

Normal one-warmup/n5 alternating CPU6 fresh CLI/warm filesystem, median±MADms:
before4491.022±56.275, after4416.546±70.418, B1331963.489±27.857; paired−.699%,
after/B2.249×. Range4432.538–4547.297→4290.693–4486.964ms; every row flags
foreign activity, so no quiet-host1× claim. Separate traced n1 module3394.961→
3289.098ms is diagnostic, without a renewed B named comparison. Traced/normal
hashes match. PeakRSS244540→244608KiB medians overlap; no memory win.

Ten-batch native mean±σ: flat guarded32.77µs±168.69ns→160.75±.18ns; nested
71.07µs±257.16ns→424.19±3.06ns. Clear8 21.41±.563→22.62±1.21µs,
clear51271.19±.402→69.71±5.80µs; keep dispersion and added proof costs visible.
No-edge51255.32±2.41→84.34±13.73ns costs29.02ns while retaining O(locals),
with no added body scan. That bounded control remains in the backlog; do not
claim every input improves. Full release/coverage/aggregate gates remain open.

The evidence driver initially retained the preceding measurement filename;
it stopped before timing at the existing-directory protection. No old result
was overwritten/accepted. Corrected measurements/runtime/profile resumed
without repeating passing gates; original failure is retained. Manual source/
API review, independent agent unavailable. Exact hashes/commands/dirty state,
all normal/traced/RSS rows, red/green and control logs:
`.tmp/large-pass-hotspots-20261001/main-copy-barrier-performance-20261002.md`.
DAE2/O/OI values above retain their d08c source and scopes. Actual DAE2 owners
remain lift/dependency CFG/read sources/lower/validation; next allocation pilot
is immutable scalar CFG edges, currently two native objects per builder call.


## October 3, 2026: shared scalar CFG edge storage

[Shared source/contracts/evidence](../dae2/starshine-strategy.md#october-3-2026-inline-scalar-cfg-edge-storage)
retain all479,079 Coalesce edge-builder invocations while eliminating958,158
separate record requests. Complete matched CL work40.822717b→40.482683b
(−.832954%). Normal n5 CPU6 CL4375.941±34.693→4311.431±54.395ms,
B1947.387±23.953; paired−1.157%, remaining2.214×, all contended. Output hashes
and78,800 canonical-byte gap remain;13,395 tests/10 controls/756 modules/2208
observations pass. RSS ranges overlap and empty-row control adds.75ns. This is
a measured shared representation gain, not completion of CL or release gates.


## October 3, 2026: indexed reverse signature validation

[Shared source and measured tradeoffs](../dae2/starshine-strategy.md#october-3-2026-indexed-reverse-signature-validation)
remove4,331,346 iterator allocation calls while retaining all 4,146,538 typed-pop
checks. Complete CL work 40,482,682,526→40,006,461,795 (−1.176357%); normal
CLI5300.039±357.333→5348.326±288.166ms/B2323.327±173.602 remains contended
and does not prove a clock win.13,403 tests and772 runtime validations/2256
observations pass; raw hashes/canonical gap78,800B remain. DAE2 work improves
2.070902%, but its repeat CLI is flat. Memory modes, command/quality gaps and
release gates remain open. Private declaration-walker allocation work belongs
to validation outside this CL module-pass scope; do not extrapolate a gain here.


## October 3, 2026: inline lift node shapes

The [shared private representation change](../dae2/starshine-strategy.md#october-3-2026-inline-private-lift-node-shapes)
removes1,350,276 CL allocation requests with every factory call/payload retained.
Complete CL instructions 40,007,028,213→39,883,336,242
(-0.309176%). Initial normal n5 CLI is3830.191→3848.662ms
(paired+0.824%); the separately retained n3 repeat is
3851.585±38.221→3846.790±26.032ms,
paired-0.840%. Foreign activity, RSS overlap and
canonical+78,800B remain. Instruction/allocation gains do not prove universal
throughput parity. All four raw hashes and 2352 runtime observations are retained.
