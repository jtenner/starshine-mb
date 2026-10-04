---
kind: concept
status: supported
last_reviewed: 2026-10-03
sources:
  - ../../../src/passes/constraint_lower.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/binary/encoded_size.mbt
  - ../../../src/binary/encode_control.mbt
  - ../../../src/ir/hot_mutate.mbt
  - ../../../src/ir/hot_core.mbt
  - ../../../src/ir/cfg.mbt
  - ../../../src/ir/local_graph.mbt
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

## DAE priority scan and source-query controls

The September 28 priority iteration starts from frozen next-v9 binary
`c2f20105e295367c7736dc5bb38700fe74e0d9502acf4497ae47aa28aaf689c2`.
The native trap-scan controls retain that implementation beside the fused scan
and check identical call facts outside the timed closure. On an AMD Ryzen 7
8845HS, native release, CPU 6, all sixteen cases pass. Flat widths 8/128/4,096
improve 200.94/664.17 ns and 15.11 µs to 177.26/375.89 ns and 6.66 µs.
Nested trap depths 8/128/512 improve 233.47 ns, 1.48 µs and 5.87 µs to
209.08 ns, 1.02 µs and 4.22 µs. Nontrapping wrapper depths 8/128, width 8,
improve 344.70 ns and 29.22 µs to 219.26 ns and 1.04 µs. The last case removes
repeated walks through singleton ancestors, not merely a cheaper leaf query.

Tests first exposed the missing summary return contract. Focused DAE tests pass
7/7; the new indexed LocalGraph API first failed as unbound, then its source
ownership/DAE2/fallback/dispatcher controls pass 14/14. `moon info`, `moon fmt`,
12,753 default wasm-gc tests and 475 native debug IR tests pass. The two public
LocalGraph query signatures were reviewed. The indexed enum query removes the
owned source-array copy but still allocates individual native enum values.
Dedicated aggregate renewal is deferred while performance work continues.
Historical v133 ratios and broader parity gaps remain unchanged claims until
renewed evidence is recorded.

V2's bounded runtime matrix validates 286 modules and observes 1,248 results,
effects and traps without mismatch against original and verified v133 behavior.
Its large DAE2 timing is rejected: the initial entry-write proof expands shared
HOT subtrees and does not finish within several minutes. V3 adds root-write
visit epochs in the same scratch and a small failing work-bound regression,
then passes nineteen focused tests. It also removes empty leaf child arrays,
repeated effect queries and per-signature type-vector copies. New enclosing
measurements must use V3; V2's helper results do not justify retaining its
unbounded traversal.

The frozen V3 binary is
`29d061679199adc8cdf701674defab6bae652f53bd23966534420a3211696ae3`.
It passes 12,773 default wasm-gc tests, ten focused native tests and forty native
benchmark cases. Its bounded original/baseline/candidate/v133 runtime matrix
validates 286 modules and observes 1,248 results, effects and traps without a
mismatch. All paired baseline/candidate output bytes match.

| Input / pass | Baseline pipeline ms | V3 pipeline ms | Change |
| --- | ---: | ---: | ---: |
| Small / DAE | 44.385 | 42.160 | -5.01% |
| Small / DAEO | 117.525 | 110.793 | -5.73% |
| Small / DAE2 | 12.694 | 12.644 | -0.39%, near noise |
| Small / DAE2-O | 19.327 | 19.249 | -0.40%, near noise |
| Active conditional writes / DAE, seven pairs | 37.385 | 36.180 | -3.22% |
| Active conditional writes / DAE2 | 12.554 | 12.228 | -2.60% |
| Active entry writes / DAE2 | 12.120 | 10.849 | -10.49% |
| Pinned call-free siblings / DAE2 | 11.048 | 3.990 | -63.88% |
| Pinned call-free siblings / DAE2-O | 19.515 | 12.285 | -37.05% |

Rows use one warmup and three alternating pairs, except the explicit seven-pair
DAE confirmation. Every accepted small/active row has no observed foreign CPU
activity. The active DAE confirmation's MAD is 0.231/0.048 ms; Callgrind improves
765,870,948 to 740,005,104 instructions (-3.38%). This resolves the earlier
V1 active DAE +6.52% regression for the selected V3 candidate, without erasing
that earlier evidence. DAE now reuses recursive path scratch; recorded sites
still own copies. Large rows remain diagnostic: eight of twenty-four accepted
rows observe foreign CPU activity. DAE2 remains 4,001.369 → 3,993.297 ms and
DAE2-O 6,932.680 → 6,825.889 ms, so these changes do not close P03.

Single-process large-input peak RSS samples improve DAE2 281,812 → 269,948 KiB
and DAE2-O 308,532 → 292,240 KiB. These are individual samples, not a repeated
memory confidence interval. Leaf-array controls improve 70.41 → 8.90 µs;
2,048 private signature appends improve 11.15 ms → 142.92 µs. Those helper
gains are not additive whole-pass evidence. A later root-interval proof and
broader pinned-call admission are under separate V4 validation.

V4 (`df12b99c52a8f66e47a9ef63b2594a9e6294d62fcc1b69455c4e5419a3be6561`)
passes 12,781 default tests, seventeen focused native tests and thirty-six
native benchmark cases. Its bounded matrix validates 325 modules with 1,560
observations and no original/baseline/candidate/v133 runtime mismatch. Outputs
match the V3 baseline exactly. Three alternating V3/V4 pairs improve pinned
call-heavy DAE2 siblings 13.196 → 6.423 ms (-51.33%) and DAE2-O 34.436 →
27.936 ms (-18.88%). All six accepted rows in each lane are free of observed
foreign CPU activity. Small, conditional-write and entry-write pipeline changes
are between -0.14% and +0.69%; large DAE2 is 3,993.374 → 4,015.127 ms (+0.54%)
and DAE2-O 6,853.406 → 6,863.409 ms (+0.15%), with host-contended rows retained
as diagnostic evidence. Large costs remain open.

The unique root-interval helper improves the 32-write/depth-64 DAG control
38.49 → 5.55 µs, but regresses one write/depth zero 213.28 → 284.68 ns and one
write/depth 64 1.63 → 2.63 µs. V5 therefore restores a separate bounded
two-epoch single-write path, using one scalar completion flag and no interval
arrays. Multiple admitted writes retain linear interval propagation. Red-first
source, repeated-root, work-bound and input-ownership tests guard both paths.
V5 (`77d1de00d44f3b571fc827db07d4ec322293738c71bb20526e3f1fdb216aaf40`)
passes 12,788 default wasm-gc tests, 477 native IR tests, nineteen focused native
tests and forty-six native benchmark cases. Its bounded runtime matrix validates
325 modules and observes 1,560 results, effects and traps without mismatch;
all baseline/candidate bytes match. The single-write path restores 210.63 →
203.31 ns at depth zero and 1.61 → 1.59 µs at depth 64; the 32-write control
retains 37.64 → 5.47 µs. The scalar LocalGraph source record improves the
128-source/128-read query 120.50 → 36.69 µs while preserving checked indices,
source ordering and ownership. Arithmetic suffix widths 1/128/4,096 improve
22.27 ns/1.81 µs/57.04 µs to 9.05 ns/1.58 µs/50.41 µs. Marked reference
suffixes regress 29.15 → 36.81 ns at width one and 566.65 → 631.19 ns at
width 32; the V6 scalar-to-ordered-stack handoff below supersedes that regression.

Three alternating V4/V5 pairs improve active conditional-write DAE 37.898 →
36.525 ms (-3.62%, MAD 0.813/0.080 ms) and DAE2 13.197 → 12.670 ms
(-3.99%, MAD 0.557/0.061 ms). Those rows have no observed foreign CPU activity.
The wide-join DAE2/O controls improve 107.725 → 106.580 ms (-1.06%) and
121.851 → 119.501 ms (-1.93%). Small compiler changes are -0.24% through
+0.80%, and large changes -1.18% through +0.88%; four of twenty-four small
and eight of twenty-four large observations record foreign CPU activity, so
these compiler deltas remain diagnostic. Single-process large RSS observations
are DAE2 291,432 → 275,752 KiB and DAE2-O 292,048 → 297,444 KiB. Earlier
V4 DAE2 samples were substantially lower; repeated memory controls remain
required before claiming a memory win.

The fresh V5 open-world comparison uses the verified Binaryen 133 oracle,
one warmup and three alternating samples on CPU 6 with `strip-debug` reference
brackets. This renews the four DAE ratios, without extending historical fuzz
signoff to current source. The large input is 6,211,596 bytes, SHA-256
`98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`;
the small input hash is
`06a9dd57ade8a4fd7c60cba2d1c97845b61e115a54f49ec484fd5a2d73b9f69c`.
Production source identity is
`528120802f356d59cdefd3c7c639906f073e74fa9debeb00d598c08827a201f5`
across 258 files. Full samples and phase attribution live in
`oracle-v5-{small,large}/summary.md` under the priority artifact directory.

| Pass | Small Starshine / v133 pass ms | Ratio | Large Starshine / v133 pass ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| DAE | 43.294 / 0.609 | 71.05× | 719.480 / 377.991 | 1.90× |
| DAEO | 122.646 / 14.865 | 8.25× | 924.849 / 1,657.570 | 0.56× |
| DAE2 | 13.301 / 0.992 | 13.41× | 3,976.588 / 425.845 | 9.34× |
| DAE2-O | 21.567 / 3.075 | 7.01× | 7,213.857 / 1,625.480 | 4.44× |

Large DAE/DAEO meet the pass-local ≤2× timing target, while the small four
passes and large DAE2/O remain open. Canonical outputs differ in every row;
smaller raw output alone does not prove a Starshine win. Large DAEO is
6,148,499 versus 6,120,298 raw bytes, and DAE2-O is 5,956,034 versus
5,573,450: both are size-losing parity gaps. DAE2-O's measured SimplifyLocals
code-section phase is 2,576.764 ms in addition to core DAE2 work; inclusive
timers and their subtotals must not be summed. Long aggregate renewal remains
deferred until the performance iteration is complete.

V6 (`ee1c6c3b57e2c83cdfa1ce090b336eff2d1e06cd1c5b76a5620e5e5039e91202`)
passes 12,795 default tests, 477 native IR tests, twenty-six focused native tests
and fifty-four native benchmark cases. Its bounded original/V5/V6/v133 matrix
validates 364 modules with 1,716 matching observations and identical V5/V6
bytes. Readonly entry parameters consumed directly by stores or pinned calls
can pin flat private void boundaries before lifting; parameter assignments and
unknown control retain HOT analysis, and admitted bodies still undergo complete
body validation. A malformed store regression rejects rather than bypassing
validation. Active dead arguments in an unrelated helper remain removable.

The marked-reference handoff resolves V5's native helper regressions: reference
width one is 28.33 ns for the frozen array control versus 28.52 ns for the
handoff, and width 32 is 583.59 → 536.81 ns. Arithmetic widths 1/128/4,096
are 21.51 ns/1.76 µs/55.99 µs versus 8.52 ns/1.35 µs/43.03 µs. The new
readonly-store pipeline benchmark checks valid output, unchanged sibling
bodies, active argument removal and reusable input; 128 private/store wrappers
with 128 stores each measure 11.11 ms in DAE2 and 30.38 ms in DAE2-O.
Three quiet alternating V5/V6 pairs improve the readonly-store DAE2 pipeline
20.911 → 8.937 ms (-57.26%, MAD 0.325/0.112 ms), and DAE2-O
37.730 → 26.156 ms (-30.68%, MAD 0.232/0.079 ms), with identical outputs.
Active conditional-write DAE improves 36.771 → 36.287 ms (-1.32%) and DAEO
334.558 → 323.669 ms (-3.25%); those lanes also have no observed foreign CPU
activity. Small compiler deltas -0.52% through +1.53% have twelve of twenty-four
contended rows. Large deltas -0.55% through +3.04% have ten of twenty-four
contended rows; the +3.04% DAE observation requires renewal before accepting
a large-input speed claim. Four of twelve wide-join rows are contended.
Individual RSS samples are DAE2 293,480 → 275,968 KiB and DAE2-O
309,836 → 291,616 KiB; earlier variance still precludes a firm memory claim.
Compiler competitiveness and final aggregate signoff remain open.

Sources: [observable parameter proof](../../../src/passes/dae2_observed_entry.mbt),
[behavior and invalid-body regressions](../../../src/passes/dae2_observed_entry_wbtest.mbt),
[readonly-store benchmarks](../../../src/passes/dae2_observed_entry_perf_wbtest.mbt),
and [wide-join pipelines](../../../src/passes/dae2_wide_joins_perf_wbtest.mbt).

V7b (`25956fad0fc86d6b9ef9a5a40fb245d8cc50fdbab135ec9993bdf98503f5d128`)
passes 12,802 default tests, 479 native IR tests, 33 focused native tests and
48 native benchmark cases. It removes complete pure unused argument slices
before localizing them, borrowing the slice endpoint and copying plan flags only
when changed. The 31-fixture four-pass matrix validates 403 modules with 1,872
matching results, effects and traps against original/V6/V7b/verified-v133.
Two plain-DAE outputs improve 83 → 72 and 87 → 69 raw bytes; canonical sizes
also decrease. Inspection attributes this to removal of nontrapping arithmetic
and unread scratch writes, retaining import order. These are wins against the
previous Starshine source, not a classification of every Binaryen shape gap.

V7b also introduces checked scalar HOT opcode reads and direct type/child field
reads while retaining node/slot bounds, incomplete deletion-proof fallback and
immutable snapshots. A separate 11-fixture, 18-pass matrix validates 605 modules
with 2,420 matching runtime observations; paired V6/V7b bytes all match there.
Native header/opcode controls improve 29.55 → 24.37 µs at width 16 and
31.05 → 25.72 µs at width 4,096 with 128 deleted nodes; type controls improve
29.98 → 25.90 µs and 31.20 → 28.70 µs. The original child reference used
different modulo work and omitted the old slot check. Its speed comparison is
withdrawn; corrected reference controls are included in V8. These helpers alone
do not establish enclosing pass gains. Sources:
[argument regression](../../../src/passes/dae_pure_arguments_wbtest.mbt),
[argument pipelines](../../../src/passes/dae_pure_arguments_perf_wbtest.mbt),
[checked fields](../../../src/ir/hot_field_queries_wbtest.mbt), and
[field controls](../../../src/ir/hot_field_queries_perf_wbtest.mbt).

The corrected V8 child reference performs the same constant-modulo slot selection
and preserves the frozen header/slot checks. Width 16 improves 34.09 → 29.66 µs;
width 4,096 with 128 deleted nodes improves 38.69 → 30.44 µs. Corrected opcode
controls are 29.98 → 25.30 µs and 31.13 → 26.18 µs; type controls are
30.63 → 28.63 µs and 31.87 → 28.67 µs. All twelve native cases pass; checked
semantics and arena ownership are asserted outside timing. These observations
supersede only the invalid original child comparison, not the historical opcode
and type observations.

V8 adds symbolic flat-body parameter/result dependencies without an initial HOT
arena. It aliases readonly parameter reads and whole-call results, allocates only
distinct dependency joins, and validates before graph commitment. Changed bodies
still lift and replay complete expression liveness in a fresh graph seeded with
the solved boundary prefix. The original module graph stays sealed. The initial
tests fail with two lifts instead of zero, then focused encoded-output comparisons
match the full HOT reference across stores, results, calls, recursion and typed
families. The frozen binary is
`83d79efc4a22662c8403cae9159c3a57df28202b5701b11eed43810bcd38ba44`;
interface generation, formatting, 12,812 default tests, 479 native IR tests,
43 focused native tests, native CLI build and 56 native benchmark cases pass.
The 37-fixture, four-pass original/V7b/V8/v133 matrix validates 481 modules
with 2,184 matching runtime observations and identical V7b/V8 output bytes.

Three alternating quiet V7b/V8 flat-body pairs improve DAE2 9.893 → 8.867 ms
(-10.37%, MAD 0.076/0.110 ms) and DAE2-O 14.949 → 10.811 ms
(-27.68%, MAD 2.119/0.078 ms). The wide baseline dispersion remains relevant.
Readonly-store DAE2/O change +0.93%/-0.23%. Quiet V6/V8 conditional-write
DAE2/O improve 4.23%/1.98%, while DAE/DAEO add 1.33%/2.73%. A bounded
Callgrind comparison records small DAE instructions +0.003% and active DAE
-0.199%; this does not erase the active wall-time costs. The V6/V8 pure-argument
fixture improves DAE 43.573 → 30.502 ms (-30.00%) and DAEO 74.091 →
41.008 ms (-44.65%). Plain DAE shrinks 13,378 → 802 raw bytes; DAEO bytes
already matched after cleanup. Three of twelve pure-argument rows observe
foreign CPU activity.

Small compiler DAE/DAEO/DAE2/O change -0.11%/+7.01%/-3.67%/+0.17% with
18/24 accepted rows observing foreign CPU activity; the DAEO cost requires
quiet renewal. Large compiler changes are -0.41%/+0.02%/+0.66%/-1.71% with
8/24 contended rows. Large DAE2 remains 4,024.403 ms and DAE2-O 6,826.048 ms.
The shared small Precompute/propagation/Coalesce/SL/OI pipelines change
-7.19%/-1.10%/-0.89%/+0.52%/+0.36% in thirty quiet rows; large changes are
+1.55%/+0.71%/-1.96%/+0.75%/+0.04%, with six of thirty rows contended.
All paired bytes match except the documented plain-DAE pure-argument improvement.
These measurements do not establish compiler competitiveness.

Five alternating V7b/V8 untraced RSS pairs instead add median DAE2
275,624 → 291,420 KiB (+15,796 KiB, +5.73%) and DAE2-O
291,932 → 297,992 KiB (+6,060 KiB, +2.08%). DAE2 samples are bimodal and
span about 269–293 MiB across both sides; no memory win is established.
Per-body replay allocation is therefore an active V9 target, alongside flat
assignments and lazy child snapshots. Sources:
[raw analysis](../../../src/passes/dae2_raw_analysis.mbt),
[exact-output and ownership fixtures](../../../src/passes/dae2_raw_analysis_wbtest.mbt),
and [active analysis/pipeline controls](../../../src/passes/dae2_raw_analysis_perf_wbtest.mbt).

V9 (`ba640e30f63c5fb9187a513c05820c0d45244375cc3e2b2bbd6f4ead8a6366b2`)
passes interface generation, formatting, 12,819 default tests, 479 native IR
tests, 50 focused native tests, native CLI build and 64 native benchmark cases.
Flat assignments carry the current local dependency while stacked earlier reads
retain their original symbol. Unchanged child rewrites allocate no owned span;
changed children own one snapshot. Changed raw bodies reuse one replay workspace,
clearing prior edges/work and reseeding immutable module boundaries. The DAE
candidate guard now recognizes shared code containing NaNs instead of rejecting
a valid pruning transaction under nonreflexive numeric equality.

The bounded 41-fixture, four-pass original/V8/V9/v133 matrix validates 533
modules with 2,444 matching observations. V8/V9 bytes match except the shared
NaN-body fixture, where DAE and DAEO shrink 90 → 74 raw bytes and canonical
sizes decrease. Inspected output removes the unused parameter/argument and
preserves the exact `nan:0x400001` instruction; this is a measured improvement
against V8, not a general classification of Binaryen residuals. Short Callgrind
traces reuse verified V8 baselines and reduce small DAE instructions
705,239,530 → 684,133,979 (-2.99%) and active DAE
715,194,988 → 681,756,205 (-4.68%), with identical bytes in those inputs.

Native child controls improve 72.51 → 36.61 ns for one rewrite and
290.10 → 136.65 µs for 4,096 rewrites. The 64-body replay control improves
66.59 → 44.79 µs at 128 boundary locations, but regresses
765.67 → 820.62 µs at 8,192 (+7.18%). Wide prefix reset therefore needs
another implementation trial; helper wins do not close memory or compiler gaps.
The initial three V8/V9 small compiler pairs improve DAE/DAEO/DAE2/O
3.36%/3.43%/11.46%/5.70% in 24 quiet rows. Quiet entry-write DAE2/O improve
12.58%/5.02%; readonly-store DAE2/O change +1.38%/-0.72%, and flat-body
DAE2/O change -0.98%/-1.52%. Pure-argument DAE/DAEO improve 1.74%/1.02%
in twelve quiet rows. Active DAE/DAEO/DAE2/O change
-6.62%/+0.28%/-2.35%/-2.82% with two of twenty-four rows contended. Large
changes are -0.97%/-0.12%/-0.66%/-1.31% with eight of twenty-four contended
rows. All paired outputs match exactly in these timing controls.

Five untraced V8/V9 RSS pairs reduce median DAE2 275,824 → 269,176 KiB
(-6,648 KiB, -2.41%) and DAE2-O 314,632 → 298,136 KiB
(-16,496 KiB, -5.24%). DAE2 ranges overlap at 269,836–289,392 versus
267,588–292,008 KiB, and O ranges overlap at 292,096–324,680 versus
292,196–310,484 KiB. These repeated observations do not establish a firm
memory win across allocator/host variation or erase the earlier V8 costs.

The fresh verified-v133 V9 sweep uses one warmup and three alternating samples
on CPU 6 with `strip-debug` brackets. Production source identity is
`6be8fc73e265a5e0beac38cf25f81099f4c51d39860e51714f2fefabbb4099d2`
across 260 files. The preceding V5 table remains historical. V9 pass medians
and ratios are:

| Pass | Small Starshine / v133 ms | Ratio | Large Starshine / v133 ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| DAE | 41.301 / 0.613 | 67.37× | 740.291 / 373.657 | 1.98× |
| DAEO | 120.710 / 14.930 | 8.09× | 937.367 / 1,660.770 | 0.56× |
| DAE2 | 11.336 / 0.963 | 11.78× | 3,935.432 / 424.018 | 9.28× |
| DAE2-O | 20.562 / 3.084 | 6.67× | 7,107.821 / 1,614.320 | 4.40× |

All canonical outputs still differ. Large DAEO remains 6,148,499 versus
6,120,298 raw bytes, and DAE2-O 5,956,034 versus 5,573,450: these remain
size-losing parity gaps. DAE2-O's SimplifyLocals code-section median is
2,518.479 ms; its inclusive/subphase timers must not be summed. Compiler
competitiveness and final aggregate signoff remain open. Full samples live in
`oracle-v9-{small,large}/summary.md` under the local priority artifact directory.
Sources:
[assignments](../../../src/passes/dae2_raw_assignments_wbtest.mbt),
[child ownership](../../../src/passes/dae2_lazy_children_wbtest.mbt),
[child controls](../../../src/passes/dae2_lazy_children_perf_wbtest.mbt),
[replay ownership](../../../src/passes/dae2_replay_workspace_wbtest.mbt),
[replay controls](../../../src/passes/dae2_replay_workspace_perf_wbtest.mbt), and
[NaN transaction](../../../src/passes/dae_nan_plans_wbtest.mbt).

V10 (`050231021b65677f2512151816d66f58501db3a6735e79678362ed72cd920d71`)
completes interface generation, formatting, 12,830 default tests, 479 native IR
tests, 61 focused native tests, native CLI build and 84 native benchmarks.
Its 260-file production hash is
`83a1d051ad02236dd4591272cce100ea72d15f0a6afa30af9753130d62f79232`.
The 48-fixture original/V9/V10/verified-v133 matrix validates 624 modules with
2,808 matching results, effects and traps. V9/V10 outputs match except the
shared NaN-global DAE/DAEO fixture: both shrink 85 → 69 raw bytes with lower
canonical sizes. Unit assertions inspect initializer bits; a JSON NaN runtime
observation by itself does not prove payload preservation.

Raw analysis now qualifies mandatory scalar loads/traps and selected GC/ref
producers, observing all their inputs even when their result is dropped. Struct
arity comes from the existing module context. This avoids the first arena,
while HOT mutation still handles changed bodies. Reset uses retained-capacity
bulk initialization: fresh/reused 64-body controls measure 65.37/42.65 µs at
128 boundaries and 720.37/629.66 µs at 8,192. This supersedes the V9 wide helper
regression without erasing its historical record. Shared metadata identity
measures 47.49 → 16.97 ns at four type groups and 32.17 µs → 16.95 ns at
4,096; distinct metadata stays 32.07/32.14 µs. Bounded borrowed multi-result
prefixes measure 123.94 → 62.49 ns for two values and 172.31 → 25.40 µs
for sixteen values with an observable prefix.

Three quiet V9/V10 pairs on active GC improve DAE2 42.576 → 39.372 ms
(-7.53%, MAD 0.199/0.090 ms) and O 64.767 → 62.962 ms
(-2.79%, MAD 0.255/0.346 ms). Quiet small DAE/DAEO/DAE2/O change
-1.08%/+1.32%/-0.45%/-0.83%; entry DAE2 improves 27.73%, but its
baseline MAD is 3.080 ms versus 0.113 ms after, so the percentage is unstable.
Large DAE/DAEO/DAE2/O change -0.59%/+0.09%/+0.62%/+3.34% with foreign
CPU activity in 2/1/2/3 of each six retained rows. Keep the optimizing increase
open for quiet renewal. Every timing-control output is byte-identical.
Seven quiet V6/V10 pairs renew earlier DAE regressions: small DAE/DAEO
41.830 → 40.698 ms (-2.71%) and 111.934 → 109.075 ms (-2.55%);
active 36.143 → 34.902 ms (-3.43%) and 326.561 → 325.156 ms (-0.43%).
These controls supersede the directional V8 regression observations.

Five V9/V10 untraced RSS pairs change DAE2 median 269,872 → 269,652 KiB
(-220), and O 297,772 → 292,232 KiB (-5,540). Their respective ranges
268,524–276,044 / 268,832–275,820 and
292,092–337,072 / 291,952–303,808 overlap; do not claim a firm memory win.
The fresh CPU-6 v133 oracle uses one warmup, three alternating samples and
`strip-debug` brackets:

| Pass | Small Starshine / v133 ms | Ratio | Large Starshine / v133 ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| DAE | 41.480 / 0.617 | 67.28× | 740.770 / 373.538 | 1.98× |
| DAEO | 121.083 / 13.753 | 8.80× | 945.515 / 1,659.900 | 0.57× |
| DAE2 | 11.464 / 0.967 | 11.86× | 3,940.761 / 421.901 | 9.34× |
| DAE2-O | 20.090 / 3.044 | 6.60× | 7,139.235 / 1,612.080 | 4.43× |

Canonical outputs all differ. Large optimizing raw sizes remain the V9
6,148,499 / 6,120,298 (DAEO) and 5,956,034 / 5,573,450 (O);
canonical sizes are 6,161,725 / 6,120,298 and 5,995,469 / 5,573,450.
These are open size-losing parity gaps. Full samples, CPU observations and
dispersion remain in `pairs-v10-*/result.json`, `oracle-v10-{small,large}/result.json`,
`memory-v10.json` and `confirm-v10-v6-*/result.json` under the priority directory.
Long aggregate renewal follows the performance trials; none of these bounded
controls replaces it. Sources:
[mandatory producers](../../../src/passes/dae2_raw_producers_wbtest.mbt),
[producer controls](../../../src/passes/dae2_raw_producers_perf_wbtest.mbt),
[owned sections](../../../src/passes/dae_owned_sections_wbtest.mbt),
[metadata controls](../../../src/passes/dae_owned_sections_perf_wbtest.mbt),
[operand bounds](../../../src/passes/dae_operand_range_wbtest.mbt), and
[multi-result controls](../../../src/passes/dae_multivalue_prefix_perf_wbtest.mbt).

V11 (`4e5b41271e087c0829022b77cb54ba3b107e7dd2fb6410ef3c8efb7cbec0fb2c`)
completes interface generation, formatting, 12,840 default tests, 73 focused
native tests, native CLI build and 52 native benchmarks. Its 261-file production
hash is `79ef94896d894d031b8f5b49589f83c4bddc6ef48e3f93c64e145a76b6ad22b9`.
The unchanged IR retains V10's 479 native checks. The 57-fixture
original/V10/V11/verified-v133 matrix validates 741 modules with 3,380 matching
observations and identical before/after bytes. NaN fixtures expose integer
reinterpretation results to prove payload preservation.

Scalar direct rewriting qualifies the existing flat analysis lane and avoids
its second HOT arena. HOT-rewrite/direct-only controls measure 38.62/12.98 µs
at tiny scale and 8.44/1.52 ms at 32 bodies/128 operations. Full HOT/direct
producer pipelines measure 51.24/14.38 µs tiny and 42.63/4.05 ms wide.
Distinct transaction fallback compares float bits in code and initializer
carriers; four red tests demonstrated changed signed-zero acceptance and
copied-NaN rejection. Shared 1,024-body snapshot identity measures 7.77 ns;
shared-body reference 94.53 µs improves to 1.99 µs, distinct copies stay
90.88/91.61 µs (+0.8%), and the last changed body improves 91.02 → 2.03 µs.

Three V10/V11 paired pipeline samples improve active flat DAE2/O
8.691 → 1.612 ms (-81.45%, MAD 0.190/0.003) and
10.811 → 3.674 ms (-66.02%, MAD 0.149/0.014); GC improves
39.670 → 4.083 ms (-89.71%, MAD 0.186/0.009) and
63.608 → 27.372 ms (-56.97%, MAD 1.651/0.172). Entry DAE2/O improves
82.43%/27.05%; readonly stores improve 2.71%/0.22%.
Initial small DAE -9.47% has baseline MAD 4.805 ms versus 0.427 after;
19/34 retained small rows and 10/24 large rows observe foreign CPU activity.
Initial active O +18.99% reverses in seven quiet pairs to
16.979 → 16.373 ms (-3.57%, MAD 0.176/0.378). That quiet cohort has
zero foreign CPU rows and improves active DAE2 12.376 → 11.518 ms
(-6.93%, MAD 0.255/0.072), while active DAEO remains
321.561 → 324.113 ms (+0.79%, MAD 1.178/1.276).
Seven quiet small DAE pairs renew to 40.874 → 40.695 ms (-0.44%,
MAD 0.627/0.249). Keep the initial runs as diagnostic evidence.
Large paired DAE/DAEO/DAE2/O changes +1.05%/-1.05%/-1.17%/-1.93%;
these contended samples do not establish a compiler win.

Five V10/V11 RSS pairs change median DAE2 275,976 → 276,120 KiB (+144)
and O 293,532 → 297,608 KiB (+4,076). Ranges respectively
270,848–291,756 / 269,560–292,148 and
291,716–338,580 / 292,264–310,284 overlap; no memory win is established.
The fresh CPU-6 v133 oracle uses one warmup and three alternating samples:

| Pass | Small Starshine / v133 ms | Ratio | Large Starshine / v133 ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| DAE | 41.749 / 0.610 | 68.40× | 741.314 / 377.260 | 1.96× |
| DAEO | 118.862 / 14.021 | 8.48× | 936.721 / 1,651.110 | 0.57× |
| DAE2 | 11.323 / 0.955 | 11.86× | 3,885.392 / 422.809 | 9.19× |
| DAE2-O | 20.289 / 3.016 | 6.73× | 7,066.518 / 1,610.630 | 4.39× |

All canonical outputs differ; large optimizing raw/canonical sizes remain
identical to V10's open size losses. Artifacts `pairs-v11-*`, `memory-v11.json`,
`oracle-v11-{small,large}` and `confirm-v11-v10-*` retain samples, MAD and
CPU observations. Sources: [scalar mutation](../../../src/passes/dae2_raw_rewrite.mbt),
[exact HOT fixtures](../../../src/passes/dae2_raw_rewrite_wbtest.mbt),
[mutation controls](../../../src/passes/dae2_raw_rewrite_perf_wbtest.mbt), and
[float-bit guards](../../../src/passes/dae_snapshot_bits_wbtest.mbt).
V12 tests early restoration admission and releasing solved adjacency before
rewrite; full pipeline, runtime and RSS evidence remains required.

V12 (`4ab85d5672c7f1ea1a5b775fd5e3069decb5eed03108d72f75708b1ca626e3d2`)
completes interface generation, formatting, 12,845 default tests,
78 focused native tests, native CLI build and
34 native benchmarks. Production hash is
`5e674ef4bffafc18d6b06b17634924fccace43c850ec31e13b2a3a84254f041b`. Its 741-module bounded matrix yields
3,380 matching observations with no output changes from V11.

Dead-suffix restoration now admits only selected unreachable zero-param bodies
whose original signature contains f64, then scans escapes lazily. Red tests
require zero scans for impossible candidates and still restore the escaped
self operand; reference comparisons cover result signatures and short bitmaps.
Tiny reference/admitted helpers measure 264.65/38.31 ns, wide 32-body/128-op
helpers 24.08 µs/62.32 ns. This work reduction does not close the small DAE gap.
V12 also drops solved adjacency capacity before mutation. Its mutable-field
trial grows native edge assembly from 90 to 115 instruction lines with two
additional drop call sites; V13 tests transferring the same solved bitvector
into a new graph with immutable adjacency fields instead.

Three paired large DAE/DAEO/DAE2/O changes -0.01%/-0.10%/+0.64%/+0.72%
observe foreign CPU in 8/24 retained rows. Initial flat O +83.57% reverses in
seven quiet pairs to 3.851 → 3.731 ms (-3.12%, MAD 0.214/0.038).
That renewal still costs flat DAE2 1.585 → 1.619 ms (+2.15%), entry DAE2
1.640 → 1.689 ms (+2.99%), entry O 21.930 → 22.518 ms (+2.68%,
MAD 0.189/0.696) and small DAEO 109.955 → 111.908 ms (+1.78%,
MAD 0.748/2.049); small DAE2 changes -1.62%. All 84 renewed rows have no
observed foreign CPU. Preserve the remaining costs for the next candidate.

