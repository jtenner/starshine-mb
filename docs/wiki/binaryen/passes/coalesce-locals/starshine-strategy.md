---
kind: concept
status: supported
last_reviewed: 2026-09-26
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

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

Use this page together with the [`coalesce-locals` landing page](./index.md)'s tagged source list, the retained 2026-05-05 research recheck, and the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that track the pass, and the remaining validation/placement constraints.

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