Five RSS pairs change DAE2 median 275,860 → 268,472 KiB (-7,388) and
O 292,068 → 295,588 KiB (+3,520); dispersion remains in `memory-v12.json`.
The fresh verified-v133 CPU-6 sweep uses one warmup and three alternating samples:

| Pass | Small Starshine / v133 ms | Ratio | Large Starshine / v133 ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| `dae` | 42.439 / 0.608 | 69.82× | 743.205 / 379.244 | 1.96× |
| `dae-optimizing` | 120.157 / 13.740 | 8.75× | 940.292 / 1,656.900 | 0.57× |
| `dae2` | 11.419 / 0.957 | 11.94× | 3,937.210 / 424.085 | 9.28× |
| `dae2-optimizing` | 19.731 / 3.235 | 6.10× | 7,137.923 / 1,621.400 | 4.40× |

All before/after bytes match, and all canonical oracle outputs differ.
Large optimizing raw/canonical size losses remain unchanged. Artifacts
`pairs-v12-*`, `oracle-v12-{small,large}`, `memory-v12.json` and
`confirm-v12-v11-*` retain samples and dispersion. Sources:
[restoration admission](../../../src/passes/dae_restore_admission_wbtest.mbt),
[restoration controls](../../../src/passes/dae_restore_admission_perf_wbtest.mbt), and
[solved storage](../../../src/passes/dae2_solved_storage_wbtest.mbt).
V13 scalar tee mutation and immutable solved-graph transfer pass seventeen
focused checks; full native and enclosing renewal are in progress.

The large native debug pass-test link hits Moonc `v0.10.14+7d59c7ec9`'s stack
limit at 16 MiB, including after removal of forced path-helper inlining. The
same ten focused native tests pass with `ulimit -s 65536`. This is a compiler
invocation setting; native CLI runtime controls use the ordinary process limit.
Preserve both failed logs and the successful retry when reporting validation.

Sources: [DAE scan](../../../src/passes/dead_argument_elimination.mbt),
[DAE controls](../../../src/passes/dae_trap_summary_perf_wbtest.mbt),
[LocalGraph queries](../../../src/ir/local_graph.mbt),
[query ownership tests](../../../src/ir/local_graph_indexed_sources_wbtest.mbt),
and [DAE2 controls](../../../src/passes/dae2_indexed_sources_perf_wbtest.mbt).
Local artifacts live under `.tmp/pass-perf-dae-priority-20260928/`; the baseline,
red/green logs, build stages and frozen source hashes identify this iteration.

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

DAE2 additionally emits `detail:dae2:prepare`, `analysis`, `solve-and-admit`,
`rewrite`, and `finalize` timers when pass timing is enabled. Analysis splits
out accumulated `analysis:lift` and `analysis:dependencies`; rewrite splits
out `rewrite:lift` and `rewrite:lower`; finalization splits out cleanup and
validation. These are nested phase totals, so adding every detail timer would
double-count work. Analysis also includes function disposal and metadata
collection; its lift subtotal includes catch-payload repair. Final type cleanup
after validation and dispatcher cleanup for `dae2-optimizing` remain outside
the respective DAE2 detail totals. The [DAE2 implementation](../../../src/passes/dead_argument_elimination2.mbt)
and [dispatcher](../../../src/passes/pass_manager.mbt) own this attribution.

### Paired wall-time attribution

Use the direct comparison tool's opt-in paired mode for `[WALL]001` work:

```text
bun scripts/self-optimize-compare.ts <input.wasm> \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/v133-signoff-oracles/binaryen-version_133/bin/wasm-opt \
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
  --wasm-opt-bin .tmp/v133-signoff-oracles/binaryen-version_133/bin/wasm-opt \
  --warmup 1 --samples 3 --out-dir <artifact-dir>
```

`pass-performance-sweep` brackets every requested-pass round with leading and trailing reference-pass commands, reversing requested-pass order on alternating rounds to reduce thermal and order bias. It rejects campaigns with fewer than one warmup or three measured rounds, refuses a pre-existing artifact directory, requires explicit Starshine and Binaryen binaries, verifies that the oracle reports version 133, and rejects a native binary older than current compiler sources. It pins both executable SHA-256 identities, the input, and a production-compiler source fingerprint before sampling; rechecks them at the end; preserves every underlying `self-optimize-compare` result; rejects traced/no-trace byte drift and cross-round Starshine or Binaryen raw-output drift, including the reference; and writes machine-readable `result.json` plus `summary.md` with raw samples, median±MAD command and bracket-adjusted measurements, pass-local and phase attribution, sizes, and canonical equality. A bracket-adjusted increment subtracts the mean of that round's two references and is noise context rather than a substitute for pass-local attribution or a causal before/after binary comparison. Use the default `strip-debug` reference only when the input is known not to carry debug payloads. The wrapper is serial internally; the outer `flock` prevents separate worktrees, builds, or campaigns from sharing the measured host interval. A timing set that overlapped an untracked heavy process is invalid and must be rerun in a fresh artifact directory.

Use `--closed-world` for passes such as `global-type-optimization` that require that mode; the sweep applies it to both tools and the bracketing reference. The 2026-09-25 v133 common-pass campaign is in `.tmp/pass-sweep-v133-combined-20260925/`: 67 Starshine-advertised names produced paired results across 63 Binaryen flag sequences. The v133 `wasm-opt --help` optimization-pass catalog has 172 flags; 110 have no paired Starshine sweep. The primary 189 KB input left both outputs unchanged for 28 names, so those timings measure admission/no-op cost rather than transform throughput. Active-input pass-local ratios above the 2x target include `dae`, `dae-optimizing`, `dae2`, `dae2-optimizing`, `inlining`, `inlining-optimizing`, `simplify-globals-optimizing`, and `simplify-locals-nonesting`; the per-pass reports contain exact medians, output sizes, and hashes. This campaign is performance evidence only; output drift still needs pass-specific parity classification.

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

## September 27, 2026: follow-up pass allocation campaign

This checkpoint supersedes earlier timing and aggregate-renewal recommendations
for the remeasured inputs and passes. Historical v131/v132/v133 results retain
their original scope. Fifteen optimizations were committed separately after
bounded red-first invariants and focused native/full-pipeline benchmarks.
Four rejected approaches remain documented, including two SimplifyLocals
continuation-index variants; their production code was removed. Remaining
compiler budgets, parity gaps and runtime coverage limits remain explicit.

### Retained changes and rejected approaches

- `e1b46f1a7`: queue changed forward local-flow blocks in source order.
- `5193aa64e`: collect type roots once before pruning unused signatures.
- `1b4a793b6`: borrow dense HOT operands during lowering and source-order checks.
- `362fecd3f`: cache negative local dependency proofs during HOT lifting.
- `b93aa67d7`: track only encountered tuple producers in local-flow transfers.
- `9dbbc4ec4`: defer DAE replay facts until candidate planning needs them.
- `180b9a339`: record rejected inlining remap allocation prototype.
- `408a1a1ce`: record rejected SimplifyLocals continuation indexes.
- `c1b6fbb7d`: allocate validation initialization masks at their final size.
- `d78b64f4d`: group numeric locals directly from compressed declaration runs.
- `153486302`: borrow immutable predecessor states until local-flow joins change.
- `d927318a1`: record rejected inlining remap preflight experiment.
- `40ed4f059`: resolve numeric grouping signatures without scanning module bodies.
- `7b78fb714`: retain identical child spans during DAE2 rewriting.
- `716f60ab6`: cache completed-root effect ordering during HOT lifting.
- `e44df6e67`: add dense Coalesce interference cliques a word at a time.
- `f1f25e82f`: reject retention-bound remapping after full-pass regression.
- `80baae5e5`: iterate actual live locals during structured interference building.
- `6d32bdae7`: memoize numeric default identities in Coalesce value analysis.

A separate harness fix, `63e9360b3`, counts enclosing pass/pipeline timers once.
The [scope correction](#september-27-2026-nested-timing-scope-correction)
supersedes nested-timer sums using the same saved traces; it is not a compiler
speedup. Six bounded timing regressions and all 21 harness tests pass.

The [LocalGraph contract](../ir2/local-ssa-policy.md) owns ordered work queues,
immutable predecessor borrowing and sparse tuple evaluation. The
[lift/lower contract](../ir2/architecture-rules.md) owns dense operand views,
negative dependency masks and completed-root effect caching. Pass dossiers
record exact per-change benchmarks and invariants for
[DFE](../binaryen/passes/duplicate-function-elimination/starshine-strategy.md),
[OI](../binaryen/passes/optimize-instructions/starshine-strategy.md),
[DAE](../binaryen/passes/dead-argument-elimination/starshine-strategy.md),
[DAE2](../binaryen/passes/dae2/starshine-strategy.md),
[Coalesce](../binaryen/passes/coalesce-locals/starshine-strategy.md),
[Inlining](../binaryen/passes/inlining/starshine-strategy.md),
[SimplifyLocals](../binaryen/passes/simplify-locals/performance-and-artifact-frontiers.md), and
[validation masks](../validate/module-validation-phases.md).
Per-change medians are not additive; cumulative gains below use the same
frozen starting and final binaries.

### Frozen tools, inputs and validation

- Starting source commit: `8eff882b37c1085a7432dd2a5f91986b33db6f69`; native SHA-256 `5d009c4396b65d613acdc187e443f6c2cee843c7bfbc48ee726ba633de2aac54`.
- Final production commit: `6d32bdae782b5f725bb85245a3caa20bd37bce02`; native SHA-256 `6610a792ef8d07151ee38bd6c6fbfe82097086e4f50f6dfd3902eecacb00320e`.
- Rebuilt native generator SHA-256: `98b9c219968bb579523cecdbb16d681436da5e31640ccd6c24b3c69af295d6d9`.
- Verified oracle: `wasm-opt version 133 (version_133)`, SHA-256 `8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
- Small input: 192,893 bytes, 45 functions, SHA-256 `06a9dd57ade8a4fd7c60cba2d1c97845b61e115a54f49ec484fd5a2d73b9f69c`.
- Large input: 6,211,596 bytes, 12,904 functions, SHA-256 `98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
- `moon info`, `moon fmt`, all **12,583 wasm-gc tests**, explicit native CLI/generator builds, timing-harness tests and README/API sync pass.
- The original dirty worktree was preserved and included in both compiler
  snapshots. This campaign adds no public `.mbti` API change.

### Cumulative alternating compiler pairs

Each row uses one warmup and three uncontended alternating samples. Traced and
untraced outputs agree, before/final raw bytes match, and outputs independently
validate. Detected busy rounds are retained as rejected samples and retried.
These are enclosing optimizer pipeline times, excluding command startup and decoding.
The saved reports also retain command wall time. Original timer sums remain
available; `final-pairs-*-corrected.json` applies the scope accounting fix.

| Input | Pass | Before pipeline ms | Final pipeline ms | Change |
| --- | --- | ---: | ---: | ---: |
| small | `dae2` | 17.907 | 17.015 | -5.0% |
| small | `dae2-optimizing` | 26.273 | 26.211 | -0.2% |
| small | `dae` | 50.769 | 51.453 | +1.3% |
| small | `dae-optimizing` | 138.098 | 136.451 | -1.2% |
| small | `inlining` | 5.692 | 5.737 | +0.8% |
| small | `inlining-optimizing` | 110.280 | 106.745 | -3.2% |
| small | `simplify-globals-optimizing` | 20.445 | 19.264 | -5.8% |
| small | `precompute` | 1.283 | 1.281 | -0.2% |
| small | `precompute-propagate` | 5.210 | 4.684 | -10.1% |
| small | `optimize-instructions` | 3.509 | 3.210 | -8.5% |
| small | `merge-locals` | 1.506 | 1.451 | -3.7% |
| small | `coalesce-locals` | 13.382 | 10.802 | -19.3% |
| small | `simplify-locals` | 6.475 | 7.173 | +10.8% |
| small | `duplicate-function-elimination` | 0.777 | 0.467 | -39.9% |
| large | `dae2` | 5787.334 | 4975.737 | -14.0% |
| large | `dae2-optimizing` | 9206.506 | 8251.110 | -10.4% |
| large | `dae` | 803.753 | 795.796 | -1.0% |
| large | `dae-optimizing` | 1008.288 | 999.407 | -0.9% |
| large | `inlining` | 1748.354 | 1738.160 | -0.6% |
| large | `inlining-optimizing` | 621.474 | 595.998 | -4.1% |
| large | `simplify-globals-optimizing` | 56.467 | 56.033 | -0.8% |
| large | `precompute` | 676.248 | 678.776 | +0.4% |
| large | `precompute-propagate` | 1805.571 | 1451.486 | -19.6% |
| large | `optimize-instructions` | 3192.209 | 2524.999 | -20.9% |
| large | `merge-locals` | 37.482 | 37.233 | -0.7% |
| large | `coalesce-locals` | 6536.898 | 4963.276 | -24.1% |
| large | `simplify-locals` | 2159.408 | 2043.669 | -5.4% |
| large | `duplicate-function-elimination` | 1359.493 | 843.849 | -37.9% |

The first small SimplifyLocals pair set increased **6.475 → 7.173 ms (+10.8%)**.
A dedicated nine-sample alternating repeat measured **6.432 → 6.269 ms (-2.5%)**,
with identical bytes and independent validation. The initial increase did not
reproduce; retain both reports and avoid treating these small differences as
a material pass-level win. Evidence: `final-repeat-small-simplify-locals/`.

The documented large guarded DAE/DAEO, inlining-optimizing, SimplifyGlobals-
optimizing and MergeLocals paths remain coverage controls. Their timing alone
does not establish active cleanup performance or unchanged optimization breadth.
Dedicated active fixtures in the owner pages separately establish applicable
gains and preserve runtime results. Small sub-millisecond differences require
care when interpreting noise.

### Verified v133 timing renewal

Fresh sweeps bracket requested passes with reference commands and retain
phase attribution, command median/MAD, canonical sizes and exact tool/input
identities. The inner Starshine pass timer can omit module cleanup and
validation; pipeline cost remains visible and governs the remaining work.
A zero recorded inner timer does not mean zero pipeline work; its ratio is omitted.
`dae2-optimizing` compares the upstream DAE2, SimplifyLocals and Vacuum sequence.
Large MergeLocals remains the separately recorded guarded case.

| Input | Pass | Starshine pipeline ms | Starshine inner ms | Binaryen pass ms | Inner ratio | Canonical byte delta |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| small | `dae2` | 17.495 | 17.457 | 1.172 | 14.89× | -97 |
| small | `dae2-optimizing` | 25.815 | 25.788 | 3.766 | 6.85× | -250 |
| small | `dae` | 52.701 | 52.677 | 0.646 | 81.50× | -134 |
| small | `dae-optimizing` | 140.066 | 140.039 | 7.100 | 19.72× | -1,373 |
| small | `inlining` | 6.184 | 6.163 | 2.562 | 2.41× | -6,504 |
| small | `inlining-optimizing` | 107.830 | 107.800 | 44.903 | 2.40× | +461 |
| small | `simplify-globals-optimizing` | 20.336 | 20.313 | 1.310 | 15.51× | -372 |
| small | `precompute` | 1.323 | 0.000 | 1.361 | n/a | -70 |
| small | `precompute-propagate` | 5.055 | 1.672 | 2.382 | 0.70× | -84 |
| small | `optimize-instructions` | 3.602 | 0.552 | 0.685 | 0.81× | -28 |
| small | `merge-locals` | 1.483 | 0.318 | 0.363 | 0.88× | -35 |
| small | `coalesce-locals` | 11.655 | 11.623 | 5.087 | 2.28× | -28 |
| small | `simplify-locals` | 6.440 | 0.494 | 1.769 | 0.28× | +19 |
| small | `duplicate-function-elimination` | 0.456 | 0.434 | 0.241 | 1.80× | -53 |
| large | `dae2` | 4954.468 | 4937.001 | 397.543 | 12.42× | -100,655 |
| large | `dae2-optimizing` | 8298.320 | 8281.018 | 1580.220 | 5.24× | +422,019 |
| large | `dae` | 804.243 | 786.800 | 380.432 | 2.07× | -3,626 |
| large | `dae-optimizing` | 1017.234 | 999.928 | 1600.130 | 0.62× | +41,427 |
| large | `inlining` | 1741.690 | 1724.454 | 812.603 | 2.12× | -1,369,483 |
| large | `inlining-optimizing` | 614.076 | 596.818 | 14089.700 | 0.04× | +933,016 |
| large | `simplify-globals-optimizing` | 55.795 | 38.458 | 1048.580 | 0.04× | +173,229 |
| large | `precompute` | 689.339 | 62.301 | 181.211 | 0.34× | -5,153 |
| large | `precompute-propagate` | 1482.456 | 591.354 | 680.520 | 0.87× | -9,535 |
| large | `optimize-instructions` | 2575.642 | 113.052 | 239.108 | 0.47× | +47,825 |
| large | `coalesce-locals` | 4921.395 | 4904.144 | 1117.400 | 4.39× | +90,915 |
| large | `simplify-locals` | 2080.387 | 95.312 | 1055.120 | 0.09× | +428,416 |
| large | `duplicate-function-elimination` | 845.856 | 828.589 | 69.875 | 11.86× | -31,031 |

### Final aggregate correctness renewal

Twenty-two dedicated lanes each compare 10,000 GenValid cases at seed `0x5eed`,
using the explicit prebuilt native CLI/generator, verified v133, `--jobs auto`,
`--max-subprocesses 8`, at most 20 saved mismatch artifacts per lane, independent
validation and Node-v2 original/Starshine/Binaryen observations. SSA and
SSA-no-merge are included because they consume the changed LocalGraph solver.
No external-generator lane or long randomized default test was added.

| Lane | Aggregate | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
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
| `ssa` | `ssa-all` | 8,713 / 640 | 647 | 0 | 9,335 / 665 |
| `ssa-nomerge` | `ssa-nomerge-all` | 3,750 / 0 | 6,250 | 0 | 6,250 / 3,750 |
| `coalesce-locals` | `coalesce-locals-all` | 3,750 / 5,000 | 1,250 | 0 | 8,750 / 1,250 |
| `duplicate-function-elimination` | `duplicate-function-elimination` | 5,000 / 0 | 5,000 | 0 | 10,000 / 0 |
| `simplify-locals` | `simplify-locals-all` | 380 / 0 | 9,620 | 0 | 10,000 / 0 |
| `simplify-locals-notee` | `simplify-locals-notee-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |
| `simplify-locals-nonesting` | `simplify-locals-nonesting-all` | 5,026 / 0 | 4,974 | 0 | 10,000 / 0 |
| `simplify-locals-nostructure` | `simplify-locals-nostructure-all` | 0 / 0 | 10,000 | 1,662 | 10,000 / 0 |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |

Across **220,000 comparisons**, validation, generator, property-counter, command
and observed Starshine/original semantic failures are zero.
**210,283** cases match observed original behavior; **9,717** runtime-blocked
cases remain unverified. Matching exported observations do not demonstrate
execution of every unexported body or establish full three-way agreement.
Separate determinism, idempotence and metamorphic lanes are outside this run.
Starshine outputs are regenerated for every case; persistent caches reuse
deterministic oracle outputs and hash-keyed runtime observations.

DAE/DAE2 and optimizing SimplifyGlobals use `drop-consts` and
`unreachable-control-debris`; Precompute variants additionally use
`local-cleanup-debris`. OI uses drop/local cleanup; Coalesce uses local and
unreachable cleanup; SSA uses local cleanup and `ssa-local-allocation-debris`.
Other listed lanes use no cleanup normalizers. Closed DAE2 adds `--closed-world`.
Exact commands and profiles are retained in `final-fuzz-campaign.json`.

### Residual and runtime-coverage review

Classifications are agent judgments. The retained-output and complete
canonical-size-loss replays compare the final compiler with the frozen start.
Byte identity establishes that the replayed output predates this campaign;
it does not by itself prove semantic equivalence or close a parity gap.

| Lane | Retained baseline-identical | All size-losing baseline-identical |
| --- | ---: | ---: |
| `dae2` | 20/20 | 0/0 |
| `dae2-closed` | 20/20 | 706/706 |
| `dae2-optimizing` | 20/20 | 0/0 |
| `dae` | 20/20 | 0/0 |
| `dae-optimizing` | 20/20 | 0/0 |
| `simplify-globals-optimizing` | 20/20 | 0/0 |
| `optimize-instructions` | 20/20 | 0/0 |
| `merge-locals` | 20/20 | 0/0 |
| `ssa` | 20/20 | 0/0 |
| `ssa-nomerge` | 20/20 | 0/0 |
| `coalesce-locals` | 20/20 | 0/0 |
| `duplicate-function-elimination` | 20/20 | 0/0 |
| `simplify-locals` | 20/20 | 0/0 |
| `simplify-locals-notee` | 20/20 | 0/0 |
| `simplify-locals-nonesting` | 20/20 | 0/0 |
| `simplify-locals-nostructure` | 20/20 | 1662/1662 |
| `simplify-locals-notee-nostructure` | 20/20 | 0/0 |

OI, MergeLocals and DFE receive exhaustive residual replays through common
verified-v133 `-Oz --all-features --strip-debug`, with independent validation:

- `optimize-instructions`: 677 residuals; 677 baseline-identical outputs; 677 byte-identical downstream outputs.
- `merge-locals`: 647 residuals; 647 baseline-identical outputs; 647 byte-identical downstream outputs.
- `duplicate-function-elimination`: 5000 residuals; 5000 baseline-identical outputs; 5000 byte-identical downstream outputs.

**Scoped OI wins:** all 677 residuals retain the previously inspected
14 tuple families, preserve lane producers and effect order under
the [tuple contract](../binaryen/passes/optimize-instructions/starshine-strategy.md),
and save 26–104 canonical bytes before common cleanup
(27,497 bytes total). Their downstream bytes are identical; the
historical v132 downstream loss is not reproduced under this v133 pair.

**Scoped MergeLocals wins:** all 647 `trivial-confusion` residuals
remove the unread tee write while preserving its branch-condition value
under the [owner contract](../binaryen/passes/merge-locals/starshine-strategy.md#residual-classifications).
Each saves 2 canonical bytes and retains identical downstream bytes.

**Scoped DFE wins:** all 5,000 fixed-point caller residuals save six
canonical bytes and converge to identical downstream bytes. Inspected output
retains one private literal callee and one caller instead of two identical
callers, under the existing [fixed-point contract](../binaryen/passes/duplicate-function-elimination/starshine-strategy.md)
and [bounded direct/three-round tests](../../../src/passes/duplicate_function_elimination_test.mbt).
The [generator](../../../src/validate/gen_valid_undersampled_passes.mbt)
contains only these private literal/call functions and exports none: the
aggregate runtime-match counter does not demonstrate body execution.
The classification relies on the inspected private-call equivalence and
measured size/downstream benefit, not that counter.

The inspected tuple-copy, unread-tee and fixed-point caller contracts and downstream
evidence in the owner dossiers support only those scoped win classifications.
Other residuals remain parity gaps; larger canonical outputs remain size-losing
quality gaps. Validation, runtime agreement or smaller output alone does not
justify accepting an uninspected shape family.

Runtime coverage limits from the full saved case census:

- `dae2` original-runtime blocks: `dae2-continuations` 688.
- `dae2-closed` original-runtime blocks: `dae2-continuations` 688.
- `dae2-optimizing` original-runtime blocks: `dae2-continuations` 688.
- `precompute` original-runtime blocks: `precompute-gc-atomic-boundary` 449.
- `precompute-propagate` original-runtime blocks: `precompute-gc-atomic-boundary` 449.
- `dae` Binaryen-side runtime limits: `dae-arg-type-refinement` 625, `dae-return-type-refinement` 625.
- `optimize-instructions` original-runtime blocks: `pass-oi-descriptor-gc` 1,090.
- `ssa` original-runtime blocks: `ssa-loop` 665.
- `ssa-nomerge` original-runtime blocks: `ssa-nomerge-stress` 1,250, `ssa-nomerge-coverage` 2,500.
- `coalesce-locals` original-runtime blocks: `coalesce-locals-unreachable` 625, `coalesce-locals-legacy-eh` 625.
- `simplify-locals` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,225, `simplify-locals-stress` 604.
- `simplify-locals-notee` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,250, `simplify-locals-stress` 625.
- `simplify-locals-nonesting` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,087, `simplify-locals-stress` 529.
- `simplify-locals-nostructure` Binaryen-side runtime limits: `simplify-locals-nostructure-effect-order` 1,683.
- `simplify-locals-notee-nostructure` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,250, `simplify-locals-stress` 625.

The separate active inline-main campaign changes all **512** main
bodies, keeps all 512 helpers present and matches baseline bytes.
Existing cleanup changes 485 helper bodies identically in both compilers.
This active lane passes
**1,920 three-way** and **640 original/Starshine** runtime comparisons.
Verified v133 rejects 128 tail-call fixtures with
`all break targets must be valid`. These are separately recorded Binaryen/tool
failures, outside the zero-command-failure aggregate rows; their Starshine
outputs validate and match original runtime behavior, while oracle coverage
remains unavailable.

### Cache and evidence inventory

| Lane | Binaryen cache hits / misses | Node-v2 cache hits / misses |
| --- | ---: | ---: |
| `dae2` | 10,000 / 0 | 10,000 / 0 |
| `dae2-closed` | 10,000 / 0 | 10,000 / 0 |
| `dae2-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `precompute` | 10,000 / 0 | 10,000 / 0 |
| `precompute-propagate` | 10,000 / 0 | 10,000 / 0 |
| `inlining` | 10,000 / 0 | 10,000 / 0 |
| `inlining-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `inline-main` | 10,000 / 0 | 10,000 / 0 |
| `dae` | 10,000 / 0 | 10,000 / 0 |
| `dae-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `simplify-globals-optimizing` | 10,000 / 0 | 10,000 / 0 |
| `optimize-instructions` | 10,000 / 0 | 10,000 / 0 |
| `merge-locals` | 10,000 / 0 | 10,000 / 0 |
| `ssa` | 2,309 / 7,691 | 0 / 10,000 |
| `ssa-nomerge` | 1,471 / 8,529 | 0 / 10,000 |
| `coalesce-locals` | 10,000 / 0 | 10,000 / 0 |
| `duplicate-function-elimination` | 23 / 9,977 | 0 / 10,000 |
| `simplify-locals` | 10,000 / 0 | 10,000 / 0 |
| `simplify-locals-notee` | 10,000 / 0 | 10,000 / 0 |
| `simplify-locals-nonesting` | 10,000 / 0 | 10,000 / 0 |
| `simplify-locals-nostructure` | 10,000 / 0 | 10,000 / 0 |
| `simplify-locals-notee-nostructure` | 10,000 / 0 | 10,000 / 0 |

All local artifacts are under `.tmp/pass-perf-next-20260927/`: final validation
and tool identities; `final-pairs-{small,large}/result.json`; `final-sweeps.json`;
each aggregate result, toolchain, cases and observations; retained and size-loss
replays; `final-all-shapes-replay.json`; `final-fuzz-details.json`; active
inline-main observations; per-change benchmarks and activity/runtime checks;
and the final original-edit/API/tool-identity preservation audit.

### Remaining performance and quality work

Large compiler pipeline costs remain open where the tables exceed the target.
Prioritize propagation state/CFG costs, DAE call facts and slicing, DAE2
analysis/lift/lower reuse, Coalesce CFG/lowering work, OI module validation and
encoding work, and inlining body classification/staged rounds. DFE is below
one second but still about 12× v133 on the large input; its remaining relative
gap needs profiling. Saved large paired traces put DFE elimination at
138.454 ms inside an 826.638 ms pass timer; isolate its surrounding cleanup
size checks and validation before tuning body hashing further. The current
whole-module size guards also account for name/fact sections and contextual
string encoding, so replacing them with body-only estimates requires proof
and boundary tests. Plain Precompute also retains substantial pipeline work
outside its inner timer. The rejected
remap and continuation-index approaches should not be retried as established
wins. Keep admission guards, canonical-size losses, residual parity families
and runtime-blocked cases visible alongside performance. Completed mechanisms
are documented above and do not need reimplementation.

## September 27, 2026: bounded reuse campaign

Seven optimizations were committed individually after focused benchmarks and
bounded red-first tests. A DAE2 retained-IR prototype was rejected after its
large-artifact time and memory regressions; its benchmark remains. Fuzzing ran
only after implementation, benchmark controls and artifact repeats finished.
This checkpoint supersedes the preceding campaign for the renewed input/pass
pairs, while preserving historical results and open parity/coverage gaps.

### Changes and focused controls

The 64 calibrated native-release benchmark cases cover each candidate, including
small, unchanged, fully changed and fallback paths where applicable. Fixtures
are built outside the timed loop and preflight assertions check their behavior.
They run through `moon bench`, outside the default behavior-test suite. Native
release uses Moon 0.1.20260920 / moonc v0.10.14+7d59c7ec9 on an AMD Ryzen 7 8845HS
(8 cores, 16 threads). Exact tool output is in `environment.json`.

| Commit / mechanism | Focused reference → candidate | Invariant and owner |
| --- | --- | --- |
| `c47849fa7` exact encoded-size pairs | 128 mostly shared bodies: 4.07 → 2.16 ms; all changed: 4.11 → 4.11 ms; tiny: 2.01 → 2.07 µs | Exact LEB boundaries, string-pool changes, metadata and encoder errors; [binary contract](../binary/function-import-export-and-code-sections.md). |
| `58152bb71` fused Coalesce copy/remap | 512 structured regions: 72.88 → 60.28 µs | Own instruction child arrays and remap the analyzed capture-aware body; [Coalesce](../binaryen/passes/coalesce-locals/starshine-strategy.md). |
| `e1caffc93` incremental statement prefixes | Width 256: 1.98 ms → 7.63 µs | Earliest valid split, effect order, invalid/terminal prefixes; [SimplifyLocals](../binaryen/passes/simplify-locals/performance-and-artifact-frontiers.md). |
| `3f16cec3a` indexed LocalGraph unions | 512 mixed sources: 81.91 → 43.23 µs; ordered subset: 31.57 µs → 238.82 ns | Stable encounter order, no input mutation, borrow unchanged subsets; [IR ownership](../ir2/architecture-rules.md). |
| `6497617af` borrowed validator branch masks | Batch of 128 read-only forks, 4096 locals: 6.72 → 1.34 µs; writing control: 6.70 → 6.91 µs | Budget-eight proof, no sibling initialization leak, conservative copy fallback; [validation](../validate/module-validation-phases.md). |
| `190f7ea62` plain-inlining body measurements | Batch of 128 warm lookups, width 1024: 87.02 → 1.13 µs; always dirty: 86.80 → 89.00 µs | Invalidate touched bodies and remap surviving indices; rebuild global call facts; [inlining](../binaryen/passes/inlining/starshine-strategy.md). |
| `9e562d96a` DAE signature prefix index | 1024 dense signatures: 415.91 → 31.58 µs; sparse first type: 33.31 → 69.66 ns | Preserve raw recursive type indices and holes; stop at largest reference; [DAE](../binaryen/passes/dead-argument-elimination/starshine-strategy.md). |
| `c36f2e895` rejected DAE2 IR retention | Small helper: 792.82 → 624.50 µs, but large plain/optimizing pipelines +3.74%/+3.00%, peak RSS +30.6% | Production retention removed; [DAE2 rejection](../binaryen/passes/dae2/starshine-strategy.md). |

The LocalGraph threshold is 256 on both inputs: smaller indexing regressed
controls. Contiguous subsets avoid indexing; arbitrary-order subsets retain
the old cheap check. Validator sharing applies only to masks of at least 128
locals and bounded read-only bodies. The larger allocated proof budget was
rejected. Inlining caching is plain/nonpartial only; always-dirty tiny bodies
pay bookkeeping cost. DAE's sparse control records its small constant setup
cost. These are bounded reuse mechanisms, not general persistent LocalGraph
states, cross-mutation validation contexts, or retained DAE2 analyses.

Benchmark sources:

- [local_graph_indexed_join_perf_wbtest.mbt](../../../src/ir/local_graph_indexed_join_perf_wbtest.mbt): 22 cases.
- [tc_branch_fork_perf_wbtest.mbt](../../../src/validate/tc_branch_fork_perf_wbtest.mbt): 12 cases.
- [inlining_measure_cache_perf_wbtest.mbt](../../../src/passes/inlining_measure_cache_perf_wbtest.mbt): 8 cases.
- [coalesce_copy_remap_perf_wbtest.mbt](../../../src/passes/coalesce_copy_remap_perf_wbtest.mbt): 4 cases.
- [statement_prefix_reuse_perf_wbtest.mbt](../../../src/passes/statement_prefix_reuse_perf_wbtest.mbt): 4 cases.
- [encoded_size_pair_perf_wbtest.mbt](../../../src/passes/encoded_size_pair_perf_wbtest.mbt): 6 cases.
- [dae_signature_index_perf_wbtest.mbt](../../../src/passes/dae_signature_index_perf_wbtest.mbt): 6 cases.
- [dae2_retention_perf_wbtest.mbt](../../../src/passes/dae2_retention_perf_wbtest.mbt): 2 cases.

### Frozen tools and validation

- Final native CLI: SHA-256 `4f2f6d0f4065aecb1723aca5af16a18d87e0c2a2710068429c12a2b2b819e871`.
- Rebuilt native generator: SHA-256 `ab205b4ff59d03789bf53471e3f0849627c9c79ccf32b2aa88be18986505a549`.
- Verified Binaryen 133: SHA-256 `8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
- Starting native SHA-256: `6610a792ef8d07151ee38bd6c6fbfe82097086e4f50f6dfd3902eecacb00320e`; starting HEAD `612c7d0e3674998a0f12173f62bac04ee8eefd70`; final production HEAD `9e562d96a`.
- Small input: 192,893 bytes / 45 functions; SHA-256 `06a9dd57ade8a4fd7c60cba2d1c97845b61e115a54f49ec484fd5a2d73b9f69c`.
- Large input: 6,211,596 bytes / 12,904 functions; SHA-256 `98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
- `moon info`, `moon fmt`, all **12,606 default wasm-gc tests**, explicit native CLI/generator builds and README/API sync pass.
- Original dirty worktree changes are included in both snapshots and remain unstaged. The sole public API addition is reviewed `binary.encoded_module_sizes(Module, Module)`; it reuses exact body sizes only within one synchronous pair and retains ordinary encoding/error behavior.

### Alternating artifact pairs

Both binaries use logical CPU 6, one warmup and alternating order. Every pair
is bracketed by the baseline Precompute reference; reference drift above 15%
rejects the pair. All rejected samples remain saved. Unrelated project activity
was observed, so these measurements include recorded contention; an idle host is not
claimed. Small cases use 31 accepted pairs, large Coalesce 11, other large cases
seven. These repeats supersede the initial seven-pair small and Coalesce rows.
Pipeline time counts `cmd:main-pipeline` exactly once. Command time and observed
foreign activity remain in the raw reports. Traced/untraced and before/after
bytes agree, and outputs independently validate.

The percentage column is the median of paired changes, with its MAD; it is
not the ratio of the two separate medians. This matters for short bimodal runs.
Near-noise changes are not established speedups or regressions.

| Input | Pass | Before pipeline ms ± MAD | Final pipeline ms ± MAD | Paired change ± MAD |
| --- | --- | ---: | ---: | ---: |
| small | `precompute` | 1.276 ± 0.031 | 1.295 ± 0.017 | +2.06% ± 1.98% |
| small | `precompute-propagate` | 4.831 ± 0.081 | 4.872 ± 0.056 | +0.71% ± 1.83% |
| small | `optimize-instructions` | 3.225 ± 0.042 | 3.233 ± 0.030 | +0.43% ± 1.92% |
| small | `simplify-locals` | 6.412 ± 0.064 | 5.867 ± 0.044 | -8.74% ± 1.08% |
| small | `coalesce-locals` | 11.307 ± 0.090 | 11.648 ± 0.118 | +3.13% ± 1.25% |
| small | `duplicate-function-elimination` | 0.442 ± 0.007 | 0.462 ± 0.017 | +3.25% ± 3.48% |
| small | `dae` | 54.304 ± 1.708 | 54.984 ± 2.121 | +0.93% ± 2.85% |
| small | `dae-optimizing` | 145.606 ± 1.490 | 143.755 ± 2.252 | -0.68% ± 1.34% |
| small | `inlining` | 6.639 ± 0.165 | 6.187 ± 0.119 | -5.83% ± 1.09% |
| small | `inlining-optimizing` | 114.317 ± 1.964 | 110.029 ± 2.312 | -4.68% ± 1.32% |
| small | `dae2` | 18.730 ± 0.313 | 18.646 ± 0.207 | -0.35% ± 1.48% |
| small | `dae2-optimizing` | 27.500 ± 0.477 | 26.640 ± 0.288 | -3.11% ± 1.17% |
| large | `precompute` | 765.347 ± 21.641 | 761.871 ± 13.350 | +2.94% ± 2.63% |
| large | `precompute-propagate` | 1723.230 ± 69.834 | 1780.002 ± 75.786 | -0.29% ± 2.20% |
| large | `optimize-instructions` | 2849.427 ± 38.057 | 2567.042 ± 24.625 | -9.84% ± 2.75% |
| large | `simplify-locals` | 2274.879 ± 32.707 | 2158.621 ± 48.570 | -3.53% ± 1.39% |
| large | `coalesce-locals` | 5104.280 ± 103.080 | 5084.441 ± 127.349 | -0.19% ± 0.69% |
| large | `duplicate-function-elimination` | 910.201 ± 14.613 | 755.143 ± 9.336 | -16.72% ± 0.84% |
| large | `dae` | 847.998 ± 5.168 | 827.356 ± 5.939 | -2.16% ± 0.95% |
| large | `dae-optimizing` | 1067.422 ± 9.007 | 1054.022 ± 13.106 | -0.81% ± 1.51% |
| large | `inlining` | 1808.186 ± 16.664 | 1702.861 ± 12.770 | -5.36% ± 0.32% |
| large | `inlining-optimizing` | 619.871 ± 6.223 | 595.232 ± 4.381 | -4.00% ± 1.00% |
| large | `dae2` | 5259.603 ± 57.159 | 5186.501 ± 22.400 | -1.34% ± 1.22% |
| large | `dae2-optimizing` | 8700.441 ± 39.262 | 8572.526 ± 22.031 | -1.61% ± 0.78% |

The repeated small Coalesce row increases by about 0.34 ms (paired +3.13%, MAD 1.25%); this remains a measured control cost, not a claimed win. Its isolated copy/remap helper improves at both tested widths. Small DFE adds roughly 0.02 ms and its paired change is comparable to noise, while large DFE improves consistently. Precompute propagation has no established cumulative pipeline gain in this campaign despite its wide-join helper improvement.


### Verified v133 comparison

Standard sweeps use default affinity, one warmup and five measured rounds with
reference brackets. Their absolute times must not be mixed with CPU-pinned
pairs. Each report preserves command/phase median and MAD, stable output hashes
and canonical sizes. Inner timers may omit substantial scheduling, validation
and encoding work; zero means no recorded inner timer, not zero work. The
DAE2-optimizing oracle sequence is DAE2, SimplifyLocals and Vacuum.

| Input | Pass | Pipeline ms | Inner Starshine ms | Binaryen pass ms | Inner ratio | Canonical byte delta |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| small | `precompute` | 1.426 | 0.000 | 1.402 | n/a | -70 |
| small | `precompute-propagate` | 5.067 | 1.703 | 2.442 | 0.70× | -84 |
| small | `optimize-instructions` | 3.529 | 0.560 | 0.701 | 0.80× | -28 |
| small | `simplify-locals` | 6.198 | 0.507 | 1.826 | 0.28× | +19 |
| small | `coalesce-locals` | 12.221 | 12.177 | 5.452 | 2.23× | -28 |
| small | `duplicate-function-elimination` | 0.493 | 0.457 | 0.270 | 1.69× | -53 |
| small | `dae` | 53.512 | 53.472 | 0.653 | 81.84× | -134 |
| small | `dae-optimizing` | 143.764 | 143.713 | 7.192 | 19.98× | -1,373 |
| small | `inlining` | 5.950 | 5.916 | 2.648 | 2.23× | -6,504 |
| small | `inlining-optimizing` | 105.054 | 105.002 | 45.423 | 2.31× | +461 |
| small | `dae2` | 18.266 | 18.221 | 1.185 | 15.37× | -97 |
| small | `dae2-optimizing` | 25.782 | 25.721 | 3.622 | 7.10× | -250 |
| large | `precompute` | 722.553 | 63.179 | 191.287 | 0.33× | -5,153 |
| large | `precompute-propagate` | 1567.475 | 624.091 | 736.025 | 0.85× | -9,535 |
| large | `optimize-instructions` | 2432.179 | 123.726 | 243.775 | 0.51× | +47,825 |
| large | `simplify-locals` | 2036.661 | 100.091 | 1120.970 | 0.09× | +428,416 |
| large | `coalesce-locals` | 5161.769 | 5143.815 | 1202.290 | 4.28× | +90,915 |
| large | `duplicate-function-elimination` | 715.878 | 698.157 | 72.046 | 9.69× | -31,031 |
| large | `dae` | 791.770 | 773.839 | 390.403 | 1.98× | -3,626 |
| large | `dae-optimizing` | 1007.601 | 989.949 | 1650.670 | 0.60× | +41,427 |
| large | `inlining` | 1678.764 | 1660.884 | 841.862 | 1.97× | -1,369,483 |
| large | `inlining-optimizing` | 588.559 | 570.952 | 14527.500 | 0.04× | +933,016 |
| large | `dae2` | 5139.265 | 5121.144 | 413.983 | 12.37× | -100,655 |
| large | `dae2-optimizing` | 8462.896 | 8443.496 | 1618.950 | 5.22× | +422,019 |

Large guarded DAE/DAEO and inlining-optimizing times do not demonstrate active
cleanup breadth. Canonical losses and unproven output-shape differences remain
quality gaps; timing alone does not justify accepting them.

### Final deferred correctness campaign

Each of 22 lanes compares 10,000 GenValid cases at seed `0x5eed`, with the
explicit rebuilt native CLI/generator, verified v133, `--jobs auto`, at most
eight subprocesses and 20 retained mismatches, independent validation and
Node-v2 observations. Shared LocalGraph consumers and all SimplifyLocals
variants are included. No external-generator campaign ran.

| Lane | Aggregate | Canonical / cleanup matches | Residuals | Canonically larger | Original/Starshine matches / blocked |
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
| `ssa` | `ssa-all` | 8,713 / 640 | 647 | 0 | 9,335 / 665 |
| `ssa-nomerge` | `ssa-nomerge-all` | 3,750 / 0 | 6,250 | 0 | 6,250 / 3,750 |
| `coalesce-locals` | `coalesce-locals-all` | 3,750 / 5,000 | 1,250 | 0 | 8,750 / 1,250 |
| `duplicate-function-elimination` | `duplicate-function-elimination` | 5,000 / 0 | 5,000 | 0 | 10,000 / 0 |
| `simplify-locals` | `simplify-locals-all` | 380 / 0 | 9,620 | 0 | 10,000 / 0 |
| `simplify-locals-notee` | `simplify-locals-notee-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |
| `simplify-locals-nonesting` | `simplify-locals-nonesting-all` | 5,026 / 0 | 4,974 | 0 | 10,000 / 0 |
| `simplify-locals-nostructure` | `simplify-locals-nostructure-all` | 0 / 0 | 10,000 | 1,662 | 10,000 / 0 |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |

All **220,000** comparisons completed: **210,283** matched observed original behavior; **9,717** remain runtime-blocked. Validation, generator, property-counter, command and observed original/Starshine semantic failures are zero. There are **99,228** residual shape observations and **2,368** canonically larger outputs. These are not an all-parity-pass result.


Cache census: Binaryen 220,000 hits / 0 misses; Node-v2 220,000 hits / 0 misses. Starshine optimized outputs are never cached.

DAE/DAE2 and optimizing SimplifyGlobals normalize dropped constants and
unreachable control debris; Precompute also normalizes local cleanup. OI uses
drop/local cleanup, Coalesce local/unreachable cleanup, SSA local cleanup and
SSA allocation debris. Other lanes use no cleanup normalizers; closed DAE2 adds
`--closed-world`. Exact commands are saved in `final-fuzz-campaign.json`.
Starshine outputs are freshly generated; deterministic Binaryen outputs and
hash-keyed runtime observations may come from the persistent cache. Runtime
matches do not prove every unexported body executed or full three-way agreement.
Separate determinism, idempotence and metamorphic campaigns are outside this run.

### Residual review and coverage limits

Classifications are agent judgments. Every saved residual and every canonical
size-losing case is replayed against the starting compiler. Byte identity
establishes provenance, not semantic equivalence or an acceptable shape gap.

Saved residual replay: 340/340 identical. Complete size-loss replay: 2368/2368 identical.

All 220,000 generated inputs match the preceding campaign. Recorded status, profile, raw/canonical sizes and semantic outcomes are unchanged for 220,000 cases. This census does not establish output byte identity for cases outside the replays.

Exhaustive residual replays through verified-v133 `-Oz --all-features --strip-debug`, with independent downstream validation:

- `optimize-instructions`: 677 residuals, 677 baseline-identical outputs, 677 identical downstream outputs; total canonical delta -27,497 bytes (per-case -104 to -26).
- `merge-locals`: 647 residuals, 647 baseline-identical outputs, 647 identical downstream outputs; total canonical delta -1,294 bytes (per-case -2 to -2).
- `duplicate-function-elimination`: 5,000 residuals, 5,000 baseline-identical outputs, 5,000 identical downstream outputs; total canonical delta -30,000 bytes (per-case -6 to -6).

The [prior inspected contracts](#residual-and-runtime-coverage-review) support
only the renewed scoped OI tuple, MergeLocals unread-tee and DFE fixed-point
caller wins: preserved producers/effect order or private-call equivalence,
measured canonical savings, and identical downstream bytes. DFE's generator
exports no functions; runtime counters alone do not exercise its bodies.
Other residuals remain parity gaps, larger outputs size-losing quality gaps,
and runtime-blocked cases unknown/unverified.

Runtime limits from the complete case census:

- `dae2` original-runtime blocks: `dae2-continuations` 688.
- `dae2-closed` original-runtime blocks: `dae2-continuations` 688.
- `dae2-optimizing` original-runtime blocks: `dae2-continuations` 688.
- `precompute` original-runtime blocks: `precompute-gc-atomic-boundary` 449.
- `precompute-propagate` original-runtime blocks: `precompute-gc-atomic-boundary` 449.
- `dae` Binaryen-side runtime limits: `dae-arg-type-refinement` 625, `dae-return-type-refinement` 625.
- `optimize-instructions` original-runtime blocks: `pass-oi-descriptor-gc` 1,090.
- `ssa` original-runtime blocks: `ssa-loop` 665.
- `ssa-nomerge` original-runtime blocks: `ssa-nomerge-stress` 1,250, `ssa-nomerge-coverage` 2,500.
- `coalesce-locals` original-runtime blocks: `coalesce-locals-unreachable` 625, `coalesce-locals-legacy-eh` 625.
- `simplify-locals` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,225, `simplify-locals-stress` 604.
- `simplify-locals-notee` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,250, `simplify-locals-stress` 625.
- `simplify-locals-nonesting` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,087, `simplify-locals-stress` 529.
- `simplify-locals-nostructure` Binaryen-side runtime limits: `simplify-locals-nostructure-effect-order` 1,683.
- `simplify-locals-notee-nostructure` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,250, `simplify-locals-stress` 625.

The separate active inline-main fixture renews 512 changed main bodies while retaining helpers and baseline bytes. Fresh runtime checks pass 1,920 three-way and 640 original/Starshine observations. Verified v133 rejects 128 tail-call fixtures with `all break targets must be valid`; these remain tool/oracle coverage failures, separate from aggregate command counters. Their Starshine outputs independently validate and match original runtime observations. Exact results are in `inline-main-runtime/result.json`.

### Remaining work and local evidence

Artifact targets remain open: Precompute propagation state/CFG transfer work,
DAE2 analysis/lift/lower costs, Coalesce CFG/lowering, OI validation and remaining
encoding, SimplifyLocals raw/lift/lower costs, DAE call facts and slicing, and
inlining staged planning. Plain Precompute still has a large pipeline/inner-time
gap; the shared LocalGraph helper improvement alone does not close propagation.
Do not retry the rejected retained-IR design without a memory/work model that
addresses the measured regressions. Wider validator sharing requires explicit
ownership; broad context caching requires mutation-aware invalidation.

Artifacts are under `.tmp/pass-perf-reuse-20260927/`: red/green logs, all focused
native controls, `final-checks.json`, `environment.json`, tool identities, initial
and repeated paired timings, v133 sweeps, every aggregate command/result/case,
retained and complete size-loss replays, downstream shape replays, cohort census,
runtime coverage details, active inline-main observations and preservation audit.
The wiki records durable conclusions; ignored artifacts retain exact local data.

## September 28, 2026 performance backlog campaign

This campaign exercises every P01–P14 owner in the performance backlog. It removes
repeated transfers, scans, setup and encoding work, with bounded red-first tests
and 322 native benchmark cases across 23 new files. The following measurements
supersede earlier timings only for the renewed input/pass pairs. Earlier versions,
rejected experiments, output-quality gaps and runtime limits remain historical
evidence. No commits or publication were performed during this campaign.

### Mechanisms, reasons and focused evidence

Benchmark setup and semantic/ownership preflight checks run outside the measured
loop. Reference implementations reproduce the preceding algorithm; results remain
observable inside the loop. Synthetic scaling cases run through `moon bench`,
outside default behavior tests. Times below are isolated native-release helpers
or explicitly named synthetic full passes; they do not predict artifact speedups.

| Slice | Change and reason | Representative reference → candidate | Contract / owner |
| --- | --- | --- | --- |
| P01 | Borrow the expanded LocalGraph input until the first set/tee; read-only blocks need no transfer copy. | 4096-local read-only: 6.93 µs → 112.12 ns; first write: 7.17 → 6.79 µs; all-write: 79.91 → 73.74 µs. | Reaching sources/write influences still recorded; first write owns the outer array, predecessor source rows remain unchanged. [Propagation](../binaryen/passes/precompute-propagate/starshine-strategy.md). |
| P02 | Reuse unchanged raw Precompute functions, defer unused statistics, gate impossible tail folds and stream the first sixteen live snapshot-prefix instructions. | 4096-instruction negative prefix: 50.90 µs → 9.44 ns; positive prefix: 53.81 µs → 12.84 ns; simple value tail: 58.69 → 20.73 ns. | Active scalar folding and infinite-loop tail cleanup remain; Nops and the sixteenth-instruction boundary retain their meaning. [Precompute](../binaryen/passes/precompute-propagate/starshine-strategy.md). |
| P03 | Keep compact control dependencies, skip a provably unaffected second lift, and admit only relevant legacy/TryTable handler rewrites. | 1024 no-handler functions: legacy preparation 617.80 → 88.66 µs; TryTable fold 444.64 → 145.90 µs. | Unknown controls stay conservative; signatures are checked before admission; grouped-local framing preserves old encoded bytes. [DAE2](../binaryen/passes/dae2/starshine-strategy.md). |
| P04 | Compile immutable raw source-hazard steps once per body, then replay them for each source local. | 128 locals: sparse 298.56 → 194.83 µs; dense 263.86 → 195.53 µs. | Preserve barriers, joins, source order and copy exceptions; source arrays remain owned by the input. [Coalesce](../binaryen/passes/coalesce-locals/starshine-strategy.md). |
| P05 | Reject impossible value suffixes with an arity precheck before repeated full typechecking. | Width 256 chain: 2.06 ms → 13.49 µs; candidate-free: 1.61 ms → 3.05 µs. | Possible/unknown suffixes use the original checker; preserve earliest split, errors, effects and all five variant rules. [SimplifyLocals](../binaryen/passes/simplify-locals/raw-lane-and-writeback.md). |
| P06 | Test unchanged code-section identity before deep equality; measure exact function-body framing from one encoded body buffer. | OI unchanged grouping, four wide bodies: 54.93 → 11.62 µs; 128 × 4096 exact body sizes: 4.20 → 4.18 ms (flat). | Full-module exact size guard, final validation, metadata, string-pool and encoder errors remain. [OI](../binaryen/passes/optimize-instructions/starshine-strategy.md). |
| P07 | Apply the same unchanged grouping admission to DFE; retain its already-fused type-root traversal and incremental fixed point. | Four wide changed bodies: 674.42 → 639.80 µs; unchanged tiny grouping: 930.09 → 882.46 ns. | Exact collision equality, host-visible identity and type/remap roots remain. [DFE](../binaryen/passes/duplicate-function-elimination/starshine-strategy.md). |
| P08 | Build count-only call facts without discarded caller/path/loop records; index typed-loop signatures once. | 512 calls: zero parameters 49.88 → 11.82 µs, sixteen parameters 82.34 → 43.02 µs; 1024 signatures 913.58 → 43.06 µs. | Preserve calls, tails, dropped results, unreachable/escaping uses and source order; existing operand/literal/forwarding caches remain. [DAE](../binaryen/passes/dead-argument-elimination/starshine-strategy.md). |
| P09 | Build HOT planning context only when needed, advance scratch-local search, and avoid classifying uncalled ordinary-inlining bodies. | 1024 active functions: full planning 4.37 ms → 131.39 µs; uniform scratch allocation 235.91 → 13.10 µs. | Reference counts still scan all bodies/globals/RefFunc uses; partial and named-main paths retain full classification; delete only actually inlined helpers. [Inlining](../binaryen/passes/inlining/starshine-strategy.md). |
| P10 | Gate dropped-result If candidates before scanning their pure prefixes; add active full SGO fixtures. | 256 unchanged candidates: 31.97 → 9.20 µs; active candidates: 32.00 → 21.97 µs. | Global constants, mutable aliases and nested cleanup effects remain. Large guard timing is a coverage control. [SGO](../binaryen/passes/simplify-globals-optimizing/starshine-strategy.md). |
| P11 | Pop expected types directly, copy aliased initialization masks without element comparisons, and share an invocation-local CA module environment. | 1024 pops: 24.92 → 17.40 µs; 128 aliased 4096-bit intersections: 312.18 → 7.23 µs; 1024 CA refinalizations: 70.59 ms → 285.94 µs. | Returned masks remain owned; underflow/type/unreachable behavior and public TcState are unchanged; environment reuse follows existing dependency invalidation. [IR ownership](../ir2/architecture-rules.md#performance-reuse-ownership-contracts), [CA](../binaryen/passes/constraint-analysis/index.md). |
| P12 | Shift root suffixes once, index large CFG membership, and read the maintained deletion bitmap before the small free-list fallback. | 4096 roots: 4.02 ms → 15.13 µs; CFG membership: 1.82 ms → 10.22 µs; 4096 node getters with sixteen tombstones: 55.94 → 41.67 µs. | Aliased replacement roots are snapshotted; CFG edges remain symmetric; liveness queries do not mutate or allocate nodes. [IR ownership](../ir2/architecture-rules.md#performance-reuse-ownership-contracts). |
| P13 | Encode sequence leaves directly and allocate work-stack tasks for structured controls; measure empty/unchanged/active CLI paths separately. | 4096 flat instructions: 113.21 → 31.82 µs; nested control: 59.10 → 17.63 µs. | Exact opcode/immediate bytes and first errors remain; required decode, validation and output-selection behavior remain. [Encoder tests](../../../src/binary/encode_sequence_cursor_wbtest.mbt). |
| P14 | Renew registry/verified-v133 coverage, add active named-main, policy, MergeLocals, CA and nested-handler fixtures, and profile CA's environment setup. | CA raw cleanup of 1024 functions: 35.40 ms → 182.09 µs; active CA artifact 2586 → 2202 bytes; handler artifact 6325 → 6197 bytes. | Assert real transformations or policy masks; unchanged/guarded inputs alone do not establish performance or transformation breadth. [CA](../binaryen/passes/constraint-analysis/fuzzing.md), [active controls](../../../src/passes/registry_active_perf_wbtest.mbt). |

Existing ordered queues, sparse tuple states, thresholded joins, effect/type
caches, immutable operand views, signature-prefix indexes and DFE type-root fusion
were audited and retained. They are not counted as newly implemented mechanisms.
The HOT getter already returns the existing node; profiling identified membership
work, not a need for a new borrowed-node representation or a public API.

Controls with costs remain explicit. The nested suffix helper measures
2.17 → 2.28 µs, tiny dense source hazards 575.71 → 582.49 ns, and a four-instruction
active Precompute tail 104.09 → 124.20 ns. The tail gate improves long active and
simple-value cases; acceptance also requires the enclosing artifact controls
below. A no-tombstone HOT getter adds approximately 2.4 µs per 4096 queries in
one tiny control. Exact-size buffering alone is flat on the wide fixture. These
results are not independent full-pass performance claims.

A liveness instrumentation wrapper was rejected. Its v3→v4 paired large Coalesce
change was +1.61% ± 1.52% MAD, and its small change +2.33% ± 2.29%; the uncertainty
is substantial, but the production wrapper introduced unnecessary hot-call
overhead. The retained direct path's v3→v5 large paired deltas are Coalesce
−3.31% ± 0.34%, DAE2 −3.88% ± 0.95%, and OI −0.51% ± 0.38%. The full getter
benchmark reference was corrected to include the original require/context calls;
only `bench-ir-liveness-corrected.log` supports its final comparison. Both rejected
and corrected checkpoints remain saved.

DAE's proposed early exit after nonuniform actuals was rejected by source review:
`None` and `Some([None])` represent different supported-plan states, and a later
unsupported control can change admission. A reusable fallthrough summary must
precede such an exit. Whole-HOT DAE2 retention remains rejected for its previously
measured time/RSS losses; no production retention was restored. Public writable
initialization arrays preclude unproved persistent-mask sharing. CA uses the
existing lazy module environment rather than a second cache.

Benchmark source inventory (reference and candidate cases are both counted):

| Benchmark source | Cases |
| --- | ---: |
| [hot_root_splice_bulk_perf_wbtest.mbt](../../../src/ir/hot_root_splice_bulk_perf_wbtest.mbt) | 6 |
| [local_graph_transfer_borrow_perf_wbtest.mbt](../../../src/ir/local_graph_transfer_borrow_perf_wbtest.mbt) | 18 |
| [cfg_membership_perf_wbtest.mbt](../../../src/ir/cfg_membership_perf_wbtest.mbt) | 6 |
| [tc_pop_expect_perf_wbtest.mbt](../../../src/validate/tc_pop_expect_perf_wbtest.mbt) | 4 |
| [encoded_size_body_perf_wbtest.mbt](../../../src/binary/encoded_size_body_perf_wbtest.mbt) | 10 |
| [encode_sequence_cursor_perf_wbtest.mbt](../../../src/binary/encode_sequence_cursor_perf_wbtest.mbt) | 8 |
| [registry_active_perf_wbtest.mbt](../../../src/passes/registry_active_perf_wbtest.mbt) | 20 |
| [dae_count_only_facts_perf_wbtest.mbt](../../../src/passes/dae_count_only_facts_perf_wbtest.mbt) | 18 |
| [inlining_planning_setup_perf_wbtest.mbt](../../../src/passes/inlining_planning_setup_perf_wbtest.mbt) | 18 |
| [dae_loop_signature_index_perf_wbtest.mbt](../../../src/passes/dae_loop_signature_index_perf_wbtest.mbt) | 6 |
| [coalesce_source_hazards_perf_wbtest.mbt](../../../src/passes/coalesce_source_hazards_perf_wbtest.mbt) | 12 |
| [sgo_full_pipeline_perf_wbtest.mbt](../../../src/passes/sgo_full_pipeline_perf_wbtest.mbt) | 6 |
| [dae2_control_summary_perf_wbtest.mbt](../../../src/passes/dae2_control_summary_perf_wbtest.mbt) | 6 |
| [local_group_identity_perf_wbtest.mbt](../../../src/passes/local_group_identity_perf_wbtest.mbt) | 24 |
| [precompute_raw_identity_perf_wbtest.mbt](../../../src/passes/precompute_raw_identity_perf_wbtest.mbt) | 6 |
| [value_suffix_reuse_perf_wbtest.mbt](../../../src/passes/value_suffix_reuse_perf_wbtest.mbt) | 18 |
| [sgo_candidate_scan_perf_wbtest.mbt](../../../src/passes/sgo_candidate_scan_perf_wbtest.mbt) | 8 |
| [inlining_called_planning_perf_wbtest.mbt](../../../src/passes/inlining_called_planning_perf_wbtest.mbt) | 12 |
| [dae2_handler_admission_perf_wbtest.mbt](../../../src/passes/dae2_handler_admission_perf_wbtest.mbt) | 16 |
| [tc_initialized_alias_perf_wbtest.mbt](../../../src/validate/tc_initialized_alias_perf_wbtest.mbt) | 12 |
| [constraint_lower_module_env_perf_wbtest.mbt](../../../src/passes/constraint_lower_module_env_perf_wbtest.mbt) | 16 |
| [hot_indexed_liveness_perf_wbtest.mbt](../../../src/ir/hot_indexed_liveness_perf_wbtest.mbt) | 42 |
| [precompute_tail_admission_perf_wbtest.mbt](../../../src/passes/precompute_tail_admission_perf_wbtest.mbt) | 30 |


### Frozen tools and validation

The starting HEAD is `36df6b8f21908bec8f85fda35bcf472c53b389c6`, with the
pre-existing dirty worktree captured separately in `initial/`. Both native
snapshots include that work; this campaign did not reset it. Public `.mbti` files
are unchanged relative to that snapshot, including the previously introduced
`binary.encoded_module_sizes` API.

- Starting CLI SHA-256: `4f2f6d0f4065aecb1723aca5af16a18d87e0c2a2710068429c12a2b2b819e871`.
- Final CLI SHA-256: `394419949064dd22f1db3937de8300599a5ad0deadcd6b32130a3dc742efe631`.
- Rebuilt generator SHA-256: `a694ff421e1200e774844b6341a5625bbaaf300b0f962063461bd704175337a2`.
- Verified `wasm-opt version 133 (version_133)` SHA-256: `8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
- Small input: 192,893 bytes / 45 functions; SHA-256 `06a9dd57ade8a4fd7c60cba2d1c97845b61e115a54f49ec484fd5a2d73b9f69c`.
- Large input: 6,211,596 bytes / 12,904 functions; SHA-256 `98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
- `moon info`, `moon fmt`, all **12,648 default wasm-gc tests**, and explicit native CLI/generator release builds and README/API sync pass. All **322 new benchmark cases** passed during their corresponding implementation checkpoints; final artifact evidence uses the final source. The performance-harness unit tests pass (13 tests, 47 assertions).

Red logs capture ownership/work assertions only after real semantic assertions:
read-only transfer identity, unchanged raw function reuse, affected DAE2 rewrite
work, source-hazard traversal, suffix typing, exact encoder framing, count-only
facts, lazy planning, mask ownership and environment acquisition. The liveness
fixture failed with 1928 fallback membership checks instead of zero after actual
tombstone mutation. Final Precompute scan admission failed four of five tests
with excess full-tail/prefix visits before implementation. The grouped-local
DAE2 framing regression also failed before its byte-preserving repair. Active
[command regressions](../../../src/cmd/cmd.mbt) cover affected canonical dispatch.

Environment: Moon 0.1.20260920 / moonc v0.10.14+7d59c7ec9, AMD Ryzen 7 8845HS,
wasm-tools 1.251.0, Bun 1.4.2 and Node v26.10.0. Tool output is retained in
`environment-final.json`. `perf` sampling is unavailable on this host; Callgrind
uses self instruction counts for attribution, not wall-time phase fractions.
Recursive inclusive counts must not be summed as pipeline shares. Peak RSS uses
the separately pinned GNU time tool recorded in `gnu-time.json`.


### Alternating artifact pairs

Both snapshots use logical CPU 6, one warmup, alternating order and baseline
Precompute reference brackets. Drift above 15% rejects a pair; rejected samples
and observed unrelated project CPU activity remain saved. An idle host is not
claimed. Small and active fixtures use 31 accepted pairs; large fixtures seven except
optimizing inlining, whose 31-pair repeat supersedes the initial seven.
Every before/after/traced/untraced output agrees byte-for-byte and independently
validates. The enclosing `cmd:main-pipeline` timer is counted once.

Percentages are medians of paired changes with their MAD, not ratios of separate
medians. Near-noise observations are not established wins or regressions.

| Input | Pass | Before pipeline ms ± MAD | Final pipeline ms ± MAD | Paired change ± MAD |
| --- | --- | ---: | ---: | ---: |
| small | `precompute` | 1.389 ± 0.012 | 1.279 ± 0.027 | -8.05% ± 1.88% |
| small | `precompute-propagate` | 5.084 ± 0.081 | 4.714 ± 0.030 | -6.48% ± 1.57% |
| small | `dae2` | 18.509 ± 0.199 | 15.397 ± 0.156 | -16.72% ± 1.51% |
| small | `dae2-optimizing` | 28.241 ± 1.226 | 23.712 ± 0.703 | -14.17% ± 1.70% |
| small | `coalesce-locals` | 12.166 ± 0.108 | 9.349 ± 0.130 | -23.50% ± 1.51% |
| small | `simplify-locals` | 6.204 ± 0.087 | 5.600 ± 0.062 | -9.51% ± 2.05% |
| small | `optimize-instructions` | 3.541 ± 0.100 | 3.393 ± 0.113 | -2.32% ± 2.74% |
| small | `duplicate-function-elimination` | 0.495 ± 0.014 | 0.491 ± 0.011 | -0.84% ± 5.15% |
| small | `dae` | 54.761 ± 0.623 | 52.938 ± 0.355 | -2.94% ± 1.48% |
| small | `dae-optimizing` | 146.205 ± 1.772 | 135.005 ± 1.219 | -7.70% ± 1.17% |
| small | `inlining` | 5.968 ± 0.087 | 2.422 ± 0.053 | -59.74% ± 0.94% |
| small | `inlining-optimizing` | 109.628 ± 1.122 | 86.686 ± 0.549 | -20.95% ± 1.31% |
| small | `simplify-globals-optimizing` | 20.956 ± 0.453 | 17.948 ± 0.341 | -13.95% ± 2.11% |
| large | `precompute` | 737.437 ± 10.879 | 693.921 ± 8.906 | -5.59% ± 0.73% |
| large | `precompute-propagate` | 1594.335 ± 12.434 | 1450.687 ± 13.781 | -8.93% ± 0.80% |
| large | `dae2` | 5446.169 ± 49.700 | 4994.467 ± 101.264 | -8.29% ± 1.01% |
| large | `dae2-optimizing` | 8999.020 ± 58.338 | 8386.827 ± 135.607 | -6.80% ± 0.84% |
| large | `coalesce-locals` | 5294.614 ± 120.257 | 5043.884 ± 134.676 | -5.24% ± 2.03% |
| large | `simplify-locals` | 2020.466 ± 18.691 | 1887.919 ± 12.143 | -6.29% ± 0.59% |
| large | `optimize-instructions` | 2474.071 ± 5.927 | 2308.359 ± 53.026 | -8.74% ± 2.02% |
| large | `duplicate-function-elimination` | 795.240 ± 9.508 | 700.123 ± 11.052 | -11.96% ± 2.14% |
| large | `dae` | 890.173 ± 26.675 | 867.560 ± 8.528 | -1.50% ± 2.31% |
| large | `dae-optimizing` | 1115.663 ± 16.480 | 1103.544 ± 32.467 | -1.77% ± 1.19% |
| large | `inlining` | 1840.841 ± 26.612 | 1813.967 ± 64.658 | -1.35% ± 5.64% |
| large | `inlining-optimizing` | 644.336 ± 14.824 | 665.637 ± 13.485 | +3.96% ± 1.11% |
| large | `simplify-globals-optimizing` | 63.927 ± 5.187 | 63.721 ± 2.751 | -0.59% ± 9.68% |
| active CA | `constraint-analysis` | 8.334 ± 0.147 | 6.527 ± 0.104 | -21.04% ± 1.72% |
| nested handlers | `coalesce-locals` | 2.087 ± 0.044 | 2.001 ± 0.036 | -3.16% ± 3.40% |

### Verified Binaryen 133 renewal

The standard sweeps also use CPU 6, one warmup, seven small/active samples and
five large samples, with raw/canonical output sizes and trace/untraced checks.
Diagnostic pipeline columns include finer tracing than the alternating compiler
pairs; their absolute values must not be mixed. Untraced command wall time,
pass timers, diagnostic phases and measured trace overhead remain separate in
the raw reports. Nested timers are not additive. Zero inner time means no
recorded inner sample, not zero work. DAE2-optimizing's oracle sequence is DAE2,
SimplifyLocals and Vacuum.

| Input | Pass | Diagnostic pipeline ms | Inner Starshine ms | Binaryen pass ms | Inner ratio | Canonical byte delta |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| small | `precompute` | 1.266 | 0.000 | 1.318 | n/a | -70 |
| small | `precompute-propagate` | 6.445 | 1.578 | 2.453 | 0.64× | -84 |
| small | `dae2` | 15.378 | 15.263 | 1.028 | 14.85× | -97 |
| small | `dae2-optimizing` | 24.562 | 24.509 | 3.159 | 7.76× | -250 |
| small | `coalesce-locals` | 9.458 | 9.362 | 5.190 | 1.80× | -28 |
| small | `simplify-locals` | 6.877 | 0.753 | 1.850 | 0.41× | +19 |
| small | `optimize-instructions` | 4.776 | 0.999 | 0.680 | 1.47× | -28 |
| small | `duplicate-function-elimination` | 0.535 | 0.503 | 0.233 | 2.16× | -53 |
| small | `dae` | 52.637 | 52.552 | 0.636 | 82.69× | -134 |
| small | `dae-optimizing` | 141.919 | 141.825 | 15.918 | 8.91× | -1,373 |
| small | `inlining` | 2.620 | 2.589 | 2.512 | 1.03× | -6,504 |
| small | `inlining-optimizing` | 95.349 | 95.179 | 56.851 | 1.67× | +461 |
| small | `simplify-globals-optimizing` | 23.381 | 23.297 | 1.343 | 17.35× | -372 |
| large | `precompute` | 888.873 | 56.436 | 199.837 | 0.28× | -5,153 |
| large | `precompute-propagate` | 1963.404 | 604.918 | 828.021 | 0.73× | -9,535 |
| large | `dae2` | 5362.162 | 5337.259 | 500.588 | 10.66× | -100,655 |
| large | `dae2-optimizing` | 9297.582 | 9277.250 | 1798.420 | 5.16× | +422,019 |
| large | `coalesce-locals` | 5320.311 | 5296.083 | 1267.020 | 4.18× | +90,915 |
| large | `simplify-locals` | 2329.675 | 170.628 | 1141.790 | 0.15× | +428,416 |
| large | `optimize-instructions` | 2637.530 | 168.124 | 254.311 | 0.66× | +47,825 |
| large | `duplicate-function-elimination` | 751.263 | 731.389 | 77.894 | 9.39× | -31,031 |
| large | `dae` | 902.947 | 882.093 | 467.477 | 1.89× | -3,626 |
| large | `dae-optimizing` | 1127.127 | 1106.040 | 2065.690 | 0.54× | +41,427 |
| large | `inlining` | 1838.314 | 1810.522 | 919.201 | 1.97× | -1,369,483 |
| large | `inlining-optimizing` | 686.286 | 666.135 | 16270.500 | 0.04× | +933,016 |
| large | `simplify-globals-optimizing` | 62.245 | 42.147 | 1233.810 | 0.03× | +173,229 |
| active CA | `constraint-analysis` | 10.723 | 2.620 | 0.255 | 10.27× | +0 |
| nested handlers | `coalesce-locals` | 2.065 | 1.971 | 0.252 | 7.82× | +384 |


The optimizing-inlining large pipeline increase was investigated before fuzzing.
A 31-pair repeat measures 644.336 → 665.637 ms, paired **+3.96% ± 1.11% MAD**.
Checkpoint pairs place most of the increase around the direct liveness change,
though that narrower 11-pair comparison is noisy (+3.18% ± 2.37%). It is retained
as a measured tradeoff: an independent eleven-pair **untraced whole-command**
control improves 1416.613 → 1368.239 ms, **−3.94% ± 0.73%**, with identical bytes
and independent validation; the pipeline remains below one second. Large
Coalesce/DAE2 benefit from direct liveness. The pipeline increase is not relabeled
as noise or a pass-local win. Helper-removal references and remap-preserved body
measurements were reviewed; they already have the proposed count/reuse behavior.
No duplicate cache or unproved traversal shortcut was added.

Small inlining improves by 59.74%, Coalesce by 23.50%, optimizing inlining by
20.95%, DAE2 by 16.72%, and SGO by 13.95% in the paired pipeline controls. Large
DFE improves by 11.96%, propagation by 8.93%, OI by 8.74%, DAE2 by 8.29%,
SimplifyLocals by 6.29%, and plain Precompute by 5.59%. Changes comparable to
MAD remain uncertain. Active CA improves by 21.04% ± 1.72%; the nested-handler
Coalesce change (−3.16% ± 3.40%) remains uncertain. Favorable large DAE/DAEO, optimizing-inlining and SGO timings
include guards/fallbacks and do not prove full nested-cleanup coverage.

Large DAE2, optimizing DAE2, Coalesce, OI, propagation, SimplifyLocals and plain
inlining remain multi-second. DFE and small DAE/SGO/CA/handler controls retain
substantial oracle ratios. Large canonical gaps persist: Coalesce +90,915,
OI +47,825, DAEO +41,427, SimplifyLocals +428,416 and optimizing inlining +933,016
bytes. Active CA has equal canonical bytes; the nested-handler fixture remains
+384 canonical bytes. Validity and smaller Starshine checkpoint outputs do not
justify accepting an unproved Binaryen shape gap.

### Command, memory, coverage and attribution

Empty, unchanged-Precompute fixed-point and active Precompute controls use both
fixed sizes, seven alternating traced/untraced pairs, drift rejection and exact
output/validation checks. Empty CLI reuses encoded input; it does not measure
full optimizer decode/validation work. Fixed-point artifacts are retained.

| Input | Control | Before / final untraced wall ms | Paired change ± MAD |
| --- | --- | ---: | ---: |
| small | empty | 3.370 / 3.236 | -2.29% ± 4.39% |
| small | unchanged | 6.739 / 6.298 | -5.75% ± 2.02% |
| small | active | 6.792 / 6.470 | -4.16% ± 1.17% |
| large | empty | 8.351 / 8.352 | -0.62% ± 0.88% |
| large | unchanged | 1437.082 / 1310.558 | -8.32% ± 0.61% |
| large | active | 1493.396 / 1365.636 | -8.55% ± 0.05% |

Peak RSS on the large artifact (KiB, one independently measured pair per owner):

| Pass | Before / final peak RSS KiB | Change |
| --- | ---: | ---: |
| `dae2` | 302,380 / 287,292 | -4.99% |
| `dae2-optimizing` | 307,320 / 312,280 | +1.61% |
| `coalesce-locals` | 246,440 / 243,024 | -1.39% |
| `precompute-propagate` | 163,536 / 157,392 | -3.76% |
| `optimize-instructions` | 164,828 / 164,740 | -0.05% |
| `inlining` | 302,300 / 302,452 | +0.05% |

The largest RSS increase among these six pairs is 1.61% (optimizing DAE2); this is a limited
single-pair memory control, not a precise allocation census or a proved memory
regression. No final pair crosses the 5% repeat threshold. All six RSS pairs
retain exact output bytes.

Registry inventory: 74 direct names plus two presets, 67 paired names and seven
unpaired Starshine names (CFG Coalesce, stable-binding DIE, the DAEO alias, three
inlining policies and compiler facts). The verified v133 optimization-section
help contains 171 flags; 115 have no exact paired name. This includes aliases,
policies and tools, so it is not a count of 115 missing semantic implementations.
The 67 small-input command probes succeed and independently validate, all with
starting/final byte identity; 30 leave raw input bytes unchanged. A benchmark's
presence or a partial function-skip trace does not establish active coverage.
New active registry fixtures assert transformations or policy masks explicitly.

Callgrind self instruction totals fall from 104,556,260 to 75,773,247 on active
CA, 42,721,611 to 41,930,072 on nested-handler Coalesce, 870,020,561 to 829,832,249
on small DAE, and 63,059,668 to 56,021,890 on small OI. Allocation/refcount/free,
validation intersections and graph/lower queries remain important owners.
The separate large Precompute checkpoint profile motivated its final raw tail
and prefix admission changes. Self instruction shares are not wall-time phase
shares; recursive inclusive attribution is not additive.

The active named-main lane changes all 512 main bodies, retains all 512 helpers
and preserves starting bytes. Fresh runtime checks pass **1920 three-way** and
**640 original/Starshine** observations, with zero mismatches. Starshine's 512
outputs and 384 successful oracle outputs independently validate. Verified v133
rejects 128 tail-call fixtures with `all break targets must be valid`; these are
separate tool/oracle coverage failures. The GenValid inlining aggregate alone
has no equivalent named-helper coverage.

### Final deferred correctness campaign

All performance iteration and the optimizing-inlining control review finished
before this final campaign. Each of 23 lanes compares 10,000 GenValid cases
at seed `0x5eed`, using the explicit rebuilt native CLI/generator and verified
v133, `--jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20`, independent
validation and Node-v2 observations. Shared LocalGraph/validator/IR consumers,
all five SimplifyLocals modes and CA are included. No external-generator
campaign ran.

| Lane | Aggregate | Canonical / cleanup matches | Residuals | Canonically larger | Original/Starshine matches / blocked |
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
| `ssa` | `ssa-all` | 8,713 / 640 | 647 | 0 | 9,335 / 665 |
| `ssa-nomerge` | `ssa-nomerge-all` | 3,750 / 0 | 6,250 | 0 | 6,250 / 3,750 |
| `coalesce-locals` | `coalesce-locals-all` | 3,750 / 5,000 | 1,250 | 0 | 8,750 / 1,250 |
| `duplicate-function-elimination` | `duplicate-function-elimination` | 5,000 / 0 | 5,000 | 0 | 10,000 / 0 |
| `simplify-locals` | `simplify-locals-all` | 380 / 0 | 9,620 | 0 | 10,000 / 0 |
| `simplify-locals-notee` | `simplify-locals-notee-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |
| `simplify-locals-nonesting` | `simplify-locals-nonesting-all` | 5,026 / 0 | 4,974 | 0 | 10,000 / 0 |
| `simplify-locals-nostructure` | `simplify-locals-nostructure-all` | 0 / 0 | 10,000 | 1,662 | 10,000 / 0 |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |
| `constraint-analysis` | `constraint-analysis` | 7,368 / 0 | 2,632 | 0 | 10,000 / 0 |

All **230,000** comparisons completed: **220,283** matched observed original/Starshine behavior and **9,717** remain runtime-blocked. Validation, generator, command and observed original/Starshine semantic failures are zero. There are **101,860** residual shape observations and **2,368** canonically larger outputs. The campaign is not an all-parity-pass result; shape residuals give affected harness lanes exit status 1.

Cache census: Binaryen 228,179 hits / 1,821 misses; Binaryen failure cache 0 hits / 0 misses; Node-v2 220,000 hits / 10,000 misses. Starshine optimized outputs are freshly generated and never cached.

DAE/DAE2 and optimizing SimplifyGlobals normalize dropped constants and
unreachable control debris; Precompute also normalizes local cleanup. OI uses
drop/local cleanup, Coalesce local/unreachable cleanup, and SSA local/SSA
allocation cleanup. Other lanes use no cleanup normalizers; closed DAE2 adds
`--closed-world`. Exact commands and configuration identities are saved in
`final-fuzz-campaign.json` and each lane’s `toolchain.json`. Hash-keyed runtime
observations may be reused; these counts do not imply fresh execution of every
case, full three-way agreement, or execution of every unexported body.
Determinism, codec, idempotence and metamorphic campaigns are separate from
this comparison run.

### Residual review and runtime limits

Classifications below are agent judgments. Baseline byte identity establishes
provenance, not semantic equivalence or an acceptable output-shape gap.

Every retained residual is baseline-identical (360/360); every canonical size-losing case is baseline-identical (2,368/2,368). All 220,000 inputs shared with the preceding campaign have identical recorded status, profile, raw/canonical sizes and semantic outcomes. This census does not establish byte identity outside the replayed outputs. CA has no preceding campaign cohort; its retained residuals are replayed against the frozen starting CLI.

Exhaustive scoped residual replays use fresh verified-v133
`-Oz --all-features --strip-debug` outputs with independent downstream
validation:

- `optimize-instructions`: 677 residuals, all baseline-identical and all downstream byte-identical; total canonical delta -27,497 bytes (per-case -104 to -26).
- `merge-locals`: 647 residuals, all baseline-identical and all downstream byte-identical; total canonical delta -1,294 bytes (per-case -2 to -2).
- `duplicate-function-elimination`: 5,000 residuals, all baseline-identical and all downstream byte-identical; total canonical delta -30,000 bytes (per-case -6 to -6).

The [previously inspected contracts](#residual-and-runtime-coverage-review)
support only the renewed scoped OI tuple, MergeLocals unread-tee and DFE
fixed-point caller wins: preserved producer/effect order or private-call
equivalence, measured canonical savings and identical downstream bytes.
DFE’s generator exports no functions; runtime counters alone do not exercise
its bodies. Residuals outside these scoped families and the CA examples below
remain parity gaps; larger outputs remain size-losing quality gaps, and
runtime-blocked cases remain unverified. The separate CA
review below does not extrapolate inspected examples to unsampled families.

Runtime limits from the full case census:

- `dae2` original-runtime blocks: `dae2-continuations` 688.
- `dae2-closed` original-runtime blocks: `dae2-continuations` 688.
- `dae2-optimizing` original-runtime blocks: `dae2-continuations` 688.
- `precompute` original-runtime blocks: `precompute-gc-atomic-boundary` 449.
- `precompute-propagate` original-runtime blocks: `precompute-gc-atomic-boundary` 449.
- `dae` Binaryen-side runtime limits: `dae-arg-type-refinement` 625, `dae-return-type-refinement` 625; original/Starshine observations are complete.
- `optimize-instructions` original-runtime blocks: `pass-oi-descriptor-gc` 1,090.
- `ssa` original-runtime blocks: `ssa-loop` 665.
- `ssa-nomerge` original-runtime blocks: `ssa-nomerge-coverage` 2,500, `ssa-nomerge-stress` 1,250.
- `coalesce-locals` original-runtime blocks: `coalesce-locals-legacy-eh` 625, `coalesce-locals-unreachable` 625.
- `simplify-locals` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,225, `simplify-locals-stress` 604; original/Starshine observations are complete.
- `simplify-locals-notee` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,250, `simplify-locals-stress` 625; original/Starshine observations are complete.
- `simplify-locals-nonesting` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,087, `simplify-locals-stress` 529; original/Starshine observations are complete.
- `simplify-locals-nostructure` Binaryen-side runtime limits: `simplify-locals-nostructure-effect-order` 1,683; original/Starshine observations are complete.
- `simplify-locals-notee-nostructure` Binaryen-side runtime limits: `simplify-locals-effect-order` 1,250, `simplify-locals-stress` 625; original/Starshine observations are complete.

Detailed blocked-reason categories and examples are saved in
`final-fuzz-details.json`. Original-runtime blocks remain outside semantic
signoff. Binaryen-side runtime limits are separate from original/Starshine
matches and do not establish complete three-way observations.

#### CA residual inspection

The fresh v133 CA aggregate has 7,368 canonical matches and 2,632 residuals,
all canonically smaller, with 10,000 complete three-way Node-v2 matches and no
runtime blocks. Its 10,000 semantic-cache misses distinguish this fresh execution
from the reused observations in the other lanes. The aggregate canonical
saving is 7,881 bytes; smaller output alone does not classify all residuals.

The twenty retained examples were inspected against the
[generator](../../../src/validate/gen_valid_constraint.mbt) and
[constraint contract](../binaryen/passes/constraint-analysis/index.md).
All preserve starting raw bytes and have complete original/Starshine/Binaryen
observations. Fresh common-v133 Oz outputs independently validate:

| Inspected examples | Cases | Raw / canonical total delta | Common-Oz total delta | Source-backed reason |
| --- | ---: | ---: | ---: | --- |
| Nonzero joins | 4 | −12 / −12 bytes | 0, identical bytes | Either arm assigns 3 or 5, so the subsequent comparison with zero is true; neither assignment is reordered. |
| Boolean range proofs | 9 | −31 / −31 bytes | −29 bytes | The unsigned conjunction bounds x between 10 and 20, proving x nonzero; x ≥ 10 or x ≤ 20 covers the entire unsigned domain, making its false arm unreachable. Predicate evaluation remains. |
| Effectful assigned constants / pending calls | 4 | −14 / −14 bytes | 0, identical bytes | The local is assigned before its comparison; global writes still execute. Pending-call cases retain the old global result before the later setter, removing only a redundant local copy and an infeasible arm. |
| Signed minimum | 1 | −12 / −12 bytes | 0, identical bytes | An i64 value cannot be less than the signed i64 minimum; the tested predicate reads a local without effects. |
| Dropped loop tees | 2 | −2 / −2 bytes | 0, identical bytes | Replace a tee whose value is immediately dropped with the same set; the increment, local write and loop control remain. |

**Agent judgment:** these twenty examples are scoped Starshine wins: concrete
transform proofs, 71 fewer raw/canonical bytes in total, complete observed
behavior agreement, and no common-Oz size regression. Eleven common-Oz pairs
are byte-identical; nine logical examples remain smaller by one or five bytes.
This does not classify the other 2,612 CA residuals, including unsampled effect,
integer and parameter-loop forms; keep them open as parity gaps pending complete
family evidence. The matching historical v133 residual count is not proof of an
unchanged cohort. Exact case/profile/diff/size data and agent judgments are in
`ca-residual-inspection.json` and `ca-residual-judgments.json`.

### Remaining work and local evidence

This campaign tries the P01–P14 bottleneck owners and retains measured
improvements; it does not establish release-wide Binaryen competitiveness.
Remaining costs include write-heavy propagation state/CFG work, DAE2
analysis/lift/lower, Coalesce CFG/interference/lowering, OI validation and
encoding, SimplifyLocals cleanup and lift/lower, DAE uniform-actual/slice
solving, called-body inlining/round updates, writable validator forks, and
decode/final-validation/command encoding. The active
[backlog](../../../agent-todo.md) records owners, contracts and exit criteria.
Unmeasured passes, guarded typed-loop cleanup, canonical losses and parity
gaps remain open. Neither a helper speedup nor a favorable inner ratio closes
an enclosing pipeline cost or missing transformation breadth.

Artifacts are under `.tmp/pass-perf-complete-20260927/`: the initial dirty
snapshot, v1–v6 source/binary checkpoints, red/green and native benchmark
logs, `standard-validation-v6.json`, `new-benchmarks.json`,
`benchmark-results.json`, `environment-final.json`, `gnu-time.json`,
`final-tool-identities.json`, paired/v133 summaries and complete raw/rejected
samples, optimizing-inlining causal/repeat/untraced controls, command
controls, `final-source-attribution/result.json`, coverage inventory,
Callgrind/RSS files, active inline-main observations, every aggregate
command/result/case, cohort census, retained/complete-size/scoped-downstream
replays, CA inspection and the final preservation audit. The wiki owns durable
conclusions; ignored files retain exact local evidence.


## September 28, 2026 follow-up performance campaign

The v7 candidate below was superseded during aggregate validation: its new
physical-identity input-byte path skipped existing encoding cleanup on NaN
modules. Seven complete lanes and 4,539 partial unnamed-main comparisons are
preserved as provisional evidence, not final signoff. The v8 correction and
renewed controls are recorded at the end of this section. In particular, v7's
unchanged-command timing cannot be carried forward without remeasurement.

This follow-up starts from the previous campaign's frozen `394419949064dd22f1db3937de8300599a5ad0deadcd6b32130a3dc742efe631`
native executable. The previous 230,000-case signoff remains evidence for that
binary, not automatic signoff for these changes. The v7 candidate passes 12,691
default tests, interface generation, formatting, native CLI build and README/API
sync. The six exact-size tests also pass after strengthening equality assertions.
The v7 timing controls completed; its aggregate renewal was later stopped for
the cleanup regression. The final v8 results supersede it.
The [active backlog](../../../agent-todo.md) retains unresolved release costs.
The v7 native SHA-256 is `31e1505a892e2471a9c02f0659ff9c2f332febf80f8cefe8ff46b8d3bf426a4e`;
`candidate-v7.json` pins all 235 production source files. Nineteen new native
benchmark files contain 380 cases completed during iteration. Generated native
arity code contains no result-array allocation. The preceding v5 binary is
`e249ba251a459c96c8855abccedfbba4c2b69b495b4293a303665be651ef1f1a`;
v6 (`12d11be43cc601273fa861b6a56c9fb46c7803521ab1fb9a8159c977f58750cc`)
changes only `validate/typecheck.mbt` from v5. v7 changes only
`binary/encoded_size.mbt` from v6 in the production inventory.

### Evidence and admission

Local evidence is in `.tmp/pass-perf-rest-20260928/`. `initial/` preserves the
starting dirty worktree. `candidate-v2.json` and `candidate-v3.json` identify
235 production MoonBit source files and their frozen binaries; the corresponding
`candidate-*-src/` directories preserve the full source trees. v3's executable is
`082fbb3d1e30bab3f2ca2d6f01e86be9d624d22dbb9ed85610d5db6a7b48dd35`.

Moon commands and heavy experiments serialize on
`/tmp/starshine-perf-sweep-heavy.lock`; timing controls use logical CPU 6.
Concurrent WAGO activity means these are not idle-host measurements. Alternating
artifact pairs retain reference-drift rejections, medians, MAD, input/output
hashes and untraced independent validation. Baseline and v3 output bytes match
on both production fixtures for every measured pass. The user-requested pause
terminated an unfinished suffix benchmark and a queued test; that partial run
is excluded, as recorded in `stopped-at-user-request.json`.

Fresh baseline Callgrind profiles attribute self instructions, not wall time:

| Input/pass | Total self instructions | Principal costs |
| --- | ---: | --- |
| Large DAE2 | 71,393,103,877 | Runtime object destruction 18.89%, free 8.75%, object scan 5.48%, node getter 4.14%, initialization intersection 2.11%. |
| Large Coalesce | 77,904,222,423 | Runtime destruction 12.76%, free 6.49%, node getter 5.05%, object scan 3.72%, branch-depth queries 3.35%. |
| Large DFE | 14,878,449,520 | Runtime destruction 18.08%, free 12.36%, initialization intersection 4.84%, control encoding 1.83%, string collection 1.70%; shape-array hashing is only 0.72%. |
| Small DAE, v2 | 830,173,373 | Runtime destruction 13.00%, free 8.61%, unreachable-root scans 5.73%, instruction equality 5.42%, call facts 5.07%. |

The apparent `ProposalFeature::make_and_blit` allocator name is native
identical-code folding of an integer-array reallocation; it does not prove
proposal-feature lists are repeatedly copied. Whole-HOT retention remains a
rejected design from the previous campaign.

### Implemented mechanisms and regression controls

Each work or ownership regression was observed failing before implementation.
Semantic, opcode, byte and ownership assertions accompany operation counters;
scaling cases remain in dedicated native benchmark tests.

| Owner | Change and correctness boundary | Bounded test source |
| --- | --- | --- |
| P04 | One preorder control index answers Coalesce fallthrough/escaping-branch queries. Loop backedges and handler conservatism remain separate. | [control summaries](../../../src/passes/coalesce_control_summary_wbtest.mbt) |
| P04 | Structured extra interference visits occupied matrix bits; plain interference maintains live members. Dense and parameter-conflict behavior is preserved. | [sparse interference](../../../src/passes/coalesce_sparse_extra_wbtest.mbt) |
| P01 | Wide tuple branches lazily journal writes; joins visit changed locals, including conservative unknown-control writes. Outer arrays remain owned. | [write journals](../../../src/ir/local_graph_write_journal_wbtest.mbt) |
| P11/P12 | Initialization masks share until the first false-to-true write in an expression; child expressions get independent owners. v6 control joins borrow identical masks; distinct masks retain exact owned intersections. HOT body forks retain definite-initialization facts. | [mask ownership](../../../src/validate/tc_initialization_cow_wbtest.mbt) |
| P09 | Wide mixed-type inlining scratch pools retain bounded per-type cursors, reset per callsite. Small/uniform pools retain direct lookup. | [typed scratch](../../../src/passes/inlining_typed_scratch_wbtest.mbt) |
| P08 | Dropped-result cleanup copies arrays only after a change, retaining separate rewrite-count and body-change facts. | [dropped-result identity](../../../src/passes/dae_dropped_result_identity_wbtest.mbt) |
| P12 | The node getter proves ordinary live access directly and retains the canonical fallback for incomplete arenas; one final array read avoids extra native reference-count traffic. | [direct getter](../../../src/ir/hot_node_get_direct_wbtest.mbt) |
| P07 | DFE remapping reuses unchanged instructions/functions and skips identity remap epochs. Exact collision checks, type normalization and roots remain. | [DFE identity](../../../src/passes/dfe_remap_identity_wbtest.mbt) |
| P08 | Dead-suffix evidence borrows its source body with an explicit start offset; operand queries start with empty suffix-local state. | [suffix borrowing](../../../src/passes/dae_dead_suffix_borrow_wbtest.mbt) |
| P08/P13 | DAE snapshot guards recognize shared code before structural equality; module comparison still checks every non-code field including compiler facts. CLI unchanged-input reuse handles clean shared NaNs under the v8 cleanup admission below. | [snapshot guards](../../../src/passes/dae_code_snapshot_identity_wbtest.mbt), [dispatcher](../../../src/cmd/cmd.mbt) |
| P06/P13 | String collection builds a content-membership index after 32 unique literals. Emission and opcode-offset scans reuse that index; external pools build one only for a lookup beyond the first 32 entries. Scope restoration, first duplicates, declaration/global/control/catch order and 127/128/129 encodings remain exact. | [string pool](../../../src/binary/encode_string_pool_wbtest.mbt), [index scopes](../../../src/binary/encode_string_index_wbtest.mbt) |
| P12 | Arity queries read type shape directly; public result-array queries remain owned. Small result-type tables reuse structural IDs before formatting keys; large tables retain indexed lookup. | [arity](../../../src/ir/hot_type_arity_wbtest.mbt), [interning](../../../src/ir/hot_type_intern_reuse_wbtest.mbt) |
| P05 | Zero-read-set cleanup reuses unchanged bodies and siblings, including NaNs; active replacements preserve the old opcode sequence across structured controls. All five dispatch variants retain coverage. | [zero-read cleanup](../../../src/passes/sl_zero_read_identity_wbtest.mbt) |
| P06/P07 | The v7 candidate reuses exact expression lengths across local-index remaps, adding unsigned-LEB deltas and re-encoding declarations and all framing. An iterative proof checks matching control structure; other changes and changed string pools retain full encoding. | [exact local remap sizes](../../../src/binary/encoded_size_local_remap_wbtest.mbt) |

The sole public-interface addition is
`tc_state_fork_body(TcState, Env, Array[ValType]) -> TcState`. Its supplied stack
is caller-owned; unchanged local storage preserves initialization facts and a
new body resets reachable-escape observations. Different local storage retains
`tc_state_new`'s existing inference policy. Direct writers of public state
arrays must clone first. See the [ownership contracts](../ir2/architecture-rules.md#performance-reuse-ownership-contracts).

### Completed controls and provisional artifact results

Selected completed helper controls (their full logs also retain tiny/dense costs):

| Control | Reference | Follow-up |
| --- | ---: | ---: |
| Coalesce control collector, depth 512 | 108.13 ms | 15.34 µs |
| Structured sparse interference, 1,024 locals | 2.33 ms | 6.02 µs |
| Structured dense interference, 1,024 locals | 7.15 ms | 3.20 ms |
| Wide tuple flow, 4,096 locals / 32 branches | 949.83 µs | 462.31 µs |
| HOT body forks, 4,096 locals / 128 forks | 9.98 µs | 4.43 µs |
| Mixed-type scratch, 1,024 slots | 403.20 µs | 14.61 µs |
| DAE nested unchanged cleanup, 4,096 instructions | 225.82 µs | 43.71 µs |
| DFE nested last-change remap, width 4,096 | 135.06 µs | 40.28 µs |

Additional v5 controls retain the following measured tradeoffs:

- Shared DAE code snapshots with 1,024 functions take 7.80 ns instead of 92.16 µs;
  distinct bodies remain approximately flat (95.18 versus 94.98 µs).
- Early-root suffix borrowing at width 4,096 takes 19.03 ns instead of 15.98 µs.
  No-root and last-root scans are slower: 10.94 versus 9.23 µs and 11.77 versus
  9.89 µs. Generated native loop code has the same predicate and reference-count
  work; this remains a measured scan-path cost, not an algorithmic win.
- Unchanged nested zero-read cleanup at width 4,096 takes 15.47 versus 56.19 µs;
  dense active cleanup is flat (38.96 versus 38.78 µs). Tiny active controls add
  about 3–9 ns.
- Scalar arity takes 8.45 versus 21.33 ns; 1,024-result arity takes 10.14 ns
  versus 1.78 µs. Small resolved-type reuse takes 17.91 versus 240.84 ns;
  the 64-shape fallback remains approximately flat.
- Collecting and looking up 4,096 unique strings takes 272.97 µs versus
  30.92 ms. Tiny four-string scope controls add 15–27 ns, and the repeated
  four-literal collection at width 4,096 takes 38.30 versus 33.87 µs. These costs
  remain visible alongside the removal of quadratic unique/distant lookups.

The initialized-branch production control has 256 functions, 1,024 locals each,
and 64 assignments in each arm. Defaultable-local Coalesce changes from
1,285.661 to 654.658 ms (−49.08%); the matched non-null control and DAE2 controls
are approximately flat. Owned initialization still costs more in its isolated
write loop: 64 previously-unset writes at width 1,024 take 227.17 ns versus
69.19 ns for the old mutable reference. An always-copy-on-write prototype took
2.64 µs and was rejected. Getter prototypes with early returns or optional
wrappers added native reference-count traffic and were replaced by one shared
array-read exit.

The v6 join controls run 128 joins per sample. Aliased width-4 masks take
0.961 µs versus 2.85 µs; width-4,096 masks take 0.985 µs versus 6.63 µs.
Distinct width-4,096 masks retain the exact owned intersection and remain flat
(299.41 versus 300.24 µs). Two bounded regressions also verify later assignments
cannot change entry/sibling masks and nested joins retain uninitialized-local
rejection. See [join benchmarks](../../../src/validate/tc_initialization_join_perf_wbtest.mbt).

Against v5, the isolated v6 join change improves large DFE pipeline time
1.80% paired (17 pairs, MAD 1.04%) and traced command time 3.17% (MAD 0.60%).
OI improves 1.99% paired (seven pairs, MAD 0.35%). Coalesce and DAE2 remain
within dispersion: −0.18% ± 0.69% and −0.48% ± 0.89%, five pairs each.
All output bytes match v5. These causal controls do not replace the separate
comparison against the campaign's original baseline.

That direct 17-pair DFE comparison still regresses 3.03% (MAD 0.62%):
631.956 → 650.631 ms. Broad v6 measurements were therefore deferred before
starting, rather than treating the v5→v6 improvement as sufficient acceptance.
The next candidate addresses repeated expression encoding in exact size guards.
It records body/declaration lengths only within one size-pair invocation and
reuses them only after proving that remaining encoded widths are unchanged.
Local-index deltas use the existing unsigned-LEB sizing helper. Control traversal
uses a worklist; legacy Try keeps full encoding. Reference-type and memory-zero
semantic aliases have canonical identical encodings; unencodable resolved heap
types cannot seed the cache. Complete module sections, encoding errors, body
and section LEB framing, string-pool invalidation and final validation remain.

Two reuse tests failed with one expression encoding instead of zero before
implementation. The v7 default suite passes 12,691 tests; a focused follow-up
strengthens the equality/encoding assertions. All 24 native
[size-pair controls](../../../src/binary/encoded_size_local_remap_perf_wbtest.mbt)
pass. With 32 functions and width 4,096, local remaps take 1.15 versus 2.15 ms;
nested remaps take 1.23 versus 2.27 ms. Wide late fallback takes 2.25 versus
2.21 ms. Tiny shared-body pairs add 47.53 ns (589.29 versus 541.76 ns), and tiny
late fallback adds about 107 ns (1.00 µs versus 892.80 ns). The enclosing
v6→v7 controls measure OI at
−3.70% paired (five pairs, MAD 2.13%) and DFE at +2.43% (MAD 1.42%).
Against the original baseline, large DFE is +4.05% paired (17 pairs, MAD 2.54%);
OI is −2.60% (seven pairs, MAD 2.79%). Seven-pair small controls remain within
dispersion. Thus the size-pair helper gain is not a demonstrated large DFE speedup.

The separate 17-pair untraced DFE control measures 1,460.285 → 1,466.859 ms,
+1.20% paired with 1.30% MAD. Median peak RSS falls from 196,620 to 182,444 KiB
(−7.21%). It retains alternating order, one warmup, a 15% reference bracket,
foreign-process observations and exact output identity. The v7 Callgrind total
is 13,797,535,604 instructions, −7.27% from the original baseline; initialization
intersection no longer appears among the 95% self-instruction contributors.
Agent decision: retain the memory/work reduction and the other measured gains,
with untraced DFE time within dispersion; keep its adverse traced-pipeline result
visible as a remaining cost. Lower instruction counts alone do not establish
a wall-time improvement. Evidence: `untraced-v7-dfe/result.json`,
`summary-pairs-v7.json` and `callgrind-v7-large-duplicate-function-elimination`.

The v3 pilot uses 21 small and five large alternating pairs, plus warmup:

| Pass | Small before → v3 ms | Change | Large before → v3 ms | Change |
| --- | ---: | ---: | ---: | ---: |
| DAE2 | 15.707 → 15.644 | −0.40% | 4,995.242 → 4,925.889 | −1.39% |
| Coalesce | 9.360 → 9.395 | +0.37% | 5,124.469 → 5,007.293 | −2.29% |
| DAE | 53.063 → 49.486 | −6.74% | 868.856 → 864.405 | −0.51% |
| Inlining | 2.397 → 2.079 | −13.27% | 1,818.876 → 1,785.136 | −1.85% |
| DFE | 0.512 → 0.498 | −2.73% | 732.942 → 750.532 | +2.40% |

These are incremental changes from the previous campaign, not Binaryen ratios.
The large DAE change is within dispersion; large DFE's adverse pilot result
requires confirmation or rejection. Small DAE MAD is 1.089/0.921 ms; small
inlining 0.040/0.072 ms; large Coalesce 24.820/16.336 ms; large DFE
24.559/13.843 ms. `pairs-v3-pilot-{small,large}/result.json` owns the complete
samples. The pilot predates string indexing, direct arity, type interning and
zero-read cleanup, so it cannot establish their enclosing-pass benefit.

The completed v5 run has 31 small and seven large alternating pairs for all
thirteen listed passes, with exact before/after output bytes and independent
validation. Small DAE improves 6.92% paired (MAD 1.13%), and inlining improves
13.67% (MAD 5.77%). Large propagation improves 3.04% (MAD 0.79%), DAE2 3.35%
(MAD 1.26%) and Coalesce 3.00% (MAD 0.68%). Large DFE instead regresses 4.81%
(MAD 1.91%); its medians are 712.474/761.608 ms. OI's +2.37% paired result
has 3.79% MAD. `summary-pairs-v5.json` preserves every row and dispersion.
The DFE regression remains an implementation concern, not a dismissed noisy
sample: its collision phase improves by about 11 ms, but encoding and validation
grow. The v5 Callgrind total drops to 14,503,853,149 instructions (−2.52%);
initialization intersection still consumes 646,638,132 self instructions (4.46%).
This motivated v6's unchanged-join reuse, whose two ownership/semantic regressions
failed before implementation; all 1,864 validator tests then passed.

An active full-command string control uses two private duplicate functions and
an exported wrapper that calls both. DFE must reduce three functions to two;
both binaries produce identical bytes, and verified v133 independently validates
the output. At 4,096 distinct literals, 21 alternating pairs measure 55.437 ms
before and 5.896 ms after (−89.35% paired, MAD 0.28%). Peak RSS is
13,220/13,292 KiB. Four- and 128-literal controls remain within dispersion
(+1.04% ± 8.02%, +0.36% ± 3.11%). These command controls record foreign CPU
activity but have no reference bracket. The initial two-function fixture exported
one duplicate, preventing Starshine's identity-preserving merge; that inactive
attempt is excluded. Evidence is `string-command-controls-active/result.json`.

### Final v7 artifact and oracle measurements

The frozen native CLI remains `31e1505a892e2471a9c02f0659ff9c2f332febf80f8cefe8ff46b8d3bf426a4e`.
The rebuilt generator is `04cf8ca75c5e442ce202981b14b5578e7254f9ec75c4d8dc7237c3dadcbf1192`;
verified Binaryen reports exactly `wasm-opt version 133 (version_133)` and retains
SHA-256 `8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
`final-tool-identities.json`, `final-api-audit.json` and `final-source-snapshot/`
preserve tool identity, the sole API addition and the final formatted test/source
snapshot. The earlier v7 snapshot predates a corrected test-constructor spelling;
all 235 production hashes remain unchanged. The focused six-test equality audit
passed after the full 12,691-test suite.

The final sweep uses five small and three large samples, plus warmup and
leading/trailing strip-debug controls, pinned to CPU 6. Both fixtures retain the
first campaign's hashes. All 26 rows have stable Starshine/Binaryen outputs and
exact traced/untraced Starshine byte identity. These are current measurements,
not before/after speedup estimates; different tracing levels and host contention
prevent subtracting historical absolute medians. Sources:
`v133-v7-{small,large}/result.json` and `final-v133-summary.json`.

Command columns show untraced Starshine/Binaryen median milliseconds and their
ratio. Inner ratios omit pipeline and command overhead. A zero small Precompute
sample means missing timer coverage, shown as n/a. Canonical size deltas are
Starshine minus Binaryen bytes; smaller output alone is not semantic proof or
an accepted output-shape exception.

| Pass | Small command ms (ratio) | Large command ms (ratio) | Small / large inner ratio | Small / large canonical ΔB |
| --- | ---: | ---: | ---: | ---: |
| `precompute` | 4.897 / 7.404 (0.66×) | 1,415.754 / 1,115.138 (1.27×) | n/a / 0.29× | -70 / -5,153 |
| `precompute-propagate` | 8.324 / 8.924 (0.93×) | 2,019.638 / 1,622.894 (1.24×) | 0.62× / 0.77× | -84 / -9,535 |
| `dae2` | 20.489 / 6.893 (2.97×) | 5,598.296 / 1,403.017 (3.99×) | 14.90× / 9.89× | -97 / -100,655 |
| `dae2-optimizing` | 27.828 / 10.187 (2.73×) | 8,575.378 / 2,749.061 (3.12×) | 7.76× / 4.87× | -250 / +422,019 |
| `coalesce-locals` | 13.782 / 11.505 (1.20×) | 6,014.839 / 2,095.019 (2.87×) | 1.82× / 3.91× | -28 / +90,915 |
| `simplify-locals` | 9.131 / 7.940 (1.15×) | 2,663.405 / 2,039.253 (1.31×) | 0.41× / 0.15× | +19 / +428,416 |
| `optimize-instructions` | 7.282 / 6.904 (1.05×) | 2,802.580 / 1,182.479 (2.37×) | 1.35× / 0.68× | -28 / +47,825 |
| `duplicate-function-elimination` | 4.135 / 6.102 (0.68×) | 1,534.940 / 1,027.195 (1.49×) | 2.85× / 8.66× | -53 / -31,031 |
| `dae` | 55.190 / 6.589 (8.38×) | 1,695.700 / 1,388.552 (1.22×) | 77.13× / 1.97× | -134 / -3,626 |
| `dae-optimizing` | 134.964 / 22.449 (6.01×) | 2,086.060 / 2,858.280 (0.73×) | 9.18× / 0.58× | -1,373 / +41,427 |
| `inlining` | 6.212 / 8.974 (0.69×) | 2,708.401 / 1,881.761 (1.44×) | 1.13× / 2.01× | -6,504 / -1,369,483 |
| `inlining-optimizing` | 90.280 / 68.359 (1.32×) | 1,486.275 / 16,204.316 (0.09×) | 1.64× / 0.04× | +461 / +933,016 |
| `simplify-globals-optimizing` | 22.234 / 7.913 (2.81×) | 626.947 / 2,073.201 (0.30×) | 18.51× / 0.04× | -372 / +173,229 |

Large DAE2, optimizing DAE2 and Coalesce still have material pass-local gaps;
large OI, SimplifyLocals and propagation retain substantial surrounding pipeline
costs despite competitive inner timers. Large optimizing inlining and SGO include
guarded paths and size losses; their low time ratios do not establish equivalent
cleanup breadth. Small DAE/DAEO and SGO also remain far from the oracle.

The final seven-pair small artifact check confirms DAE at −8.12% paired
(MAD 3.03%), DAEO at −4.05% (MAD 0.92%) and plain inlining at −14.71%
(MAD 7.98%) against the starting binary. Other rows are small or within host
dispersion; `pairs-v7-small/result.json` retains every row and rejected bracket.
The dedicated large DFE/OI measurements and DFE tradeoff remain as recorded above.
These gains are incremental to the first campaign, not gains against Binaryen.

### Final command, active and memory controls

Seven alternating pairs plus warmup compare empty, fixed-point Precompute and
actively transforming Precompute commands on both inputs. A 15% reference bracket
retains rejected samples; traced/untraced output bytes match and independent
validation passes. Untraced command medians and paired dispersion are below.
Empty commands reuse their encoded input and do not exercise the full optimizer.
Source: `command-controls-v7/result.json`, summarized in `final-control-summary.json`.

| Control | Before → v7 wall ms | Paired change (MAD) | Before → v7 peak RSS KiB |
| --- | ---: | ---: | ---: |
| small empty | 3.379 → 3.249 | -4.86% (7.39%) | 8,644 → 8,568 |
| small unchanged | 6.442 → 6.169 | -9.05% (6.19%) | 14,344 → 14,200 |
| small active | 6.898 → 6.605 | -6.88% (7.98%) | 14,428 → 14,420 |
| large empty | 8.695 → 8.884 | +5.12% (4.37%) | 14,772 → 14,784 |
| large unchanged | 1,401.582 → 1,142.180 | -18.51% (2.19%) | 150,212 → 142,732 |
| large active | 1,431.454 → 1,427.857 | -2.00% (1.75%) | 167,180 → 159,740 |

The large unchanged-command improvement is repeatable in these controls; most
small differences and the large active time difference have substantial noise.

The active string control repeated on the final v7 binary has 21 alternating
pairs. At 4,096 literals, command wall changes from 53.891 to 6.068 ms:
−88.62% paired, MAD 0.69%; peak RSS is 13,224/13,304 KiB. Four and 128 literals
remain within dispersion (+10.26% ± 16.57% and −1.73% ± 11.80%). Three functions
must become two, and before/final output bytes match. Verified v133 validates
the active output. This is an end-to-end gain on the stated string-heavy fixture,
not an estimate for arbitrary modules. Source: `string-command-controls-active-v7/result.json`.

The seven-pair active CA pipeline stays flat: 6.547 → 6.541 ms, −0.76% paired
with 4.94% MAD. Its current inner/v133 ratio is 10.39× and untraced command ratio
2.80×; canonical sizes are equal. The nested-handler Coalesce pipeline instead
adds 0.123 ms, 1.983 → 2.106 ms, +5.35% paired with 0.97% MAD. Traced command
wall has +2.41% paired change with 16.25% MAD. Agent decision: retain this small
absolute active-path cost alongside the sparse/deep-control gains and record it
as an unresolved performance tradeoff, not a speedup. Its final inner/v133 ratio
is 8.63×, command ratio 1.59× and canonical gap remains +384 bytes. Both fixtures
must actively change their input, and their final output bytes match the starting
binary. Sources: `pairs-v7-active-*`, `v133-v7-active-*`, `v7-active-identities.json`.

All 67 paired registry names execute successfully on the small input, pass
independent validation and retain exact before/final bytes. Thirty return the
input bytes; this census does not establish active coverage for every name.
The separately recorded large-input RSS samples are one before/after observation
per pass, not a repeated memory distribution:

| Pass | Before → v7 peak RSS KiB |
| --- | ---: |
| `dae2` | 287,292 → 281,528 |
| `dae2-optimizing` | 312,416 → 291,916 |
| `coalesce-locals` | 244,552 → 244,528 |
| `precompute-propagate` | 161,280 → 171,684 |
| `optimize-instructions` | 164,796 → 157,756 |
| `inlining` | 303,060 → 302,564 |
| `duplicate-function-elimination` | 196,468 → 184,800 |

Propagation's +10,404 KiB sample remains visible; do not claim universal memory
improvement. DFE's separate 17-pair RSS result above is stronger evidence than
this one-pair inventory. Source: `v7-source-attribution/result.json`.

### Provisional v7 correctness renewal

After performance iteration, the explicitly rebuilt native tools run the same
23 affected 10,000-case GenValid aggregates and normalizers as the first campaign,
with eight subprocesses, independent validation, the deterministic oracle cache
and Node-v2 observations. Starshine outputs are freshly generated. Semantic
observations may be cached: the [cache key](../../../scripts/lib/optimizer-semantic-cache.ts)
includes all three exact wasm hashes, seed, policy, runtime identity/version,
execution contract and observation limits. Cache hits therefore reuse runtime
evidence for identical bytes, not a newly executed runtime trial. No external
wasm-smith lane is included. This v7 campaign was later stopped for the cleanup
regression; the completed v8 renewal below supersedes it.

A fresh 512-case named-main control already passes: every main body changes,
every helper remains, and all final bytes match the starting binary. There are
1,920 successful three-way runtime observations and 640 original/Starshine
observations, with zero mismatches. Binaryen v133 rejects the same 128 tail-call
cases with `all break targets must be valid`; these are tool/coverage failures,
not semantic matches. Sources: `inline-main-runtime/manifest.json`,
`inline-main-runtime/result.json` and `final-signoff-inline-main-runtime.log`.

#### v8 cleanup correction

The v7 unnamed-main aggregate exposed larger raw outputs despite equal canonical
outputs and matching observed behavior. Inspection of cases 4, 7 and 8 found
33–52 extra bytes: no-op instructions and flattenable control shells that the
existing `encode_module_for_pipeline` cleanup would remove. Module identity
proved the optimizer returned its input, but did not prove that bypassing the
encoding cleanup preserved output quality. This is a rejected optimization
admission, not an accepted representation difference.

The v7 aggregate was stopped after seven complete 10k lanes and 4,539 partial
unnamed-main cases, preserving all evidence in `.tmp/pass-perf-rest-20260928/`.
Two bounded tests first failed on exact output bytes and cleanup admission.
The v8 guard now uses an iterative candidate scan before its new identity path:
no-ops, potentially flattenable control shells, terminal returns and removable
empty sections retain the previous equality/encoding path. Conservative control
candidates avoid duplicating the encoder's branch-rebasing proof. Clean NaN
modules retain exact-byte reuse. Existing structural-equality behavior and final
validation remain unchanged. Tests cover nested If/TryTable, blocks, loops,
terminal returns, empty data/count sections and a complete command invocation:
[cleanup regressions](../../../src/cmd/cmd_input_reuse_cleanup_wbtest.mbt).

The corrected reuse benchmark adds six clean-input controls, retaining dirty
controls and the original reference. v8 source, build, benchmark, targeted replay,
artifact/oracle and correctness evidence is isolated in
`.tmp/pass-perf-rest-v8-20260928/`; all pass, IR, validator and binary mechanisms retain their
source unchanged. Final v8 validation is recorded below. The stopped v7 campaign and its favorable
command timings are not release signoff.

The v8 CLI SHA-256 is
`bbde3e9e5c7dff18409fe37a560ec59299f177a3b81b1943e8a15e39d3138116`;
the rebuilt generator remains `04cf8ca75c5e442ce202981b14b5578e7254f9ec75c4d8dc7237c3dadcbf1192`.
All 12,693 default tests, interface generation, formatting, native builds and
README/API sync pass. The 235-file production inventory differs from v7 only in
`src/cmd/cmd.mbt`; the public API audit is unchanged. All 100 targeted unnamed-main
replays match the original baseline bytes and independently validate.

All 18 corrected CLI reuse benchmarks pass on CPU 6. Clean NaN bodies at width
4 take 39.01 ns versus 66.95 ns for structural equality; width 128 takes
227.10 versus 810.17 ns, and width 4,096 takes 6.26 versus 24.56 µs. Dirty
width-4 controls add about 31–33 ns; dirty width-4,096 controls remain nearly flat
at 11.77–11.78 versus 11.74 µs. Their required cleanup remains enabled. Including
six additional clean controls, the follow-up now has 386 benchmark cases in
19 files, completed during iteration. Source: `bench-input-reuse.log`,
`bench-input-reuse-affinity.json`, `new-benchmarks-final.json`,
`raw-cleanup-replay/result.json` and `standard-validation.json` under the v8 root.

#### v8 final results

The corrected candidate supersedes v7 for current command and oracle claims.
The final sweep retains five small and three large samples, warmup, CPU 6,
verified v133 and the same pinned inputs. All 26 production rows have stable
outputs and exact traced/untraced bytes. The thirteen small before/after controls
use seven alternating pairs. Small inlining improves 22.75% paired (MAD 6.73%),
DAE 6.67% (MAD 2.79%) and DFE 4.96% (MAD 1.32%). Other small changes are limited
or noisy. These are incremental gains from the first campaign's frozen binary,
not Binaryen speedup claims. `summary-pairs-v8-small.json` owns the full pairs.

The current diagnostic large pipeline and untraced command ratios are below.
Inner timers and full commands measure different scopes; missing small
Precompute timing remains n/a. Canonical deltas are Starshine minus Binaryen.

| Pass | Large pipeline ms | Small / large command ratio | Small / large inner ratio | Small / large canonical ΔB |
| --- | ---: | ---: | ---: | ---: |
| `precompute` | 837.585 | 0.67× / 1.24× | n/a / 0.28× | -70 / -5,153 |
| `precompute-propagate` | 1,736.038 | 0.96× / 1.23× | 0.65× / 0.75× | -84 / -9,535 |
| `dae2` | 4,726.612 | 2.74× / 3.98× | 15.03× / 10.12× | -97 / -100,655 |
| `dae2-optimizing` | 8,174.386 | 2.54× / 3.13× | 7.75× / 4.78× | -250 / +422,019 |
| `coalesce-locals` | 4,844.430 | 1.09× / 2.81× | 1.72× / 3.93× | -28 / +90,915 |
| `simplify-locals` | 2,186.084 | 1.18× / 1.28× | 0.39× / 0.15× | +19 / +428,416 |
| `optimize-instructions` | 2,539.513 | 1.03× / 2.50× | 1.29× / 0.66× | -28 / +47,825 |
| `duplicate-function-elimination` | 742.713 | 0.64× / 1.46× | 1.95× / 9.85× | -53 / -31,031 |
| `dae` | 884.529 | 6.95× / 1.22× | 74.79× / 1.99× | -134 / -3,626 |
| `dae-optimizing` | 1,117.779 | 5.78× / 0.65× | 8.69× / 0.56× | -1,373 / +41,427 |
| `inlining` | 1,786.330 | 0.61× / 1.37× | 1.02× / 2.01× | -6,504 / -1,369,483 |
| `inlining-optimizing` | 677.465 | 1.36× / 0.09× | 1.72× / 0.04× | +461 / +933,016 |
| `simplify-globals-optimizing` | 62.529 | 2.76× / 0.30× | 17.55× / 0.04× | -372 / +173,229 |

Source: `v133-v8-{small,large}/result.json`, summarized in
`final-v133-summary.json`. Large DAE2/Coalesce and small DAE/DAEO/SGO still have
substantial oracle gaps. Large OI, propagation and SimplifyLocals retain costly
surrounding work. Guarded optimizing-inlining/SGO paths and larger canonical
outputs do not demonstrate equivalent cleanup breadth.

The final command controls use seven alternating pairs and the same 15%
reference bracket, preserving rejected samples and foreign-process observations:

| Control | Before → v8 wall ms | Paired change (MAD) | Before → v8 RSS KiB |
| --- | ---: | ---: | ---: |
| small empty | 3.452 → 3.470 | -0.65% (9.62%) | 8,548 → 8,616 |
| small unchanged | 6.263 → 6.292 | +0.64% (2.22%) | 14,388 → 14,280 |
| small active | 6.493 → 6.875 | +4.24% (5.92%) | 14,488 → 14,456 |
| large empty | 8.535 → 8.588 | -0.27% (1.54%) | 14,796 → 14,720 |
| large unchanged | 1,391.420 → 1,333.669 | -4.15% (1.34%) | 150,380 → 155,036 |
| large active | 1,429.464 → 1,403.805 | -2.09% (1.20%) | 166,996 → 160,604 |

The corrected unchanged-command improvement is 4.15%, not v7's rejected 18.51%
claim. Its median RSS is higher than the baseline. Active large Precompute has
a small gain; small-command differences remain within dispersion.

The active 4,096-string command retains the principal encoding win: 55.456 →
6.296 ms, −88.21% paired (21 pairs, MAD 0.84%), with RSS 13,148 → 13,316 KiB.
Tiny four- and 128-string cases remain noisy (+1.79% ± 5.13%, +6.13% ± 12.37%).
All output bytes match the starting binary; the fixture must remove one of the
two private duplicate functions and verified v133 validates the result.

Active-fixture pipeline controls remain distinct from guarded production paths:

| Fixture | Before → v8 pipeline ms | Paired change (MAD) | Inner / command v133 ratio | Canonical ΔB |
| --- | ---: | ---: | ---: | ---: |
| `constraint-analysis` | 6.584 → 6.495 | -1.35% (2.65%) | 10.15× / 2.83× | +0 |
| `coalesce-locals` | 2.016 → 2.119 | +4.11% (1.14%) | 9.13× / 1.63× | +384 |

Both fixtures must change their input and retain baseline output bytes. The
nested-handler Coalesce cost remains a measured tradeoff alongside sparse/deep
control gains; its +384-byte canonical gap remains open.

All 67 registry probes independently validate and retain baseline bytes; 30
return input bytes, so this is not active coverage for every name. One RSS pair
per large pass gives the following limited memory evidence:

| Pass | Before → v8 peak RSS KiB |
| --- | ---: |
| `dae2` | 284,592 → 280,552 |
| `dae2-optimizing` | 291,720 → 310,444 |
| `coalesce-locals` | 243,288 → 244,492 |
| `precompute-propagate` | 162,632 → 167,244 |
| `optimize-instructions` | 165,472 → 158,376 |
| `inlining` | 302,116 → 302,624 |
| `duplicate-function-elimination` | 196,648 → 182,488 |

Do not extrapolate these single RSS pairs into universal memory improvements.
The adverse propagation and unchanged-command samples remain visible. Evidence:
`command-controls-v8/result.json`, `pairs-v8-active-*`, `v133-v8-active-*`,
`v8-source-attribution/result.json`, `string-command-controls-active-v8/result.json`
and `final-control-summary.json` under `.tmp/pass-perf-rest-v8-20260928/`.

The fresh 512-case named-main runtime control again has 512 changed main bodies,
512 retained helpers and 512 baseline byte matches. All 1,920 three-way and 640
original/Starshine observations match; the same 128 Binaryen tail-call failures
remain separate tool/coverage limits. The completed matrix and replay audits
follow below.

#### v8 final correctness and residual review

The full affected matrix completed after the corrected performance controls,
using the frozen CLI/generator and verified Binaryen 133 above. Exact commands,
normalizers, profiles and tool identities are in `final-fuzz-campaign.json` and
each lane's `toolchain.json`; `--jobs auto --max-subprocesses 8` and the 20-artifact
cap remain. No external-generator lane was used. Each row has 10,000 comparisons.

| Lane | Canonical / cleanup matches | Residuals | Canonically larger | Observed original/Starshine matches / runtime blocks |
| --- | ---: | ---: | ---: | ---: |
| `dae2` | 2,879 / 667 | 6,454 | 0 | 9,312 / 688 |
| `dae2-closed` | 0 / 100 | 9,900 | 706 | 9,312 / 688 |
| `dae2-optimizing` | 2,233 / 0 | 7,767 | 0 | 9,312 / 688 |
| `precompute` | 3,238 / 6,762 | 0 | 0 | 9,551 / 449 |
| `precompute-propagate` | 2,766 / 7,234 | 0 | 0 | 9,551 / 449 |
| `inlining` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |
| `inlining-optimizing` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |
| `inline-main` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |
| `dae` | 3,750 / 0 | 6,250 | 0 | 10,000 / 0 |
| `dae-optimizing` | 5,153 / 0 | 4,847 | 0 | 10,000 / 0 |
| `simplify-globals-optimizing` | 5,055 / 0 | 4,945 | 0 | 10,000 / 0 |
| `optimize-instructions` | 8,920 / 403 | 677 | 0 | 8,910 / 1,090 |
| `merge-locals` | 9,353 / 0 | 647 | 0 | 10,000 / 0 |
| `ssa` | 8,713 / 640 | 647 | 0 | 9,335 / 665 |
| `ssa-nomerge` | 3,750 / 0 | 6,250 | 0 | 6,250 / 3,750 |
| `coalesce-locals` | 3,750 / 5,000 | 1,250 | 0 | 8,750 / 1,250 |
| `duplicate-function-elimination` | 5,000 / 0 | 5,000 | 0 | 10,000 / 0 |
| `simplify-locals` | 380 / 0 | 9,620 | 0 | 10,000 / 0 |
| `simplify-locals-notee` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |
| `simplify-locals-nonesting` | 5,026 / 0 | 4,974 | 0 | 10,000 / 0 |
| `simplify-locals-nostructure` | 0 / 0 | 10,000 | 1,662 | 10,000 / 0 |
| `simplify-locals-notee-nostructure` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |
| `constraint-analysis` | 7,368 / 0 | 2,632 | 0 | 10,000 / 0 |

All **230,000 comparisons** completed, with **zero validation,
generator, property, command or observed original/Starshine semantic failures**.
There are 220,283 observed original/Starshine matches and
9,717 runtime-blocked cases. The 101,860
residual shape observations and 2,368 canonical
size losses remain open; affected harness lanes exit 1 for these residuals.
This is not an all-parity-pass result.

Cache census: Binaryen 230,000 hits /
0 misses; semantic-v2
230,000 hits / 0 misses.
Starshine outputs were regenerated. Hash-keyed runtime evidence can be reused
for identical wasm bytes, runtime identity, seed, policy and limits; these counts
do not mean every runtime observation was freshly executed or every unexported
body exercised. The separate 512-case named-main observations were fresh.

All 230,000 shared cohort inputs and their recorded profile, status, raw/canonical
sizes and semantic outcomes match the first campaign. In particular, the corrected
unnamed-main lane restores every recorded raw size. This cohort comparison is not
an all-case output-byte proof. Fresh replays establish baseline byte identity for
all 360 retained residuals and every one of the 2,368 canonical
size-losing cases. The additional 100-case cleanup replay also has exact baseline
bytes and independent validation.

Agent classification: these performance changes introduce no new recorded quality
or semantic gap in this cohort. Previously inspected scoped wins retain their
[source and downstream evidence](#residual-review-and-runtime-limits); this renewal
adds no broader exception. Other residuals remain parity gaps, larger outputs
remain size-losing quality gaps, and runtime-blocked cases remain unverified.
Baseline identity establishes provenance, not semantic proof by itself. The full
runtime-block/profile census and Binaryen-side observation limits are preserved
in `final-fuzz-details.json`; the same 128 named-main Binaryen tail-call failures
remain separate tool/coverage limits.

Final local evidence is under `.tmp/pass-perf-rest-v8-20260928/`:
`candidate-v8.json`, `candidate-v8-src/`, `final-tool-identities.json`,
`standard-validation.json`, red/green provenance in `cleanup-regression-evidence.json`,
`completed-helper-benchmarks-final.json`, the paired/oracle/command/active/RSS files,
`final-evidence-summary.json`, all comparison and replay records, and source/API/link
preservation audits. Earlier helper, profile and rejected-candidate evidence remains
under `.tmp/pass-perf-rest-20260928/`. The [active backlog](../../../agent-todo.md)
retains the multi-second costs, oracle gaps, memory/timing tradeoffs and missing
coverage. This work does not establish release-wide Binaryen competitiveness.


## September 28, 2026 next performance campaign

This iteration follows the complete v8 checkpoint above. Its local evidence is
`.tmp/pass-perf-next-20260928/`; earlier oracle and semantic counts apply only to
their recorded source/binary snapshots. Three changes have real red-first work
or ownership regressions plus behavior assertions:

- DAE2 scans writes once when reads demand analysis. Parameters with no writes
  anywhere in the function have a direct dependency; immutable default locals
  need none. Mutable locals retain the previous flow analysis and conservative
  fallback. [Tests](../../../src/passes/dae2_lazy_flow_wbtest.mbt) and
  [six native controls](../../../src/passes/dae2_immutable_reads_perf_wbtest.mbt)
  cover active argument pruning and mixed mutable reads at several widths.
- HOT instruction typechecking reuses its owned stack for known pop counts;
  generic inference retains a copy. Region-entry signatures remain isolated.
  [Ownership/behavior tests](../../../src/ir/hot_lift_stack_reuse_wbtest.mbt) and
  [six native controls](../../../src/ir/hot_lift_stack_reuse_perf_wbtest.mbt)
  cover prefixes 0, 32 and 512. On this host, reference/owned means are
  195.62/160.57 ns, 308.96/227.48 ns and 2.24/1.10 us, respectively; these are
  helper measurements, not command-level gains.
- Dense Coalesce coloring accumulates scores in reused arrays and stops at the
  first legal slot attaining the maximum possible score. Ties, parameter slots,
  types and conflicts retain the old deterministic result. The
  [regression](../../../src/passes/coalesce_dense_score_wbtest.mbt) reduces the
  bounded unweighted fixture from 192 visits to 24 while checking exact reference
  coloring. [Twelve native controls](../../../src/passes/coalesce_dense_score_perf_wbtest.mbt)
  cover weighted/conflicted and unweighted widths.

### Provisional fixed-artifact measurements

Before is v8 `bbde3e9e5c7dff18409fe37a560ec59299f177a3b81b1943e8a15e39d3138116`;
next-v1 is `64186e9d0a5eb0bdcfb6159ab32dc3d43eac5e28ccd4804a58ed01e095c9494f`.
These CPU-6 pipeline measurements use the same pinned small and large inputs as
above, one warmup and three alternating pairs, bracketed by the unchanged
reference. A separate WAGO process was active on another core; the host was not
idle. They are preliminary iteration evidence. Paired percentage medians are
computed per pair, not from the ratio of independently reported time medians.

| Pass | Small paired change / MAD | Large paired change / MAD |
| --- | ---: | ---: |
| DAE2 | -6.03% / 0.92% | -3.46% / 1.08% |
| DAE2 optimizing | -3.57% / 1.61% | -1.41% / 0.17% |
| Coalesce locals | -0.18% / 5.30% | -2.96% / 0.87% |
| Precompute propagate | -3.54% / 5.80% | -4.11% / 0.83% |
| Simplify locals | -3.82% / 4.79% | +0.77% / 0.06% |
| Optimize instructions | -2.70% / 2.72% | +0.18% / 0.11% |

Every measured output is byte-identical before/after and traced/untraced, with
independent validation. The small controls largely overlap dispersion. Preserve
the two large regressions in later comparisons. These measurements do not renew
Binaryen ratios, peak RSS or the complete active-coverage matrix, and do not
establish release-wide competitiveness. `paired-summary-v1.json` and both
`pairs-candidate-v1-*/result.json` files retain individual measurements.

### Typed control and frontend correctness

A new valid parameterized-if fixture exposed a preexisting lift/lower stack
underflow. The repaired representation keeps entry operands after the three
structural If children, but evaluates them before the condition. Arm lowering
starts with those values already present. CFG and dataflow use the same order;
constant selection carries entry operands into an explicit block prefix.
[Architecture rules](../ir2/architecture-rules.md#typed-conditional-entry-operands-september-28-2026)
own the contract. Nine [IR fixtures](../../../src/ir/hot_lower_if_parameters_wbtest.mbt)
and three [dispatcher fixtures](../../../src/cmd/typed_if_entry_wbtest.mbt), each
across ten passes, cover scalar/tuple producers, effects, implicit else, label
payloads, CFG order and demotion. The initial failures and green replays are
preserved in the local campaign logs.

The [WAT function-label contract](../wast/control-flow-authoring.md) now admits
numeric branches to the implicit function label; malformed depths remain invalid.
[Name decoding](../binary/custom-and-name-sections.md) consumes exactly its bounded
payload and cannot borrow bytes from a following custom section. Both have direct
fixture assertions. Explicit branch-payload fixtures and the global function
index documentation audit remain in the active backlog.

`moon info`, `moon fmt` and all **12,716 default tests** pass for next-v2.
The fresh native CLI SHA-256 is
`e8451dabefb4a6c7ec54e1c549a43dc6f9ab45bd4ca3fb823a136ae9bd6d6725`;
`candidate-v2.json` pins every source hash and `candidate-v2-src/` preserves it.
All 24 native helper cases pass. Dense unweighted coloring reference/bounded
means at 16/64/256 locals are 861.45/554.48 ns, 8.58/3.41 us and
127.35/41.50 us; weighted/conflicted controls are 1.00/0.872 us, 8.12/6.98 us
and 113.18/99.35 us. Active immutable/mixed DAE2 controls complete at
43.58/56.27 us (one pair), 4.32/5.62 ms (128), and 57.51/62.38 ms (1,024).
The DAE2 rows compare different workloads and are not before/after speedups.
`completed-helper-benchmarks-v2.json` records the case census. Next-v1 timings precede the typed
control repair and must not be presented as next-v2 performance or final signoff.
Independent runtime controls, renewed artifact/RSS comparisons and final shared
consumer GenValid renewal remain open; long fuzz stays deferred during iteration.

### Next-v3 lowering iteration

Lowering now borrows its private, read-only resolved parameter array and only
queries block signatures for the block-specific path. The
[ownership regression](../../../src/ir/hot_lower_signature_borrow_wbtest.mbt)
first fails on the copied array. Its tuple fixture then exposed duplicated
constant entry roots and four unnecessary scratch locals in each lowered
function. Leading entry-result roots now remain in their existing stack slots;
the fixture retains the original encoded body and the dispatcher regression
retains zero scratch locals. Independent effectful scalar entries have an exact
instruction-order control as well. Public owned-array queries are unchanged.

The lowering input-prefix search now tries the largest candidate first and
returns on its first match. It retains the old longest-suffix contract without
allocating an index. A [bounded work regression](../../../src/ir/hot_lower_input_prefix_wbtest.mbt)
first requires 528 comparisons for 32 identical tuple lanes; the implementation
reduces this to 32. Partial, repeated, empty and mismatching lanes retain their
expected overlap. [Signature controls](../../../src/ir/hot_lower_signature_borrow_perf_wbtest.mbt)
and [prefix controls](../../../src/ir/hot_lower_input_prefix_perf_wbtest.mbt)
add 32 passing native cases. Signature reference/borrow means at widths
0/1/16/256 are 19.93/13.33, 31.11/13.35, 54.46/14.77 and 537.18/14.61 ns.
Complete repeated-lane prefix matching improves 479.09/35.38 ns at width 32
and 117.21/0.461 us at width 512. The mismatch controls retain quadratic
worst-case work: width 32 increases 369.15 to 375.25 ns and width 512 changes
95.66 to 91.30 us with noisy reference samples. Tiny controls overlap dispersion.
These helper results do not establish enclosing-pass gains.

The explicit function-label payload fixtures and [AUDIT]006 global function-index
documentation/tests are complete. All 12,724 wasm-gc tests pass after interface generation and formatting.
An accidentally selected linear-Wasm run was interrupted and
is not a completed validation claim. The next-v3 native CLI hash is
`bc4eb92eb1345ce4f7dc5a28a90536e824ed53c78358e833e6f82bc6b7c21ca0`.
Nine explicit typed-control fixtures across ten passes produce **756 fresh
runtime observations**, including originals, Starshine and verified Binaryen 133,
with zero mismatches. Return values, tuple lanes, four condition values and import
call order are compared. All 189 modules independently validate. Binaryen's
`--all-features` output initially produced 20 Node compile blocks from compact
imports; the successful lane adds `--disable-compact-imports` and retains the
blocked outputs separately. `dae2-optimizing` uses the harness's upstream
`dae2`/`simplify-locals`/`vacuum` expansion. Evidence is in
`typed-runtime-v3-portable/result.json`; this bounded lane does not replace final
aggregate signoff. Enclosing-pass measurements remain pending.

Profile follow-up: compiler function folding shares the apparent
`ProposalFeature` copy symbol with integer-array reallocation, and the apparent
`oc_node_children` helper with owned HOT child spans. Caller edges, not those
symbol names alone, identify 2,773,226 child-span calls from DAE2 analysis and
4,152,576 integer-array reallocations from local-flow unions in the saved large
v8 profile. Immutable analysis traversal and small ordered unions are the next
allocation targets; mutation-time snapshots and public ownership contracts must
remain intact. Local `integer-array-copy-callers.json` preserves attribution.

### Next-v4 traversal and source-row allocation

Read-only DAE2 analysis now visits child/root slots directly. The
[regression](../../../src/passes/dae2_analysis_children_wbtest.mbt) checks real
argument dependencies, unchanged IR/body ownership, and five removed child
snapshots. Rewrite-time snapshots remain owned because that phase mutates nodes.
LocalGraph initially borrowed immutable first observations and used a reserved
ordered union for extensions. Its [source-row controls](../../../src/ir/local_graph_read_source_borrow_perf_wbtest.mbt)
and [union-capacity controls](../../../src/ir/local_graph_join_capacity_perf_wbtest.mbt)
add 36 passing native cases. First observations improve, but four-merge source
controls regress by 76.7–212%: copying every extension is an unresolved performance
regression in v4. The next repair must retain sibling/source isolation while
reusing a row after its first private copy. It is not accepted on allocation
counts alone. Reserved unions improve the width-1 and width-4 overlap controls
by 27.3% and 20.5%; width-128 overlap costs 0.78% and small subset controls cost
7.7–11.3%. Larger controls are mixed. These are ratios of helper means.

Next-v4 passes all 12,728 wasm-gc tests, interface generation, formatting and a
fresh native build. Its SHA-256 is
`c711c4101d042750e3d38409baad199a7e9ecedeec2cd1d269b5f47417565e9c`.
The iteration has 92 passing native helper cases at this checkpoint. Frozen v3
versus v4 pipeline pairs use the same CPU/input/reference protocol as above:

| Pass | Small paired change / MAD | Large paired change / MAD |
| --- | ---: | ---: |
| DAE2 | -2.53% / 0.40% | -1.45% / 0.70% |
| Coalesce locals | -2.48% / 1.60% | +0.28% / 0.08% |
| Precompute propagate | -6.54% / 3.25% | -0.08% / 0.50% |
| Optimize instructions | -4.28% / 9.59% | +0.45% / 0.47% |

Every measured output is byte-identical across candidates and traced/untraced
runs and independently validates. The small OI set includes an anomalous -54.14%
pair despite passing the reference bracket; it does not establish a repeatable
small-pass improvement. Large results remain small/mixed. Evidence:
`candidate-v4.json`, `helper-means-v4.json`, `pairs-v3-v4-*/result.json` and
`paired-summary-v4-node-value.json` under the local campaign root.

### Native HOT node value-layout experiment

An isolated v4 copy marks the immutable eight-field `HotNode` as `#valtype`.
The installed compiler accepts this layout and reduces direct generated native-C
HotNode allocation sites from 49 to zero. All 467 IR tests pass; the generated
human-readable public interface has no diff. This experiment retains field and
query semantics; it does not change the HOT arena layout. Its native CLI hash is
`8292c7ffad2c06b8aea1f29b9d8f822de2abf36af02a4786ecef0e4a869753e9`.
The before/after pipeline comparisons against v4 are:

| Pass | Small paired change / MAD | Large paired change / MAD |
| --- | ---: | ---: |
| DAE2 | -2.47% / 0.04% | -3.11% / 0.12% |
| Coalesce locals | -0.83% / 2.13% | -2.28% / 0.23% |
| Precompute propagate | +1.04% / 2.66% | -0.93% / 0.33% |
| Optimize instructions | +1.04% / 2.23% | -0.66% / 0.51% |

All measured bytes match and validate. The three-pair large Coalesce, propagation
and OI sets each include a positive (slower) sample, so the modest medians need
continued enclosing controls. The separate WAGO process remained active. RSS,
full-suite integration and active-control renewal remain pending for this
experiment; these results do not establish release-wide competitiveness.
`candidate-node-value.json`, `value-node-layout-red.json`,
`pairs-v4-node-value-*/result.json` and `paired-summary-v4-node-value.json` retain
source/codegen provenance, individual pairs and dispersion.

The node-layout experiment's three untraced RSS samples per pass/input are now
complete. Median v4/value-layout peak RSS (KiB) is: small DAE2 18,000/17,748,
Coalesce 15,836/15,880, propagation 16,324/16,456, OI 16,580/16,736; large DAE2
279,984/270,936, Coalesce 244,492/244,544, propagation 171,520/171,632 and OI
158,808/159,056. Thus large DAE2 saves 9,048 KiB; the other large controls add
52–248 KiB. Every output in this lane is byte-identical and independently
validates. The attribute is retained for integration into next-v5 based on the
DAE2 timing/memory win and bounded costs elsewhere. `memory-node-value/result.json`
retains all samples; integration validation is still pending.

### Next-v5 ownership repair and integration

Next-v5 integrates the retained HotNode value layout with private LocalGraph
row ownership, shared empty rows and an ordered union that skips its already
proved prefix. The repeat-merge/empty-row regressions fail first and then pass;
all 12,731 wasm-gc tests, interface generation, formatting, native build and 60
helper controls pass. This adds 24 union-prefix cases to the iteration (116 unique
native cases). Its native CLI SHA-256 is
`1f2a3b7705084277e3c8dcd8368e402a20abeae62bf7491defe0ce15bbe4b8e4`.
The generated interface has no diff against v4 and the native HotNode allocation
site count remains zero.

The width-32/four-merge source controls now improve against the original union
helper: 1.28/0.952 us for one read and 155.90/109.07 us for 128 reads. Singleton
sources still regress: four merges cost 63.33/112.24 ns for one read and
4.80/12.86 us for 128 reads. This is a remaining cost, not a completed acceptance
claim. The first-observation 128-read controls improve 2.92/0.551 us (width 1)
and 42.09/0.534 us (width 32). The original helper reference calls the union
directly with no influence recording; a further benchmark retains the complete
original recorder as a separate reference, without replacing these measurements.

The prefix regression reduces eight right-hand membership queries to five while
preserving order, duplicates and both input arrays. At width 128, a late extension
changes 6.95/2.51 us; early extension is 11.36/11.27 us, subset 2.42/2.61 us.
The wide indexed controls remain unchanged in algorithm and overlap noise.
These helper ratios are not paired artifact timing improvements.

| Pass | v4→v5 small paired change / MAD | Large paired change / MAD |
| --- | ---: | ---: |
| DAE2 | -3.58% / 3.05% | -4.11% / 0.11% |
| Coalesce locals | -0.31% / 0.49% | -2.21% / 0.09% |
| Precompute propagate | +0.26% / 0.61% | -2.99% / 0.33% |
| Optimize instructions | -4.03% / 1.17% | -1.43% / 1.08% |

All measured outputs remain byte-identical before/after and traced/untraced and
independently validate. The small propagation set includes a -16.58% outlier;
its median is a slight regression. The host still has separate WAGO activity.
`candidate-v5.json`, `helper-means-v5.json`, `paired-summary-v5.json` and
`pairs-v4-v5-*/result.json` retain provenance and individual observations.
These results do not update whole-command Binaryen ratios or final shared-IR
signoff. The singleton source controls are still being improved.

### Next-v6 correctness and rejected predicate experiment

A scalar ownership slot now handles the first privately extended LocalGraph
row; the bitmap is deferred until a second row needs ownership. The bounded
ownership regression fails first, then passes, including a sparse reset and a
second independently extended row. The two private recorder layers carry `#inline`; this annotation alone does not
prove native inlining. Eight additional controls preserve the complete original
recorder separately from the existing direct-union reference. The completed
24-case native run brings this iteration to 124 unique passing helper cases.

The small-DAE native profile attributes 47,538,077 of 775,057,113 instructions to
its simple unreachable-root predicate. A proposed common inline predicate delegated
only singleton nested Blocks to recursive handling. Twelve helper controls retain
the previous recursive implementation at depths 0/4/32 with both outcomes. The
initial C-site estimate was superseded by final native disassembly below; the
experiment required actual call elimination before accepting any speedup.
This does not narrow the predicate's existing singleton-block semantics.

The typed-control consumer audit reproduces missing operand ranges, local-read
hazards and global-write hazards after cleanup removes unused arm-entry roots.
Four focused regressions now pass, including a demoted Block. A fifth regression
and dispatcher fixture expose Precompute deleting a producer still referenced
by its conditional header. Batched physical-reference filtering preserves that
producer and deletes detached debris. The [architecture contract](../ir2/architecture-rules.md#typed-entry-pass-consumers-and-tail-cleanup)
records the traversal and deletion rules. All six dispatcher tests, five focused
consumer tests and all **12,737 wasm-gc tests** pass. The native CLI builds and
the expanded bounded runtime lane completes: 10 fixtures × 17 passes plus each
original produce 350 validated modules and **1,400 fresh observations**, with
zero return/trap, import-trace or exported-global mismatches. Binaryen 133 uses
`--disable-compact-imports` for Node v26.10.0 compatibility. These
changes extend final renewal to the dedicated HSO and broad random-all-profiles
HSO lanes; long fuzz remains deferred during performance iteration.

The v6 native build completes, but the reachability inlining experiment fails
its code-generation gate: 26 C symbol references remain, and native disassembly
shows 28 direct calls/jumps both before and after. `#inline` plus the helper split
does not remove those calls with this toolchain. The predicate change is rejected;
its source has been restored to the v5 predicate after the independent
source-row benchmark completed.
The dedicated predicate benchmark was prepared but has not been run or counted
as passed. `dae-unreachable-inline-red.json`, `dae-unreachable-inline-green.json`
(the latter records `gatePassed: false`) and `dae-unreachable-native-calls.json`
preserve the failed experiment. The frozen v6 source/binary explicitly retains
that unsuccessful split for provenance; it is not the accepted final candidate.


The v6 source-row controls retain a singleton repeated-merge cost. Against the
complete original recorder, four merges take 70.82 → 102.54 ns for one read
(+44.79%) and 5.72 → 7.67 us for 128 reads (+34.09%). Width-32/four-merge cases
improve 1.28 → 0.888 us and 156.71 → 109.09 us. The direct-union reference remains
visible separately. `helper-means-v6.json`, `candidate-v6.json`, and
`typed-runtime-v6-portable/result.json` retain raw evidence under the campaign
directory. Concurrent WAGO activity makes these timing observations provisional.

### Next-v7 fused DAE traversal and small observation-row capacity

The [DAE topology regressions](../../../src/passes/dae_topology_fusion_wbtest.mbt)
first fail with 30/29 redundant instruction visits. Graph construction and refresh
now collect the seven topology fields during the required call-fact walk. Active
and dead tails, imported numbering, direct/indirect/reference calls, nested arms
and legacy handlers retain exact topology and call facts. Supplied topology stays
borrowed; the typed-only batch path still omits unused extras. The
[dispatcher fixture](../../../src/cmd/dae_topology_fusion_wbtest.mbt) retains a tail
call while removing unused forwarded arguments in both DAE modes. Sixteen
[benchmark cases](../../../src/passes/dae_topology_fusion_perf_wbtest.mbt) compare
separate and fused scans at 1/128 functions, 8/128 calls and depth 0/8. These isolate
scan removal; full-pass controls are required before claiming enclosing gains.

A [capacity regression](../../../src/ir/local_graph_read_source_borrow_wbtest.mbt)
first fails because the first private two-element observation row has no spare
capacity. That row now reserves at least four entries. Immutable dataflow joins
keep their existing policy; empty/subset observations keep borrowing, and later
owned observations reuse the private row. The five ownership tests pass; existing
source-row controls will measure whether the extra small capacity repairs the
remaining singleton cost. Full v7 interface generation, formatting, **12,742 wasm-gc tests** and native
CLI build pass, with no interface diff from v6. The native SHA-256 is
`dfe4adbfdbced2f5bb6ba9813ed679fdf21cbe114ff545fccf043a5c0094ad92`.
The 24 renewed source-row controls pass. Singleton/four-merge observations now
take 70.73 → 92.01 ns for one read (+30.09%) and 6.01 → 6.40 us for 128 reads
(+6.49%) against the complete old recorder. Thus the capacity repair reduces,
but does not eliminate, the small-row cost. Width-32/four-merge observations take
1.30 → 0.931 us and 159.88 → 109.47 us. All 16 native DAE controls pass, bringing this iteration to 140 unique passing
helper cases. Fused/separate means for 128 functions × 128 calls are
1.49 → 1.29 ms at depth 0 and 2.21 → 1.98 ms at depth 8. Small controls are mixed:
1 function × 8 calls × depth 8 regresses 2.29 → 2.45 us (+6.99%), and
128 functions × 8 calls × depth 0 regresses 109.70 → 111.28 us (+1.44%).
The other four shapes improve 7.45–22.01%. Enclosing measurements remain pending;
new external WAGO jobs still limit timing claims.


The v7 bounded runtime lane renews all 1,400 observations across 17 passes with
zero mismatches and 350 independently validated modules. The small DAE native
instruction profile changes **775,057,113 → 741,585,749 (-4.32%)** against v5,
with byte-identical output. The redundant topology scanner disappears; combined
unreachable-root self instructions fall 47,538,077 → 32,734,382. This work
reduction is separate from wall timing and remains meaningful under contention.

| Pass | v6→v7 small paired change / MAD | Large paired change / MAD |
| --- | ---: | ---: |
| DAE | -13.16% / 7.64% | +1.85% / 11.97% |
| DAE optimizing | -2.59% / 1.55% | +0.58% / 4.76% |
| Simplify globals optimizing | +4.77% / 3.91% | not sampled |
| DAE2 | -6.30% / 0.83% | +2.47% / 0.55% |
| Coalesce locals | -0.24% / 7.69% | +1.60% / 2.14% |
| Precompute propagate | -0.80% / 0.61% | +2.54% / 3.24% |
| Optimize instructions | -6.13% / 7.63% | +8.51% / 6.37% |

These are **contended diagnostics, not acceptance evidence for speedups**:
WAGO, browser or other CPU activity is recorded in every pass cohort. The large
regressions remain visible and require quiet renewal. All before/after and
traced/untraced outputs are byte-identical and validate. `paired-summary-v6-v7.json`,
`pairs-v6-v7-*/result.json`, `dae-topology-instructions-v5-v7.json` and
`typed-runtime-v7-portable/result.json` retain the complete evidence.

### Lowering value-layout compatibility gate

The isolated `HotLowerStackValue` experiment copies frozen v7 sources and changes
only its private immutable record to `#valtype`. All 471 wasm-gc IR tests and the
native release CLI build pass, and four native heap construction sites become
zero. Native **debug** IR compilation then fails in MoonBit
`Machine_of_clam_lower.lower_array_make`: uninitialized non-null GC reference
arrays are unsupported for this value record. This candidate is **rejected for
the current toolchain**, never integrated into main, and its artifact timing,
RSS and runtime jobs stop before running. Its binary hash is
`5ccc46351ac0aa533480f900680c699257c60275a140d0c3abd80fc79fdeb52e`;
`value-stack-v7-layout-red.json`, `candidate-v7-stack-value.json` and
`stack-value-v7-ir-native.log` preserve the result. No compiler/toolchain source
was changed to work around the failure.

The separate `HotLowerInputs` query-result layout has six native heap construction
sites before its value-type annotation. Its records are returned by value rather
than stored in arrays. Next-v8 passes all 471 native debug IR tests, all 12,742 wasm-gc tests,
interface generation, formatting and native release CLI build. Its six heap
construction sites become zero, with no public interface diff. All 28 lowering
helper controls pass, bringing the current campaign to 144 unique native cases
(the four operand-view controls are renewed historical benchmarks, not newly
written cases). The native hash is
`dc64a096ebc72467627f62a5e9a6bb934272799bd3e72f04c173bfe87a51cf1f`.
Small artifact instruction counts change Coalesce 181,251,492 → 180,505,490
(-0.41%) and propagation 74,000,560 → 73,644,765 (-0.48%), with identical output
bytes. All 471 release IR tests also pass, and the 17-pass bounded runtime lane renews
1,400 observations without mismatch. This modest work reduction does not
establish Binaryen parity. Operand order, borrowed child spans, absent-slot compaction and typed
entry behavior retain their existing direct IR and dispatcher fixtures.


| Pass | v7→v8 small paired change / MAD | Large paired change / MAD | Large median peak RSS, KiB v7→v8 |
| --- | ---: | ---: | ---: |
| DAE2 | +0.19% / 2.91% | -0.40% / 3.49% | 279,016 → 278,332 |
| Coalesce locals | +1.62% / 1.51% | +2.42% / 4.26% | 244,804 → 244,744 |
| Precompute propagate | -6.15% / 4.32% | -1.70% / 2.17% | 169,188 → 169,952 |
| Optimize instructions | +1.47% / 1.56% | -0.08% / 1.15% | 158,120 → 158,340 |

Wall-time samples remain diagnostics under recorded host activity; the small
DAE2 cohort alone reports no >25% foreign process. All outputs match before/after
and traced/untraced and independently validate. Peak RSS uses three alternating
untraced samples. The largest median increase is 764 KiB in propagation.
`paired-summary-v7-v8.json`, `memory-v7-v8/result.json`,
`lower-inputs-instruction-results.json`, `native-helper-ledger-v8.json` and
`typed-runtime-v8-portable/result.json` retain details.

### Next-v9 lazy influence rows

[Influence ownership regressions](../../../src/ir/local_graph_influence_borrow_wbtest.mbt)
first fail because every HOT node gets a private empty observer list. All three
LocalGraph builders now share immutable empty rows. Recording a write's first
observer creates its private row with ordinary eight-entry growth room; subsequent
observers preserve insertion order and deduplicate in place. Unobserved rows
remain shared, and public influence queries stay owned. The
[SSA-nomerge dispatcher fixture](../../../src/cmd/local_graph_influence_borrow_wbtest.mbt)
keeps observers of successive writes on distinct local versions.

Thirty [native controls](../../../src/ir/local_graph_influence_borrow_perf_wbtest.mbt)
compare original eager allocation/recording against lazy rows at 32/2,048/32,768
nodes, empty/sparse/dense observed writes and one/four observers. Fixtures are
built outside the timed closure, verify the HOT arena and exact observer order,
and reject contamination of unobserved rows. The two ownership tests and dispatcher fixture pass. Next-v9 passes all
**12,745 wasm-gc tests**, **473 native debug IR tests**, interface generation,
formatting and native release build, with no public interface diff. Its hash is
`c2f20105e295367c7736dc5bb38700fe74e0d9502acf4497ae47aa28aaf689c2`.
All 30 influence controls and 24 renewed source-row controls pass; this campaign
now has 174 unique native helper cases. This optimization adds no public API.


The influence helper improves in every measured shape: 58.61–87.41%. At 32 nodes,
empty rows change 381.96 → 82.95 ns and dense four-observer rows
506.87 → 197.34 ns. At 32,768 nodes, empty rows change 366.52 → 46.16 us,
sparse four-observer rows 360.08 → 46.29 us, and dense four-observer rows
507.97 → 188.60 us. These are helper measurements, not whole-compiler ratios.
The separate singleton source-row control still costs 68.82 → 93.77 ns for one
read/four merges; the 128-read control measures 6.97 → 6.41 us. Keep the earlier
small-row regression visible rather than treating this one control as closure.

Small artifact native instructions change DAE2 **232,389,132 → 230,085,924
(-0.99%)** and propagation **73,643,791 → 73,361,574 (-0.38%)**, with identical
output bytes. The bounded runtime lane expands to 11 fixtures and 18 passes,
adding successive local writes and SSA-nomerge. All **407 modules validate** and
**1,628 fresh observations** match original and verified Binaryen 133 return/trap,
import-trace and exported-global behavior. This does not replace aggregate fuzz
or establish complete oracle parity.

| Pass | v8→v9 small paired change / MAD | Large paired change / MAD | Large median peak RSS, KiB v8→v9 |
| --- | ---: | ---: | ---: |
| DAE2 | +1.08% / 1.26% | -1.94% / 0.75% | 279,272 → 279,340 |
| Precompute propagate | -0.83% / 3.42% | -0.51% / 0.80% | 169,588 → 169,092 |
| Optimize instructions | -0.50% / 0.32% | +0.70% / 1.40% | 157,052 → 158,628 |

All measured artifact outputs match before/after and traced/untraced and validate.
No >25% foreign process is recorded in the small cohorts; large cohorts still
record foreign activity. These wall-time samples remain diagnostic. The initial
three-pair OI RSS increase (+1,576 KiB) does not repeat in seven additional
alternating pairs: medians are **158,308 → 156,660 KiB**, with broad overlapping
ranges. Preserve both runs; neither a firm RSS regression nor a firm RSS win is
established. Small three-pair RSS deltas are DAE2 -64 KiB, propagation +88 KiB,
and OI -76 KiB.

`candidate-v9.json`, `native-helper-ledger-v9.json`, `helper-means-v9.json`,
`influence-row-instruction-results.json`, `paired-summary-v8-v9.json`,
`memory-v8-v9/result.json`, `memory-v8-v9-oi-renewal/result.json` and
`typed-runtime-v9-portable/result.json` retain source pins and raw evidence.
The current iteration adds 46 benchmark cases in the topology/influence files.
Quiet enclosing/oracle timing, remaining owner bottlenecks and final aggregate
renewal remain open in [the active backlog](../../../agent-todo.md).

### v9 large DAE2 and Coalesce attribution

The frozen v9 executable (`c2f20105…`) was profiled with Callgrind 3.24 on CPU
6 against the same large input (`98189860…`); the saved v8 binary is pinned by
`bbde3e9e5c7dff18409fe37a560ec59299f177a3b81b1943e8a15e39d3138116`. These
whole-command instruction profiles include decode, validation, HOT lift/lower
and output encoding; they are not pass-local wall-time measurements. DAE2 records
59,486,224,808 instructions versus 67,548,321,537 for the saved `before.exe`
profile (-11.9%); Coalesce records 69,294,061,478 versus 74,189,242,342
(-6.6%). The source and input hashes, outputs, annotations and raw Callgrind
data are in `.tmp/pass-perf-next-20260928/profile-v9-large.json` and the
adjacent `callgrind-v9-large-*` artifacts. These totals summarize cumulative
campaign work and do not attribute the reductions to the v9 influence-row
change alone.

Current DAE2 self costs are runtime object destruction 17.96%, `mi_free` 8.19%,
HOT node reads 5.59%, object scanning 5.00%, and HOT liveness checks 1.41%.
LocalGraph source extraction is 1.17%, sparse-flow construction 0.84%, and
source joins 0.52%; DAE2 function analysis itself is 0.58%. Current Coalesce
self costs include object destruction 12.34%, HOT node reads 6.28%, frees
5.81%, object scanning 3.45%, HOT value/local-access conflict checks 2.09%,
control-instruction analysis 1.94%, control-body boundaries 1.66%, and
copy-forward scans 1.48%. Coalesce slot-interference queries are 1.14%, down
from 1.74% in the saved profile. Together these measurements say the next P12
work should test whether hot consumers can read only the needed HOT node fields
without weakening liveness checks; the repeated source-row helper alone is no
longer the dominant opportunity. P04 should measure control summaries and
value/local conflict analysis against active full-pass artifacts. P03 should
first separate HOT lift, DAE2 analysis, lower, and final validation costs before
adding more graph metadata. The current profiles do not justify a broad arena
or allocator redesign.

Callgrind's recursive inclusive tree double-counts nested control walks, so the
percentages above use `--inclusive=no` self costs. In particular, the
RefFunc-declaration walker is only 0.38% self in the DAE2 profile; its recursive
inclusive total is not evidence that it owns most runtime destruction. The
v133 pass ratios in the preceding table remain the latest complete oracle
sweep; these v9 profiles do not renew them.


V13 (`f2991e5d…`) completes 12,850 default tests, 83 focused native checks and
46 native benchmark cases. Its 67-fixture matrix validates 871 modules with
3,900 matching results, effects and traps. Small three-pair DAE2/O pipeline
medians improve 11.100 → 3.894 ms (-64.92%, MAD 0.014/0.041) and
18.237 → 11.083 ms (-39.23%, MAD 0.090/0.089) against V12, with identical
bytes. These are incomplete candidate measurements: large DAE2 adds 316 raw
bytes across 86 functions, so the evidence runner stops at its size guard.
Agent judgment classifies these unread local.tee additions as a size-losing
parity gap. Large DAE2/O timings, RSS and fresh oracle ratios remain unfinished.
V14's red-first repair matches HOT lowering's surviving-read rule and keeps
prior measurements under V13. Sources: the [raw projection](../../../src/passes/dae2_raw_rewrite.mbt),
[focused fixtures](../../../src/passes/dae2_raw_tee_captures_wbtest.mbt) and
[dispatcher checks](../../../src/cmd/dae2_raw_tee_wbtest.mbt). Local artifacts:
`evidence-v13-driver.log`, `v13-large-drift.json` and `pairs-v13-large/`
under `.tmp/pass-perf-dae-priority-20260928/`.


### V14 complete checkpoint and next cleanup targets

V14 (`7d2273c17b0525891abd4ee5e05460a05431c7ccf3b8ce70db0b17735c4a1527`)
completes 12,853 default wasm-gc tests, 86 focused native tests, 46 native
benchmark cases, interface generation, formatting and the native CLI build.
Its production-source fingerprint is
`c225621db57e6886c5f7aa9347cb4fbb11affec94c0b70b682edd06e3daf7acd`
over 261 files using the sweep's source definition. The 70-fixture bounded
matrix independently validates 910 modules and matches 4,056 results, effects
and traps against original, V12 and verified Binaryen 133 output. All V12/V14
matrix bytes match. This closes the V13 unread-tee regression: large DAE2 and
DAE2-O again emit exactly 6,114,805 and 5,956,034 raw bytes, identical to V12.
It supersedes V13's partial candidate evidence without erasing that failed run.

CPU-6 enclosing comparisons use one warmup and three alternating measured
pairs, reference brackets capped at 1.15 and exact traced/untraced byte guards.
The following are pipeline medians, separate from the oracle pass-local timers:

| Fixture / pass | V12 → V14 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: |
| small / `dae2` | 11.474 → 4.306 | -62.47% | 0.076 / 0.248 |
| small / `dae2-optimizing` | 19.506 → 11.572 | -40.67% | 0.547 / 0.106 |
| large / `dae2` | 4,297.992 → 4,256.530 | -0.96% | 9.896 / 37.143 |
| large / `dae2-optimizing` | 7,349.547 → 7,234.680 | -1.56% | 29.647 / 35.667 |
| tee / `dae2` | 46.634 → 3.781 | -91.89% | 0.071 / 0.013 |
| tee / `dae2-optimizing` | 249.312 → 203.725 | -18.29% | 1.660 / 0.751 |
| gc / `dae2` | 4.313 → 4.430 | +2.71% | 0.009 / 0.128 |
| gc / `dae2-optimizing` | 28.148 → 28.800 | +2.32% | 0.134 / 0.061 |
| entry / `dae2-optimizing` | 22.413 → 22.955 | +2.42% | 0.185 / 0.410 |
| pure / `dae` | 29.326 → 29.929 | +2.06% | 0.001 / 0.037 |
| pure / `dae-optimizing` | 41.484 → 41.914 | +1.04% | 0.061 / 0.259 |

Eight of 24 retained large rows observe foreign CPU activity; their small
movements remain diagnostic. All 120 retained small/active/GC/entry/store/tee/
flat/pure rows have no observed foreign CPU. The quiet GC, entry and pure costs
above remain open controls; a fast tee fixture does not resolve them. Five
alternating large RSS pairs have overlapping ranges: DAE2 medians 268,588 →
269,060 KiB; DAE2-O 314,740 → 292,140 KiB. Neither establishes a firm RSS change.

The fresh V14 verified-v133 oracle sweep uses one warmup, three alternating
samples and the same pinned small/large inputs and oracle hash documented
above. Pass-local medians and ratios are:

| Pass | Small Starshine / Binaryen ms | Ratio | Large Starshine / Binaryen ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| `dae` | 43.623 / 0.634 | 68.76× | 823.656 / 413.227 | 1.99× |
| `dae-optimizing` | 124.767 / 15.273 | 8.17× | 1,048.609 / 1,800.840 | 0.58× |
| `dae2` | 4.137 / 0.997 | 4.15× | 4,057.233 / 453.382 | 8.95× |
| `dae2-optimizing` | 13.446 / 3.112 | 4.32× | 7,531.072 / 1,704.020 | 4.42× |

Starshine pass MADs are 0.761/0.416/0.018/0.082 ms small and
5.313/2.610/13.791/34.137 ms large, in table order. Large optimizing size gaps
remain: DAEO +28,201 raw / +41,427 canonical bytes and DAE2-O +382,584 raw /
+422,019 canonical bytes versus v133. Agent judgment retains these as size-losing
parity gaps. Bounded runtime agreement does not prove these shapes win or sign
current source; aggregate renewal remains deferred until performance trials end.

The unchanged V14 active-tee output has a focused whole-command Callgrind
profile of 4,434,777,079 instructions. Self costs put first-use/intervening-local-
write queries at 34.89%, HOT live-node reads at 14.85%, checked unreferenced-node
assertions at 8.04%, node reads at 7.62%, capped child-use scans at 2.80% and
subtree effect scans at 2.14%. This includes decode, validation, lift/lower and
encoding; the percentages are not pass-local wall times. The tee benchmark's
nested phase timers attribute most optimizing work to the main SL scan;
inclusive pipeline totals must not be added to their child timers.

V18 therefore tests three private SL mechanisms: identity/revision/local-count
read-count snapshots, epoch-marked effect-scan scratch and memoized minimum
value-producing node IDs for the exact older-value predicate. All retain
mutation invalidation and tiny direct paths. The combined 24-fixture slice
passes; full/native builds, helper timings, enclosing shared-consumer controls,
size and RSS evidence are pending. Sources and benchmark contracts are in the
[SL reuse dossier](../binaryen/passes/simplify-locals/raw-lane-and-writeback.md#september-29-2026-mutation-scoped-query-reuse).
Reverse exact-literal DAE scans also reuse their existing graph snapshot's
indexed function types; heap-type/import-offset active fixtures cover it.

Artifacts under `.tmp/pass-perf-dae-priority-20260928/`:
`candidate-v14.json`, `build-v14.json`, `runtime-v14/result.json`,
`pairs-v14-*/result.json`, `memory-v14.json`, `oracle-v14-{small,large}/result.json`,
`tee-profile-v14.callgrind` and `tee-profile-v14-annotated.txt`.
Sources: [raw tee projection](../../../src/passes/dae2_raw_rewrite.mbt),
[exact capture checks](../../../src/passes/dae2_raw_tee_captures_wbtest.mbt),
[tee pipeline controls](../../../src/passes/dae2_raw_tee_perf_wbtest.mbt),
[immutable graph controls](../../../src/passes/dae2_graph_fields_perf_wbtest.mbt),
[reverse-signature fixtures](../../../src/passes/dae_reverse_signature_wbtest.mbt).


### V18 cache controls and bounded shared-consumer validation

V18 native `6ee7789427a8324f921c0d89333696eef385333b5e21de079e4014a2e7d79c88`
passes 12,877 default wasm-gc tests, 112 focused native tests and 62 native
benchmark cases. One failed benchmark setup read a child slot from a childless
root; that fixture access is corrected and the failed attempt remains in
`build-v18-first-attempt.json`. No production change was needed for that abort.

The 79-fixture runtime matrix includes the four DAE passes, all five SL variants,
SGO and optimizing inlining, plus four scalar NaN WAT frontend witnesses. All
2,730 outputs independently validate and 12,008 results/effects/traps match
original and verified v133 output; all binary-input V14/V18 bytes match.
This bounded check does not replace final affected-consumer aggregate renewal.

Native helper means (ten calibrated batches) isolate the mechanisms:

| Control | Reference → V18 | Scope |
| --- | ---: | --- |
| two unchanged count stages, width 4,096 | about 53.6 → 26.9 µs | helper median from the standalone diagnostic run |
| effect sweep, width 4,096 | 7.38 ms → 206.03 µs | masks/visit counts checked |
| leaf effect sweep, width 4,096 | 7.32 ms → 66.58 µs | childless roots included |
| independent later-root query, width 128 | 11.79 → 4.62 µs | one fresh minimum cache per query |
| older-stack hazard query, width 128 | 11.81 → 4.70 µs | exact true predicate retained |
| reverse nonconstant signatures, 256 types / 32 helpers | 39.45 → 32.02 µs | complete candidate scan/snapshot |
| reverse active signatures, same scale | 1.07 → 1.06 ms | near dispersion, no strong active claim |

Forced minimum caches cost more on tiny queries: 233.12 → 274.16 ns independent
and 368.57 → 451.21 ns hazard. Production keeps the direct path below 16 roots;
these forced helper costs are preserved rather than presented as tiny wins.
The enclosing tee pipeline benchmark measures 144.23 ± 1.21 ms. Causal V14/V18
pairs, RSS and a fresh verified-v133 sweep are complete below. Do not subtract
historical absolute benchmark times or infer broad Binaryen competitiveness
from these helpers.

Sources: [count controls](../../../src/passes/sl_get_count_cache_perf_wbtest.mbt),
[effect controls](../../../src/passes/sl_effect_scan_workspace_perf_wbtest.mbt),
[minimum controls](../../../src/passes/sl_value_order_minimum_perf_wbtest.mbt),
[signature controls](../../../src/passes/dae_reverse_signature_perf_wbtest.mbt).
Artifacts: `build-v18.json`, `candidate-v18.json`, `runtime-v18/result.json`,
`bench-dae-priority-v18.log`, `native-bench-v18-summary.json` and
`native-bench-v18-diagnostic.log` under the priority artifact directory.
### V18 complete enclosing evidence and remaining gaps

The production source fingerprint is
`de647bd3356cee3001c3ff1f73dda2c7fee82d4f3d34200fc6f996ce9131d447`
(264 compiler files), recorded by both fresh oracle sweeps. One warmup and
three alternating V14/V18 pairs use CPU 6, a 1.15 maximum reference bracket,
exact traced/untraced output hashes and independent validation. Across the
thirteen cohorts including the seven-pair pure renewal, 286 accepted timed
rows include 22 observations of foreign CPU activity: large DAE 9/24,
shared large 4/42, small DAE 4/24 and tee DAE2/O 5/12. The other 184 accepted
rows observe none. Rejected attempts stay in the artifacts; these diagnostic
cohorts do not establish a compiler-wide win.

| Pipeline control | V14 → V18 median ms | MAD before / after ms | Change |
| --- | ---: | ---: | ---: |
| small DAE | 42.952 → 41.159 | 1.298 / 0.122 | -4.17% |
| small DAE2 | 3.892 → 3.929 | 0.013 / 0.039 | +0.95% |
| small DAE2-O | 11.221 → 11.114 | 0.470 / 0.034 | -0.95% |
| large DAE2 | 3,898.518 → 3,888.051 | 0.627 / 1.580 | -0.27% |
| large DAE2-O | 6,749.551 → 6,752.515 | 4.499 / 1.633 | +0.04% |
| active tee DAE2-O | 206.742 → 142.062 | 3.956 / 0.632 | -31.29% |
| active tee SL | 193.715 → 135.647 | 0.503 / 0.224 | -29.98% |
| active tee SL nostructure | 198.906 → 136.593 | 2.288 / 4.185 | -31.33% |
| active mutable DAE2 | 11.372 → 11.693 | 0.130 / 0.031 | +2.82% |
| entry DAE2-O | 21.746 → 22.045 | 0.135 / 0.049 | +1.37% |
| initial pure DAE | 28.996 → 35.830 | 0.024 / 4.659 | +23.57% |
| renewed pure DAE, seven pairs | 30.877 → 30.569 | 0.523 / 0.617 | -1.00% |

Keep the initial pure cost and its dispersion beside the renewal. The remaining
SL tee variants improve 3.29–4.38%; small shared SL modes range -4.57% to
+2.25%, and large modes -2.11% to +0.33%. Shared SGO and optimizing inlining
have no material large gain; their detailed medians, MAD and small changes are
in `v18-paired-summary.json`. Reverse-signature reuse has no material large DAE
or active mutable gain. Small/entry/mutable costs remain controls for the next
candidate rather than being dismissed as safe representation differences.

Fresh v133 pass-local medians (CPU 6, one warmup, three samples):

| Pass | Small Starshine / Binaryen ms | Ratio | Large Starshine / Binaryen ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| DAE | 43.616 / 0.746 | 58.46× | 831.609 / 429.078 | 1.94× |
| DAEO | 124.685 / 15.243 | 8.18× | 1,090.860 / 1,793.310 | 0.61× |
| DAE2 | 4.546 / 1.023 | 4.44× | 4,169.155 / 461.853 | 9.03× |
| DAE2-O | 13.152 / 3.224 | 4.08× | 7,538.402 / 1,706.020 | 4.42× |

Absolute V14/V18 oracle sweeps are different cohorts, so their times are not
causal speedup evidence. Large optimizing size gaps are unchanged: DAEO adds
28,201 raw / 41,427 canonical bytes, DAE2-O 382,584 raw / 422,019 canonical.
All paired artifact bytes match. Five alternating RSS pairs give DAE2 medians
259,772 → 267,936 KiB (+8,164), ranges 259,060–281,340 / 256,496–279,796;
DAE2-O gives 292,152 → 292,348 KiB (+196), ranges 291,828–324,840 /
291,912–314,620. Overlapping ranges do not prove a memory win or regression.

Artifacts under the priority directory: `evidence-v18-driver.log`,
`v18-paired-summary.json`, `pairs-v18-*/result.json`, `memory-v18.json`,
`oracle-v18-small/result.json` and `oracle-v18-large/result.json`. They preserve
binary/input/oracle hashes, reference retries and timer scope. Long affected
aggregate renewal remains deferred until the bottleneck trials finish.


### V21 stacked-block runtime failure and V24 repair trial

V21 native `8f6158cc0d64f536401f116cfe9b1e9a7ea2bdc6a872e27c3b4ead27a7a5cf64`
passes 12,887 default tests, 122 focused native tests and 22 benchmark cases.
The new branchless-block controls compare complete DAE2 cores: wide depth-1
HOT/direct paths measure 9.93/1.70 ms, depth-16 paths 12.17/1.84 ms.
Checked/fresh wrapper factories include identical lift work: width 4,096
measures 1.52/1.42 ms. These helper observations do not establish an enclosing
compiler-artifact gain.

The expanded 92-fixture matrix validates 3,172 modules and records 13,776
observations, but V21 has four true semantic failure rows in SL full and
nostructure: an entry or earlier-written value stacked across a block overwrite
is replaced by the overwritten value. Original execution and verified v133
agree (entry plus 11, or constant 16); faulty SL returns 22. V18 has eight
failing baseline rows in these new witnesses, also including DAE2/O.
This supersedes any inference that V18's original 79-fixture matrix covered
these shapes. V21's expanded operand-flow fix repairs DAE2/O; its extra
1–4 canonical bytes in these witnesses are a correctness repair, not a size win.
Enclosing pairs/RSS/oracle renewal stopped before measurement.

The V24 trial guards earlier stacked reads and definitions in SL. Shared
source-order dependency queries use preserved execution order rather than
a wrapper's new allocation ID; this preserves both lowering and expanded CFG
anti-dependencies. A reduced IR fixture covers direct and indexed root paths;
pass and dispatcher fixtures cover all five SL policies and input ownership.
Thirty-four focused checks pass. Exact-owner DAE reverse graph reuse passes
active and unchanged controls, foreign-owner rebuild and commit-path fixtures.
Full/native/runtime and enclosing evidence remain pending; the release blocker
is open until native runtime confirmation.

Sources: [IR wrapper regression](../../../src/ir/hot_source_order_wrapper_wbtest.mbt),
[SL value regression](../../../src/passes/sl_stacked_block_order_wbtest.mbt),
[dispatcher regression](../../../src/cmd/sl_stacked_block_order_wbtest.mbt),
[reverse graph fixture](../../../src/passes/dae_reverse_graph_reuse_wbtest.mbt),
[graph controls](../../../src/passes/dae_reverse_graph_reuse_perf_wbtest.mbt).
Local replay artifacts are `build-v21.json`, `runtime-v21/result.json`,
`bench-dae-priority-v21.log`, `dae-reverse-graph-v22-red.log`,
`sl-stacked-block-v23-wrapper-corrected-red.log` and
`sl-stacked-block-v23-focused-green.log` under
`.tmp/pass-perf-dae-priority-20260928/`.

The first V24 full-suite attempt rejects broader computed value-order
substitution: it loses a forwarded old local read (7 becomes 99) and changes
nested-if/store-call parity fixtures. No expectations are weakened. The
corrected query uses an explicitly preserved earlier source position for an
extracted wrapper and retains allocation-order bounds for ordinary inserted
computations and existing consumer IDs. The three failed tests and rejected
attempt remain in `test-v24-first-attempt.log` and `build-v24-first-attempt.json`.

The remaining nested-if failure identifies a replacement conditional allocated
after its existing read consumer. Both one-armed-if paths now rewrite the
original conditional in place, attaching an else region through the existing
checked `hot_build_region` builder, newly exported. This preserves the node,
source position and label while avoiding a replacement conditional and then
region. The additive `.mbti` signature needs review. All 1,561 affected IR, SL
and OI checks pass; full/native and the expanded 95-fixture runtime matrix are
pending. The latter adds conditional writes, branch exits and the consumed
nested-result witness.


V24 completes 12,893 default / 251 focused native tests, info/fmt/native CLI,
30 native controls and README API sync. Candidate SHA-256 is
`5c22e42461f8968b6237a894272c548f18aa26c59078744372fd3d76e5562891`.
Matched fresh-wrapper controls retain their tiny-case cost/noise: 4.39 to
4.65 us, versus width 4096 at 1.57 to 1.46 ms. Reverse exact-owner graph
reuse reduces heavy nonconstant full rounds from 51.67 to 33.50 us; active
2.03 to 2.00 ms remains near dispersion. These controls do not establish an
enclosing pass improvement.

The expanded conditional matrix exposes an additional branch-exit problem:
V18 aborts on the reduced one-armed branch witness in DAE2-O, full SL and
SL-notee; V24 public execution falls back to the original void if, while
direct HOT verification rejects the result conversion. These are separate
from the eight baseline stacked-read semantic failures. V25's red-first
direct HOT and command tests preserve the original exit label as a void
block around the new result-if capture, so a taken branch skips assignment.
Non-branching result conversions retain the in-place source-position fix.
See `src/passes/sl_stacked_block_order_wbtest.mbt` and
`src/cmd/sl_stacked_block_order_wbtest.mbt`. The 110 focused checks plus
12,895 default / 253 native checks pass; 30 controls and the expanded
96-fixture matrix with seven fixed conditions are being renewed. Known V18
SIGABRTs are recorded as baseline tool failures, never candidate successes
or semantic matches. Candidate and oracle failures still reject evidence.

V25 evidence uses `/tmp/starshine-v25-frozen-evidence/src`, copied from the
saved candidate source and checked against all 1,295 source manifest entries.
This preserves the candidate/evidence identity while the separately requested
vacuum PR #9155 parity fix is developed. Historical V18 evidence and the
failed V21/V24 replays remain preserved; long aggregate fuzz renewal is deferred.


V25 bounded runtime completes: 3,302 independently validated modules and
25,018 fixed observations across 96 fixtures / eleven passes. Candidate and
verified v133 oracle match all original observations; eight V18 stacked-read
semantic-failure rows and six known baseline SIGABRT rows remain archived.
Candidate SHA-256 is
`3ffbd021ee11a012235592b07e495b5bff72b8f85b242ca485f09ee107daaa63`.
The first enclosing cohort preserves small DAE2/O regressions of
18.61%/7.18% (4.213 to 4.997 ms / 11.539 to 12.367 ms); DAE/O are
within dispersion at -0.53%/-0.66%. Large DAE2 byte drift rejects the
measurement guard before full enclosing/RSS/oracle completion. Do not
relax the guard or claim a new large-compiler speedup without classifying
that artifact-level change and measuring its relevant deltas.


The V25 large DAE2 drift is narrowed to code-section changes in 41 of 12,904
defined functions, totaling +458 bytes (6,114,805 to 6,115,263). Types, function
signatures and other non-custom sections match. This is not proof of semantic
equivalence or an accepted representation difference: preserve the guard and
inspect/replay these bodies before classifying the artifact change. The frozen
V25 scope JSON retains each changed body index, size and hash.


## October 1, 2026 small DAE pilot and release priorities

This bounded pilot starts from clean `d10a98e33d50a88060607a80b91a33243f1a2f62`
on `perf/small-dae-pilot-20261001`, preserving the original checkout and active
DAE2/O owner. Official Binaryen 133, native release/O2/mimalloc, Ryzen 7 8845HS
CPU 6; build excluded. Frozen manifests, commands, all samples, rejected timers
and source review live in `.tmp/dae-small-pilot-20261001/local-report.md`.
Small/large inputs are 192,893/6,211,596 bytes with SHA prefixes `06a9dd57ade8` /
`98189860f95b`. The sweep's automatic source identity describes its original
checkout; the separate frozen candidate/final manifests identify the worktree.

Small DAE has 45 functions, 1,715 direct callsites and 87 distinct edges.
Five baseline traced samples attribute 23.757 ms to the fixed loop and 21.934 to
selected lanes (21.409 reverse-literal is included); decode/encode are
0.709/0.390 ms. Callgrind finds 66 snapshots, 21 graph refreshes, 29 core rounds,
44 dependency builds, 35 module validations /1,575 body validations. Inclusive
validation 39.47%, recursive uniform scanning 30.67%, snapshots 12.87% and
slicing 12.26% overlap; they cannot be added. This confirms repeated work,
without proving validation removal safe.

[Shared operand recovery](../../../src/passes/dae_uniform_operands.mbt) now
uses the established contiguous zero-input/one-output-root proof during raw
recursive uniform forwarding; complex arguments retain full slicing and
complete control admission. Seven alternating untraced CLI pairs, median±MAD:
DAE **48.846±0.708→45.564±0.306 ms**, median paired **−4.93%**;
optimizing **118.603±0.641→101.407±0.418**, **−14.73%**.
Traced enclosing pairs improve 8.98%/14.59%; do not mix scopes.
Small DAE instructions fall 682,420,343→623,846,235, slice calls 12,106→4,899
and malloc calls 2,698,405→2,399,936. All snapshot, round, discovery and
validation counts above stay intact. Two RSS samples per side show no material
change. Frozen artifact bytes are identical before/after. A five-pair large
repeat is flat in paired pipeline time (−0.06%/−0.17%), with broad optimizing
spread and command +0.26%/+1.65%; no large speedup is claimed.

[Proof/fallback regressions](../../../src/passes/dae_uniform_operands_wbtest.mbt)
and [dispatcher tests](../../../src/cmd/dae_uniform_operands_wbtest.mbt) include
scalar/GC roots, mutation, recursion/export exposure, multi-value/effect barriers,
later invalid control and exact NaN payloads.
[Native controls](../../../src/passes/dae_uniform_operands_perf_wbtest.mbt)
compare 1/16 scalar roots with the frozen slicing reference and include a
computed fallback control. The two separate warm pipeline cases require copying
the pinned small artifact to `.tmp/dae-small-benchmark.wasm`; parsing is outside
timing, verification remains. `moon bench --package jtenner/starshine/passes
--file dae_uniform_operands_perf_wbtest.mbt --release --target native` runs this
dedicated lane. Default tests exclude benchmarks.

Fresh representative matrix: one warmup /three alternating samples; milliseconds
below are same-host medians. Untraced command and traced inner samples are
separate. Complete MAD/range/sample evidence is in `matrix-{small,large}`.

| Large pass | Command S /133 | Inner S /133 | Symmetric bounded canonical S−133 bytes |
| --- | ---: | ---: | ---: |
| DAE | 1715.2 /1466.5 | 966.5 /447.5 | −17,900 |
| DAE optimizing | 2098.3 /3151.0 | 1217.9 /2129.7 | +27,178 |
| DAE2 | 4815.4 /1496.2 | 3795.3 /499.7 | −114,486 |
| DAE2 optimizing | 7884.6 /2940.3 | 7211.1 /1814.6 | +99,251 |
| CoalesceLocals | 5356.3 /2225.9 | 4167.7 /1311.2 | +78,800 |
| SimplifyLocals | 2689.2 /2087.4 | 157.1 /1138.2 | +373,507 |
| OptimizeInstructions | 2994.2 /1220.0 | 146.0 /255.8 | +33,497 |

Large DAE optimizing explicitly uses the restricted typed-loop-safe batch and
raw cleanup: productive output does not prove oracle cleanup breadth.
All raw outputs are stable and match traced/untraced outputs; every pass changes
its strip-debug control. Canonical differences remain open parity gaps unless
separate contract/replay/quality evidence proves a Starshine win. Smaller bytes
and validation alone do not prove equivalence.

Size protocol correction: the sweep defaults to projected Starshine versus raw
oracle bytes. This table instead projects both sides with
[`canonicalizeWasm`](../../../scripts/lib/pass-fuzz-compare-task.ts): v133
parse/write, all features, strip debug, **no optimization passes**, at most eight
rounds, stable bytes or first writer encoding if growth persists. Both results
are independently validated. Current DAE2-O matches all four V83 artifact
hashes: raw 5,563,501/5,573,450, bounded canonical 5,686,688/5,587,437.
Writer growth adds 123,187/13,987 total bytes, 123,808/13,982 code-body bytes,
and 27,725/3,479 locals in 5,975/388 functions. Differential writer growth
109,200 turns the raw 9,949-byte win into the 99,251-byte deficit; this is real
body/capture legalization cost, not interchangeable encoding scopes.

Release priorities: existing P03 DAE2/O first (about 3.3/5.4 seconds inner
excess plus capture quality), P04 Coalesce (about 2.86 seconds), shared P12/P13
pipeline envelope and P05/P06 quality, then remaining P08 small DAE work.
SimplifyLocals/OptimizeInstructions optimizer non-pass diagnostics are
2,075/2,377 ms; lift/lower are included and explain only a small fraction.
Keep validation mandatory and isolate context/rebuild/check costs next.
Preset source schedules optimizing DAE and repeated Coalesce, but production
frequency is unmeasured. P08's next safe experiment is caller-local uniform
fact reuse within an exact unchanged graph epoch, with body/signature/exposure
invalidation proofs; compatible validation batching needs its own invariant.
Long fuzz, coverage and full release gates are deferred; this pilot does not
close release/parity blockers or change their gates.


Final pilot validation: all **13,283 bounded tests**, `moon info/fmt/check`, native
release rebuild, eight native cases, README/API sync and **987 fixed runtime
observations** pass. Rebuilt native SHA `2fcf0c810692b5b89a4d6565aed38c6d7e2fdc4d11d470bac81857aac64c98ec`
exactly matches the frozen measured candidate. No public API changes.
Native controls report mean±σ over ten batches: scalar1 **211.76±1.92→32.10±0.53 ns**;
scalar16 **2.53±0.059 µs→161.69±1.74 ns**. Computed fallback costs
**306.24±4.03→349.68±46.46 ns**; three short repeats are noisy, with the quietest
306.00→318.93 ns. Keep this bounded proof/wrapper cost explicit; no all-input
helper win is claimed. Separate warm pipeline means are **47.45±0.539 /111.96±0.998 ms**
(ten batches of three/one runs), with no comparable warm v133 baseline.
Plain NaN forwarding canonical bytes improve **66→61 versus v133 74**, with exact
payload replay; optimizing remains 62 versus 79. Fine exclusive candidate
validation/transform wall timers were unavailable; use instruction attribution,
not inferred milliseconds. Aggregate fuzz/coverage/full release signoff and
independent human code review remain unavailable/deferred for this pilot.


## Callgrind collection scope and allocation counters

`--collect-atstart=no --toggle-collect=<exact-nonrecursive-worker>` bounds
instruction events, but does not bound every call count in the shared call
graph. A callee invoked inside and outside the collected scope can retain all
calls while its instruction cost counts only collected executions. A local
four-call `malloc` probe, with two calls inside the toggled wrapper, reports
`calls=4` with the instruction cost of two executions. Retained source, executable
and raw dump: `.tmp/large-pass-hotspots-20261001/callgrind-scope-probe.*`.

Consequently, summing incoming `mi_malloc` edges from a toggled profile is not
an exclusive scoped allocation count. Label those totals as mixed shared-call-site
counts, and do not turn them into scoped allocation percentages. Full-command
collection remains suitable for whole-command totals. A directly toggled leaf
worker's own allocation site has no off-scope invocations; its direct edge can
support that worker's allocation count. Public wrapper allocations outside a
new worker must still be accounted for. Preserve instruction/counter scopes in
manifests and distinguish calls, allocated bytes and peak live objects.

The October 2 DAE2 proof retains its scoped instruction reduction (19.60%) and
source-order factory reduction. Its initial 2.93% **scoped allocation** claim is
superseded by this accounting correction. The October 1 OI full-command
instruction/allocation comparisons retain their full-command scope.

## October 2, 2026: large four-pass checkpoint and timer scopes

A renewed fixed-fixture matrix uses production source `971cd0b682259297e438d2046b330feb88fdbe46`
(native SHA-256 `833e27c8881d85daa673998518b4093721ecb78dfe61dfa19e1b34ea376c9243`),
verified v133 oracle SHA-256 `8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`,
and the 6,211,596-byte / 12,904-function compiler fixture SHA-256
`98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
Moon0.1.20260920/moonc0.10.14+7d59c7ec9, native release GCC14.2/O2/mimalloc,
Bun1.4.2 and wasm-tools1.251 remain the saved toolchain. Ryzen7 8845HS CPU6,
performance governor, build outside timing, shared heavy lock, one warmup and
three alternating same-host samples per side; temperature/turbo uncontrolled.
Every measured row records foreign activity. These are observed diagnostic
cohorts, not a quiet-host release signoff, and supersede older timing leads only
for this fixture/source/scope. Preserve original cohorts and rejected trials.

Normal fresh-process CLI with warm filesystem (median ± MAD milliseconds):

| Pass | Starshine | Binaryen133 | Ratio | Absolute excess ms | Raw bytes S / B |
| --- | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 4303.065 ± 16.192 | 1195.969 ± 12.683 | 3.60× | 3107.096 | 6115221 / 6232586 |
| DAE2 optimizing | 7460.968 ± 97.709 | 2423.250 ± 6.537 | 3.08× | 5037.718 | 5563501 / 5573450 |
| CoalesceLocals | 5056.280 ± 7.271 | 1937.773 ± 23.110 | 2.61× | 3118.507 | 5706503 / 5627625 |
| OptimizeInstructions | 2398.466 ± 11.892 | 973.832 ± 2.667 | 2.46× | 1424.634 | 6205998 / 6172971 |

Starshine ranges: DAE2 4286.873–4321.569, optimizing7363.259–7572.342,
CL5049.009–5074.773, OI2386.574–2473.927 ms. Oracle ranges:
1183.286–1236.917 / 2416.713–2484.855 / 1914.663–2024.695 /
955.831–976.499 ms. Commands are `taskset -c 6 <frozen-native> --<pass>
--out <output> <input>` and `taskset -c 6 <verified-wasm-opt> --all-features
--<pass> <input> -o <output>`; optimizing maps to `--dae2 --simplify-locals
--vacuum`. It is distinct from DAE and dae-optimizing. All outputs validate,
every side is deterministic across normal/debug samples, and outputs differ
from the input: this is actual aggregate transformation activity, not proof that
every function takes an active path. Existing admission guards remain visible.

Independent three-sample timer diagnostics (milliseconds, not normal CLI):

| Pass | Starshine named timer median ± MAD | Binaryen debug timer median ± MAD |
| --- | ---: | ---: |
| DAE2 | 3519.933 ± 80.675 | 469.100 ± 8.292 |
| DAE2 optimizing | 6556.497 ± 58.139 | 1851.615 ± 9.856 (per-row sum of three top-level pass timers) |
| CoalesceLocals | 4171.480 ± 157.309 | 1226.080 ± 1.880 |
| OptimizeInstructions | 86.298 ± .212 | 260.895 ± .578 |

These scopes differ. Starshine's DAE2 timer includes lift/lower and mandatory
module verification; HOT named function timers omit wrapper/guard/encoding
cleanup. Binaryen debug=1 times top-level passes with verification outside those
timers and serial function-pass execution, unlike normal worker batching.
See [v133 PassRunner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/pass.cpp#L854).
Debug command wall must never replace normal command wall; no cross-scope speed
parity conclusion follows from OI's fast named timer. Separate Starshine main
pipeline medians are 3539.113 / 6575.991 / 4190.477 / 1769.863 ms. Filesystem
warmup is not an in-process resident warm-pass benchmark or a cold-cache run.

Optimizing diagnostic owners include DAE2 analysis1616.779 ms (lift689.303,
dependencies851.913), rewrite1004.150 (lift281.288, lower540.833), finalize609.362
(including validation362.493), and suffix function wrappers2164.583. These are
nested inclusive scopes; do not add children and parents or force medians into
an exact total. Complete cleanup instruction profiles and single-change cohorts
are in the [DAE2 dossier](../binaryen/passes/dae2/starshine-strategy.md#october-2-2026-complete-optimizing-cleanup-instruction-attribution)
and [Vacuum gate evidence](../binaryen/passes/vacuum/starshine-hot-ir-strategy.md#october-2-2026-bound-indexed-tag-wrapper-admission-before-deep-scans).
OI's 1769.863 ms pipeline versus86.298 ms named transform leaves substantial
lift/lower and encoding-cleanup work. Its code-section837.278 ms includes
function806.669 ms; final CLI validation289.639, encoding168.389 and post-encode
validation43.791 are separate. The remaining pipeline remainder is not an
exclusive direct measurement of `oi_cleanup_module_encoding`; profile that
source owner before proposing another validation change.

Prioritize optimizing's ≈5.04s command gap, shared DAE2/CL CFG/lift/lower and
CL's ≈3.12s gap, then OI's ≈1.42s envelope by actual frequency and safety cost.
CL's historical label-row copy edge is a real depth-squared source pattern but
only≈.129b inclusive profile instructions; it does not outrank the large CFG/
lower/interference owners. No mandatory verification or optimization coverage
may be removed. Raw size and canonical size remain distinct: optimizing raw is
9949bytes smaller but the preserved bounded canonical gap is99251bytes larger.
The normalizer contract, byte gaps and release gates remain active.

Artifacts: `.tmp/large-pass-hotspots-20261001/large-matrix-20261002/{result,rows}.json`,
`measure-large-matrix.py`, all command stderr/wasm rows, frozen manifests and
local report. This source checkpoint precedes the separate unchanged-recurrence
row pilot; that pilot needs its own before/after evidence. No long fuzz,
coverage/full CI gate or independent-agent review was run for this checkpoint.


## October 2, 2026: main read-index checkpoint

This subsequent checkpoint follows the main integration and
[initialized read-index reuse](../binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md#october-2-2026-retain-initialized-continuation-read-indexes).
Base commit7f8cc5b3b plus the recorded dirty pilot uses final native SHA-256
`75dd44c3bb8e211724989144bccb550bd1316cbb880203d3b630f9274d7e2ef7`;
production read-set source SHA-256
`deee264cdbffb154f6973c1d0d7bf88025814204774472707bd16c2920a24263`.
Toolchain, input, verified v133 oracle, CPU6 and command mappings match the
preceding checkpoint. Build is excluded; one warmup and three alternating
normal fresh-process samples per tool/pass, tracing and Binaryen debug unset.
These are filesystem-warm CLI times, not cold-cache or resident warm-pass times.
All measured rows record foreign CPU activity, including a large unrelated
compile during the final CL row. Do not interpret this as quiet-host signoff
or estimate this single fix from differences against the earlier matrix.

| Pass | Starshine ms ± MAD | Binaryen133 ms ± MAD | Ratio | Excess ms | Raw bytes S / B |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 4403.601 ± 33.059 | 1292.056 ± 44.009 | 3.41× | 3111.545 | 6115221 / 6232586 |
| dae2-optimizing | 7238.023 ± 91.216 | 2428.617 ± 16.123 | 2.98× | 4809.406 | 5563501 / 5573450 |
| coalesce-locals | 5057.458 ± 65.304 | 2030.738 ± 28.268 | 2.49× | 3026.719 | 5706503 / 5627625 |
| optimize-instructions | 2631.101 ± 8.543 | 1032.556 ± 3.744 | 2.55× | 1598.544 | 6205998 / 6172971 |

Ranges, n=3 each:

- dae2: Starshine4370.542–4514.779; oracle1244.269–1336.065 ms.
- dae2-optimizing: Starshine7146.807–7405.003; oracle2412.494–2460.961 ms.
- coalesce-locals: Starshine4992.153–6781.249; oracle2002.470–2121.866 ms.
- optimize-instructions: Starshine2622.558–2718.422; oracle1002.674–1036.301 ms.

All normal outputs validate, are deterministic and differ from input; their
hashes match the earlier quality checkpoint. Activity is aggregate: unchanged
and guarded functions still exist and no work coverage is reduced. No fresh
inner/debug matrix was run here; the earlier diagnostic scopes retain their
source/date and must not be relabeled current. The independently paired pilot
measures the fix itself: complete cleanup instruction work −7.85%, normal
optimizing paired median −2.72% under contention, traced inner wall inconclusive.

Current command priorities by absolute excess remain optimizing≈4.81s,
DAE2/shared CFG/lift/lower≈3.11s, CL≈3.03s, OI≈1.60s. The raw optimizing
9,949-byte win and preserved canonical99,251-byte deficit are separate.
CL and OI raw deficits are78,878 and33,027bytes respectively; historical
canonical deficits are separate normalization evidence, not these raw rows.
No allocation/RSS saving or general speed/output parity is asserted.

Artifacts: `.tmp/large-pass-hotspots-20261001/large-matrix-main-readset-20261002/`,
`measure-main-readset-matrix.py`, final/measured native manifests and
`readset-copy-final-source-review.json`. The final rebuild differs from the
paired pilot executable4565f45c… in44 text bytes within command repro-note
routines; all read-set method machine-code bytes are identical. Their hashes
remain distinct. Current four-pass numbers use the exact final executable.


### Subsequent main suffix-storage pilot

The [independent suffix storage pilot](../binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md#october-2-2026-reuse-unchanged-pure-and-effectful-suffix-storage)
uses base main7b9a83c82 native75dd44c3… and candidate331bf0d4… with the same
large input, oracle, flags, CPU6 and toolchain. One warmup/five alternating normal
optimizing CLI samples give6383.282±14.001→6374.044±3.062ms; v1332277.007±5.074
(median±MAD). Ranges6328.438–6397.283 /6342.562–6633.037 /2271.933–2375.374ms;
paired −.10% is within spread. All rows flag foreign activity. Newer lower host
bands must not be credited to this fix against older unpaired cohorts.
Separate traced inner medians5571.157±11.261→5577.765±35.657ms are inconclusive.

Same-scope complete cleanup instructions20,910,594,832→20,626,352,801 (−1.36%);
source/frozen native controls establish omitted unchanged row/control copies.
The baseline profile remains labeled with its original4565 native hash; the
current75dd baseline has identical pass machine code and only off-scope command
repro-note changes. Candidate profile completes under300s and validates exact
output. Neither nested edge sums nor mixed call counters are allocation/RSS
percentages. Compiler bytes and the prior canonical protocol remain unchanged.
Artifacts: `.tmp/large-pass-hotspots-20261001/suffix-storage-*`,
`dae2-cleanup-suffix-storage-*`, commands, manifests and local report.


## October 2, 2026: main bounded-middle checkpoint

Base main8fb4ebd30 plus the independently tested bounded-middle pilot; exact
native SHA256 `366ed01cb3ba34077004c9d830b28d8f11b5ae807a12dc5894a3b7520e720d18`.
The input, verified v133 oracle, features, toolchain, CPU6 and command mappings
match the preceding main checkpoint. One warmup/three alternating normal
fresh-process rows per tool/pass, tracing/debug unset, build outside timing.
These are filesystem-warm CLI measurements, not cold-cache or resident pass
measurements. Every row records foreign activity; the newer host band is not
causal evidence for a particular fix. Earlier matrices retain source/date/scope.

| Pass | Starshine ms±MAD | Binaryen133 ms±MAD | Ratio | Excess ms | Raw bytes S / B |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3931.213±35.727 | 1106.453±0.282 | 3.55× | 2824.760 | 6115221 / 6232586 |
| dae2-optimizing | 6336.743±7.430 | 2316.345±6.822 | 2.74× | 4020.397 | 5563501 / 5573450 |
| coalesce-locals | 4536.558±17.041 | 1756.782±4.067 | 2.58× | 2779.776 | 5706503 / 5627625 |
| optimize-instructions | 2161.347±0.552 | 911.040±2.729 | 2.37× | 1250.307 | 6205998 / 6172971 |

Ranges, n=3 each:

- dae2: Starshine3817.563–3966.941; oracle1106.171–1107.785ms.
- dae2-optimizing: Starshine6329.313–6355.548; oracle2309.523–2359.910ms.
- coalesce-locals: Starshine4509.125–4553.599; oracle1747.945–1760.849ms.
- optimize-instructions: Starshine2160.794–2246.462; oracle908.311–915.377ms.

All outputs validate, differ from input, are deterministic and match previous
output hashes. Transformation activity is aggregate; some functions remain
unchanged or guarded. No fresh inner/debug matrix was run for these four passes.
The optimizing command remains≈4.02s behind, plain/shared CFG/lower≈2.82s,
CL≈2.78s, OI≈1.25s. Prioritize those absolute costs rather than ratios alone.
Raw optimizing9,949-byte advantage is distinct from the preserved symmetric
bounded-canonical99,251-byte deficit. CL/OI raw deficits78,878/33,027 B are not
their historical canonical deficits. Broad speed/output parity remains open.

The [independent bounded-middle experiment](../binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md#october-2-2026-bound-dupable-copy-middle-discovery)
uses native331bf baseline and366ed candidate, five normal alternating pairs:
6346.596±14.516→6319.850±43.716ms, oracle2283.413±7.101ms. Paired−.44% remains
within spread under contention; separate traced inner5538.991±9.872→
5502.523±6.937ms is diagnostic only. Complete cleanup instructions fall2.42%,
20,626,352,801→20,126,748,368. Across three independently reviewed main fixes,
root instructions fall11.30% from22,691,343,936; neither nested edge sums nor
added wall-time percentages nor allocation/RSS savings are asserted.
Native repeated-use controls improve≈40–45%, but the later loop remains
quadratic and the repeated active1 control costs+10.30ns. Both remain active.

Artifacts: `.tmp/large-pass-hotspots-20261001/large-matrix-main-pure-middle-20261002/`,
`measure-main-pure-middle-matrix.py`, `pure-middle-*`, `dae2-cleanup-pure-middle-*`.
Manifests retain exact source/dirty state, executable/oracle/input hashes,
commands, runtime features, all rows, profiles and compact-import replay notes.


### Subsequent cache rejection and memory checkpoint

The [per-flat statement cache](../binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md#october-2-2026-rejected-per-flat-statement-boundary-cache)
is rejected: complete cleanup instructions+0.175%, normal CLI paired−.108%
within spread, peakRSS flat, despite wide synthetic wins. Its code is archived
and removed from main; accepted source remains699648988/native366ed01c.
Five normal baseline/oracle samples, one warmup, give6345.666±13.890 /
2288.298±8.772ms, and peakRSS294448±132 /153104±4KiB (median±MAD). Every row
flags foreign activity. These are separate cohorts from the four-pass matrix;
no trace/debug timer or raw/canonical byte scope is relabeled. Kernel wait4
measures exact per-process CPU/RSS after posix_spawn/taskset; the unavailable
GNU time attempt is preserved as failed evidence before any accepted timing.
No peak-memory win or phase-specific RSS cause is established.

A [fresh complete CL module profile](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-complete-main-module-pass-attribution)
collects49,112,542,755 instructions; CFG lane35.333b includes lower10.895b and
interferences3.274b. Lift local-access conflict3.437b and object-drop exclusive
6.645b expose larger candidates than tee/control guards. All nested costs overlap;
old partial profiles remain historical. Parsing/final CLI validation/encoding
are outside this collection. No new CL timing improvement is claimed.


## October 2, 2026: main lowering storage checkpoint

The [lowering ownership and evidence](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-retain-unchanged-lowering-cleanup-rows)
reduces complete CL instructions1.309% and optimizing cleanup.094% with exact
bytes, without new collections or omitted verification. Candidatefd2abde6…,
baseline366ed01c…, fixed6,211,596 B compiler and verified v133; one warmup/five
alternating normal commands on CPU6, all foreign-activity flagged:

| Pass | S before median±MAD ms | S after | B133 | Paired change |
| --- | ---: | ---: | ---: | ---: |
| CL |4595.264±46.602|4763.210±84.057|1763.781±9.522|+.715%|
| DAE2-O |7495.994±120.762|7162.457±266.091|2521.723±62.640|−2.459%|

CL has no command win; optimizing's observed gain overlaps spread. The higher
host band does not establish a regression from earlier accepted commits.
Separate traced timers are diagnostic. Neither peakRSS improves measurably;
the active-tee native cost+30.90ns is retained. Source/input/binary/option hashes,
full ranges, RSS rows and runtime import normalization are in the existing pass
dossier/local report. A post-profile stale verifier-path error is recovered by
normal-exit logs and actual output equality, not by accepting partial data.
13,338 bounded tests and672 fixed observations pass; bytes stay exact, canonical
optimizing+99,251 B and all release aggregate/coverage/full gates remain open.
Plain DAE2/OI keep the preceding matched matrix's exact older binary/date/scope;
these two renewed rows do not relabel the earlier four-pass matrix.


## October 2, 2026: main weightless member checkpoint

The [bounded CL search](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-stop-weightless-member-searches-after-the-first-valid-slot)
reduces the real member worker20.04% and complete CL instructions.2925%, with
no new storage or changed bytes. Five normal paired commands have no clock win;
weighted63's repeated+.34µs cost stays visible. This is not full parity signoff.
Current frozenf111fea4… follows ef3e10438/fd2abde6… lowering storage. Fixed
6,211,596 B compiler SHA98189860… and verified v133 SHA8f25e9fd…; CPU6,
release GCC14.2/O2/mimalloc, build outside timing, one warmup/n3 alternating
normal fresh-process commands with warm filesystem:

| Pass | Starshine median±MAD ms | Binaryen133 | S/B | Raw S / B bytes |
| --- | ---: | ---: | ---: | ---: |
| dae2 | 5008.383±313.869 | 1296.329±56.102 | 3.86× | 6,115,221 / 6,232,586 |
| dae2-optimizing | 7436.486±351.151 | 2504.557±3.812 | 2.97× | 5,563,501 / 5,573,450 |
| coalesce-locals | 5065.838±171.368 | 2629.070±611.023 | 1.93× | 5,706,503 / 5,627,625 |
| optimize-instructions | 2498.174±22.068 | 994.902±3.777 | 2.51× | 6,205,998 / 6,172,971 |

All rows flag foreign activity. Particularly broad Binaryen CL spread makes its
1.93× ratio fragile; do not call it a causal improvement from earlier cohorts.
The same-cohort normal excess medians are optimizing4931.929ms, plain DAE2
3712.054ms, CL2436.768ms (broad B spread), OI1503.272ms. DAE2/O are separate
from DAE/O. Full ranges, raw rows, exact process wait4 CPU/peakRSS and command/
input/tool hashes are in `.tmp/large-pass-hotspots-20261001/large-matrix-main-member-zero-20261002/result.json`.
No current matched inner matrix is implied; older timers retain original scopes.

All four output hashes remain exact, preserving earlier fixes/V83. Raw optimizing
S−9949 B does not close the separately verified bounded canonical+99,251 B gap.
Optimizing peakRSS n3 S294444/B155148 KiB leaves about136MiB; no phase cause is
proved. Current13,341 bounded tests, eight native controls/two weighted repeats
and348 fixed observations pass. The build's full/tmp failure is recovered with
repository-local compiler temp storage; timing begins only after successful gates.
Quiet matched clocks, size families, larger shared pipeline/CL/OI owners and full
aggregate/coverage/CI remain release blockers. No long fuzz campaign was run.


## October 2, 2026: main scalar-clique checkpoint

The [small clique proof](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-scalar-words-for-small-single-word-cliques)
reduces complete CL instructions.39355% and the nonrecursive clique entry17.85%
with no new allocations or changed bytes. Main1c8485122/f111fea4… baseline,
candidate ddc2b774…, fixed compiler SHA98189860…, verified v133 and CPU6.
Five alternating normal commands: S5044.567±55.049→5053.472±109.127ms,
B2036.637±15.455ms, paired+1.282%; foreign CPU activity on every row, no
command-speed or RSS win. Traced inner rows are independent and inconclusive.
Pinned native repeats confirm small single-word savings while wide fallback
+10.47ns remains.13,346 tests/360 fixed observations pass; raw CL bytes exact.
Previous four-pass matrix above remains1c/f111, not this candidate. Larger
shared DAE2/O/CL/OI owners, canonical byte gaps and aggregate/CI/coverage remain
open; no long fuzz campaign. Full commands/ranges/hashes/source/native proof
are in the existing dossier and local scalar-clique report.


## October 2, 2026: main binary-spill storage checkpoint

[Spill storage proof and measurements](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-retain-unchanged-binary-constant-spill-cleanup-storage)
reduce complete CL work.81535% and the nonrecursive spill entry61.49%, with
unchanged output and no new collection/API. Main db1412a75/ddc2b774… baseline,
candidate08382360…, same6.21MB compiler, verified v133 and CPU6. Five normal
alternating pairs: CL5289.570±115.064→4980.679±60.348ms/B1990.480±16.113,
paired−3.457%; optimizing7301.133±116.990→7379.340±56.890/B2559.307±34.185,
paired+.868%. Foreign activity on every sample; optimizing has no clock win,
CL's observed gain is not quiet-host signoff. Separate traced timers overlap;
peakRSS is flat. All13,352 wasm-gc tests,12 native controls and 1224 fixed observations
across423 validated modules pass with exact bytes. Prior plain/
OI matrix keeps1c/f111 source provenance. Full release gates and canonical byte
quality remain open; larger shared lift/validation owners still take priority.


## October 2, 2026: main checked lift-read checkpoint

[Checked arena read proof](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-checked-arena-reads-for-lift-local-conflicts)
records actual native boundary removal with unchanged admission/traversal and no
new object/cache/API. Main c2aec5040/native08382360… baseline, candidate e57d9b45…;
same6.21MB compiler SHA98189860…, verified v133, CPU6/GCC14.2/O2/mimalloc.
Complete CL instructions47,745,254,152→47,506,930,728 (−0.49916%);
nonrecursive conflict entry−6.7014%. Corrected getter symbol supersedes the earlier
empty/self0 row; nested costs are not additive or allocation measurements.

One warmup/n5 alternating normal fresh-process commands, median±MAD ms:
DAE2 3816.061±7.324/B1120.057±8.250; CL4486.629±9.747/B1778.481±7.655;
optimizing6589.943±199.950/B2440.277±121.585. Every row flags foreign activity;
paired changes−0.216/+0.190/+0.853%, no causal command win. Full ranges and
independent traced diagnostics are in the existing dossier/local report.
OI retains its earlier four-pass source. Raw hashes/V83 unchanged; bounded
canonical optimizing+99,251 B remains distinct from raw−9,949 B.

PeakRSS has no measured win. Plain's initial n5 median+9736KiB is retained;
one-warmup/n3 alternating normal repeat268160±84→268196±76KiB shows lower
memory modes on either binary. Phase/lifetime cause and optimizing≈138MiB excess
remain open. Full13,355 default tests plus subsequent new dispatcher1/1,
twelve native controls and447 validated modules/1296 fixed observations pass;
no .mbti change. Manual review, no independent agent. Broader current matrix,
quiet clocks, canonical gaps and final aggregate/CI/coverage remain release work.
No long fuzz campaign. Full reproducible local report:
`.tmp/large-pass-hotspots-20261001/main-lift-access-fields-performance-20261002.md`.


## October 2, 2026: current DAE2 dependency attribution

[Current source-backed breakdown](../binaryen/passes/dae2/starshine-strategy.md#october-2-2026-current-large-dependency-cost-after-checked-lift-reads)
uses main ddd0053b9/e57d9b45… and the same pinned compiler input. One bounded180s
delayed dependency-wrapper capture exits normally with exact validated output.
Root9,908,757,394 instructions; direct CFG5,224,349,718, read sources2,018,098,328,
entry proof789,531,719. Nested verification/region/query edges are not additive;
shared off-scope allocator counts are omitted. This is attribution, not a new
before/after claim or wall-time measurement. Existing predecessor compression is
linear; prospective wide-edge symmetry indexing needs degree/work/allocation
measurement before implementation. Larger storage/lifetime owners remain active.


## October 2, 2026: main compact lowering-count checkpoint

[Compact counts and ownership proof](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-use-compact-counts-throughout-lowering)
removes unused use-site/local overlays while retaining complete count/transform/
verification work. Main86fc89961/e57d9b45… baseline, candidate c93901ee…;
fixed compiler SHA98189860… and verified v133 SHA8f25e9fd…. Complete CL
instructions47,506,930,728→45,745,669,624 (−3.7074%), nested lower−19.6033%.
Bounded300s profile exits normally with exact validated output; no allocator-byte
or summed nested-phase claim. Actual native full-builder call1→0, compact call1.

CPU6/native GCC14.2/O2/mimalloc; build outside timing, one warmup/n5 alternating
normal CLI commands, median±MAD milliseconds:

| Pass | Starshine | Binaryen133 | S/B |
| --- | ---: | ---: | ---: |
| dae2 | 3768.526±15.606 | 1121.804±1.798 | 3.36× |
| dae2-optimizing | 6320.913±8.961 | 2410.442±21.913 | 2.62× |
| coalesce-locals | 4459.136±34.020 | 1790.915±9.380 | 2.49× |
| optimize-instructions | 2278.473±71.614 | 1028.363±61.973 | 2.22× |

Every normal row flags foreign CPU activity. Paired changes−2.181/−1.584/−2.692/
−2.996% respectively, corroborated by reduced CL work; not quiet-host1× signoff.
Older four-pass1c/f111 measurements above retain their source/date/scope.
Separate traced diagnostics n3 plain/n1 others do not renew a matched B inner
matrix. RSS essentially flat; memory modes and optimizing≈138MiB excess remain.
Raw hashes/V83 unchanged; canonical byte gaps remain distinct and active.
All13,360 default tests, six native controls/explicit release repeat and628
validated modules/1824 fixed observations pass, no API change or long fuzz.
Exact range/flags/source/output hashes/rows in the dossier and local
`.tmp/large-pass-hotspots-20261001/main-lower-use-counts-performance-20261002.md`.
Final aggregates/CI/coverage and the1× target remain open.


## October 2, 2026: main direct result-stack checkpoint

[Complete result-stack evidence](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-avoid-temporary-arrays-in-lower-result-stacks)
uses main43da34011/c93901ee…→c4165396…, same6.21MB compiler/v133/CPU6.
Actual owned-result native call1→0; complete CL instructions−.586449%, nested
lower−3.706198%. All13,362 tests, six release controls,660 validated modules/
1920 observations and API sync pass; raw hashes/V83 unchanged.

Normal one-warmup/n5 alternating median±MAD ms; latest CL repeat is separate
from the initial four-pass cohort retained in the dossier:

| Pass | S | B133 | S/B |
| --- | ---: | ---: | ---: |
| DAE2 | 4000.468±71.176 | 1174.730±32.875 | 3.41× |
| DAE2-O | 6351.003±35.572 | 2335.604±8.912 | 2.72× |
| CL repeat | 4351.828±26.160 | 1787.193±4.291 | 2.44× |
| OI | 2215.836±6.229 | 928.787±3.496 | 2.39× |

Initial paired changes+2.102/+.792/+2.996/+.274%; justified CL repeat−1.042%.
Foreign activity on every row, no consistent/quiet-host clock claim. RSS is not
a win: repeat CL+4076KiB median, both binaries also reach≈249MB initially;
plain/CL pool/lifetime modes and optimizing≈138MiB excess remain unexplained.

Independent matched one-warmup/n3 tracing/debug1 timers and exact traced-vs-normal
hash checks renew named scopes: DAE2 S3005.985/B431.100ms; CL3359.694/B1137.040;
OI79.059/B239.510; OO S5480.129, B explicit DAE2/SL/Vacuum per-row sum recorded
locally. Binaryen debug1 serializes function passes and adds verification outside
timers; Starshine module and narrow HOT timers include different surrounding
work. Never compare debug command wall to normal CLI or infer OI overall parity
from its narrow timer. Full raw rows/ranges/phase/bytes/RSS/source/binary hashes:
`.tmp/large-pass-hotspots-20261001/main-lower-result-stack-performance-20261002.md`.
Next CL lead is unused full use-def discovery; DAE2 dependency/lift, optimizing
cleanup and OI command envelope remain priorities. Canonical quality,1× and
final aggregate/CI/coverage gates remain open.


## October 2, 2026: main block-only Coalesce liveness checkpoint

[Constructor proof and measurements](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-build-coalesce-liveness-without-unused-use-site-graphs)
freeze maind4541bb83/c4165396…→02637b4c… with the same large input/v133/CPU6.
CL normal one-warmup/n5 alternating median±MAD4431.467±34.244→4214.653±25.652ms,
B1789.610±17.290ms; paired−4.8926%, remaining2.36× command ratio. Every row
flags foreign activity. Complete CL instructions45.477b→43.437b (−4.4869%)
corroborate reduced work. Traced n1 module3390.306→3212.553ms is diagnostic;
no renewed B inner comparison or quiet-host/parity claim. Other pass numbers
above retain c416 provenance. RSS median+4200KiB has overlapping low/high modes;
no memory win.13,367 tests/169 validated modules/492 observations and API sync
pass; one narrow public constructor, complete graph/validation semantics and
exact raw hashes retained. Canonical quality and aggregate/release gates remain.
Local report: `.tmp/large-pass-hotspots-20261001/main-cl-block-liveness-performance-20261002.md`.


## October 2, 2026: main effect-only lowering checkpoint

[Demand and ownership evidence](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-separate-effect-only-lowering-from-ordering-demand)
freeze main5ec1e3556/02637b4c…→e7529ee2… on the same compiler/v133/CPU6.
Normal n5 alternating median±MAD milliseconds:

| Pass | Starshine | B133 | Ratio |
| --- | ---: | ---: | ---: |
| DAE2 | 4244.746±50.739 | 1291.718±16.741 | 3.29× |
| DAE2-O | 7299.012±80.794 | 2594.935±29.086 | 2.81× |
| CL | 4601.658±62.996 | 2083.079±6.779 | 2.21× |
| OI | 2633.724±30.778 | 1034.079±3.749 | 2.55× |

Paired changes−.533/−2.380/−4.372/−2.785%; every row flags foreign activity.
Complete CL instructions−2.439308%, nested lower−15.083062% corroborate reduced
work; lower full factories4565→297 with4083 effect-only builds. No summed nested
phase, allocation-byte or quiet-host1× claim. Raw hashes/API/V83 retained;
13,374 tests/692 modules/2016 observations pass. Native carried fallback costs
+140ns/+6.93µs remain open. RSS modes/optimizing excess and canonical quality
remain. Independent traced n1 scopes are diagnostic; matched B inner values
above retain their earlier c416 source and dates. Exact commands/source/binaries,
normal/traced range/RSS rows and accepted profile:
`.tmp/large-pass-hotspots-20261001/main-lower-demand-effects-performance-20261002.md`.


## October 2, 2026: main checked payload query checkpoint

[Source, controls and consumer evidence](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-checked-scalar-reads-for-exact-payload-queries)
freeze mainbc6f6ea3b/nativee7529ee2…→6e22e72f… on the same6,211,596B compiler,
verified v133 and CPU6. Build excluded; normal n5 alternating after one warmup,
fresh processes/warm filesystem. Median±MAD milliseconds:

| Pass | Starshine normal CLI | B133 normal CLI | Ratio |
| --- | ---: | ---: | ---: |
| DAE2 | 4081.539±83.697 | 1226.426±27.000 | 3.328× |
| DAE2-O | 6993.348±74.721 | 2508.565±40.995 | 2.788× |
| CL | 4535.650±60.614 | 1978.689±32.228 | 2.292× |
| OI | 2443.540±37.293 | 979.768±2.775 | 2.494× |

Paired changes+1.440/−1.342/−1.715/+1.650%; every row flags foreign activity.
No command-level win or1× signoff. Complete CL instructions−.131286%, nested
payload verification−22.203%; getters disappear in all three actual payload
readers.24 isolated native lanes retain the original selector boundary; initial
eight combined controls were not a faithful baseline.13,379 tests/708 modules/
2064 observations pass; public API/raw hashes/V83 retained. PeakRSS medians are
near-flat or overlap existing modes; no allocation/RSS win is inferred.

Separate n3 alternating named diagnostics (one warmup), medianms:
DAE23190.564/B491.551; OO6026.947/B explicit per-row pass-sum1778.100;
CL3423.120/B1270.190; OI90.380/B253.911. B debug1 serializes function passes
and validates outside named timers. Starshine module scopes include setup/lift/
lower/validation; OI narrow timer excludes its costly envelope. These debug
artifact hashes match normal rows, but debug wall is not normal wall. Keep
MAD/ranges/individual OO stages in the local report; never sum nested stages
or component medians. Prior c416/October1 measurements remain historical.

Normal S/B bytes D2 6115221/6232586, OO5563501/5573450, CL5706503/5627625,
OI6205998/6172971 are unchanged. Canonical OO5686688/5587437 (+99251B) remains
separate from raw−9949B; all other quality/coverage/aggregate/full-release gates
stay active. Next targets remain DAE2 dependencies/lift, optimizing cleanup,
OI envelope and bounded conflict queries. Exact protocols/source hashes/all
samples and rejected trial failures live in
`.tmp/large-pass-hotspots-20261001/main-payload-direct-match-performance-20261002.md`.


## October 2, 2026: main completed lift band checkpoint

[Source, invariant, controls and consumer evidence](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-completed-local-band-proofs-in-lift)
freeze main177be8505/native6e22e72f…→d08c0fdb… on the same compiler/v133/CPU6.
Build excluded; normal n5 alternating, one warmup, fresh CLI/warm filesystem.
Median±MAD milliseconds:

| Pass | Starshine normal CLI | B133 normal CLI | Ratio |
| --- | ---: | ---: | ---: |
| DAE2 | 4426.975±213.283 | 1301.502±14.096 | 3.401× |
| DAE2-O | 7108.224±176.857 | 2526.604±25.495 | 2.813× |
| CL | 4599.278±72.573 | 1949.186±45.078 | 2.360× |
| OI | 2427.675±38.118 | 969.681±2.776 | 2.504× |

Paired+4.736/+2.541/−.022/−3.490%; every row flags foreign activity. Mixed
clock results do not establish a command win or quiet-host1× signoff. Complete
matched CL instructions−.630267%, nested conflict wrapper−8.281889% independently
support removed traversal work; recursive/parent edges overlap and are not
summed.13,386 tests/724 runtime modules/2112 observations/32 native controls
pass with exact raw hashes/public API/V83 savings. Saturated fallback controls
regress and remain active; native array width/layout is not an allocation-byte
or RSS proof. RSS modes/optimizing excess and canonical quality remain open.

Independent traced n1 diagnostics do not refresh B inner evidence; the prior
n3 checkpoint retains native6e22/date and different validation/lift/lower/timer
scopes. Raw and canonical artifacts stay distinct: OO−9949 raw versus+99251
bounded canonical bytes. Exact manifest/source hashes, normal/traced ranges,
flags/all samples, layout and red/green evidence:
`.tmp/large-pass-hotspots-20261001/main-lift-byte-extent-performance-20261002.md`.
Next: DAE2 dependency/cleanup, OI envelope, Coalesce guaranteed-false pair scans
and unused block-write scratch. Aggregate/full CI/coverage gates remain open.


Complete DAE2 consumer follow-up on the same frozen binaries is effectively
unchanged:34.604264b→34.604092b instructions (−.000498%).
[Exact parent/child attribution](../binaryen/passes/coalesce-locals/starshine-strategy.md#dae2-consumer-attribution-follow-up)
places its costs in lift, dependency CFG/source analysis, rewrite lower and
mandatory validation. The CL benefit cannot be extrapolated to DAE2.


## October 2, 2026: main Coalesce global-barrier checkpoint

[Exact predicate and consumer evidence](../binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-reject-globally-blocked-copy-pairs-once)
freeze main7a5676ba9/natived08c→dbbaefbe. Normal CPU6 one-warmup/n5 alternating
fresh CLI/warm filesystem CL4491.022±56.275→4416.546±70.418ms,
B1963.489±27.857ms; paired−.699%, remaining2.249×. Every row flags foreign
activity. Complete CL instructions−2.930209%, nested safe-copy owner−98.240377%
support reduced work without summing parent/recursive edges. Traced n1 module
3394.961→3289.098ms is diagnostic; no refreshed B inner comparison. PeakRSS
medians overlap; raw hashes/canonical gap78,800B unchanged.13,391 tests/10
native controls/185 validated runtime modules/540 observations pass; tiny clear/
no-edge costs,1× and release gates remain. DAE2/O/OI retain the preceding frozen
source; no extrapolation from CL. Exact evidence/driver correction:
`.tmp/large-pass-hotspots-20261001/main-copy-barrier-performance-20261002.md`.


## October 3, 2026: main inline CFG edge checkpoint

[Source, invariants and full evidence](../binaryen/passes/dae2/starshine-strategy.md#october-3-2026-inline-scalar-cfg-edge-storage)
freeze main3631c1d0c/nativedbbaefbe→43feef6e, verified133, same input/CPU6.
Normal n5 alternating after warmup1, fresh CLI/warm filesystem, median±MADms:
DAE24437.228±267.521/B1382.867±140.725; OO7184.540±270.244/B2567.837±43.839;
CL4311.431±54.395/B1947.387±23.953; OI2424.382±13.781/B981.942±9.450.
Ratios3.209/2.798/2.214/2.469× remain open. Every row flags foreign activity;
OO before11.142/14.075s outliers invalidate a causal23% clock-gain claim.
Complete matched DAE2/CL work−.887845/−.832954%, unchanged builder counts
and native allocation red/green establish a smaller storage improvement.

Separate n3 named diagnostics after warmup1, median±MADms:
DAE23275.024±38.347/B502.812±3.511;
OO6107.553±91.745/B explicit per-row stage sum1828.087±20.570;
CL3335.802±39.340/B1278.750±8.540;
OI94.693±4.552/B262.355±2.146.
Binaryen debug1 serializes function passes and adds verification outside timers;
Starshine module/narrow pass scopes have different setup/lift/lower/validation.
Debug hashes match normal outputs; debug wall never substitutes for normal wall.
OI's narrow pass advantage still leaves a costly command envelope.

13,395 tests/10 controls/756 runtime modules/2208 observations pass. Raw hashes,
canonical deficits and V83 savings remain exact; no new normalization is claimed.
RSS ranges/modes and tiny empty-row+.75ns remain explicit. Full CI/coverage/
aggregate release gates stay open. Exact manifests, commands, samples, spreads,
profiles and allocation scope:
`.tmp/large-pass-hotspots-20261001/main-cfg-edge-value-performance-20261003.md`.


## October 3, 2026: main reverse-signature checkpoint

[Source, full normal matrix and retained repeats](../binaryen/passes/dae2/starshine-strategy.md#october-3-2026-indexed-reverse-signature-validation)
freeze main 3d46f7e52/native 43feef6e→8bfe3761, verified133, same input/CPU6.
Complete DAE2/CL instruction work falls2.070902/1.176357%; direct allocation
calls fall5,634,510/4,331,346 with unchanged typed-pop checks and exact bytes.
Normal n5 clocks are heavily contended; DAE2/OI regressions prompted one n3
repeat, all initial samples retained. Repeat DAE2 4748.599±16.029→4762.781±26.670ms,
B1425.710±14.176; OI 2857.043±11.592→2825.212±17.848, B1151.825±10.469.
Remaining ratios3.341/2.453× and mixed first/repeat clocks prevent a1× or general
command-speed claim. Traced Starshine n1 diagnostics remain separate; the prior
CFG binary's Binaryen debug named timers are not relabeled as current evidence.
13,403 tests/10+2 native controls/772 runtime validations/2256 observations pass.
No public API or output/canonical changes; memory modes and release gates stay
open. No long fuzz. Exact commands, hashes, samples, spreads and profile scopes:
`.tmp/large-pass-hotspots-20261001/main-reverse-types-performance-20261003.md`.


## October 3, 2026: shape-first Vacuum predicates in optimizing cleanup

[The source proof and complete capture](../binaryen/passes/vacuum/starshine-hot-ir-strategy.md#october-3-2026-reject-mismatched-vacuum-prefixes-before-recursive-scans)
compare nativefd2af4bd…→ec2a0ed4… against verified133 on the unchanged6.21MB
compiler. Complete per-function DAE2-O cleanup work−5.30022%; nested Vacuum
−20.96197%, with all predicate invocations retained and exact output. These
instruction percentages are not milliseconds or additive phase totals.

One warmup/n5 rotating alternating fresh-process CLI samples on CPU6, warm
filesystem, build/profile excluded, milliseconds±MAD:

| Pass | Before ms±MAD | After ms±MAD | Binaryen133 ms±MAD | After /133 | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2-optimizing | 6517.788±93.704 | 6500.347±39.193 | 2541.850±3.816 | 2.557× | -0.268% |
| vacuum | 1377.093±21.189 | 1265.246±5.326 | 859.986±7.017 | 1.471× | -8.639% |
| dae2 | 3505.817±34.924 | 3511.341±70.028 | 1169.492±18.526 | 3.002× | +0.841% |
| coalesce-locals | 3847.499±37.491 | 3877.968±55.493 | 1857.337±10.346 | 2.088× | +1.306% |
| optimize-instructions | 2266.195±31.429 | 2275.239±17.130 | 1024.043±5.635 | 2.222× | +1.304% |
| dae2-optimizing repeat | 6502.646±124.324 | 6541.975±38.733 | 2483.771±6.556 | 2.634× | +0.009% |

All rows record foreign CPU activity. Standalone Vacuum ranges are disjoint and
its median saves111.847ms; DAE2-O remains within spread in both bounded cohorts,
so no enclosing optimizing gain is claimed. Positive DAE2/CL/OI control costs
remain visible. Separate traced n1 data and complete ranges/RSS live in the
local report; the named Vacuum timer excludes raw preclean.13,447 tests,18
wasm-gc controls and1296 original-primary execution observations pass. No public
API/output change, peak-memory claim, fresh canonical measurement or1×/release
signoff. Next source-backed investigation: exact SL cleanup's reachable-read
counting and repeated branch-aware fallthrough, alongside DAE2 dependencies.
