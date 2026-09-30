---
kind: entity
status: working
last_reviewed: 2026-09-30
sources:
  - ../../../../../src/passes/dae_stack_effect_ref_eq_wbtest.mbt
  - ../../../../../src/cmd/dae_stack_effect_ref_eq_wbtest.mbt
  - ../../../../../src/passes/dae2_capture_callbacks_wbtest.mbt
  - ../../../../../src/passes/dae2_capture_callbacks_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_capture_callbacks_reference_wbtest.mbt
  - ../../../../../src/passes/dae2_scalar_forwarding_wbtest.mbt
  - ../../../../../src/passes/dae2_scalar_forwarding_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_scalar_forwarding_reference_wbtest.mbt
  - ../../../../../src/cmd/dae2_scalar_forwarding_wbtest.mbt
  - ../../../../../src/passes/dae2_balanced_captures_wbtest.mbt
  - ../../../../../src/passes/dae2_balanced_captures_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_balanced_captures_reference_wbtest.mbt
  - ../../../../../src/cmd/dae2_balanced_captures_wbtest.mbt
  - ../../../../../src/ir/local_graph_read_flow_wbtest.mbt
  - ../../../../../src/ir/local_graph_read_flow_perf_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_carried_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_carried_reference_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_carried_perf_wbtest.mbt
  - ../../../../../src/ir/hot_source_order.mbt
  - ../../../../../src/ir/hot_region_fields_wbtest.mbt
  - ../../../../../src/ir/hot_region_fields_reference_wbtest.mbt
  - ../../../../../src/ir/hot_region_fields_perf_wbtest.mbt
  - ../../../../../src/ir/hot_labels.mbt
  - ../../../../../src/ir/hot_region_edit.mbt
  - ../../../../../src/ir/hot_query.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/signature_lookup_wbtest.mbt
  - ../../../../../src/passes/signature_lookup_reference_wbtest.mbt
  - ../../../../../src/passes/signature_lookup_perf_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_minimum_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_minimum_reference_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_minimum_perf_wbtest.mbt
  - ../../../../../src/ir/local_graph_source_union_wbtest.mbt
  - ../../../../../src/ir/local_graph_source_union_perf_wbtest.mbt
  - ../../../../../src/ir/local_graph_entry_reads_wbtest.mbt
  - ../../../../../src/ir/local_graph_entry_reads_reference_wbtest.mbt
  - ../../../../../src/ir/local_graph.mbt
  - ../../../../../src/ir/local_graph_sparse.mbt
  - ../../../../../src/ir/local_graph_write_facts_wbtest.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_lower_input_header_wbtest.mbt
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

**Native counter scope correction (September 30):** the callback section below
also supersedes earlier descriptions of allocator or query-call counts as
dependency-window-only. Toggled event collection scopes instruction totals;
call counters retain the whole command. Historical values remain evidence under
that broader call domain. Direct code-site budgets and whole-command profiles
retain their stated scope.

## September 30, 2026 binary reference equality correction

The shared `dae_instr_stack_effect` incorrectly groups `ref.eq` with unary
instructions. Its actual stack effect is **two inputs, one output**. Extended
capture cleanup can consequently consume its held capture while leaving an
earlier stack reference behind. Both outputs validate, yet the earlier reference
becomes the return value. Moving `RefEq` to the existing binary group restores
the checked stack floor; the capture stays in a local when equality needs an
operand below it. No other opcode family or cleanup ordering changes.

The [arity and direct-capture regressions](../../../../../src/passes/dae_stack_effect_ref_eq_wbtest.mbt)
fail **Some((1,1)) != Some((2,1))** and **zero locals instead of one**.
The [public command fixture](../../../../../src/cmd/dae_stack_effect_ref_eq_wbtest.mbt)
also fails zero versus one before implementation. All three focused wasm-gc
tests pass after the correction. A bounded original/V35/verified-v133 runtime
replay confirms a **true semantic mismatch**: original and Binaryen return the
produced GC reference and observe equality **1**; V35 returns null and observes
**0**, with the same ordered base/producer/observer calls. An earlier dropped
equality variant also returns null incorrectly. Validation alone missed both.

The V32–V37 capture checkpoints therefore retain a reference-equality correctness
hole. Their previously documented runtime results cover their selected fixtures;
they are not general correctness or release signoff. Corrected frozen V38 native replay returns the produced reference and observes
**1**, matching the original and verified v133. Info/fmt, focused wasm-gc/native
tests and **13,015 default tests** pass. The small and large compiler outputs
contain no `ref.eq` instructions, so their historical artifact comparisons retain
that limited scope. The current V38 CLI is SHA-256
`5f93f13ab6609f8494637a45edbf9d3373213e5050ccc290f9a2e6b262b090e7`;
it also includes the separately measured parameter-alias cleanup. Its fresh
v133 oracle artifacts and size/timing evidence are retained. Long fuzz remains
deferred while performance iteration continues. Evidence:
`.tmp/dae2-lean-20260929/{ref-eq-{core,command}-{red,green}.log,
ref-eq-initial-probe.json,ref-eq-initial-{original,v35,binaryen}.wasm,
ref-eq-stack.{wat,mjs},ref-eq-stack-probe.json,ref-eq-stack-v38-result.json,
ref-eq-macro-opcodes.json,validation-v38.json,oracle-v38-{small,large}}`.

## September 30, 2026 capture callback reuse

Five raw cleanup traversals now create their recursive child visitor once per
region: local counting, balanced capture removal, local remapping, DAE2 forwarding
and branchless block flattening. Flattening resets its per-instruction child
branch flag before every sibling. Shared counters, accumulated changes, label
masks and recursive scopes retain their previous lifetime. Native generated-code
TDD finds **five per-instruction allocation sites in V34, zero in V35**; this is
a compiled work-budget regression, not an initially failing semantic fixture.
The [three behavior guards](../../../../../src/passes/dae2_capture_callbacks_wbtest.mbt)
compare exact fields, instructions, flags, counters and label masks against the
[frozen V34 reference](../../../../../src/passes/dae2_capture_callbacks_reference_wbtest.mbt).

Info/fmt, native/debug guards, the existing command forwarding test, **13,000
default tests**, native CLI build and twelve native benchmarks pass. At 8/64/512
captures, cleanup improves **2.84 → 1.36µs / 21.04 → 8.62µs /
163.85 → 65.14µs**; branchless traversal improves **1.34 → 0.432µs /
9.61 → 2.82µs / 77.76 → 22.05µs**. Setup stays outside timed regions.
The large final-capture-only native profile falls **5,075,747,935 →
2,955,409,451 instructions (41.8%)**. Incoming `mi_malloc` calls fall
**52,254,437 → 43,495,605**, `mi_free` **164,228,390 → 151,194,926**.
Instructions are capture-scoped; call counters cover the whole command even
with event collection toggled. A deterministic counter check records 3,007
allocator calls while only seven occur in the selected function. The request
reduction therefore cannot be attributed solely to final capture cleanup; these
are not allocated bytes or live objects. See the
[Callgrind collection/instrumentation distinction](https://valgrind.org/docs/manual/cl-manual.html#cl-manual.limits).
Both profiled outputs validate and are byte-identical.

Matched CPU-6 V34/V35 medians (one warmup, three samples; before/after MAD) are
large plain **3516.314 → 3458.885ms** (10.612/37.971), optimizing
**6342.742 → 6180.746ms** (3.028/15.229); small **3.914 → 3.746ms**
(0.029/0.034), optimizing **10.741 → 9.972ms** (0.029/0.064).
Active tee is **3.530 → 2.694ms** (0.010/0.049) /
**101.413 → 99.306ms** (1.018/0.200). Rejected small reference brackets
1.170 and 1.207 remain recorded. Large peak RSS medians/ranges (KiB) are plain
**279,864 [279,736–279,992] → 269,828 [258,548–281,564]**, optimizing
**290,140 [289,708–291,028] → 292,364 [291,908–312,168]**. Optimizing RSS
is not an established improvement and remains a control cost.

All paired raw outputs are identical. Bounded original/V34/V35/v133 replays
match **126 modules / 1,029 observations**, with independently validated outputs.
Fresh v133 pass-local medians are small **3.828 / 0.957863ms (4.00×)** and
**11.469 / 3.176240ms (3.61×)**; large **3429.937 / 419.500ms (8.18×)**
and **6552.495 / 1615.990ms (4.05×)**. These oracle cohorts are separate
from causal pairs. The optimizing gap remains **235,151 raw / 369,000 canonical
bytes**. Remaining callback/storage churn, aliases, HOT lifting and optimizing
cleanup are active work; this checkpoint does not close Binaryen parity.

Frozen V35 SHA-256:
`e91d6a105bbceed6ffdf6f375a26e3e1c886928a6f1bc70d5b05e9d3706345e3`.
Oracle is verified release-v133 SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
Evidence: `.tmp/dae2-lean-20260929/{validation-v35.json,candidate-v35.json,
callback-cost-{v34,v35}.json,callback-native-cost-v35.json,native-{v34,v35}.c,
oracle-v35-{small,large},pairs-v35-{small,large,tee},runtime-v35,
callbacks-memory-v35.log,callgrind-{v34,v35}-captures,
callgrind-counter-scope.{c,json},v35-bench.log}`.
No public API changes. Long fuzz and final signoff remain deferred.

## September 30, 2026 scoped scalar forwarding cleanup

The final optimizing cleanup now exposes scalar and nested local-read forwarding
blocks, including nonnullable GC references. The reduced direct cleanup fails
**one local instead of zero** before the change. A bottom-up forwarding walk uses
the existing shared type snapshot; finding a scalar forwarding wrapper triggers
`pass_lower_cleanup_branchless_blocks` for that function. Its environment is
built lazily once. Blocks with inputs or control transfers retain their headers.
Changed functions lose stale label maps; the metadata guard now retains an actual
branch target instead of an obsolete scalar wrapper. The frozen V30 tuple helper
moves into its test reference, keeping that earlier benchmark control unchanged.

[Four fixtures](../../../../../src/passes/dae2_scalar_forwarding_wbtest.mbt)
cover nested i32/f64/externref captures, loads, nonnullable GC forwarding and
intentional input/branch fences. The [command guard](../../../../../src/cmd/dae2_scalar_forwarding_wbtest.mbt)
checks f64 results and calls. **12,997 default tests**, native/debug, command,
info/fmt, native release build and six native controls pass. Guarded V34 improves
8/64/512 forwarding controls **12.07 → 10.18µs / 87.97 → 61.47µs /
726.56 → 483.98µs**. The eager V33 trial is rejected: despite faster synthetic
controls, it changes no artifact bytes and matched large optimizing rises 2.21%.

V32/V34 raw artifact outputs are identical, including all 12,904 large functions;
this latent forwarding improvement saves no additional artifact bytes. Bounded
original/V32/V34/v133 replays match **126 modules / 1,029 observations**, plus
**36 modules / 108 call/reference/trap observations** and a reduced imported-call
loop's **7 modules / 42 observations**. Every output validates. That loop remains
**260 raw / 272 writer bytes versus 220** for v133 optimizing; another symmetric
SimplifyLocals/Vacuum round brings all three outputs to 220. The remaining loop
family contains parameter aliases and reused local captures, not raw forwarding
blocks. Writer-created expression wrappers must not be mistaken for raw blocks.

Matched CPU-6 V32/V34 compiler medians (one warmup, three samples; before/after
MAD) are large plain **3721.289 → 3668.633ms** (22.954/13.784), optimizing
**6705.669 → 6755.573ms** (9.821/28.158); small **4.110 → 3.951ms**
(0.030/0.006), optimizing **11.512 → 11.273ms** (0.055/0.036).
Tee is **3.743 → 3.779ms** (0.000/0.018) / **102.939 → 105.275ms**
(0.729/0.258). Rejected small reference brackets 1.186 and 1.180 stay recorded.
The optimizing artifact and tee costs remain explicit; this does not establish a
whole-pass win. Native C review finds per-instruction callback allocations in
forwarding, local counting and balanced-capture traversal; hoisting them is the
next allocation trial. Parameter-alias regressions also fail on retained locals
and branch-dominated reads and remain pending implementation.

Fresh v133 pass-local medians are small **4.142 / 0.999541ms** and
**13.505 / 3.174240ms**; large **3707.065 / 466.812ms (7.94×)** and
**7124.317 / 1690.510ms (4.21×)**. Output gaps remain **235,151 raw /
369,000 canonical optimizing bytes**. V34 binary SHA-256 is
`7b6e08f6af505a1b8dfe5f1fa19983448efd3d421568f3125bc4609f9b3c4725`.
Both oracle runs precede the next uncommitted alias fixtures. Evidence:
`.tmp/dae2-lean-20260929/{validation-v34.json,candidate-v34.json,
oracle-v34-{small,large},pairs-v34-{small,large,tee},runtime-v34,
forwarding-shape-v34.json,forwarding-runtime-v34,forwarding-loop-v34,
v33-red.log,v34-bench.log,native-{count,balanced,forwarding}-v34.c}`.
No public API changes; long fuzz and final signoff remain deferred.

## September 30, 2026 balanced effect-spanning captures

The final optimizing cleanup now removes a single-write/single-read capture
across balanced calls, arithmetic and known trapping producers. The producer
stays at its original position; its stack value remains below every intervening
operand. A checked stack-height scan requires each operand to come from above
that value. Unknown effects, structured regions, branches and unreachable
instructions end the scan. Calls resolve through the shared module type snapshot;
indirect/reference calls include their target operand. The interval remains
bounded at 256 instruction slots. Other callers keep their existing leaf scan.

The original scalar/reference fixtures fail with **one local instead of zero**.
[Six focused tests](../../../../../src/passes/dae2_balanced_captures_wbtest.mbt)
cover i32/f64/externref, trapping loads, indirect/reference/multivalue calls,
consumption of an earlier stack operand, branch intervals, repeated reads and
overlapping captures. The [command fixture](../../../../../src/cmd/dae2_balanced_captures_wbtest.mbt)
checks the public optimizing route's exact opcodes and validity. The first
extended-greedy prototype adds capture pairs in **25 artifact functions**; the
reduced overlap test fails **2 != 1 locals**. Final V32 runs the original smaller
leaf plan first, then removes additional balanced pairs. It preserves that test's
one-local output. V31 is rejected evidence, not the final size checkpoint.

All non-code semantic sections and nonlocal opcode/immediate streams of V30/V32
are identical. Across 12,904 large defined functions, **6,444 functions lose
32,070 set/get pairs**, none gain pairs, and tee counts stay unchanged. Small
loses four pairs in two functions. Raw optimizing output falls
**5,956,477 → 5,808,601 bytes (147,876 saved)**. The verified-v133 result is
5,573,450, leaving **235,151 raw bytes**. The comparison writer expands Starshine's
new held stack values: its canonical output is **5,942,450**, down 53,470 but
still **369,000 bytes larger**. This writer rewrites Starshine; it is not a
symmetric downstream optimization comparison. Plain DAE2 bytes stay unchanged.
These reductions prove a win over the previous Starshine capture shape; they do
not classify all remaining Binaryen drift or close the optimizing quality gap.

Info/fmt, **12,992 default tests**, six native/debug cases, the command case,
native CLI build and six native benchmarks pass. The bounded original/V30/V32/v133
replay matches **126 modules / 1,029 observations**. Another **36 modules /
108 observations** cover normal calls, side-effecting throws, out-of-bounds loads,
divide-by-zero traps, references and signed zero. Every output validates. All
producer/consumer event order, result and trap observations match the original.

The legacy-first plan has a cost: 8/64/512 capture microbenchmarks are
**4.24 → 4.76µs / 24.65 → 29.78µs / 193.45 → 222.34µs**. Matched CPU-6 V30/V32
compiler medians (one warmup, three samples; before/after MAD) are large plain
**3721.430 → 3753.686ms** (5.083/8.693), optimizing
**6667.219 → 6729.063ms** (36.251/23.845); small **3.900 → 3.976ms**
(0.015/0.068), optimizing **10.915 → 11.613ms** (0.051/0.096).
Active tee is **3.896 → 3.767ms** (0.137/0.031) /
**105.353 → 104.819ms** (0.303/0.477). A rejected small reference bracket
(1.152) is retained. This is a quality improvement with measured control costs,
not a demonstrated whole-pass speed improvement. Extra scan/materialization work
and scalar forwarding blocks remain optimization targets; peak RSS and native
allocation counts have not been renewed for this unit.

Fresh release-v133 pass-local medians are small **4.136 / 1.020240ms** and
**12.827 / 3.251740ms**; large **3679.039 / 451.402ms (8.15×)** and
**7060.102 / 1686.680ms (4.19×)**. This separate cohort is not a causal
comparison with V30. Long fuzz and final signoff remain deferred.

Frozen V32 native SHA-256 is
`3801863d728b9f07e166f0225a327597f150f91a3f88e4b8b310d494d3455c3c`;
V30 baseline and verified release-v133 hashes are recorded in the next section.
Both small and large oracle runs use the frozen source snapshot before the next
forwarding-block tests are added. Evidence:
`.tmp/dae2-lean-20260929/{validation-v32.json,candidate-v32.json,
oracle-v32-{small,large},pairs-v32-{small,large,tee},runtime-v32,
balanced-runtime-v32,capture-shape-v32.json,capture-shape-v31.json,
v32-bench.log,v33-red.log}`. No public API changes.

## September 30, 2026 read-source flow projection

DAE2 now requests `HotLocalReadSources`, an immutable snapshot with checked
count/scalar queries. The shared reverse/sparse solver preserves full-flow
source order, exceptional edges, unknown rows and shared-action fallback.
Only complete `HotLocalGraph` callers build writer influences, tee metadata,
already-SSA classification and defaultability. The narrower type has private
storage; no partial object is returned through the full graph API.

The original native work guard fails on **749,781 influence publications** and
**9,887 builds each** of already-SSA and defaultability metadata. Frozen V30
reduces all three to zero. Dependency-only instructions fall
**14,932,874,985 → 14,408,661,632 (3.51%)**; incoming allocator/free calls each
fall **754,570**, to 33,574,154 / 109,020,401. These are call counts, not
allocated bytes or whole optimizing-pipeline totals.

[Three fixtures](../../../../../src/ir/local_graph_read_flow_wbtest.mbt) compare
all ordered source rows and full graph fields against the frozen solver,
including joins, loops, references, exceptional edges, shared fallback,
unknown reads and snapshot ownership after mutation. Native/debug and wasm-gc
checks pass, including **12,985 default tests** and **549 IR tests**.
[Eight native controls](../../../../../src/ir/local_graph_read_flow_perf_wbtest.mbt)
compare identical CFG work: 8/64/512 conditional writers improve
2.68 → 2.28µs / 16.25 → 13.71µs / 128.33 → 106.20µs. The cold lift+CFG control
is 10.21 → 10.12µs. These isolate the solver, not compiler gains.

Matched V29/V30 CPU-6 compiler medians (one warmup, three samples; before/after
MAD in parentheses) are large DAE2 **3724.037 → 3736.133ms**
(17.523/4.853), optimizing **6650.038 → 6604.935ms** (6.424/37.735); small
3.985 → 3.951ms (0.036/0.033), optimizing 11.104 → 10.991ms (0.016/0.087).
Active tee is 3.783 → 3.852ms (0.004/0.105) / 104.228 → 104.248ms
(0.378/1.168). Conditional writers are 11.294 → 11.311ms (0.026/0.133) /
16.306 → 16.424ms (0.142/0.021), with a rejected 1.162 reference bracket kept.
No large plain-pass wall-time win is established.

Three-pair large peak-RSS medians are 281,020 → 268,772KiB for plain, with
259,644–281,116 / 257,656–282,200 ranges; optimizing 291,908 → 292,088KiB,
with 291,752–292,220 / 292,024–305,380 ranges. Overlapping ranges and the
optimizing increase remain explicit. The bounded original/V29/V30/v133 replay
matches **126 modules / 1,029 observations**, plus conditional-writer
**7 modules / 42 observations**. Every measured output validates and Starshine
bytes remain unchanged.

Fresh verified release-v133 pass-local medians are small
**4.133 / 1.014870ms** and **13.222 / 3.195760ms**; large
**3695.418 / 447.885ms (8.25×)** and
**6965.520 / 1682.870ms (4.14×)**. This separate cohort does not establish
causal improvement over earlier oracle runs. Canonical optimizing output
remains **+422,470 bytes**. Long fuzz and final signoff remain deferred.

Size attribution now isolates **+422,257 bytes in function bodies**: 8,687
positive functions add 432,374 bytes; 1,729 smaller bodies save 10,117. Compact
samples contain retained local captures around calls and arithmetic. The
imported-call loop reduction is **284 versus 215 raw bytes**. At this checkpoint, balanced-call
capture regressions failed with one retained local instead of zero. The later
balanced-capture section above supersedes that gap and its size baseline.

Evidence: `.tmp/dae2-lean-20260929/{validation-v30.json,candidate-v30.json,
oracle-v30-{small,large},pairs-v30-{small,large,tee},runtime-v30,
conditional-writers-v30,callgrind-v30-dependencies,dependency-cost-v30.json,
flow-work-{v29,v30}.json,memory-v30.json,size-v29.json}`. Frozen V30 native SHA
is `d8c339b06f04a18840a13acc5a05a144dcfba844ff11dcd85e31dd90d1e87af7`.
After freezing evidence, the internal solver record was marked private to
avoid an accidental opaque API export; the three source fixtures were rerun.
The next native checkpoint will include that visibility-only cleanup.

## September 30, 2026 carried dependency workspace

Nonempty preceding-dependency queries now reuse the carried-value vector in the
existing immutable facts workspace. Each query clears its temporary values and
visited flags before returning; selected rows remain independently owned.
Pure roots and empty candidate sets return before creating the workspace.
The collector appends a carried node only while its consumer bound is unset,
so the retained vector's high-water length is bounded by the snapshot's node
count. No per-query result row is retained or returned as workspace storage.

The actual original construction point is instrumented before implementation:
the reuse guard fails **8 vectors != 1**, and a fresh empty-future query wrongly
creates scratch. A semantic effect/ownership guard is initially green. Four
[focused guards](../../../../../src/ir/hot_source_order_carried_wbtest.mbt)
now pass, including alternating widths, held/mutated caller results, pure/empty
and indexed exits, independent facts, traps, local writes and reference values.
They retain revision, source ordering, all consumer flags and empty temporary
storage. The 32-value high-water fixture retains its capacity across narrower
and empty queries; the sibling owns a different vector. The private work counter
is a nullable native Int-array pointer; the emitted default wrapper maps an
omitted counter to zero without constructing a counter object.

An independent native allocation budget is also red on frozen V28. With the
same **1,070,492 root-header checks**, direct query `mi_malloc` calls fall
**3,092,437 → 1,788,660 (42.16%)**, passing the required 25% reduction.
Sorting calls fall **977,587 → 651,397** because empty candidates avoid the
old empty-vector sorting/selection setup; scratch construction falls
12,718 → 12,393. The matched complete large dependency scope falls
**15,059,317,658 → 14,932,874,985 instructions (0.84%)** and removes
**1,310,672 incoming `mi_malloc` calls and 1,310,672 `mi_free` calls**
(35,639,396 → 34,328,724 requests; 111,085,643 → 109,774,971 frees).
Direct query counts exclude constructor descendants. None of these call counts
are allocated bytes, live objects or optimizing-cleanup totals.

[Twelve native controls](../../../../../src/ir/hot_source_order_carried_perf_wbtest.mbt)
keep the original four-field scratch layout and fresh carried vectors in the
reference. Cold controls include new facts and scratch; warm controls reuse
facts and return a fresh selected row each time. Arena construction is outside
timing. The reference passes its old scratch explicitly, so its helper ABI is
not identical to the former CLI; compiler gains use frozen binaries below.
The controls remain mostly flat and do not establish a helper speedup:

| Carried values | Reference → selected warm mean | Reference → selected cold mean |
| --- | --- | --- |
| 8 | 380.48 → 379.66ns | 1.49 → 1.49µs |
| 128 | 5.40 → 5.44µs | **18.36 → 19.44µs (5.88% cost)** |
| 1024 | 42.21 → 42.32µs | 141.98 → 142.02µs |

A repeated cached native run retains the initial cold cost: 128-value cold
18.06 → 18.18µs, warm 5.35 → 5.43µs; 1024-value cold 140.44 → 141.70µs
and **warm 41.91 → 43.64µs (4.13% cost)**. Both complete twelve-control
logs stay saved. Fewer requests do not guarantee faster dense queries.

Matched V28/V29 compiler medians use CPU 6, one warmup, three accepted
alternating samples and stable leading/trailing reference brackets:

| Workload | Plain median ms (MAD before/after) | Optimizing median ms (MAD before/after) |
| --- | --- | --- |
| Large compiler | 3644.091 → 3634.874 (10.951/20.050; 0.25% gain) | 6551.206 → 6556.749 (29.150/22.673; 0.08% cost) |
| Small compiler | **3.961 → 4.033 (0.066/0.049; 1.82% cost)** | **10.857 → 11.283 (0.007/0.423; 3.92% cost)** |
| Tee | 3.718 → 3.779 (0.021/0.060; 1.64% cost) | 103.783 → 103.037 (1.110/0.111) |
| Joined readers | 18.946 → 18.934 (0.007/0.194) | **28.876 → 29.905 (0.328/0.434; 3.56% cost)** |
| Pure tail | 11.876 → 11.814 (0.072/0.049) | 12.109 → 12.007 (0.037/0.115) |
| Conditional writers | 11.508 → 11.276 (0.243/0.187) | 16.052 → 15.994 (0.112/0.037) |

Seven-sample repeats preserve the initial small/joined costs: small **3.940 →
3.910ms** (MAD 0.032/0.022) / **10.835 → 10.801ms** (0.066/0.052);
joined **19.013 → 19.052ms** (0.134/0.068) / **28.727 → 28.667ms**
(0.060/0.282). Small command CPU medians are 8.302 → 8.334ms /
15.283 → 15.136ms; joined 23.069 → 23.048ms / 32.865 → 32.904ms.
Rejected reference ratios 1.738, 1.878, 2.560, 2.454, 1.157 and 1.837,
including warmups, remain saved. This is a heap-work reduction with modest
compiler timing changes, not evidence that the Binaryen gap is closed.

Whole small-command instructions fall 77,344,251 → 77,237,587 plain and
168,261,163 → 168,149,251 optimizing. Small named allocator requests/frees
fall by 825 plain and 951 optimizing. Three alternating large RSS samples are
plain **259,636 → 255,680KiB**, ranges 258,964–281,368 / 255,212–282,892;
optimizing **292,064 → 293,352KiB (0.44% cost)**, ranges
291,796–292,268 / 292,208–302,424. Ranges overlap; reduced calls do not
prove reduced peak memory. Carried capacity persists only for its existing
facts lifetime, and downstream/high-water costs remain tracked.

All **12,982 bounded default tests**, four focused native guards, 546 IR tests
and twelve native controls pass after `moon info`/`moon fmt`; `.mbti` is unchanged.
Fixed original/before/after/verified-v133 replay validates **126 modules / 1029
observations**, plus three dedicated seven-module controls totaling **98
observations**. There are no observation mismatches or Starshine byte changes.
Traced, untraced, profile and RSS outputs independently validate and preserve
saved bytes. Large canonical optimizing output remains **5,995,920 vs
5,573,450 bytes (+422,470)**; raw remains +383,027. Long fuzz is deferred.

Frozen lean-v29 native SHA-256:
`eb63bbd7b170f33d5b6d2735dea1ee0c6bddf044970ffee9fed5679ba6d9e44d`.
Both fresh-source oracle reports identify production-source digest
`e26fd6977553625c0f2f4aa29cad78249f21296dfbfcfc4a4d23a81d372d18c2`
and the verified release-v133 binary
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
The manifest hashes all 1360 `src` files. Fresh open-world pass-local medians
are small **4.245 / 0.990528ms (4.29×)** and **12.916 / 3.147350ms
(4.10×)**; large **3632.536 / 436.392ms (8.32×)** and
**6880.646 / 1656.100ms (4.15×)**. These are a separate cohort from the
matched gain/cost estimates, not untraced command times.

Local evidence is `.tmp/dae2-lean-20260929/{validation-v29.json,candidate-v29.json,
carried-work-{v28,v29}.json,carried-native-v29.json,oracle-v29-{small,large},
pairs-v29-{small,large,tee},runtime-v29,conditional-writers-v29,joined-readers-v29,
pure-tail-v29,dependency-cost-v29.json,small-instructions-v29,memory-v29,
review-v29-{small,joined},v29-cold-review.log}` and associated drivers/logs.
Remaining comparator closures, source/reader rows, field reads, flow scaling,
read-only flow projection, optimizing cleanup, size-family investigations and
cumulative/final release evidence remain active in the backlog.

## September 29, 2026 checked region fields

Label, body-boundary, region-holder, optional-arm and opcode queries now read
only the required fields after the existing checked live admission. Region count
and selection reuse the admitted holder; selecting a root checks the holder,
body boundary and slot in the original error order without validating the same
holder twice. The private body-boundary helper requires prior live admission.
No query caches a node header or adds retained node-sized storage. Indexed
block inputs and loop branch arguments remain outside the selected body roots.

The actual native work budget is red on frozen V27: **16,005,714 full-header
return calls != 0** from the selected queries in the dependency scope. Both
public and private getter names are included. V28 passes with **zero** calls;
all twelve real generated query definitions, including the private body-boundary
helper, also contain no full-header call. This verifies a removed boundary,
not a renamed getter or an annotation. Four semantic guards are initially green,
not original correctness failures. They compare all current control families,
absent arms, shared roots, indexed block/loop inputs, root regions, incomplete
deletion indexes, node replacement and intentionally invalid holder labels with
[frozen query contracts](../../../../../src/ir/hot_region_fields_reference_wbtest.mbt).
Revision and arena ownership remain unchanged; public interfaces do not change.

[Twelve native controls](../../../../../src/ir/hot_region_fields_perf_wbtest.mbt)
include 4096 queries per timed batch, with arena construction outside timing.
They alternate blocks and loops and keep the complete descendant reference
queries frozen:

| Query | 16 holders, no deletions: header → fields | 4096 holders, 128 deletions: header → fields |
| --- | --- | --- |
| Label | 33.17 → 27.81µs | 39.02 → 33.16µs |
| Body boundary | 52.62 → 43.44µs | 55.67 → 43.62µs |
| Region root selection | 136.77 → 59.37µs | 169.48 → 57.27µs |

Matched V27/V28 compiler medians remain mostly near flat. One warmup, three
accepted samples, alternating order, CPU 6 and leading/trailing reference
brackets are retained with rejected attempts:

| Workload | Plain median ms (MAD before/after) | Optimizing median ms (MAD before/after) |
| --- | --- | --- |
| Large compiler | 3692.572 → 3684.686 (1.012/19.221; 0.21% gain) | 6611.134 → 6556.094 (8.584/11.077; 0.83% gain) |
| Small compiler | 3.979 → 3.959 (0.088/0.002) | **10.997 → 11.773 (0.002/0.363; 7.06% cost)** |
| Tee | 3.706 → 3.735 (0.009/0.021; 0.78% cost) | 108.308 → 103.424 (2.444/0.564; 4.51% gain) |
| Joined readers | **18.955 → 19.310 (0.010/0.449; 1.87% cost)** | **28.223 → 29.216 (0.069/0.626; 3.52% cost)** |
| Pure tail | 11.914 → 11.775 (0.161/0.080) | 12.007 → 12.035 (0.020/0.077; 0.23% cost) |
| Conditional writers | 11.520 → 11.257 (0.014/0.057) | 16.322 → 16.268 (0.154/0.079) |

Seven-sample repeats preserve the initial small/joined costs as evidence rather
than erasing them: small **4.006 → 4.010ms** (MAD 0.039/0.041) /
**11.179 → 11.098ms** (0.026/0.131); joined **19.425 → 19.337ms**
(0.151/0.151) / **29.347 → 29.353ms** (0.140/0.678). Small command CPU
medians are 8.408 → 8.234ms / 15.462 → 15.438ms; joined 23.668 →
23.643ms / 33.528 → 33.772ms. These repeats do not establish a universal
compiler speedup. Rejected reference ratios 2.445, 1.159, 1.230, 2.261 and
1.681 remain saved, including rejected warmups.

Direct shared-consumer controls also preserve bytes and validation. Initial
small SimplifyLocals/Vacuum medians are 5.325 → 5.355ms / **1.672 →
1.797ms (7.48% cost)**; conditional 1.285 → 1.327ms / 3.066 → 3.019ms.
Seven-sample small repeats are 5.383 → 5.334ms (MAD 0.034/0.033) /
1.651 → 1.667ms (0.015/0.045). Conditional SimplifyLocals/Vacuum repeats are
1.335 → 1.356ms (0.010/0.010; 1.57% cost) / 3.119 → 3.026ms
(0.022/0.022; 2.98% gain). Reference ratios 1.160 and 2.441 are rejected
and retained. Original costs stay visible;
these controls alone do not close P12 or its full artifact lanes.

The matched large dependency scope falls **15,509,334,518 →
15,059,317,658 instructions (2.90%)**. Incoming `mi_malloc`/`mi_free`
calls remain **35,639,396 / 111,085,643**: this reduces header/validation
work, not allocation requests. Whole small-command instructions fall
77,714,235 → 77,341,580 plain and 169,301,017 → 168,263,868 optimizing;
small named allocator calls are unchanged. Three alternating large RSS samples
show plain **258,916 → 269,656KiB (4.15% cost)**, ranges 255,484–259,080 /
258,440–270,260; optimizing 292,000 → 292,208KiB, ranges
291,952–292,088 / 291,864–302,624. Ranges overlap and this introduces no
new retained cache, but the measurements do not prove a memory improvement.

All **12,978 bounded default tests**, four focused native guards, 542 IR tests
and twelve native controls pass after `moon info`/`moon fmt`; `.mbti` is unchanged.
The fixed original/before/after/v133 replay validates **126 modules / 1029
observations**, plus three dedicated seven-module controls totaling **98
observations**, with no observation mismatch or Starshine byte change. Traced,
untraced, profile and RSS outputs independently validate and match saved bytes.
Large canonical optimizing output remains **5,995,920 vs 5,573,450 bytes
(+422,470)**; raw remains +383,027. Plain smaller output remains an open
parity classification, not a declared win.

Frozen lean-v28 native SHA-256:
`89c643a8f5c66f1ab3725c98a612f8d873ddc367e4856591b64127551550d3a6`.
Verified release-v133 oracle SHA-256:
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
Fresh-source open-world v133 pass-local medians, a separate cohort from the
matched gain estimates, are small **4.302 / 0.998993ms (4.31×)** and
**13.599 / 3.191740ms (4.26×)**; large **3654.406 / 437.909ms (8.35×)**
and **6907.248 / 1658.680ms (4.16×)**. The candidate manifest hashes all
1357 `src` files; both oracle reports identify the same 265 production compiler
files and production-source digest
`f9bf6d5981e0cc6ea83c05dbf52556c64476ab5de19397b30dfd08165ab1f36e`.

Local evidence is `.tmp/dae2-lean-20260929/{validation-v28.json,candidate-v28.json,
region-fields-work-{v27,v28}.json,region-fields-native-v28.json,oracle-v28-{small,large},
pairs-v28-{small,large,tee},runtime-v28,conditional-writers-v28,joined-readers-v28,
pure-tail-v28,dependency-cost-v28.json,small-instructions-v28,memory-v28,
review-v28-{small,joined},affected-cleanup-v28-{small,conditional},
review-cleanup-v28-{small,conditional}}` and the associated drivers/logs.
Remaining source/local field queries, scratch vectors and repeated flow work,
read-only flow projection, optimizing cleanup setup, size families, cumulative
matched evidence and long aggregate/final release signoff remain open. Long fuzz
is deferred while those performance trials continue.

## September 29, 2026 cached raw signatures

Function admission and raw cleanup previously flattened the complete recursive
type section for each defined-function parameter lookup, even when the existing
HOT module context already owned that table. Shared pipeline state now borrows
the context's flattened subtype row. A replacement type-section object refreshes
the raw table once, independently of the original context; unchanged type
snapshots survive body edits. Lowering already copies the section before
appending types. Lookup still reads the current function declaration and preserves
import offsets, recursive groups, invalid-index boundaries and context fallback.
There is no new node-sized cache or retained per-function HOT graph.

The [five focused guards](../../../../../src/passes/signature_lookup_wbtest.mbt)
first require the missing indexed seam, then the mechanically instrumented
original fails **9 table builds != 1**, existing-context borrowing and unchanged-
snapshot identity. Two semantic guards are initially green, not original
semantic failures. Replacement/append, isolated states, empty sections, mixed
imports and GC declarations match the
[frozen section-only lookup](../../../../../src/passes/signature_lookup_reference_wbtest.mbt).
An adjacent dispatcher guard runs both DAE2 modes and asserts valid live GC
parameters, results and exact helper instructions after removing an unused
scalar parameter. Generated native C confirms that the first cache-hit return
allocates nothing, the disabled work counter is a null pointer, and snapshot
identity compares the underlying RecType-array pointer.

[Twelve native controls](../../../../../src/passes/signature_lookup_perf_wbtest.mbt)
query every function in a validated module. Warm selection borrows the existing
context table; cold selection includes fresh pipeline state and its first table
build. Fixture construction is outside the timed loop:

| Functions/types | Original → selected warm mean | Original → selected cold mean |
| --- | --- | --- |
| 8 | 472.26 → 123.31ns | 503.65 → 195.40ns |
| 128 | 84.51 → 1.87µs | 84.17 → 2.56µs |
| 1024 | 5.23ms → 15.14µs | 5.17ms → 20.11µs |

This eliminates functions-times-types table materialization. A bounded V24b
large optimizing profile scoped to the original section-only lookup collects
**307,868,174 instructions**: object destruction 33.54%, subtype-array push
25.86%, reference-array growth 18.85%, and flattening itself 13.50%. That is
a helper scope, not total optimizer work. The candidate bypasses that wrapper;
comparing its same-symbol toggle would be an unmatched profile, so no such
before/after percentage is claimed.

Matched V26/V27 compiler medians remain near flat: large plain **4156.151 →
4189.225ms (0.80% cost)** and optimizing **7359.567 → 7319.885ms (0.54%
gain)**, MAD 24.948/20.383ms and 5.000/31.758ms. Small 4.177 → 4.142ms /
**11.933 → 12.248ms (2.64% optimizing cost)**, MAD 0.052/0.018ms and
0.137/0.256ms. Tee 3.827 → 3.858ms / 108.063 → 106.887ms, MAD
0.043/0.008ms and 0.381/0.423ms; joined readers 19.811 → 19.437ms /
29.409 → 29.213ms; pure-tail 12.596 → 12.396ms /
**12.271 → 12.765ms (4.03% optimizing cost)**. Small reference brackets
1.166/1.256 and joined brackets 1.577/1.155 are rejected and retained.
The wide helper gain does not establish a comparable compiler gain.

The initial conditional-writer medians are 13.370 → 13.390ms /
**18.168 → 22.292ms (22.70% optimizing cost)**, MAD 0.277/0.111ms and
0.652/2.180ms. A rejected 1.601 reference bracket stays saved. One accepted
candidate command takes 31.390ms wall versus 21.647ms CPU, showing a pause
that stable leading/trailing brackets do not exclude. Seven-sample matched
repeats retain, rather than erase, the initial record:

| Workload | V26 → V27 plain median (MAD before/after) | V26 → V27 optimizing median (MAD before/after) |
| --- | --- | --- |
| Conditional writers | 11.979 → 11.755ms (0.121/0.172ms) | 16.799 → 17.356ms (0.058/0.292ms; **3.32% cost**) |
| Pure tail | 12.093 → 12.412ms (0.048/0.105ms; **2.64% cost**) | 12.196 → 12.404ms (0.050/0.192ms; **1.71% cost**) |
| Small compiler | 4.123 → 4.068ms (0.036/0.069ms) | 11.360 → 11.594ms (0.172/0.247ms; **2.06% cost**) |

Repeated command CPU medians are 15.920 → 15.743ms / 21.069 → 21.673ms,
15.732 → 16.060ms / 15.561 → 16.035ms, and 8.484 → 8.563ms /
16.138 → 16.100ms, respectively. Additional rejected reference brackets
remain in the review manifests. These controls do not prove that each timing
cost is caused by signature lookup; costs remain visible rather than being
dismissed as noise.

Bounded whole-command instruction checks on those controls remain effectively
unchanged: conditional writers **223,839,619 → 223,840,813** plain and
**310,558,096 → 310,558,990** optimizing; pure tail **213,719,472 →
213,716,839** / **214,103,227 → 214,098,515**. These validate unchanged
bytes independently. Near-identical work counts do not establish identical
wall time or dismiss the measured control costs.

Plain dependency-analysis instructions stay near flat at **15,507,706,416 →
15,509,334,518 (0.011% increase)**, with unchanged named incoming malloc/free
calls **35,639,396 / 111,085,643**. This plain-pass scope does not measure
optimizing raw-cleanup table reuse. Small whole-command instructions are
77,710,218 → 77,711,474 / 169,373,687 → 169,306,686. Plain named allocator
calls remain 307,635 / 305,968; optimizing requests/frees fall by **135 each**,
487,682 → 487,547 / 486,015 → 485,880. Counts are incoming calls, not bytes
or net live objects. Three-sample RSS medians are 274,592 → 254,920KiB
plain, ranges 252,828–274,692 / 254,352–273,028; optimizing **289,616 →
290,912KiB (0.45% increase)**, ranges 289,592–289,816 / 290,128–309,764.
Three samples do not establish a causal memory win or regression.

Info, fmt, five native guards, the dispatcher guard, **12,974 default tests**,
release CLI and all controls pass. The fixed 126-module / 1,029-observation
original/v133 replay and active joined/pure/conditional replays match; measured
before/after and traced/untraced bytes stay identical and independently validate.
Public interfaces are unchanged. Local `.tmp/dae2-lean-20260929/` `v27`
records use candidate SHA-256
`679a713e3328d84a17b6cdeb5d3a20037338ab40ff011c787cffc82e25c1c0a1`.
Fresh verified-v133 pass medians are small 4.222/1.009660ms (**4.18×**)
and 13.055/3.181020ms (**4.10×**), MAD 0.074/0.002370ms and
0.502/0.011590ms; large **4001.091/503.817ms (7.94×)** and
**7659.620/1784.100ms (4.29×)**, MAD 18.437/7.730ms and 52.911/13.830ms.
One warmup, three samples and CPU 6 are retained; separate oracle cohorts do
not establish causal before/after gains.
The optimizing canonical size gap stays **422,470 bytes**. This is a quadratic
scaling fix, not closure of the multi-second pass gap; long fuzz remains deferred.

## September 29, 2026 cached dependency minima

The expanded CFG's preceding-dependency collector now consults the existing
per-node minimum cache before walking an operand subtree that cannot itself be
carried. A subtree whose earliest eligible value is at or after the current
source-order bound cannot contribute a preceding value. Direct carried values
keep their earlier fast path; selected value order and consumer bounds remain
unchanged. The cache is filled lazily within the existing immutable facts
snapshot, with no new node-sized storage. An in-progress minimum is conservative
for malformed cyclic query inputs; normal facts construction still requires
acyclic operand graphs.

The [four focused guards](../../../../../src/ir/hot_source_order_minimum_wbtest.mbt)
first expose a missing private kernel, then the instrumented original collector
fails **33 operand queries != 2**. Two semantic guards are initially green;
they are not claimed as original semantic failures. The work budget applies to
collection with a populated minimum cache, excluding the one-time cache fill.
Cold/repeated results match the [frozen V24b collector and query](../../../../../src/ir/hot_source_order_minimum_reference_wbtest.mbt),
including calls, local state, loads/traps, references, typed control and shared
inputs; scratch rows reset between queries.

[Twelve native controls](../../../../../src/ir/hot_source_order_minimum_perf_wbtest.mbt)
separate warm queries from cold facts construction plus the first query:

| Effectful leaves | Original → selected warm mean | Original → selected cold mean |
| --- | --- | --- |
| 8 | 407.40 → 148.25ns | 1.60 → 1.60µs |
| 128 | 4.71µs → 167.72ns | 17.63 → 17.81µs (1.02% cost) |
| 1024 | 39.34µs → 152.45ns | 139.20 → 138.87µs |

Matched V24b/V26 large compiler pass medians improve **4214.100 →
4094.742ms (2.83%)** / **7355.494 → 7215.137ms (1.91%)**, MAD
40.017/12.972ms and 23.468/12.770ms. Small medians are 4.146 → 4.064ms /
11.933 → 11.199ms, MAD 0.013/0.005ms and 0.222/0.141ms. Rejected small
reference brackets 1.337/1.458/1.386 remain saved. Tee plain costs **3.889 →
3.933ms (1.13%)**, MAD 0.032/0.029ms; tee optimizing is 107.362 →
106.651ms, MAD 0.084/0.267ms. Joined readers stay near flat at 19.432 →
19.354ms / 29.512 → 29.559ms. Pure-tail medians are 12.213 → 11.984ms /
13.098 → 13.008ms. Conditional writers are 11.687 → 11.716ms /
**16.618 → 17.014ms (2.38% optimizing cost)**, MAD 0.225/0.019ms and
0.159/0.105ms. These controls remain costs/limits rather than being hidden by
the warm-helper gain.

Dependency-analysis instructions fall **17,113,284,401 → 15,507,706,416
(9.38%)**. Named incoming malloc/free calls fall by **36,784 each**,
35,676,180 → 35,639,396 / 111,122,427 → 111,085,643; these are scoped
calls, not allocation bytes or net live objects. Small whole-command instruction
counts are 78,693,572 → 77,714,999 / 170,356,809 → 169,374,480.
Three-sample RSS medians are 257,852 → 256,616KiB plain and **290,712 →
302,024KiB optimizing (3.89% increase)**. Ranges 256,552–280,756 /
256,228–268,952 and 289,796–302,228 / 290,028–313,304 overlap; this does
not establish a causal memory gain or regression.

Info, fmt, four native guards, **12,968 default tests**, release CLI and all
controls pass. The 126-module / 1,029-observation original/v133 replay, two
active 7-module / 28-observation lanes and conditional 7-module / 42-observation
lane match, with unchanged before/after and traced/untraced bytes plus independent
validation. Fresh verified-v133 medians are small 4.162/1.017660ms and
13.704/3.195640ms; large **4042.251/489.438ms (8.26×)** and
**7554.394/1767.560ms (4.27×)**. One warmup, three samples, CPU 6 and frozen
hashes are retained. Oracle cohorts are not causal before/after experiments.
Optimizing canonical output still adds **422,470 bytes**; neither pass is closed.
Local `.tmp/dae2-lean-20260929/` evidence uses `v26`, candidate SHA-256
`0786d1da42c7fd2e72e23c5d2b575e92a69282ad17993b4fdf8eba7066d46e8a`.
Long fuzz remains deferred; operand/header reads, scratch churn, overlapping
access lists, lift/lower and optimizing cleanup remain active targets.

## September 29, 2026 bounded and linear source union

Admitted reverse-flow actions already have one node-to-block owner. Source
union now uses that existing index and seen workspace after eight source
lanes; the first lanes keep bounded contiguous searches. Each writer block
then contributes once, including a separately tracked query-root loop write.
Completed sources reset writer marks in linear time before ordinary visited
state resets. Entry sources remain disjoint and unique; unadmitted/shared
query callers retain the original general union, while full graph admission
still sends shared actions to sparse flow. No new node/block-sized storage or
public graph field is added. Source order and immutable row borrowing remain.

The nullable owner index is constructed once per build. Initial generated C
showed its constructor increment/decrement around each query; final native C
has **zero constructor increments in the query call branch**. This is
reference-count work, not a heap-box/allocation claim; incoming allocator
calls are unchanged. The automated native guard ran after C regeneration and
is green refinement evidence, not an initial-trial red. Its local mistagged
record was corrected rather than used as baseline evidence.

Seven [bounded guards](../../../../../src/ir/local_graph_source_union_wbtest.mbt)
cover ordered sources, cached-row identity, clean scratch, root loop writes,
parallel/exceptional edges, shared-action fallback and complete graph fields
in both operand modes. Initial zero-search work guards genuinely fail
**22 != 0 / 3 != 0** while semantic guards are green. The first all-marking
trial passes but costs **3.10%/1.65%** on matched compiler pipelines
(4106.148 → 4233.424ms / 7342.394 → 7463.294ms), MAD 27.909/2.743ms and
146.586/53.792ms. Its dependency instructions increase 0.18%; requests/frees
are unchanged. Those results remain historical and do not sign the refinement.

The refined contract uses at most eight-lane searches, with promotion for
wide rows. Tiny-row actual mark-write/reset work fails first, **2 != 0**,
then becomes zero; the wide 16-writer/two-edge guard proves bounded searches
and actual promotion with the exact original row. The earlier zero-search
expectations become bounded-search budgets; source/ownership assertions stay.
Eight [native query controls](../../../../../src/ir/local_graph_source_union_perf_wbtest.mbt)
force fresh rows, preserve indices/scratch and consume the complete result:

| Writers | Original search → bounded/linear mean |
| --- | --- |
| 1 | 90.47 → 89.82ns |
| 8 | 198.89 → 216.56ns (**8.88% cost**) |
| 128 | 6.17 → 2.03µs (**67% gain**) |
| 2048 | 977.16 → 27.24µs (**97% gain**) |

Compiler pipelines stay near flat: **3928.146 → 3910.220ms (0.46%)** /
**6707.366 → 6706.087ms (0.02%)**, MAD 72.691/41.775ms and
43.367/10.613ms. Small 4.152 → 4.159ms / **11.085 → 11.350ms (2.39% cost)**,
MAD 0.016/0.063ms and 0.025/0.242ms; tee 3.743 → 3.757ms /
**104.962 → 106.491ms (1.46% cost)**, MAD 0.005/0.012ms and
0.218/1.030ms. Joined-reader medians are 18.409 → 18.582ms /
27.859 → 27.961ms. Pure-tail **11.435 → 11.941ms (4.43% plain cost)** /
11.823 → 11.836ms, MAD 0.067/0.379ms and 0.162/0.274ms. Rejected brackets
1.184/1.221/1.214 are retained. Conditional-write pipelines are near flat,
11.312 → 11.206ms / 16.381 → 16.194ms, MAD 0.060/0.035ms and
0.170/0.164ms. Keep costs/dispersion; helper gains are not compiler gains.

Dependency instructions increase **17,063,254,721 → 17,113,284,401 (0.29%)**,
while requests/frees stay **35,676,180 / 111,122,427**. Small command
instructions increase 78,678,660 → 78,689,078 / 170,355,450 → 170,361,588,
with unchanged requests/frees. RSS medians are 280,804 → 257,560 KiB,
ranges 256,516–281,476 / 256,068–258,648; optimizing 292,200 → 292,004 KiB,
ranges 292,096–314,712 / 291,928–302,000. Overlap and three samples do not
establish a causal memory win. Retain this slice for bounded/linear scaling,
not as a general compiler or allocation win; small-row costs remain open.

Info/fmt, seven native guards, **12,964 default wasm-gc tests**, release CLI,
eight controls, fixed 126 modules/1,029 observations, two seven-module/
28-observation lanes and conditional seven-module/42-observation replay pass.
All before/after and traced/untraced bytes match and independently validate.
Public interfaces are unchanged. Frozen native SHA-256 is
`ad7f6c03df341abcd1eb325115b1ef084d98c7bf5da3271b6be1a45be56d3660`.

Fresh verified-v133 medians are small 4.588 / 1.027220ms (**4.47×**) and
13.632 / 3.176530ms (**4.29×**); large 3895.690 / 446.419ms (**8.73×**)
and 7325.910 / 1670.670ms (**4.39×**). MADs are 0.005/0.018150ms,
0.845/0.026540ms, 7.389/0.639ms and 52.810/2.360ms. CPU 6, one warmup,
three samples and unchanged canonical sizes retain the **422,470-byte
optimizing gap**. Separate cohorts do not establish causal ratio gains.
Local `.tmp/dae2-lean-20260929/` v24/v24b manifests, red/validation/bench,
fixed/active/conditional/RSS/work/oracle and constructor records own evidence.
Next are unused-local entry preflight, query header work, preceding-dependency
scratch, field reads and optimizing cleanup. Aggregate fuzz remains deferred.

## September 29, 2026 immutable entry reads

Full reverse LocalGraph construction now admits each action once, records
which locals have any write, and resolves never-written reads with one
entry-origin reachability walk. It reuses the existing seen/visited/work and
nearest-write vectors; only two local-count rows are new. Reached immutable
reads share one completed entry row per local. Unknown/unreachable reads stay
empty, including closed cycles and entries with admitted predecessors.
Exceptional-edge filtering and shared-action sparse fallback are unchanged.
All graph fields and source ordering remain complete; this is not a partial
sources-only public API.

Four [bounded guards](../../../../../src/ir/local_graph_entry_reads_wbtest.mbt)
compare every graph field with the frozen preceding builder, including
written definitions, default/parameter/reference locals, both operand modes,
exceptional entry backedges, reachable/unreachable cycles, and shared actions.
The actual per-block cache budget fails first, **67 != 51**, while the three
semantic guards are initially green. Six
[native full-build controls](../../../../../src/ir/local_graph_entry_reads_perf_wbtest.mbt)
include all graph construction and consume the completed result:

| Conditional writes | Original → immutable-entry build |
| --- | --- |
| 8 | 3.53 → 2.62µs |
| 64 | 78.86 → 16.45µs |
| 512 | 4.23ms → 154.94µs |

These improve **26%, 79%, 96%**. The new dedicated 1024-conditional-write
pipeline falls **29.287 → 11.745ms (59.90%)** / **33.833 → 16.797ms
(50.35%)**, MAD 0.060/0.048ms and 0.034/0.020ms. Its seven original/before/
after/v133 modules validate and match all 42 bounded runtime observations.
Input is 16,441 bytes, SHA-256
`d63812884c36c2742a24dd8dae7b8c4a27fb5dcd7e311dbd3545dc7f59960027`.
This is a dedicated performance lane, not an artifact-scale default test.

Three matched large compiler pairs fall **4044.453 → 3918.751ms (3.11%)**
/ **7071.974 → 6895.721ms (2.49%)**, MAD 33.823/41.118ms and
38.932/20.322ms. Small plain costs **4.037 → 4.077ms (0.99%)**, MAD
0.011/0.002ms; optimizing 11.325 → 11.316ms, near flat. Tee medians are
3.781 → 3.715ms / 108.483 → 107.940ms, MAD 0.041/0.017ms and
1.538/0.011ms. Rejected reference brackets 1.228/1.316 remain in evidence.
Joined-reader medians are 19.473 → 19.060ms / 29.753 → 28.947ms;
pure-tail **12.025 → 12.198ms (1.44% plain cost)** / 12.182 → 12.102ms,
MAD 0.056/0.340ms and 0.012/0.056ms. These controls and dispersion remain
limits; separate timing cohorts are not cumulative causal gains.

Dependency-analysis instructions fall **18,176,793,615 → 17,063,254,721
(6.13%)**, and incoming allocator requests/frees by **298,741** each:
35,974,921 → 35,676,180 / 111,421,168 → 111,122,427. Counts are named calls,
not bytes/net objects. Small whole-command instructions fall 78,762,741 →
78,683,467 / 170,418,104 → 170,356,583, with 150 fewer requests/frees in
both modes.

Untraced RSS medians are **281,536 → 282,212 KiB (0.24% plain cost)**,
ranges 281,512–283,280 / 258,060–282,308; optimizing 304,336 → 292,140 KiB,
ranges 292,104–314,440 / 292,020–314,496. Ranges overlap, so these three
samples do not establish a causal memory improvement. Preserve the extra
local-count storage and small/control costs for follow-up.

Info/fmt, four native guards, **12,957 default wasm-gc tests**, release CLI
and six controls pass. Fixed 126-module / 1,029-observation and both previous
seven-module / 28-observation replays match original/v133 results. All
before/after and traced/untraced bytes match and independently validate.
Frozen SHA-256 is
`916b6c74a5eac4d24146de60c0877185fa6b15c327712938349053f92d895ece`.
Public interfaces are unchanged; aggregate fuzz remains deferred.

Fresh verified-v133 medians are small 4.169 / 0.981300ms (**4.25×**) and
12.680 / 3.155730ms (**4.02×**); large 4017.808 / 437.888ms (**9.18×**)
and 7334.642 / 1718.580ms (**4.27×**). MADs are 0.089/0.003427ms,
0.425/0.059750ms, 2.472/0.062ms and 22.521/16.740ms. The input, one warmup,
three samples and CPU 6 are retained. The optimizing canonical size gap is
still **422,470 bytes**; no shape-win classification is inferred.

Evidence is local `.tmp/dae2-lean-20260929/` v23 manifests, red, validation,
bench, fixed/active/conditional-write runtime records, matched compiler,
work/allocator profiles and verified-v133 folders. Next are linear writer
source union, scratch reuse, field reads and optimizing cleanup. The entry
preflight can still walk for a never-read unwritten local; refine that trigger
without changing unknown rows. Buffer lifetime/memory follow-up stays open.

## September 29, 2026 fused writer metadata

Forward, reverse and sparse LocalGraph builders now construct their existing
writer-local and tee fields in one live arena scan. Both scalar vectors have
the known node-count span from allocation, with unchanged deleted/nonwriter
sentinels. The private two-reference value result adds no retained graph
field. Reverse flow borrows the completed local-ID index for predecessor
queries and retains both fields for its final graph; tee storage is therefore
available earlier in that build than in the original separate scans.

Three [bounded guards](../../../../../src/ir/local_graph_write_facts_wbtest.mbt)
cover zero/15-node spans, sets/tees/nonwriters, deletion-index fallback,
revision/free-list ownership and all three builders in both operand modes.
The baseline combines the original helpers and genuinely fails its known-
span work assertion, **16 != 15**, before the fixed-span fused implementation.
Its two semantic guards are green before; no semantic failure is claimed.
Eight [native controls](../../../../../src/ir/local_graph_write_facts_perf_wbtest.mbt)
include allocation of both result vectors and consume their complete rows:

| Roots / writer density | Separate → fused mean |
| --- | --- |
| 128 / sparse | 1.21µs → 421.89ns |
| 128 / dense | 2.70µs → 992.09ns |
| 8192 / sparse | 66.15 → 24.14µs |
| 8192 / dense | 157.90 → 59.79µs |

Helper gains are **62–65%**. Dependency-analysis instructions fall
**18,429,845,490 → 18,176,793,615 (1.37%)**; incoming allocator requests/frees
fall by **89,396** each, 36,064,317 → 35,974,921 /
111,510,564 → 111,421,168. These count named calls, not bytes/net objects.
Small whole-command instructions fall 78,940,083 → 78,751,426 /
170,611,371 → 170,425,152, with 126 fewer requests/frees in both modes.

Three matched compiler pairs are near flat: large **3802.798 → 3783.394ms
(0.51%)**, MAD 1.059/1.018ms; optimizing **6619.884 → 6609.561ms (0.16%)**,
MAD 31.514/50.202ms. Small medians are 3.883 → 3.810ms / 10.672 → 10.664ms;
tee 3.566 → 3.639ms (**2.05% cost**) / 106.013 → 102.011ms. Joined-reader
medians are 20.413 → 19.234ms / 29.388 → 30.724ms (**4.55% optimizing cost**),
MAD 0.851/0.109ms and 0.488/1.564ms. A 1.714 reference-bracket retry is kept;
host visibility and dispersion do not support a causal active-workload gain.
Pure-tail medians are 12.176 → 12.103ms / 12.147 → 12.088ms, near flat.

Untraced RSS medians are **257,288 → 269,580 KiB**, ranges
256,588–282,656 / 269,412–281,312; optimizing 292,044 → 291,896 KiB,
ranges 292,012–292,064 / 291,848–292,236. Preserve the **4.78% plain median
increase** and earlier tee-buffer lifetime; overlapping ranges establish no
causal memory win. Further memory/lifetime work remains open.

The candidate passes info/fmt, native debug, **12,953 default wasm-gc tests**,
release CLI and all eight controls. Fixed 126-module / 1,029-observation and
both seven-module / 28-observation active replays match original/v133 results.
All before/after and traced/untraced bytes match and independently validate.
Public interfaces are unchanged. Frozen SHA-256 is
`5ddc236e0a05eb81f6b4ba31692300a5cb6d0f6dd61b46f2f5f603b343a440de`.

Fresh verified-v133 medians are small 4.356 / 0.937708ms (**4.65×**) and
13.444 / 3.077960ms (**4.37×**); large 3759.060 / 416.509ms (**9.03×**)
and 6949.506 / 1595.020ms (**4.36×**). MADs are 0.051/0.012233ms,
0.160/0.066730ms, 0.934/1.037ms and 1.028/3.940ms. CPU 6, one warmup and
three samples remain; ratios from different cohorts are not causal changes.
Canonical sizes retain the **422,470-byte optimizing parity gap**.

Evidence uses local `.tmp/dae2-lean-20260929/` v22 manifests, actual red,
validation/bench logs, dependency/allocator/instruction profiles, matched
fixed/active/RSS records and oracle folders. Next targets are repeated
never-written-local reaching queries, quadratic source membership and
preceding-dependency working buffers. Preserve exact entry/unreachable
source rows and shared-action fallback; aggregate fuzz remains deferred.

## September 29, 2026 checked input-header fields

Operand-input queries keep the complete checked node-admission contract, then
read the arena header locally. The existing private admission helper has the
same live-index and legacy free-list fallback as `hot_node_get`; no unchecked
read, operand policy, retained cache, revision or public API changes.

The first two [bounded guards](../../../../../src/ir/hot_lower_input_header_wbtest.mbt) pass against the original query: they are
semantic/ownership controls, not claims of a prior semantic failure. They
compare the frozen original complete input query on real CFG control fixtures,
block/if/multivalue loop inputs, duplicate tuple lanes, intentionally supported
temporary absent slots, deletions and an incomplete deletion index, including
copy counts and unchanged revision/free storage. Six [native controls](../../../../../src/ir/hot_lower_input_header_perf_wbtest.mbt) consume
every complete operand query at 8/64/512 control groups outside setup.

The initial `v21` trial called the private full-header reader directly. Its
first native guard observed zero public-name calls, but native inspection
showed **15,921,704** calls to the private header-returning symbol from the
same input query. That renamed boundary did not meet the intended work
contract. The guard now includes both public and private complete-header
readers and fails on both original and initial trial. The initial profile
falls 0.86%, 18,434,089,586 → 18,275,167,806 instructions, with unchanged
36,064,317 requests / 111,510,564 frees. It is retained trial evidence, not
proof of boundary elimination. Initial matched large medians regress
3849.195 → 3889.291ms (1.04%, MAD 1.074/2.554) and optimizing
6653.685 → 6680.301ms (0.40%, MAD 14.018/32.700). Small 3.882 → 3.924ms /
10.961 → 10.863ms, tee 3.576 → 3.545ms / 101.440 → 99.771ms; joined
18.547 → 18.447ms / 28.041 → 28.004ms; pure-tail 11.752 → 11.585ms /
11.758 → 11.549ms. Its RSS ranges overlap, so no causal claim is made.

The refined `v21b` calls checked admission, then reads `func.nodes[id]` in
the query. Unlike the initial trial, the intended native contract is no
complete-header return calls from this reader, regardless of symbol name.
The strengthened guard passes at **zero** full-header return calls; checked
admission still runs, so this is not a reduction in all query/validation work.
Final dependency instructions are nearly flat, **18,434,089,586 →
18,429,845,490 (−0.023%)**. Requests/frees stay **36,064,317 / 111,510,564**.
Small whole-command instructions increase slightly, 78,936,034 → 78,941,581 /
170,584,657 → 170,617,575, with unchanged allocator calls in both modes.

Final complete-query controls at 8/64/512 groups are **1.40 → 1.21µs**,
**11.04 → 9.80µs**, and **88.64 → 78.18µs** (11–14%); setup and arena
allocation are outside timing. Matched large medians improve
**3877.834 → 3834.564ms (1.12%)**, MAD 6.644/3.253ms, while optimizing
**6637.800 → 6620.646ms (0.26%)**, MAD 35.379/9.621ms, is near flat.
Small medians are 4.152 → 4.037ms / 10.719 → 10.669ms; a 1.192 reference
bracket retry is retained. Tee medians are 3.522 → 3.518ms /
101.465 → 103.818ms: preserve the **2.32% optimizing control cost**.

Plain untraced RSS median increases **257,904 → 259,196 KiB**, ranges
257,504–258,336 / 258,624–281,912. Optimizing medians are
292,000 → 291,908 KiB, ranges 291,924–292,292 / 291,848–293,504.
Record the plain increase (0.50%) without a causal claim from three samples;
optimizing ranges overlap. No retained cache or node-array buffer was added.

Final verified-v133 medians are small 4.397 / 0.937713ms (**4.69×**) and
13.295 / 3.044530ms (**4.37×**); large 3776.687 / 421.478ms (**8.96×**)
and 6932.212 / 1600.160ms (**4.33×**). MADs are 0.086/0.004388ms,
0.260/0.006610ms, 2.512/2.657ms and 0.661/11.390ms. Ratios retain CPU 6,
one warmup and three samples, and do not measure a causal ratio change
against older cohorts. Canonical bytes/sizes retain the **422,470-byte
optimizing parity gap**; smaller plain output alone is not a proven win.

Both iterations pass info/fmt, native debug, **12,950 default wasm-gc tests**,
release CLI, six controls and fixed 126-module / 1,029-observation replays.
Byte-exact before/after and traced/untraced output independently validates.
Public interfaces are unchanged. Initial SHA-256 is
`a03464a2316394b2197020f74a20175d1468a5afc313e176ddbabd50533ee657`; final
`f4538c12dd02d6dfa54a94f2829fe8f13fc01f3bb80f5f735646cd6e7810f679`.

Evidence: local `.tmp/dae2-lean-20260929/` v21/v21b manifests, validation and
bench logs, strengthened red/work guards, dependency/allocator/instruction
profiles, fixed/paired/RSS records and verified-v133 oracle folders. Both final
active lanes pass seven modules / 28 matching original/v133 observations, with
identical before/after bytes. Joined-reader medians are 18.587 → 18.474ms /
27.836 → 27.675ms; pure-tail 11.434 → 11.433ms / 11.953 → 11.899ms,
all near flat. Larger targets
are LocalGraph writer scans, quadratic source membership and unused read rows,
and preceding-dependency working buffers. Aggregate fuzz stays deferred.

## September 29, 2026 single core validation

The public all-verifier called the complete core verifier before calling the
control verifier, which starts by calling core again. No mutation or callback
separates those checks. The all-verifier now delegates to the same complete
control entry point once; standalone core/control APIs, their validation
coverage, cache argument behavior and error order remain unchanged. The private
work counter is per verification, not per node; it adds no retained cache.

Two [bounded guards](../../../../../src/ir/hot_verify_core_once_wbtest.mbt)
fail first with **2 != 1** on the original two-call sequence, then check one
complete core walk on empty, ordinary, control and legacy-catch functions.
They compare original all-verifier results, unchanged revisions, both cache
argument types, core-before-control error precedence, malformed exit arity
and orphan catch rejection. The earlier helper-raises compile failure is kept
separate from the actual red work assertion. Eight
[native controls](../../../../../src/ir/hot_verify_core_once_perf_wbtest.mbt)
compare complete validation with and without legacy catches at 128/4096 roots.

The first single-core candidate (`v20`) still boxed an explicitly forwarded
`None` work counter. Generated C identifies the allocation, and a focused
native cost guard fails with **17 != 0** on the small command while its raw
bytes independently validate and equal the matched output. The first guard
attempt used a canonical oracle output path and failed its byte comparison;
that harness failure is retained separately and is not the allocation red.
The final `v20b` default path calls the uncounted complete control entry point
and keeps explicit counters on their instrumented path. The cost guard is
now green at **zero** default-forwarding allocations, with unchanged bytes.
Source-only suspicion of per-query reverse-flow counter boxes is superseded:
its generated C already forwards the nullable pointer directly to the inner
kernel. No change is justified for that suspected allocation.

Final complete-verifier controls:

| Roots / legacy catch | Original duplicate → single mean |
| --- | --- |
| 128 / absent | 3.24 → 1.86µs |
| 4096 / absent | 100.19 → 56.43µs |
| 128 / present | 5.12 → 3.50µs |
| 4096 / present | 135.14 → 90.03µs |

The initial v19→v20 dependency profile removes **9,887** direct core calls;
12,718 core calls from control entry remain. Instructions fall
**19,116,248,490 → 18,436,041,744 (3.56%)** and incoming requests/frees by
**280,661** each (36,354,865 → 36,074,204 / 111,801,112 → 111,520,451).
Small whole-command instructions fall 79,499,491 → 78,939,286 /
171,144,584 → 170,595,337; requests/frees fall by 481 in both modes.
Three matched compiler pairs are near flat: large **3899.809 → 3880.437ms
(−0.50%)**, MAD 14.442/10.174ms; optimizing **6678.827 → 6636.707ms
(−0.63%)**, MAD 20.770/17.782ms. Small medians are 3.963 → 3.875ms /
10.782 → 10.736ms, tee 3.532 → 3.561ms / 100.914 → 103.071ms.
Active joined-reader medians are 18.764 → 19.156ms / 27.858 → 27.618ms;
pure-tail 11.571 → 12.079ms / 12.527 → 12.172ms. Preserve the plain active
and optimizing tee costs and dispersion. Managed visibility does not prove
quiet-host timing. Untraced large RSS medians are 271,816 → 269,588 KiB,
ranges 259,544–281,584 / 255,516–270,484; optimizing 292,076 → 314,440 KiB,
ranges 292,012–294,080 / 292,172–314,536. The optimizing median increase is
recorded; overlapping ranges do not establish a causal memory claim.

The initial current-source v133 renewal gives small medians 4.090 / 0.950781ms
(**4.30×**) and 12.090 / 3.032920ms (**3.99×**); large
3853.517 / 418.791ms (**9.20×**) and 6995.914 / 1601.970ms (**4.37×**).
MADs are 0.023/0.001793ms, 0.274/0.005700ms, 21.610/1.912ms and
10.893/6.670ms. These fresh cohorts do not measure causal ratio changes.
Initial frozen SHA-256 is
`49427761448648d73764a36f88a5179c4e74adaf5a006b7fc5233d6e4e9d975e`;
final `v20b` is
`13312635576e7a89a4e616faea3d50a73057b44973ff21e4e53e6abb7a8e12ca`.
Both pass info/fmt, native debug, all **12,948 default wasm-gc tests**, release
CLI and eight controls. Initial fixed/active replays and the final fixed replay
pass with exact before/after bytes and original/v133 observations; final
measurements are separately owned below rather than silently replacing this
initial control. Public interfaces remain unchanged.

The final v20→v20b refinement removes **9,887** more dependency-window
requests/frees: **36,064,317 / 111,510,564** remain. Instructions fall another
1,952,158 (0.0106%), to **18,434,089,586**. Relative to the original v19 core
sequence, final instructions are down **3.57%** and requests/frees by
**290,548**. These are named call/work counts, not allocation-byte or retained-
object counts. Small requests/frees drop by 17 in both modes; instruction
controls are near flat, 78,932,831 → 78,931,546 /
170,586,274 → 170,590,506, preserving the optimizing cost.

Three refinement pairs give near-flat large medians **3847.115 → 3854.029ms
(+0.18%)**, MAD 13.862/10.605ms, and optimizing **6660.027 → 6617.547ms
(−0.64%)**, MAD 26.241/13.900ms. Small medians are 3.998 → 3.960ms /
10.860 → 10.936ms; tee 3.493 → 3.561ms / 100.850 → 101.048ms; joined
readers 18.418 → 18.400ms / 27.861 → 27.810ms; pure-tail
11.474 → 11.467ms / 11.679 → 11.614ms. Do not multiply gains across these
separate cohorts. Refinement RSS medians are 281,644 → 281,308 KiB,
ranges 258,656–281,980 / 256,968–281,668; optimizing
304,304 → 292,004 KiB, ranges 292,200–314,656 / 291,900–302,116. Overlap
establishes no causal memory gain. Final fixed and both active replays match
all bytes and original/v133 observations, with independent validation.

Final verified-v133 medians are small 4.313 / 0.961476ms (**4.49×**) and
12.425 / 3.113380ms (**3.99×**); large 3869.286 / 422.985ms (**9.15×**)
and 7049.952 / 1605.100ms (**4.39×**). MADs are 0.089/0.027601ms,
0.212/0.058020ms, 6.175/2.496ms and 14.445/1.620ms. They retain CPU 6,
one warmup and three samples; new-cohort ratios are not causal gains over
prior sweeps. The large sweep and queued profile steps were interrupted by
the server restart. Completed validation, small-oracle, fixed replay and
memory records were retained; only unfinished steps were resumed. The partial
large folder/log remains interrupted evidence, and the successful renewal is
`oracle-v20b-large-recovered/`. Canonical sizes are unchanged; the
**422,470-byte optimizing gap remains open**, and smaller plain output alone
is not a proven win.

Local `.tmp/dae2-lean-20260929/` evidence uses `v20` and `v20b`, including
source manifests, red/validation/bench/native-cost logs, fixed/paired/active
replays, `dependency-cost-v20{,b}.json`, small instructions/allocator and RSS
records, and initial/final oracle folders. Both seven-module active lanes
observe 28 matching results; the fixed lane retains 126 modules / 1,029
observations. Final source is frozen before later experiments advance it.
The pinned input/oracle hashes remain below. The next confirmed cost is the
operand-query helper's **15,921,704** public complete-header reads; consider
the existing checked private implementation with native call/instruction
and full pipeline controls. Aggregate fuzz remains deferred by request.

## September 29, 2026 catch-layout preflight

The full control verifier already scans every live HOT node. It now records
whether that scan encounters `Try` or `Catch`; only those operations can affect
the legacy catch-payload layout check. A catch-free function skips the unused
admission vector and two arena walks. Legacy tries and live orphan payloads
still run the original checker; core validation, branch checks, handler checks
and error precedence remain intact. This is a preflight for a vacuous check,
not an unchecked validation entry point or a revision cache.

Two [bounded guards](../../../../../src/ir/hot_verify_catch_layout_wbtest.mbt)
compare the frozen original full control verifier, unchanged revisions,
valid catch payloads, invalid function-exit arity and live orphan payloads.
The valid catch-free work assertion fails first with **1 != 0**, then passes;
valid legacy catches and orphan rejection each still invoke the layout checker
once. Eight [native controls](../../../../../src/ir/hot_verify_catch_layout_perf_wbtest.mbt)
include the complete core/control validation:

| Roots / legacy catch | Original → guarded mean |
| --- | --- |
| 128 / absent | 2.87 → 1.82µs |
| 4096 / absent | 88.62 → 56.50µs |
| 128 / present | 3.56 → 3.57µs |
| 4096 / present | 95.84 → 93.44µs |

Dependency-window instructions fall **19,515,570,507 → 19,116,248,490
(2.05%)**. Incoming allocator requests/frees fall by **38,154** each,
36,393,019 → 36,354,865 / 111,839,266 → 111,801,112. The original layout
checker had 12,718 named calls; the catch-free large profile has none after
the guard. These are named call counts, not byte or retained-object counts.
Small instructions fall 79,872,223 → 79,493,215 / 171,579,405 → 171,144,932;
requests/frees fall by 63 plain and 75 optimizing.

Three alternating v18→v19 large pairs give DAE2 **3982.634 → 3925.734ms
(−1.43%)**, MAD 4.410/4.675ms, and optimizing **6788.859 → 6702.398ms
(−1.27%)**, MAD 7.191/6.543ms. Small medians are 3.957 → 3.924ms /
11.039 → 10.891ms; tee 3.575 → 3.522ms / 101.305 → 102.764ms.
The small optimizing bracket retries reference drift 1.157. Preserve the
optimizing tee cost and dispersion; managed visibility does not prove quiet
host timing. Active joined-reader medians are 19.328 → 18.664ms /
28.353 → 27.974ms; pure-tail 12.280 → 11.736ms / 12.417 → 11.778ms.
Three alternating untraced large RSS samples give plain medians
282,176 → 258,780 KiB, ranges 260,340–282,608 / 257,272–269,344;
optimizing 309,864 → 292,200 KiB, ranges 292,020–314,400 / 292,020–292,216.
Overlapping ranges do not establish a causal memory gain.

Info/fmt, native debug, all **12,946 default wasm-gc tests**, release CLI and
eight controls pass. Exact before/after/traced bytes, independent validation,
126 modules / 1,029 original/v133 observations and both seven-module /
28-observation active replays pass. No public API changes.

The freshly frozen current-source v133 renewal uses CPU 6, one warmup and
three samples. Small pass-local medians are 4.331 / 0.966971ms (**4.48×**) and
12.265 / 3.135380ms (**3.91×**); large 3888.417 / 423.069ms (**9.19×**)
and 7048.657 / 1607.030ms (**4.39×**). MADs are 0.080/0.000742ms,
0.327/0.108670ms, 12.981/0.328ms and 10.373/0.380ms. These fresh cohorts
are not paired ratio gains over v18. Canonical sizes retain the values below;
the **422,470-byte optimizing gap remains open**, and smaller plain output
alone does not prove a Starshine win.

Local `.tmp/dae2-lean-20260929/` evidence uses `v19`: source manifest,
red/validation/bench logs, fixed/paired/active replays, `dependency-cost-v19.json`,
small instruction/allocator and RSS records, and `oracle-v19-{small,large}/`.
Frozen candidate SHA-256 is
`9fafad5c41d229a788a04e43646a518e38c0549e526c099e4e78704bea00afcb`;
before is v18 `3fef08348d42db75886acb76d0acf548f2dad245ba32996213ad0045e3332155`.
Pinned input/oracle hashes remain below. Source inspection/profile attribution
also confirms the all-verifier's duplicate core call: 9,887 direct calls in
addition to 12,718 control-entry core calls. That separate work remains open
at this checkpoint. Aggregate fuzz remains deferred by request.

## September 29, 2026 empty continuation-query guard

The CFG builder already scans every live node for continuation instructions.
When that scan leaves its continuation cache empty, segmentation now uses a
Boolean query that returns false directly and block processing skips the empty
target loop. Nonempty caches retain the original target aggregation, ordering
and branch-edge construction. No extra retained buffer or public API is added.

Three [bounded guards](../../../../../src/ir/cfg_continuation_guard_wbtest.mbt)
cover published-row ownership/order, empty and cold caches, frozen original
segmentation, complete partial-CFG/root maps and both operand modes. Published
rows are opaque cache facts, not a new runtime continuation fixture. The initial
red compile lacks the new private helper; it establishes the new work/API
contract rather than a preexisting semantic failure. Eight
[native controls](../../../../../src/ir/cfg_continuation_guard_perf_wbtest.mbt)
include fresh builder/source-fact construction:

| Workload | List queries → guarded mean |
| --- | --- |
| 128 empty queries | 1.74µs → 717.54ns |
| 8192 empty queries | 109.51 → 45.20µs |
| Region, 64 groups | 43.58 → 41.71µs |
| Region, 512 groups | 347.47 → 333.60µs |

Dependency-window instructions fall **20,041,432,123 → 19,515,570,507
(2.62%)**. Incoming allocator requests fall **40,733,403 → 36,393,019**:
**4,340,384 fewer (10.66%)**. Frees fall by the same count,
116,179,650 → 111,839,266. These are named call counts, not byte or retained-
object measurements. Small command instructions fall 80,271,379 → 79,877,693 /
171,954,261 → 171,561,201; each removes 3,241 requests and frees.

Three alternating v17→v18 large pairs give DAE2 **4259.192 → 4218.427ms
(−0.96%)**, MAD 13.736/37.014ms, and optimizing **7317.563 → 7211.068ms
(−1.46%)**, MAD 128.740/11.458ms. Small medians are 4.219 → 4.245ms /
11.372 → 11.398ms; tee 3.846 → 3.859ms / 103.396 → 105.478ms. Active
joined-reader medians are 20.785 → 20.016ms / 30.023 → 30.248ms; pure-tail
13.184 → 13.175ms / 13.428 → 13.223ms. Preserve the optimizing tee/control
costs and reference-drift retries (1.205 small and 1.199 pure-tail). Managed
process visibility does not prove quiet-host timing. Three alternating untraced
RSS samples have plain medians 257,676 → 257,544 KiB, ranges
257,608–280,724 / 257,176–282,056; optimizing 292,148 → 292,296 KiB,
ranges 292,016–314,300 / 291,852–304,340. Overlap establishes no memory gain.

Info/fmt, native debug, all **12,944 default wasm-gc tests**, release CLI and
eight controls pass. Exact before/after/traced bytes, independent validation,
126 modules / 1,029 original/v133 observations and both seven-module /
28-observation active replays pass. The current-source verified-v133 renewal
uses CPU 6, one warmup and three samples: small medians 4.364 / 0.998475ms
(**4.37×**) and 13.103 / 3.275570ms (**4.00×**); large
4170.494 / 446.723ms (**9.34×**) and 7586.644 / 1626.730ms (**4.66×**).
MADs are 0.022/0.017834ms, 0.364/0.103740ms, 33.291/4.613ms and
7.916/3.890ms. These fresh cohorts do not measure a causal ratio change over
v17. Canonical large sizes remain unchanged; the **422,470-byte optimizing
gap remains open**, and smaller plain output alone is not a proven win.

Local `.tmp/dae2-lean-20260929/` evidence uses `v18`: source manifest,
validation/bench logs, fixed/paired/active replays, `dependency-cost-v18.json`,
small instruction/allocator and RSS records, and `oracle-v18-{small,large}/`.
Frozen candidate SHA-256 is
`3fef08348d42db75886acb76d0acf548f2dad245ba32996213ad0045e3332155`;
before is v17 `e7b6149bbea19956d8adb8dcbdbef2a5857b0b30b806371ba33f8f8bbc66060c`.
Pinned input/oracle hashes are preserved below. Aggregate fuzz remains deferred
at the user's request; these bounded checks do not renew generated signoff.

## September 29, 2026 shared own-effect results

The operand-order walk already computes each node's own effects for its first
external-effect order. It now writes those contributions into the mask buffer
that all-child effect aggregation will consume. Aggregation ORs descendant
contributions in place instead of querying node flags/exact payloads again.
The operand-order and all-child walks still use their original distinct edge
sets; control-region effects cannot contaminate operand first-effect orders.
No additional node-sized array is retained, and standalone effect construction
keeps its original computation when no owned buffer is supplied.

Three [bounded guards](../../../../../src/ir/hot_source_order_own_masks_wbtest.mbt)
check exact own contributions, pointer reuse, all-child masks and operand
orders against frozen original walks. Cases cover division traps, memory and
GC reads, imported effects, control inputs, source-ordered local writes,
shared operand DAGs, deleted IDs and empty arenas. New private fields/arguments
are absent at the initial red compile; this is an API/work contract addition,
not a preexisting semantic parity failure. Ten [native controls](../../../../../src/ir/hot_source_order_own_masks_perf_wbtest.mbt)
include all fresh fact allocation and four standalone-builder comparisons:

| Construction | Original → reused mean |
| --- | --- |
| Facts, 8 roots | 15.93 → 13.33µs |
| Facts, 64 roots | 125.61 → 105.74µs |
| Facts, 128 roots | 251.16 → 209.91µs |
| Standalone masks, 8 roots | 6.47 → 6.48µs |
| Standalone masks, 128 roots | 102.91 → 102.78µs |

Dependency-window instructions fall **20,241,185,629 → 20,041,432,123
(0.99%)**. Recorded named own-effect call edges fall **7,410,967 → 3,704,362**;
the operand-order visitor retains its 3,704,362 calls. These are Callgrind
function edges, not a guarantee that every inlined evaluation appears as a
named call. Large allocator requests/frees remain 40,733,403 / 116,179,650;
small command counts also remain unchanged. Small instructions fall
80,491,061 → 80,271,203 / 172,211,670 → 171,957,006.

Three alternating v16→v17 pairs give near-flat compiler medians: large DAE2
**4270.513 → 4249.844ms (−0.48%)**, MAD 8.519/15.334ms; optimizing
**7186.294 → 7217.688ms (+0.44%)**, MAD 14.279/98.167ms. Small medians
are 4.192 → 4.173ms / 11.145 → 11.232ms; tee medians are
3.724 → 3.672ms / 105.400 → 105.614ms. Active joined-reader medians
are 20.614 → 20.275ms / 30.133 → 29.853ms; pure-tail medians are
13.441 → 13.407ms / 13.889 → 13.765ms. Preserve control costs and dispersion;
no compiler-wide timing gain is established. Managed visibility does not
establish quiet-host timing. Three alternating untraced large RSS samples give
plain medians 259,928 → 280,724 KiB (ranges 259,688–281,736 /
259,376–281,912) and optimizing 292,292 → 293,496 KiB (ranges
292,276–314,332 / 292,144–304,528). The median increases remain recorded;
overlapping ranges do not establish a causal memory increase or gain.

Info/fmt, all **12,941 default wasm-gc tests**, native debug, release CLI,
ten controls and README/API sync pass. Exact before/after/traced bytes,
independent validation, 126 modules / 1,029 original/v133 observations and
both seven-module / 28-observation active replays pass. No public API change.

The current-source oracle renewal passes with verified v133, CPU 6, one warmup
and three samples. Small pass-local medians are 4.277 / 0.999788ms (**4.28×**)
and optimizing 13.144 / 3.13785ms (**4.19×**); large are
4432.497 / 494.776ms (**8.96×**) and 7732.823 / 1763.390ms (**4.39×**).
MADs are 0.051/0.029676ms, 0.231/0.046850ms, 122.378/5.498ms and
201.165/10.210ms. These are fresh comparison cohorts, not paired ratio gains
over earlier sweeps. Canonical sizes retain the v15 values below; the
**422,470-byte optimizing gap remains open** and smaller plain output alone
is not a proven win. The rejected v16 freshness attempt remains failed evidence.

Local `.tmp/dae2-lean-20260929/` evidence uses `v17`, including its source
manifest, validation/bench/API logs, paired/fixed/active replay folders,
`dependency-cost-v17.json`, small instruction/allocator and memory records,
and `oracle-v17-{small,large}/`. Frozen candidate SHA-256 is
`e7b6149bbea19956d8adb8dcbdbef2a5857b0b30b806371ba33f8f8bbc66060c`;
before is v16 `56ecbd2857cec1234dd72015284e6c2100748d5f72221d17996d1a923171dc3d`.
The pinned large input and verified v133 oracle retain the hashes below.
Aggregate fuzz remains deferred at the user's request.

## September 29, 2026 fixed-size CFG workspaces

CFG node-to-block and label-to-target maps now allocate their known lengths
once rather than growing by repeated pushes. The node arena span includes
deleted IDs; the existing live continuation scan and exception/source facts
are unchanged. Two [bounded guards](../../../../../src/ir/cfg_fixed_workspace_wbtest.mbt)
check complete sentinel maps, exact fixed spans, dead nodes, independent
builder ownership, empty arenas and both operand modes. The first regression
fails before implementation with capacity **16 instead of 15**; both now pass.

Eight [native controls](../../../../../src/ir/cfg_fixed_workspace_perf_wbtest.mbt)
include fresh builder allocation and, in expanded mode, all source facts.
Inputs have 129/8193 scalar roots plus three labeled blocks:

| Builder | Grown → sized mean |
| --- | --- |
| 129, compact | 845.29 → 667.45ns |
| 8193, compact | 41.02 → 36.64µs |
| 129, expanded | 5.24 → 5.64µs (cost retained) |
| 8193, expanded | 302.02 → 287.62µs |

The 8193 compact selected standard deviation is 4.38µs; do not treat its mean
alone as a firm speedup. Three alternating v15→v16 compiler pairs give large
DAE2 **4558.923 → 4607.221ms (+1.06%)**, MAD 34.938/79.508ms, and
optimizing **7863.144 → 7735.328ms (−1.63%)**, MAD 158.383/78.134ms.
Small medians are 4.379 → 4.376ms / 11.689 → 11.605ms; tee medians
are 3.890 → 3.794ms / 105.939 → 105.024ms. Active joined-reader medians
are 20.799 → 21.204ms / 30.847 → 30.979ms; pure-tail medians are
13.799 → 13.671ms / 14.197 → 13.941ms. Preserve control costs and the
tee optimizing reference-drift retries. These do not establish compiler-wide
speedups; managed process visibility still does not establish quiet timing.

Dependency-window incoming allocator requests/frees each fall by **63,326**:
requests 40,796,729 → 40,733,403; frees 116,242,976 → 116,179,650.
Instructions fall **20,310,625,985 → 20,241,185,629 (0.34%)**.
Small command instructions fall 80,556,565 → 80,489,707 /
172,271,280 → 172,212,041, with 78 fewer allocator requests/frees per command.
Retain the simpler fixed-span construction for growth/work reduction without
claiming an RSS benefit. Allocator calls are not allocation bytes or live objects.

Info/fmt, all **12,938 default wasm-gc tests**, native debug, native CLI build,
eight controls, exact before/after/traced bytes and independent validation
pass. The 126-module / 1,029-observation replay and both seven-module /
28-observation active replays match original and verified v133. No API diff.
A queued v16 oracle sweep is rejected by the source-freshness guard after the
next prototype advances the worktree; retain that failed attempt, rather than
claiming a current-source sweep. The accepted v15 oracle below remains its
own historical cohort; renew against the next frozen current-source candidate.

Local `.tmp/dae2-lean-20260929/` evidence uses `v16`, including its source
manifest, `validation-v16.json`, bench/paired logs, fixed runtime and active
replays, `small-instructions-v16/` and `dependency-cost-v16.json`. Frozen
candidate SHA-256 is `56ecbd2857cec1234dd72015284e6c2100748d5f72221d17996d1a923171dc3d`;
before is v15 `7c48e6c9c62c2d3ad5278008cb05f42f73813094d5195519914466ed68b9493e`.
The large input and verified v133 oracle retain the hashes below. Fuzz is deferred.

## September 29, 2026 packed CFG segment storage

Private CFG segment metadata now occupies three consecutive integers per row
instead of one heap record per segment. A value record decodes rows only when
all fields are needed; the next-block and entry queries read just the block ID.
Public CFG blocks, root mappings, source ordering and segmentation decisions
are unchanged. The primitive backing array also avoids the previously rejected
native debug compiler limitation for arrays of custom value records.

The [three bounded guards](../../../../../src/ir/cfg_segment_storage_wbtest.mbt)
cover empty/growing storage, exact ordered fields and complete block/root
mappings against a frozen boxed reference in both operand modes. The initial
arena/API tests fail to compile before the implementation because the private
API is absent; this is not a preexisting semantic failure. The structural
comparison passes before and after. Eight [native controls](../../../../../src/ir/cfg_segment_storage_perf_wbtest.mbt)
include growth/consumption or fresh builder/source-fact/segment construction:

| Control | Boxed → packed mean |
| --- | --- |
| 128 metadata rows | 1.14µs → 488.32ns |
| 1024 metadata rows | 8.74 → 3.12µs |
| 64 segments, region construction | 48.30 → 47.11µs |
| 512 segments, region construction | 389.75 → 374.13µs |

Three alternating v13→v15 pairs give near-flat compiler timings: large DAE2
**4510.768 → 4542.607ms (+0.71%)**, MAD 25.722/20.813ms; optimizing
**7585.983 → 7544.887ms (−0.54%)**, MAD 11.476/12.469ms. Small medians
are 4.264 → 4.278ms / 11.470 → 11.418ms; tee medians are
3.866 → 3.864ms / 106.370 → 105.713ms. Active joined-reader medians
are 20.772 → 21.071ms / 31.773 → 31.361ms; pure-tail medians are
14.080 → 14.276ms / 13.786 → 14.121ms. Preserve those control costs and
the pure-tail reference-drift retry; no full-pass speedup is established.
Managed process visibility does not establish quiet-host timing.

The reason to retain this slice is measured heap churn: dependency-only
incoming `mi_malloc` calls fall **41,287,576 → 40,796,729 (490,847 fewer,
1.19%)** and `mi_free` calls fall by the same count. Instructions fall
20,329,087,979 → 20,310,625,985 (0.09%). Small whole-command allocator
requests/frees fall by 248 in each pass; instructions change
80,558,748 → 80,550,362 / 172,281,532 → 172,289,872. These scopes count
calls, not allocation bytes or net live objects. Three alternating untraced
large RSS samples give plain medians 272,216 → 253,328 KiB (ranges
252,140–273,244 / 251,280–273,772) and optimizing 292,024 → 299,264 KiB
(ranges 289,788–313,424 / 292,144–300,008). Preserve the latter cost;
overlapping ranges do not prove a memory gain or regression.

Info/fmt, all **12,936 default wasm-gc tests**, native debug guards, release CLI
build and eight controls pass. The frozen binaries preserve every measured
output byte and pass independent validation, the 126-module / 1,029-observation
replay and both seven-module / 28-observation active replays against original
and verified v133. No public interface changes.

Fresh verified-v133 pass-local medians (one warmup, three samples) remain gaps:
small DAE2 4.653 / 1.02914ms (**4.52×**), optimizing 13.213 / 3.20605ms
(**4.12×**); large DAE2 4507.166 / 523.992ms (**8.60×**), optimizing
8534.009 / 1764.800ms (**4.84×**). MADs are 0.119/0.01865ms,
0.459/0.01736ms, 17.027/1.136ms and 52.358/5.520ms respectively.
These are a new oracle cohort, not a causal ratio improvement over v13.
Large canonical sizes remain 6,132,389 / 6,232,586 bytes for plain DAE2 and
5,995,920 / 5,573,450 for optimizing; the **422,470-byte optimizing parity
gap remains open**, and smaller plain output alone is not a proven win.

Local evidence under `.tmp/dae2-lean-20260929/` uses `v15`, including the
source manifest, validation/bench logs, `pairs-v15-*`, active replay folders,
`dependency-cost-v15.json`, `small-instructions-v15/`, `memory-v15/` and
`oracle-v15-{small,large}/`. Frozen candidate SHA-256 is
`7c48e6c9c62c2d3ad5278008cb05f42f73813094d5195519914466ed68b9493e`;
before is accepted v13 `a367397e0045ee3db4cc3711135edab4b1449cca2647cb0f202f684fc14360ab`.
The oracle is verified `wasm-opt version 133 (version_133)`, SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`;
the pinned large input remains `98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
Long aggregate fuzz remains deferred at the user's request.

## September 29, 2026 rejected predecessor-row reuse

Two single-predecessor query trials are removed from production. The first
borrows a completed predecessor's immutable source row when it has no write
to the queried local. The revised version also resolves a sole preceding write
directly and avoids processing its first edge twice on the fallback path.
Both preserve exact source order, overwrite boundaries, exceptional policy,
entry-reaching loops and closed cycles. No retained cache is added.

The [candidate guards](../../../../../src/ir/local_graph_predecessor_cache_wbtest.mbt)
retain the frozen v13 reference and the rejected revised algorithm in white-box
code. Sharing and known-write workspace regressions fail before their respective
implementations; the boundary guard compares both locals and exceptional
policies. The [eight native controls](../../../../../src/ir/local_graph_predecessor_cache_perf_wbtest.mbt)
include cold cache/index/scratch allocation, query each block once and exclude
CFG/fact construction equally. The revised installed candidate measures:

| Query chain | Original → candidate |
| --- | --- |
| 64 read-only blocks | 10.43 → 3.90µs |
| 512 read-only blocks | 83.53 → 29.91µs |
| 64 overwriting blocks | 5.09 → 4.49µs |
| 512 overwriting blocks | 39.87 → 34.09µs |

The first trial's overwrite controls regress 4.90 → 5.82µs / 37.87 → 44.79µs;
the revision removes that helper cost, but neither trial improves the compiler
pipelines. Three alternating v13→v14b pairs measure large DAE2 **4248.864 →
4351.417ms (+2.41%)**, MAD 0.004/18.881ms, and optimizing **7296.766 →
7425.941ms (+1.77%)**, MAD 8.655/67.920ms. The first trial also records
large costs of +1.61%/+0.78%. Preserve those timing observations without
claiming every difference is causal: dependency-only instructions fall only
20,329,087,979 → 20,299,338,150 (−0.15%), and counted allocator requests/frees
fall by only 343 in that window. Active joined-reader and pure-tail pipelines
are near flat for the revision; helper wins do not establish a full-pass win.

Small revised medians are 4.968 → 4.485ms / 11.750 → 11.806ms; tee medians
are 3.706 → 3.728ms / 104.978 → 104.549ms. Small instructions fall
80,559,242 → 80,546,335 / 172,282,363 → 172,264,765, with two fewer allocator
requests/frees in each command. Reference-drift retries and the identical-binary
calibration limit small timing claims. Managed process visibility still does
not establish quiet-host timing. Counts are incoming allocator calls, not
allocated bytes, net live objects or RSS.

Installed v14/v14b prototypes pass 12,932/12,933 default tests, info/fmt,
native build, eight controls and the 126-module / 1,029-observation replay.
Each also passes the two seven-module / 28-observation active replays against
original and verified v133. All measured before/after bytes, traced/untraced
outputs and independent validation match. The production query is restored
exactly to v13; candidate implementations remain confined to dedicated tests.
Rejected binary SHA-256 values are
`092a57cd4f5bcc2870451d4649b5599a7fdfa37fcac2d2d083af0cec48e8c05b`
and `b52ea87e0602f61285f21b21a0f2928a8b8806e227c8001efbf8f94a1b0b3dd1`.
Local evidence under `.tmp/dae2-lean-20260929/` uses `v14`, `v14b`,
`rejected-v14/`, `rejected-v14b/` and `dependency-cost-v14b.json`.
Current production oracle evidence remains the accepted v13 sweep below.
Fuzz remains deferred.

After restoring production, info/fmt, all 12,933 default tests, native build
and the eight candidate-only controls pass. The rebuilt CLI is byte-identical
to v13, so its accepted oracle and runtime evidence still describe production.
Renewed control means are retained in `v14-controls-bench.log`; they do not
alter the installed-prototype pipeline results above.

Direct allocation attribution identifies larger targets: v13 dependency
analysis records 4,927,673 calls from CFG region segmentation to `mi_malloc`,
3,092,437 from preceding-dependency queries, and 1,914,225 from block creation.
The initially recorded “proposal-feature array” interpretation is superseded:
the 5,982,618 calls reach an int-sized generic allocation specialization named
for `ProposalFeature`, but 5,980,331 originate in `Array[Int]` reallocation.
The specialization name does not identify proposal metadata construction.
Upstream growth edges include 979,607 from CFG segmentation, 830,456 from
operand collection variants, and 472,703 from reverse entry-source queries.
These are call edges with potentially folded generic implementations and
wrapper layers, not independent allocation totals. Inspect buffer lifetimes
before adding another cache. Evidence is `allocation-callers-v13.json` and
`array-growth-callers-v13.json`.

## September 29, 2026 pure-subtree dependency pruning

The shared preceding-value collector and indexed minimum query stop at a pure
subtree. Effect masks already include every live child, while these dependency
queries follow subsets of those operands. A zero subtree mask therefore cannot
contain a value with nonzero effects that needs carrying across a statement.
The collector leaves its scratch arrays untouched; the minimum query caches
only the root's no-dependency sentinel. Calls, local-state reads, loads and
numeric traps still follow the existing traversal. No retained cache or new
allocation is introduced.

Two [work-invariant regressions](../../../../../src/ir/hot_source_order_pure_wbtest.mbt)
fail before the change: the old minimum query fills a pure leaf's cache slot,
and collection records all 33 nodes in its touched workspace. Both now pass,
with an additional effect/trap guard matching the original query reference.
Eight [native controls](../../../../../src/ir/hot_source_order_pure_perf_wbtest.mbt)
exclude fact construction and compare balanced 64/512-leaf trees. Collection
improves 2.45µs → 19.67ns / 19.74µs → 19.49ns; minimum queries, including
fresh cache-vector initialization, improve 2.40µs → 51.96ns /
19.37µs → 254.87ns. These are helper controls, not compiler-wide speedups.

Three alternating v11→v13 pairs, with CPU 6 affinity and the independent
precompute-reference bracket, measure the following pipeline medians:

| Input | DAE2 before → after | DAE2-O before → after |
| --- | --- | --- |
| Large compiler | 4683.480 → 4615.983ms (−1.44%) | 8061.194 → 8024.433ms (−0.46%) |
| Small compiler | 4.418 → 4.346ms (−1.63%) | 11.536 → 11.448ms (−0.76%) |
| Active tee | 4.055 → 4.161ms (+2.61%) | 106.419 → 107.161ms (+0.70%) |

Large before/after MADs are 21.715/41.907ms and 57.195/27.438ms. Optimizing
compiler timing is near flat; small/control changes remain limited by the
identical-binary calibration. Managed-sandbox process visibility limits foreign
CPU observation, so empty observations do not establish a quiet host.
Dependency-only Callgrind instructions fall 20,486,620,723 → 20,329,087,979
(−0.77%). Small whole-command instructions fall 80,724,625 → 80,565,783 /
172,455,037 → 172,284,529; allocator request/free calls fall by only 7/9.
Do not interpret those request counts as allocated bytes or peak RSS.

The fresh verified-v133 sweep uses one warmup and three samples:

| Input / pass | Starshine | Binaryen 133 | Ratio |
| --- | ---: | ---: | ---: |
| Small DAE2 | 4.749ms | 0.999ms | 4.75× |
| Small DAE2-O | 14.283ms | 3.295ms | 4.33× |
| Large DAE2 | 4297.268ms | 451.817ms | 9.51× |
| Large DAE2-O | 7739.332ms | 1684.540ms | 4.59× |

Large Starshine/Binaryen MADs are 37.034/6.357ms and 42.177/0.870ms.
These separate cohorts are not a paired v11→v13 oracle-ratio improvement.
Canonical sizes remain 6,132,389/6,232,586 and 5,995,920/5,573,450 bytes;
the optimizing 422,470-byte gap and plain output-shape classification stay open.
The oracle/input hashes are the same verified v133 hashes recorded below;
new oracle evidence is `oracle-v13-{small,large}/`.

Info, fmt, all 12,929 default tests, native CLI build and all eight controls
pass. The fixed replay validates 126 modules with 1,029 matching
original/v133 observations; all measured before/after bytes and traced/untraced
outputs match. Candidate v13 SHA-256 is
`a367397e0045ee3db4cc3711135edab4b1449cca2647cb0f202f684fc14360ab`.
Evidence under `.tmp/dae2-lean-20260929/` uses `pairs-v13-*`,
`callgrind-v13-dependencies`, `small-instructions-v13/`,
`allocator-calls-v13.json`, `pure-red.log` and `validation-v13.json`.
The cumulative section below preserves the earlier directly measured checkpoint;
do not multiply its gains by this cohort's percentages. Fuzz remains deferred.

## September 29, 2026 active pure-tail pipeline benchmark

The [permanent full-pass workload](../../../../../src/passes_perf_long/dae2_pure_tail_perf_test.mbt)
has a private helper with one removable argument, a conditional local write,
32 calls that increment an exported global, and a balanced dropped numeric
tail. Fewer than 64 statement roots exercise direct future-dependency scanning:
previously every preceding call rediscovered the pure tail's operands. The
conditional reaching definitions and actual signature change keep DAE2 analysis
and rewriting active. Balanced trees avoid conflating that repeated work with
deep-stack stress.

The bounded eight-leaf test validates both pass outputs, checks argument removal
and confirms input ownership. All four dedicated native benchmarks pass at
512/8192 leaves: DAE2 means 961.23µs/13.59ms, optimizing means 1.01ms/13.57ms.
Setup validates the output and requires argument removal outside timing; these
standalone means are not before/after improvement percentages. Info/fmt and
the focused default guard pass after the 12,929-test full run recorded above.

A matching 8192-leaf CLI fixture, one warmup and three alternating v11/v13
pairs with the independent reference bracket, measures DAE2 **24.764 →
13.431ms (−45.76%)** and DAE2-O **25.466 → 13.921ms (−45.33%)**. Before/after
MADs are 0.038/0.060ms and 0.091/0.002ms. Before/after bytes, traced/untraced
outputs and validation match. Original, both frozen Starshine binaries and
verified v133 return identical results and exactly 32 writes for four inputs:
seven modules and 28 runtime observations. This scaling gain does not establish
a compiler-artifact speedup; the compiler results remain separately recorded.

Local evidence is `.tmp/dae2-lean-20260929/pure-tail-v13/`,
`pure-tail-{controls,bench,test}.log` and `pure-tail.wat`. Input SHA-256 is
`1ce3aa502916d19fec1f9740965806afa2fb4e633acf9e8105d0eda5a69966f0`.
Both frozen binary and verified oracle hashes are recorded in the surrounding
checkpoints. Production code is unchanged by this benchmark addition; no
aggregate fuzz runs.

## September 29, 2026 cumulative lean checkpoint

A fresh matched comparison uses v1 (the reverse-flow repair) as its baseline,
not the earlier correctness-broken V18 or the roughly 39-second dense solver.
Three alternating pairs, pinned to CPU 6 with an independent frozen precompute
reference, give the following pipeline medians:

| Input | DAE2 before → v11 | DAE2-O before → v11 |
| --- | --- | --- |
| Large compiler | 5403.347 → 4553.645ms (−15.73%) | 8689.363 → 8006.475ms (−7.86%) |
| Small compiler | 4.800 → 4.654ms (−3.04%) | 12.057 → 11.639ms (−3.47%) |
| Active tee | 3.885 → 3.930ms (+1.16%) | 111.039 → 106.728ms (−3.88%) |

Large before/after MADs are 0.851/183.876ms and 165.795/184.159ms.
All measured bytes match, traced/untraced outputs agree, and outputs validate.
Reference-drift retries are retained. Eleven of twelve accepted large runs
record foreign Chrome/kernel CPU activity, so this is not a quiet-host signoff;
the small differences also remain limited by the identical-binary calibration.
These cumulative figures are measured directly, not products of percentages from separate optimization cohorts.

A separate fresh **verified Binaryen 133** sweep, one warmup and three samples,
uses the same frozen v11 binary. Its pass-local pipeline medians are:

| Input / pass | Starshine | Binaryen 133 | Ratio |
| --- | ---: | ---: | ---: |
| Small DAE2 | 4.827ms | 1.036ms | 4.66× |
| Small DAE2-O | 14.155ms | 3.315ms | 4.27× |
| Large DAE2 | 4671.195ms | 458.548ms | 10.19× |
| Large DAE2-O | 8281.950ms | 1802.110ms | 4.60× |

Starshine/Binaryen large MADs are 38.016/5.873ms and 26.839/67.390ms.
The compiler performance target remains open. Canonical large output sizes are
6,132,389/6,232,586 bytes for DAE2 and 5,995,920/5,573,450 bytes for DAE2-O.
The optimizing size gap is 422,470 bytes; the smaller plain output alone does
not prove a Starshine win or close the output-shape parity investigation.
No output-shape difference is newly accepted by these performance measurements.

Local evidence is `.tmp/dae2-lean-20260929/cumulative-v11-{small,large,tee}/`
and `oracle-v11-{small,large}/`. V1 SHA-256 is
`a612ebefc2f7d54085530d22d88d2565861d26e4753b64e9660b282999a18fc3`;
v11 SHA-256 is
`c43278a2cf8ced917ccdcc21d3d2cfd216c75d182ac336126fb6b9e10482248b`.
The oracle is `wasm-opt version 133 (version_133)`, SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
The large input SHA-256 remains
`98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
The dependency-only Callgrind profile falls from **26,495,753,239 instructions
at v2 to 20,486,620,723 at v11 (−22.68%)**, with byte-identical validated output.
This baseline already includes the direct tuple-opcode improvement; it differs
from the v1 timing baseline above. It counts the analysis dependency function,
not the whole compiler command. Remaining nonrecursive inclusive costs are
CFG construction 62.12% and LocalGraph 23.94%; source-order dependency
queries account for 19.04% inside CFG construction. These nested percentages
must not be added. Largest self costs include HOT node reads 13.35%, reverse
entry queries 7.06%, object destruction 6.61% and liveness reads 3.96%.
The source-order query total is essentially unchanged from v2, making repeated
region scans a useful next target. Profiles are `profile-v11-{self,inclusive}.txt`
and `callgrind-v11-dependencies`; v2 retains the earlier equivalent scope.

Whole-command small-input Callgrind controls compare v1/v11. DAE2 instructions
fall 85,690,018 → 80,721,030 (−5.80%); optimizing instructions fall
178,863,157 → 172,466,407 (−3.58%). Counted calls into `mi_malloc` fall
325,973 → 312,090 and 512,453 → 492,159 (13,883 and 20,294 fewer requests).
The corresponding frees fall by the same counts. These are native allocator
call counts, not allocated bytes or a claim about peak memory.

Three alternating large-input RSS samples overlap: DAE2 median 282,308 →
281,308 KiB, ranges 255,884–283,288 / 259,160–281,808; DAE2-O median
292,356 → 302,336 KiB, ranges 292,024–314,784 / 291,804–304,696. Retain the
higher optimizing median without claiming a proven memory regression or win.
The initial RSS launcher found no `/usr/bin/time`; its setup error is preserved,
and completed samples use a fresh Python child wrapper's Linux `ru_maxrss`.
Evidence is `memory-v11/`, `small-instructions-v11/` and `allocator-calls-v11.json`.
All corresponding outputs validate and retain exact before/after bytes.

This is bounded performance/correctness evidence; aggregate fuzz remains
explicitly deferred until the performance trials finish.

## September 29, 2026 rejected smaller-region index threshold

A 64 → 32 root-index threshold trial is removed. The existing index algorithm
is valid on small regions, but the measured compiler inputs show no pipeline
benefit. Three alternating pairs measure large DAE2/O 4349.487 → 4404.810ms
(+1.27%) / 7460.982 → 7517.513ms (+0.76%). Small medians are 4.241 →
4.870ms (+14.83%) / 11.727 → 11.892ms (+1.41%); active tee medians are
3.924 → 3.928ms / 108.375 → 107.433ms. Preserve these timing observations
without claiming all differences are causal: small instruction and allocator
counts are essentially identical, and prior calibration demonstrates timing
variation. Small instructions are 80,724,150 → 80,722,900 /
172,465,174 → 172,463,564; allocator request counts are unchanged.

The [suffix-query controls](../../../../../src/ir/hot_source_order_threshold_perf_wbtest.mbt)
include facts/index construction and compare direct/indexed queries at 4/16/32
roots. Their repeated-barrier pattern is a kernel workload. The additional
[region controls](../../../../../src/ir/hot_source_order_region_perf_wbtest.mbt)
query each actual effectful root once, with the real changing cutoff and suffix.
At 32 roots sparse regions improve 13.25 → 7.58µs, but dense regions cost
16.74 → 17.64µs (+5.38%). At 16 roots they measure 4.38 → 3.51µs and
5.72 → 6.12µs. These synthetic tradeoffs do not establish a compiler win.

The [bounded index guards](../../../../../src/ir/hot_source_order_threshold_wbtest.mbt)
retain equality across every suffix for sparse/dense 4/16/32-root regions, and
check the 32-root candidate set directly. The prototype's threshold-admission
regression was red first; after rejection its admission assertion becomes a
direct index-algorithm guard. The shipping threshold remains 64. No existing
feature or supported index algorithm is removed.

While the prototype was installed, info/fmt, 12,926 default tests, native build,
12 kernel controls, eight actual-region controls, and the 126-module /
1,029-observation original/v133 replay pass with identical output bytes.
The interrupted paired run was resumed by checking binary/input/reference
hashes and completed sample artifacts, retaining partial evidence and avoiding
re-measurement of completed pairs. Later managed-sandbox process visibility
limits foreign-CPU detection; an empty observation does not prove a quiet host.
Local evidence uses `v12`, `region-*`, `threshold-*` and `rejected-v12/` under
`.tmp/dae2-lean-20260929/`. Rejected candidate SHA-256 is
`6c698eb8a86eb8fa250a0562944ad547fe3c7f8e547fa879f0c255de6adc2798`.
Its completed v133 sweep remains saved under `oracle-v12-{small,large}/`;
the accepted production oracle at that checkpoint was v11, now superseded
by the v13 sweep above.
Fuzz remains deferred.

## September 29, 2026 fuse source-order operand walks

Source-order facts now compute maximum value order and first external-effect
order in one operand traversal. The two existing result arrays retain their
sentinels and discovery order; no cache is added. The standalone first-effect
query remains separate for consumers that need only that summary. The old
value-only traversal survives only as a test reference.

The [bounded guard](../../../../../src/ir/hot_source_order_fused_wbtest.mbt)
compares both arrays before and after on calls, stacked writes, indexed control,
loads and deleted nodes. Six [native controls](../../../../../src/ir/hot_source_order_fused_perf_wbtest.mbt)
compare full fact construction with the original two-walk reference. A repeated
low-variance cohort measures 8/64/128 roots at 19.58 → 15.79µs /
153.10 → 124.40µs / 340.18 → 246.32µs. The first noisy timing cohort is
preserved, but does not support the helper claim.

Three alternating pairs measure large DAE2 **4779.348 → 4589.724ms (−3.97%)**,
MAD 61.700/67.940ms, and DAE2-O **7924.408 → 7826.148ms (−1.24%)**,
MAD 19.823/44.409ms. Ten of twelve accepted large runs record foreign CPU
activity; preserve that limit alongside the helper and instruction evidence.
Small medians are 4.736 → 4.541ms /
12.252 → 12.391ms; active tee medians are 3.778 → 3.888ms /
106.876 → 105.483ms. Small changes remain subject to the calibration limits;
these results do not establish Binaryen competitiveness.

Info, fmt, 12,923 default tests, native build and all six controls pass. The
126-module / 1,029-observation original/v133 replay and before/after artifact
bytes match. Candidate SHA-256 is
`c43278a2cf8ced917ccdcc21d3d2cfd216c75d182ac336126fb6b9e10482248b`.
Local evidence under `.tmp/dae2-lean-20260929/` uses `v11`; the repeated
controls are in `controls-order-repeat.log`. No aggregate fuzz ran.

## September 29, 2026 borrow completed reverse-query rows

Reverse-flow query cache entries are immutable after collection. Cache insertion
and lookup now share the completed source row instead of copying it. Unique
reverse recording borrows the row; iterative recording keeps its existing
copy-on-write merge. Public owned queries still return independent arrays.
The [ownership regression](../../../../../src/ir/local_graph_source_cache_wbtest.mbt)
first failed because the returned row differed physically from the cache; it
now checks both cache sharing and isolation of a later merge.

The [full graph controls](../../../../../src/ir/local_graph_source_cache_perf_wbtest.mbt)
measure repeated entry-source reads in one block. At 128/512/2048 reads they
improve 13.06 → 10.94µs / 49.33 → 41.23µs / 194.82 → 162.59µs (about 16.5%).
Paired large DAE2 is flat at 4736.866 → 4732.602ms, MAD 16.009/13.716ms;
DAE2-O measures 7938.411 → 7812.697ms (−1.58%), MAD 92.021/1.483ms.
Small medians are 4.362 → 4.422ms / 11.594 → 11.633ms; active tee medians
are 4.582 → 3.963ms / 106.764 → 109.645ms. Preserve the +2.70% optimizing
tee observation and the timing-calibration limits rather than claiming a win
on every input.

Info, fmt, 12,923 default tests, native build, three cache benchmarks and six
next-stage order controls pass. The 126-module / 1,029-observation original/v133
replay and artifact byte checks pass. Candidate SHA-256 is
`0ca046728397956793707c6e2de24d672bc4ea3bd1ba164c832e8f15a6819fe3`;
local evidence uses `v10` and `cache-borrow-red.log`. The suite includes the
fused-order guard before that optimization. No aggregate fuzz ran.

## September 29, 2026 append unique reverse-flow readers

Reverse flow records each get once with a deduplicated source row. Its recorder
now assigns that row directly and appends each write influence without searching
all earlier readers. Dense/sparse iterative recording retains its merge and
deduplication logic. This removes quadratic reader-list searches and the unused
copy-on-write recorder on the reverse path, without adding an index or cache.

The [bounded guards](../../../../../src/ir/local_graph_unique_reads_wbtest.mbt)
pass before and after for ordered readers, branch-joined writes and shared-read
fallback. [Full graph controls](../../../../../src/ir/local_graph_unique_reads_perf_wbtest.mbt)
at 128/512/2048 readers improve 11.50 → 9.57µs / 68.77 → 32.84µs /
611.87 → 128.49µs. The high-count case is 4.76× faster and scaling is now
approximately linear. This is a graph-construction gain, not a compiler-wide
speedup claim.

An additional active DAE2 workload joins two writes (7 or 9) and consumes the
local 8,192 times in a balanced addition tree. Its private helper also has an
unused argument, which DAE2 removes. The v7/v9 paired full pipelines improve
**51.781 → 22.058ms (−57.40%)** and **64.182 → 32.221ms (−49.80%)** for
DAE2/O, with MADs 0.094/0.035ms and 0.551/0.467ms. Seven original/before/after/
v133 modules validate and return identical values in 28 observations; before/
after bytes match. This is a deliberate scalability workload, separate from the
compiler artifact below. The permanent [active pipeline benchmarks](../../../../../src/passes_perf_long/dae2_joined_readers_perf_test.mbt)
cover 512/8192 readers for both passes, with a bounded default guard proving
argument removal and input ownership. All four native controls and that guard
pass. Final v11 benchmark means are 1.33/21.28ms (DAE2) and 2.05/31.18ms
(DAE2-O); these are standalone controls, not matched improvement estimates.
The subsequent cache-borrowing change is flat on the active 8192-reader input:
21.871 → 22.012ms / 31.555 → 31.495ms, with seven validated modules and 28
matching observations. Local `joined-readers-v9/`, `joined-readers-v10/`, `joined-readers.wat` and
`joined-readers.py` retain it; input SHA-256 is
`60935ce550d11451d4dce59ff319d6ed58633b645496ecf9eac3fdcc62079f86`.

Independent-reference paired medians retain a large DAE2 cost:
4623.318 → 4697.854ms (+1.61%; MAD 78.203/38.001ms). DAE2-O is nearly
flat at 7955.797 → 7918.754ms, MAD 21.181/66.549ms. Small medians are
4.379 → 4.388ms / 11.641 → 11.566ms; active tee medians are
3.819 → 3.788ms / 107.230 → 107.812ms. Preserve the observed costs; the
asymptotic improvement does not close the compiler-artifact gap.

Seven-pair identical-binary controls with the separate reference measure small
DAE2/O variation of −1.08%/−2.61% and tee variation of −0.84%/−0.10%.
The new bracket removes asymmetric reference invocation, but timing noise
remains. These controls limit claims from small differences in later trials.

Info, fmt, 12,921 tests, native build, three reader benchmarks and three next-stage
cache controls pass. The 126-module / 1,029-observation original/v133 replay and
all output byte checks pass. Candidate SHA-256 is
`61a7017554e3ba466f22538b40c7fa90f9629c6c2e3e70ea7239f9b04efb2484`;
local evidence uses `v9` and `calibration-independent-{small,tee}/`. A corrected
runner-path argument error is preserved in `evidence-v9-harness-error.log`;
completed runtime evidence was hash-checked and reused before the successful
paired run. Fuzz remains deferred.

## September 29, 2026 rejected native getter annotation

Adding `#inline` to `hot_node_get` produced an **identical native binary** to
v7: SHA-256 `eeadc7c3e87fdb0a56b31aaf27721f92e97a718cea28ccf5ad6b8ac6ecf20763`,
14,352,728 bytes. The annotation was removed. All 12,921 tests, native build,
12 existing field-query controls and three next-stage reader controls pass;
no native performance benefit can be attributed to this source annotation.

The identical-binary v8 comparison is also a timing calibration: small DAE2/O
appeared +9.85%/+2.50%, large +0.75%/+0.58%, and active tee −0.40%/−2.97%.
These are measurement variation, not code regressions or wins. Preserve earlier
small/control timings as observations, but do not infer a causal improvement
from similarly small differences. Native helper scaling, fixed output/runtime
checks and large gains have separate evidence; sub-percent artifact changes
were already classified as near flat.

The earlier bracket ran `precompute` through the before binary. Subsequent
trials use a separate frozen reference executable for both brackets so neither
candidate receives that asymmetric code-cache warmup. An independent-reference
identical-binary calibration is recorded with subsequent results; this setup
change alone is not proof that all timing noise is eliminated. Local evidence
uses `v8`, `machine-v8.json` and `affinity-pairs-independent.py`. Fuzz remains
deferred.

## September 29, 2026 bounded SSA source summaries

LocalGraph's SSA flag needs only one distinct reaching source and agreement
with every write. It now records unseen/singleton/multiple identities in two
flat local-indexed arrays during one arena scan. This replaces growing unions
with linear membership searches, one heap array per local and a second arena
scan. Finalized nonnegative source IDs remain distinct from the private summary
sentinels; unused writes still invalidate singleton reads when identities differ.

The [bounded guards](../../../../../src/ir/local_graph_ssa_summary_wbtest.mbt)
cover entry values, singleton/multiple writes and unread conflicting writes;
they pass before and after. The [native controls](../../../../../src/ir/local_graph_ssa_summary_perf_wbtest.mbt)
compare the original union with the summary: 16/128/512 writes take
0.643 → 0.266µs / 6.22 → 1.68µs / 48.72 → 6.47µs. This removes the
quadratic union on that workload without claiming a large compiler gain.

Paired large DAE2/O medians are effectively flat at
4553.674 → 4562.817ms / 7615.647 → 7540.545ms; respective MADs are
33.512/51.085ms and 157.977/39.231ms. Small medians are
4.723 → 4.334ms / 11.619 → 11.747ms; active tee medians are
3.791 → 3.985ms (+5.12%) / 106.828 → 106.876ms. Preserve these noisy control
costs. Separate whole-command Callgrind counts on the small input fall
81,849,693 → 81,523,967 / 173,674,540 → 173,343,909 instructions
(−0.40%/−0.19%); active tee counts are essentially unchanged
102,629,320 → 102,633,080 / 2,049,641,510 → 2,049,674,565. Instruction
counts do not establish wall-time improvements or erase the observed costs.

Info, fmt, 12,919 default tests, native build, six controls and the fixed
126-module / 1,029-observation original/v133 replay pass with identical output
bytes. Local evidence has the `v7` suffix, plus `small-instructions-v7/` and
`tee-instructions-v7/`; candidate SHA-256 is
`eeadc7c3e87fdb0a56b31aaf27721f92e97a718cea28ccf5ad6b8ac6ecf20763`.
No aggregate fuzz ran.

## September 29, 2026 reuse CFG region-root snapshots

Expanded CFG construction already snapshots each region's roots for source
ordering. It now reuses that array when visiting roots and registering operand
blocks, removing repeated region/label/type lookups. Root-only construction
registers its already-known roots directly. This adds no cache or allocation.
The [bounded guard](../../../../../src/ir/cfg_root_snapshot_wbtest.mbt) checks
indexed inputs and exact body slots in both modes; it passes before and after.
The [native controls](../../../../../src/ir/cfg_root_snapshot_perf_wbtest.mbt)
measure full CFG construction: 8/64 expanded roots improve 82.75 → 72.05µs /
510.40 → 444.74µs, and 64 root-only roots 148.16 → 141.56µs.

Three alternating large-input pairs measure DAE2 **4663.759 → 4476.399ms
(−4.02%)**, MAD 5.624/7.962ms; DAE2-O is nearly flat at
7496.749 → 7452.244ms (−0.59%), MAD 72.745/17.440ms. Small medians are
4.507 → 4.402ms / 11.804 → 12.231ms; active tee medians are
3.743 → 3.813ms / 106.230 → 107.506ms. Small/control costs and rejected
reference-drift attempts remain recorded; this is chiefly a large DAE2 gain.
Do not combine absolute times from different cohorts as a matched comparison.

Info, fmt, 12,919 default tests, native build and three controls pass. The fixed
126-module / 1,029-observation original/v133 lane has zero behavioral or
before/after byte differences. Local evidence uses the `v6` suffix under
`.tmp/dae2-lean-20260929/`; candidate SHA-256 is
`c14847b66efd69ab8b8be8b7b20b1cb70ff37e270666b9c74ef0dc3506a339a1`.
The suite includes the next SSA trial's guards before its implementation.
Aggregate fuzz remains deferred.

## September 29, 2026 rejected source-order cache trials

Two cache prototypes are **not in production**. A lazy write-presence cache
avoided access-list materialization for read-only carried expressions. It reduced
the 128-deep one-direction control 250.33 → 22.27µs, but the reverse write/read
query still materialized the same trees: a bidirectional control remained
277.07 → 264.98µs. Its large DAE2/O medians were effectively flat
4607.042 → 4614.436ms / 7620.928 → 7566.612ms, with small/tee control costs.

A second prototype cached compact uniform-local identities and earliest-access /
latest-write orders, retaining the original mixed-local scan. It reduced the
bidirectional 128-deep control 279.23 → 26.78µs, but regressed paired small DAE2
4.421 → 4.672ms (+5.68%) and large DAE2 4600.324 → 4673.942ms (+1.60%).
Large DAE2-O was flat at 7659.031 → 7664.762ms; active tee medians were
3.797 → 3.784ms / 106.223 → 105.765ms. These synthetic wins do not justify
keeping the additional per-function cache and real-input costs. Both prototypes
were removed; the accepted production baseline remains v4 at this checkpoint.

The [read-only/dead-tail guards](../../../../../src/ir/hot_source_order_write_free_wbtest.mbt),
[bidirectional/order-bound guards](../../../../../src/ir/hot_source_order_uniform_wbtest.mbt)
and their [one-direction](../../../../../src/ir/hot_source_order_write_free_perf_wbtest.mbt)
/ [bidirectional](../../../../../src/ir/hot_source_order_uniform_perf_wbtest.mbt)
benchmarks remain useful controls. The selected benchmark path always measures
the current implementation; the reference retains the original scan. The
quadratic overlapping-access-list family remains open rather than being hidden
by a helper-only success claim.

The second prototype passed 12,918 default tests, native build and four controls;
both passed the 126-module / 1,029-observation fixed replay with unchanged bytes.
Local `.tmp/dae2-lean-20260929/` evidence uses `v5` and `v5b`; rejected v5b source
is preserved in `rejected-v5b/`. Binary hashes are
`2ad9d25559765dc54f191fb194ba807b8faa4f72d7b97f3996c2028bab13d912` and
`05a93a72a031a2996e3e273720945aeddf4c6d8c2335aeb6a944c67a29c1b5fe`.
This is experimental evidence, not accepted performance or aggregate signoff.

## September 29, 2026 reuse the write-local index

Reverse-flow construction now builds its required node-to-write-local vector
before queries and reuses it for short write scans, lazy block indexes and
transparent-chain admission. It retains the same vector in the finished graph;
there is no additional persistent index. This removes repeated complete HOT
node reads in predecessor queries. The
[bounded lookup guard](../../../../../src/ir/local_graph_write_index_wbtest.mbt)
passes before/after for reads, sets, tees, absent locals and prefix limits;
[native controls](../../../../../src/ir/local_graph_write_index_perf_wbtest.mbt)
compare the old scan and the indexed lookup on the same function. A 512-query
batch improves 6.31 → 3.70µs (−41.36%).

The enclosing effect is modest: three paired large medians are
4324.275 → 4293.496ms for DAE2 (−0.71%; MAD 3.134/13.836ms) and
7115.667 → 7094.366ms for DAE2-O (−0.30%; MAD 35.662/5.471ms).
Small medians are 4.261 → 4.151ms / 11.095 → 11.091ms; active tee medians
are 3.680 → 3.693ms / 103.460 → 102.506ms. These near-flat artifact controls
must not be presented as a major pipeline win. All bytes match; info, fmt,
12,914 default tests, native build, both controls and the fixed 126-module /
1,029-observation original/v133 lane pass. Candidate SHA-256 is
`df13c59e51ff5d011a90083dfd623f6a01d4e9aa473fb631bc1a4519702e5c04`;
local evidence has the `v4` suffix. The additional source-order tests present
in this validation are guards for the following trial, not yet its implementation.
No aggregate fuzz or new competitiveness claim is made.

## September 29, 2026 read-only predecessor chains

Reverse local-flow queries previously walked every intervening read-only block
again for each local. A linear prepass now resolves single-predecessor chains,
stopping at writes and joins. Closed read-only cycles retain one representative;
exceptional-edge selection follows the query policy. The
[bounded graph fixture](../../../../../src/ir/local_graph_transparent_wbtest.mbt)
compares sources with dense flow across chains, joins, reachable loops,
disconnected cycles and exception edges. Source sets pass before and after;
post-change assertions also check the compressed predecessor map.

The existing expanded-flow benchmarks now take 13.69/53.08/102.54µs at
32/128/256 reads, versus 25.92/279.86/1040µs in the earlier v1 cohort. These
helper cohorts differ; the current same-process dense controls are
66.56/867.01/3220µs. Scaling is now approximately linear on this fixture.
Three alternating artifact pairs give large DAE2 4558.704 → 4331.999ms
(−4.97%; MAD 2.407/14.058ms) and DAE2-O 7342.827 → 7083.803ms
(−3.53%; MAD 14.866/18.654ms). Small controls are 4.242 → 4.331ms and
11.376 → 11.057ms; active tee controls are 3.544 → 3.504ms and
104.067 → 106.056ms. Preserve the observed +2.10% small DAE2 and +1.91%
active optimizing costs; this does not establish a win for every workload.

All output bytes match. Full 12,911-test validation, native build, six native
benchmarks and the 126-module / 1,029-observation fixed replay lane pass.
Candidate SHA-256 is
`888b45565e826f0d7cabc51e8a7042fa889b29328302f51ebb6f8136b757e327`;
artifacts use `.tmp/dae2-lean-20260929/` and the `v3` suffix. Fuzz remains deferred.

A fresh dependency-only Callgrind profile of the preceding **v2** binary records
26,495,753,239 instructions with validated, byte-identical large output. Its
nonrecursive inclusive CFG and LocalGraph owners account for 56.38% and 32.81%;
self costs include HOT node reads 15.46%, reverse entry traversal 12.20%, indexed
last-write lookup 5.72%, and object destruction 5.44%. Recursive inclusive
attribution overlaps and must not be added. This is not a whole-command profile
or a timing comparison with v9. The next trials target repeated node decoding
in write lookup and source-order subtree scans; local `profile-v2-{self,inclusive}.txt`
and `callgrind-v2-dependencies` preserve the attribution.

## September 29, 2026 tuple preparation without opcode strings

Shared HOT lowering now tests `HotOp::TupleMake` directly and reads result
metadata only for tuple nodes. Previously it formatted every live opcode into
a temporary string merely to identify that one opcode. The
[bounded type/IR guard](../../../../../src/passes/tuple_prepare_opcode_wbtest.mbt)
passes before and after the change, preserving zero/scalar/multivalue handling,
node counts, type interning and valid HOT output. This is a performance change,
not a newly implemented semantic behavior.

[Native controls](../../../../../src/passes/tuple_prepare_opcode_perf_wbtest.mbt)
compare the original string scan with opcode matching, including fresh function
construction and active multivalue promotion each iteration. At 64/1024 roots,
means fall 31.45 → 6.15µs and 480.45 → 76.75µs; lowered IR and resulting type
sections match the reference. Full validation passes 12,910 default tests,
interface generation, formatting, native CLI build and all four benchmarks.
Frozen binary SHA-256 is
`cb4d1d0054ff4c54d08f95dd2bdc9a4c4c5987e05ac8fad626e1a1f92c1aa385`;
local artifacts use `.tmp/dae2-lean-20260929/` with the `v2` suffix.
Three alternating CPU-affined pairs after a warmup preserve all output bytes:
small DAE2/O medians 4.310 → 4.205ms / 11.295 → 10.921ms; large medians
4752.195 → 4567.170ms / 7575.284 → 7355.966ms (−3.89%/−2.90%). Large
MADs are 1.404/14.403ms and 25.654/17.601ms, respectively. Active tee DAE2
is flat (3.545 → 3.555ms), while DAE2-O improves 109.851 → 104.022ms
(−5.31%). The 126-module fixed runtime lane again validates 1,029 observations
with zero behavioral or byte differences. Rejected reference-drift warmup and
foreign CPU observations remain in local evidence; no aggregate fuzz ran.

## September 29, 2026 expanded-flow performance repair

Expanded operand CFGs now use the existing reverse reaching-definition solver.
Their nodes already represent evaluation order, so action extraction records
local reads/writes directly rather than recursively expanding operands again.
Root-only CFG admission and shared-expression fallback remain intact. The
[red-first regression](../../../../../src/ir/local_graph_expanded_reverse_wbtest.mbt)
first observed duplicate actions `[0,0,1,2,2]` instead of `[0,1,2]`; six bounded
fixtures compare source sets with the dense solver across stacked reads,
loop-carried writes, branches and indexed inputs. The
[native benchmark](../../../../../src/ir/local_graph_expanded_reverse_perf_wbtest.mbt)
compares both solvers at 32/128/256 reads and 128/512/1024 locals.

Three alternating, CPU-affined samples after one warmup give these pipeline
medians in milliseconds (identical before/after wasm bytes, validated outputs):

| Input | DAE2 before → after | DAE2-O before → after |
| --- | ---: | ---: |
| Small | 5.181 → 4.654 | 12.703 → 12.704 |
| Large compiler | 39136.021 → 5092.202 | 38973.233 → 7936.136 |
| Active tee | 3.723 → 3.801 | 106.362 → 106.250 |

Large reductions are 86.99%/79.64%; median absolute deviations are
30.347/73.633ms for DAE2 and 43.095/102.208ms for DAE2-O (before/after).
These repair the dense-flow regression introduced by the source-order
correctness fix: **they are not improvements of that magnitude over historical
V18's 4.17s/7.54s**, whose newly exposed semantic failures remain documented.
A traced large sample reduces dependency analysis 36317.052 → 2074.588ms;
rewrite/lower/validation costs remain. Native 128-read graph construction is
932.16 → 279.86µs, and 256-read construction 3.79 → 1.04ms. Residual scaling
and multi-second artifact costs remain active performance gaps.

`moon info`, `moon fmt`, all 12,909 default tests, native CLI build and six
native benchmarks pass. Eighteen fixed runtime fixtures validate 126 modules
and 1,029 result/effect/trap observations against original inputs and verified
Binaryen v133, with zero mismatches or before/after output changes. This bounded
lane is not aggregate fuzz signoff. Baseline binary SHA-256 is
`5c03b6a93d19e8c90403b7b691f87ebfc94c42eb670052506bfa7cad50a2fbf8`;
candidate is `a612ebefc2f7d54085530d22d88d2565861d26e4753b64e9660b282999a18fc3`.
Local reproducibility artifacts are `.tmp/dae2-lean-20260929/`: source manifests,
`validation-v1.json`, `runtime-v1/result.json`, and `pairs-v1-{small,large,tee}/`.
The pair runner retains rejected reference-drift attempts and foreign CPU
observations; no new v133 timing ratio or memory improvement is claimed.
Fuzz renewal is explicitly deferred until performance work is complete.

## September 29, 2026 branchless scalar blocks and source-order flow

The next candidate admits input-free void/scalar blocks with no branches,
early returns, indexed signatures or other structured control. An iterative
walk flattens their ordered children for the existing symbolic scalar analysis
and direct mutation. Flat analysis retains its original shared instruction row;
block output matches the full-HOT reference exactly. Indexed, tuple, branched,
loop, exception and continuation families retain their complete fallback.
[Red-first block fixtures](../../../../../src/passes/dae2_raw_branchless_blocks_wbtest.mbt)
cover nested results, global effects, writes, load tees, import results, traps
and recursive forwarding in both world modes, with zero analysis/rewrite lifts.
[Native controls](../../../../../src/passes/dae2_raw_branchless_blocks_perf_wbtest.mbt)
compare complete HOT/direct DAE2 at tiny/wide sizes and depths 1/16.

The trials exposed a correctness error in the previous HOT fallback: a read
already on the operand stack could be assigned the definition from a later
block write because the root-only CFG visits its consuming parent later.
An entry read lost its parameter; a read after an earlier write lost that
write. A first-write entry-edge experiment fixed only the former and is
superseded. Demanded LocalGraph now uses expanded operand control, preserving
both actual source families and loop-carried writes. Read-only and proved
entry-write admission still avoid the graph.
[Dependency regressions](../../../../../src/passes/dae2_stacked_block_entry_wbtest.mbt)
first fail on the lost entry parameter and earlier write, then require exact
signatures, retained writes, valid output and owned input. The
[dispatcher](../../../../../src/cmd/dae2_raw_branchless_blocks_wbtest.mbt) checks
both modes. Nineteen focused checks pass; full/native, bounded execution and
artifact cost/size evidence remain under way. Keep this as a release blocker
until runtime replays and final affected aggregate renewal complete.

## September 29, 2026 scalar tees and solved graph transfer

V13 tracks a tee's stack value separately from its local write. Demanded writes
keep their ordered tee/drop shape; unread captures for removed parameters
vanish. The first V13 projection incorrectly retained unread original
body-local tees: the large DAE2 input grew 316 bytes across 86 functions.
V14 projects retention from surviving local.get instructions, matching
`hot_lower_impl_prune_dead_local_tees_in_body` even for reads preceding a later
write. [Red-first capture fixtures](../../../../../src/passes/dae2_raw_tee_captures_wbtest.mbt)
cover unread body locals, earlier reads, overwrites and removed parameters;
the dispatcher fixture also failed before the repair. [Tee fixtures](../../../../../src/passes/dae2_raw_tee_wbtest.mbt) compare
exact full-HOT bytes for stacked entry reads, overwritten definitions, mandatory
loads/calls, removed results and f32/f64 reinterpretation. Both
[dispatcher modes](../../../../../src/cmd/dae2_raw_tee_wbtest.mbt) retain discarded
import effects. The initial two tests failed with a second rewrite lift; the
combined tee/storage slice now passes seventeen focused checks.

V12 drops solved module adjacency before rewrite but requires mutable graph
fields. V13 instead transfers the same solved bitvector into a fresh empty
graph, so the owned analysis graph dies without adding mutable-field reference
work to every edge. [Transfer tests](../../../../../src/passes/dae2_solved_transfer_wbtest.mbt)
require shared solved values, zero new edge capacity and unchanged borrowed
storage. [Matched graph controls](../../../../../src/passes/dae2_graph_fields_perf_wbtest.mbt)
compare the frozen V12 mutable graph with immutable fields. V14 completes
12,853 default and 86 focused native tests, 46 benchmarks and 4,056 matching
bounded observations. Large DAE2/O bytes match V12. Small DAE2/O pipelines
improve 62.47%/40.67%; active tee pipelines improve 91.89%/18.29%. Large costs
remain multi-second with contended small movements; RSS ranges overlap, and
quiet GC/entry/pure costs remain. The [complete V14 report](../../../tooling/tracing-playbook.md#v14-complete-checkpoint-and-next-cleanup-targets)
records hashes, oracle ratios, size gaps and the SL stack-order hotspot.

## September 29, 2026 scalar direct mutation

V11 qualifies scalar flat bodies for mutation without a second HOT arena.
A body-local dependency graph demands stack values and the last local write
feeding each read. Calls demand only retained arguments; mandatory producers
still execute in original order and drop unused retained results at production.
Removed results, explicit returns and kept-result calls follow solved module
boundary liveness. Local slots and names use the existing reverse removed-param
placement and capture compaction map. Complete final-module validation remains.

[Exact HOT comparisons](../../../../../src/passes/dae2_raw_rewrite_wbtest.mbt)
cover writes beneath stacked reads, traps, effects, recursion, grouped locals,
names and 130 parameters. Tuple results and indirect calls retain HOT mutation at this checkpoint;
V13/V14 subsequently admit scalar tees under the contract above. The [dispatcher](../../../../../src/cmd/dae2_raw_rewrite_wbtest.mbt)
checks both modes. The initial eight-fixture test failed with two rewrite lifts
before implementation; the final focused slice passes fifteen checks. V11
passes 12,840 default and 73 focused native tests and 52 native benchmarks.
The 741-module bounded matrix has 3,380 matching runtime observations and
identical V10/V11 outputs. Direct-only mutation controls improve 38.62 →
12.98 µs at tiny scale and 8.44 → 1.52 ms at 32 bodies/128 operations.
Enclosing active flat DAE2/O improve 81.45%/66.02% and GC 89.71%/56.97%.
Large compiler DAE2/O remain 3.89/7.07 seconds at 9.19×/4.39× v133.
The [priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
records the initial active O regression, its quiet renewal, RSS variation and
remaining size gaps. V12 completes releasing solved module adjacency before rewrite;
[storage and active rewrite checks](../../../../../src/passes/dae2_solved_storage_wbtest.mbt)
require zero retained edge capacity and unchanged solved liveness/output.

## September 29, 2026 mandatory producers and replay reset

V10 qualifies flat scalar loads, trapping numeric operations and selected GC,
reference, table and growth producers without the first HOT arena. All inputs
are observed even for a dropped result, preserving possible traps and effects;
struct field counts use the existing module subtype context. Changed functions
still replay and mutate through HOT. The
[direct opcode and exact-HOT fixtures](../../../../../src/passes/dae2_raw_producers_wbtest.mbt)
include array operations missing from the text reader, and the
[dispatcher](../../../../../src/cmd/dae2_raw_producers_wbtest.mbt) covers both modes.

Bulk replay reset preserves the retained-capacity and immutable-boundary
contracts, restoring the wide helper after V9's 7.18% regression. Fresh/reused
64-body controls measure 720.37/629.66 µs at 8,192 boundaries. V10 passes
12,830 default tests, 61 focused native tests and 2,808 bounded runtime
observations. Quiet active GC DAE2/O improve 7.53%/2.79%; large passes remain
four/seven seconds with a contended O increase requiring renewal. The
[priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
owns exact hashes, RSS dispersion and fresh verified-v133 ratios.

## September 29, 2026 flat writes and rewrite allocation

V9 extends the symbolic stack with one current dependency per local. A flat
`local.set` replaces that symbol; `local.tee` replaces it while preserving the
stack value. Values already on the stack retain their earlier symbol across a
later write. Validation still precedes graph commitment, and structured writes
retain full HOT/LocalGraph analysis. The
[assignment fixtures](../../../../../src/passes/dae2_raw_assignments_wbtest.mbt)
compare exact full-HOT bytes for overwrites, tees, stacked entry reads and a
body-local carrier, with no initial lifts.

Changed raw bodies now share one module-scoped replay workspace. Reset clears
all expression edges, work and observed state, then reseeds the immutable solved
boundary prefix. Capacity is bounded by that prefix and the largest replayed
body; no HOT arena is retained. [Reset and multi-body tests](../../../../../src/passes/dae2_replay_workspace_wbtest.mbt)
prove old edges cannot affect a smaller next body or mutate module liveness.
[Native controls](../../../../../src/passes/dae2_replay_workspace_perf_wbtest.mbt)
compare fresh and reused replay allocation at 128/8,192 boundaries.

The rewrite walk reads checked child slots until a child ID changes, allocating
one owned parent snapshot at the first replacement. Unchanged ordinary nodes
return directly; calls retain the old producer IDs required for tuple grouping.
[Ownership fixtures](../../../../../src/passes/dae2_lazy_children_wbtest.mbt)
assert unchanged encoded expressions/revisions and independent changed snapshots;
[controls](../../../../../src/passes/dae2_lazy_children_perf_wbtest.mbt) compare
the former owned-map path against lazy snapshots. The expanded focused suite
passes 451 tests and V9 passes 12,819 default, 50 focused native and 479
native IR tests plus 64 native benchmark cases. Its 2,444 bounded runtime
observations match. Child controls improve 72.51 → 36.61 ns and
290.10 → 136.65 µs; replay improves 66.59 → 44.79 µs at 128 boundaries,
but regresses 765.67 → 820.62 µs at 8,192. The wide reset needs another
trial, completed by V10 above. The priority report records completed V9
enclosing, repeated memory and fresh oracle evidence; V8's historical costs
remain visible.

## September 29, 2026 symbolic flat-body analysis

An active flat body can record parameter and whole-result dependencies without
its initial HOT arena. Constants and default-initialized locals contribute no
dependency; readonly parameter reads alias their boundary location. Pure scalar
operators merge distinct dependencies through compact integer joins. Call
arguments depend on the callee's parameter locations, returned lanes alias its
whole-result location, and indirect/reference targets are observed. Stores
observe their operands. Recursive forwarding therefore retains the same least
fixed point without a fixed parameter-count limit.

Qualification completes before committing graph edges and every admitted body
is validated. Assignments, structured control, tail calls, intrinsic targets,
trapping producers and unsupported SIMD/GC operations retain full HOT analysis.
Only bodies needing a rewrite are lifted; their expression liveness is replayed
in a fresh graph seeded with the solved boundary prefix. No solved module edges
are mutated. A newly observed boundary triggers a complete HOT reanalysis of
the original module. The private reference switch enables exact encoded-output
comparisons; it is not a public optimizer option.

[Red-first tests](../../../../../src/passes/dae2_raw_analysis_wbtest.mbt)
cover stores, dropped expressions/results, final returns, multiple result lanes,
recursion, indirect/reference families, 96 parameters, input ownership and invalid
types. [Both command modes](../../../../../src/cmd/dae2_raw_analysis_wbtest.mbt)
retain live store operands while pruning an unused argument. Dedicated
[benchmarks](../../../../../src/passes/dae2_raw_analysis_perf_wbtest.mbt)
compare full HOT and raw analysis with active rewriting at tiny and wide sizes,
then measure complete plain and optimizing pipelines. V8 passes 12,812 default
and 43 focused native tests; 2,184 bounded runtime observations and exact
HOT-reference output controls match. Three quiet flat-body pairs improve
DAE2/O 10.37%/27.68%, while large DAE2 remains about four seconds. Five
V7b/V8 RSS pairs add median 15,796/6,060 KiB for DAE2/O with wide variation.
The compiler and memory gaps remain open; the priority report owns exact hashes,
MAD and host contention.

## September 29, 2026 readonly observable boundaries

Flat private void bodies can establish readonly parameter liveness before HOT
lifting. Qualification scans the whole body first and marks a parameter only
when a direct leaf read supplies an observable store or pinned call operand.
Parameter assignments, unsupported control and unknown arities retain the
complete analysis. Newly pinned boundaries use the same validated first-lift
admission as exposed functions; every call/control family must also be pinned,
and intrinsic calls retain HOT target analysis. Invalid bodies still reject.

[Pass and ownership regressions](../../../../../src/passes/dae2_observed_entry_wbtest.mbt)
and [both dispatcher modes](../../../../../src/cmd/dae2_observed_entry_wbtest.mbt)
preserve stores and live arguments while removing an unrelated dead parameter.
The V6 checkpoint passes 12,795 default tests and 1,716 bounded runtime
observations. Three quiet pairs improve the 128-wrapper/128-store pipeline
57.26% in DAE2 and 30.68% in DAE2-O with identical bytes. Full compiler costs
remain near their prior four/seven-second levels; this does not close P03.
The [priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
owns exact hashes, native controls, MAD, memory uncertainty and pending renewal.

## September 28, 2026 compact locations and early admission

Node locations now occupy one contiguous range per analyzed function. The
function snapshot stores its base and count instead of an additional node-ID
array. Bulk graph growth retains spare capacity across neighboring bodies;
dependency IDs, negative sentinels and insertion order are unchanged. V3 fused
call metadata and intrinsic target pins into dependency analysis. V4 records
all six call forms during the existing raw control scan, including legacy
bodies/catches, and avoids collecting the same metadata again in HOT.

A body whose boundary, callees and indexed control families are fully pinned
may avoid its first HOT lift. Public type-family seeds count as pins before
fixed-point propagation; private direct boundaries stay independent. The
original body still undergoes function-body validation against a reusable
module environment. Each validation owns its local, label, operand and
initialization state; no sibling state is retained. Intrinsic calls retain
HOT analysis to pin their literal `ref.func` targets. Legacy/unknown controls,
invalid family IDs and unpinned boundaries retain the full path. Metadata still
drives rewrite admission after solving.

For a local with exactly one unconditional top-level `local.set`, root-order
analysis can resolve reads to entry or that write without building CFG and
LocalGraph. Operand reads precede completion of the write. Shared reads seen
on both sides, detached reads, conditional/repeated writes, shared writes and
handler/continuation bodies retain the complete flow/unknown fallback. The
proof does not mutate HOT and dies with the analyzed function.

The initial v2 proof expanded shared HOT subtrees repeatedly and stalled on the
large compiler input. That prototype is rejected: its small runtime controls
and faster graph-allocation benchmarks did not establish enclosing performance.
A sixteen-node regression subsequently failed its traversal-work bound while
preserving the expected cross-write unknown read. V3 caches non-read visits in
the source scratch, invalidating them after each admitted root write. This
fixes exponential expansion but can revisit a shared subtree after every
unrelated write. V4's red-first many-write DAG regression exposed that remaining
cost. Unique postorder plus one reverse propagation computes each node's first
and last reaching root ordinal. A read entirely before its sole write is an
entry read, a read entirely after is a write read, and a crossing interval is
unknown. Operands within the write root precede its completion. A write used
under another root, or repeated as a root, requires full flow. The work is
linear in nodes, child edges and roots; scratch remains function-scoped.

V4's one-write native controls regress, so V5 uses a separate single-write
proof with only two visit epochs and a scalar completion flag. It avoids the
interval/postorder arrays while preserving linear work. The multi-write proof
still uses root intervals; shared or repeatedly executed writes require full
flow. Indexed LocalGraph queries now return a scalar readonly source record
for DAE2, avoiding an enum allocation per source. Owned-array and enum queries
remain available, with identical source order and checked bounds.

V3 also keeps retained leaf rewrites scalar, classifies dependency-node effects
once per operand loop, and appends private function signatures in one owned type
workspace. The outer source group vector is copied once; original definitions
remain unchanged. Lowering may replace the workspace after adding control
types, at which point its flattened count is recomputed. Private appends update
that count directly, preserving metadata and allocation order. Family rewriting,
canonicalization, name remaps and full final validation remain unchanged.

Red-first controls exposed extra lifts, exact-capacity bulk growth, missing call
metadata, unnecessary local flow and repeated DAG traversal. V5 passes 12,788
default wasm-gc tests, 477 native IR tests and nineteen focused native tests.
The bounded runtime matrix validates 325 modules with 1,560 matching results,
effects and traps against original/baseline/candidate/verified-v133 behavior.
V4 pinned-call sibling pipelines improve DAE2/O 51.33%/18.88%, and V5
conditional-write DAE2 improves 3.99% over V4. The fresh V5 large pass-local
comparison remains 3,976.588 ms at 9.34× v133 for DAE2 and 7,213.857 ms at
4.44× for DAE2-O. DAE2-O also remains larger than the oracle by 382,584 raw
bytes. These improvements do not close the large compiler or output-quality
gaps. Exact hashes, dispersion and controls are in the
[priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls).
Dedicated aggregate renewal remains deferred
during performance iteration; these changes do not inherit earlier signoff.

Sources: [implementation](../../../../../src/passes/dead_argument_elimination2.mbt),
[range invariants](../../../../../src/passes/dae2_compact_locations_wbtest.mbt),
[first-lift controls](../../../../../src/passes/dae2_first_lift_wbtest.mbt),
[raw call metadata](../../../../../src/passes/dae2_raw_calls_wbtest.mbt),
[pinned-call benchmarks](../../../../../src/passes/dae2_pinned_calls_perf_wbtest.mbt),
[entry-write behavior](../../../../../src/passes/dae2_entry_write_wbtest.mbt),
[source-order checks](../../../../../src/passes/dae2_entry_sources_wbtest.mbt),
[DAG interval benchmarks](../../../../../src/passes/dae2_entry_interval_perf_wbtest.mbt),
[scalar source ownership](../../../../../src/ir/local_graph_scalar_sources_wbtest.mbt),
[scalar query benchmarks](../../../../../src/ir/local_graph_scalar_sources_perf_wbtest.mbt),
[native controls](../../../../../src/passes/dae2_priority_perf_wbtest.mbt),
[leaf rewrites](../../../../../src/passes/dae2_rewrite_leaf_wbtest.mbt),
[type workspace](../../../../../src/passes/dae2_type_workspace_wbtest.mbt),
[allocation controls](../../../../../src/passes/dae2_rewrite_allocation_perf_wbtest.mbt),
[dispatcher](../../../../../src/cmd/dae2_entry_write_wbtest.mbt), and
[validation ownership](../../../../../src/ir/hot_validation_env_wbtest.mbt).

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

This page describes the implemented Binaryen 132 port, superseding the earlier
proposal to leave `dae2` unknown or to add only parameter forwarding.

The module pass owns a short-lived usage graph. Each function parameter and
whole result tuple has a location; HOT expression values have locations too.
Type-family locations connect referenced functions to indirect calls. Observable
uses seed the graph, and a queue visits each live location at most once.

## September 27, 2026 flat dependency storage

DAE2's parameter, result, and expression-value graph stores actual dependencies
in flat source/next arrays, with first/last edge indices for each location.
Creating a location no longer allocates an empty heap array. Appending through
the last edge preserves insertion order and therefore the existing observation
queue order. Duplicate dependencies remain harmless; unobserved cycles remain
unused, and a later observation resumes the same monotone fixed point.

The sparse-location regression first failed with 64 edge rows for an edgeless
64-location graph. It now requires no edge entries until a dependency is added,
then verifies exact live locations, duplicates, disconnected cycles, negative
sentinel inputs, insertion order, and repeated solving. The existing unrepresented
read test still checks both parameter-entry and write dependencies. The command
fixture verifies dead-argument removal while keeping a live forwarded parameter
in both DAE2 modes.

Sources: [graph implementation](../../../../../src/passes/dead_argument_elimination2.mbt),
[invariants](../../../../../src/passes/dae2_sparse_edges_wbtest.mbt),
[sparse and dense controls](../../../../../src/passes/dae2_sparse_edges_perf_wbtest.mbt),
[dispatcher fixture](../../../../../src/cmd/dae2_sparse_edges_wbtest.mbt).
All six focused regressions pass. Native construction/solve benchmarks compare
the original row algorithm and flat storage in the same binary: **114.69 →
32.27 µs** for 8,192 sparse locations, **454.05 → 127.55 µs** for 32,768, and
**117.19 → 79.24 µs** for a denser 4,096-location control. These isolate graph
storage and solving; they do not establish a whole-pass speedup. Final artifact
and generated evidence belongs to the
[tracing playbook](../../../tooling/tracing-playbook.md).

## September 26, 2026 sparse local-flow query storage

Reverse reaching-definition queries now allocate cache entries only for queried
block/local pairs. They reuse visited-block and worklist storage and index a
predecessor's last local writes lazily; blocks with at most four actions retain
the direct scan. The sparse control-flow fallback also reuses traversal storage.
Caches remain scoped to one immutable function/CFG, preserve source ordering,
and publish results only after completing the predecessor closure.

Bounded tests first failed on dense cache capacity and eight query-workspace
allocations instead of one. They retain exact reaching writes across separate
blocks. Existing join, loop and handler fixtures compare sparse results with
the converged reference solver. Command coverage checks real unused-argument
pruning while preserving a cross-block local value.

Focused native graph-construction benchmarks improve `749.80 → 401.22 µs` for
128 cross-block reads and `2.81 → 1.47 ms` for 256; each fixture declares four
times as many locals as it reads. These measurements establish the targeted
analysis gain, not a whole-DAE2 speedup. Evidence:
`src/ir/local_graph_query{,_perf}_wbtest.mbt`,
`src/cmd/perf_local_flow_wbtest.mbt`, and
`.tmp/pass-perf-work-20260926/local-query-{before,after}.log`.
Final aggregate results and runtime limits are in the [shared renewal](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal).

## September 26, 2026 shared source-order index

The [CoalesceLocals source-order renewal](../coalesce-locals/starshine-strategy.md#september-26-2026-source-order-local-access-index) also improves large-input DAE2: seven isolated alternating pairs give pipeline `7,633.494ms → 6,438.548ms` (**15.7% faster**), with byte-identical outputs. Unlike the lazy-flow fixture gain below, this is a confirmed compiler-artifact improvement. The shared ordering proof and strict bounds remain unchanged; the linked page owns hashes, tests, the small DAEO tradeoff and signoff evidence. Initial lifting and required local-flow solving remain open targets.

## September 26, 2026 lazy local-flow analysis

LocalGraph/CFG construction now waits for the first live local read. The conservative all-writes index waits for the first read whose reaching sources are unknown. Both snapshots are function-local and built at most once; unknown reads still depend on the entry parameter and every possible write, including unrepresented nodes. This follows the demand-driven `LazyLocalGraph` queries in [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp); Starshine also needs dependencies through body locals.

Two bounded regressions failed with two unnecessary builds each. Final tests cover real signature pruning, retained parameter reads, deliberately unrepresented reads with conservative dependencies, and command dispatch. The focused suite passes 77 tests; `moon info`/`moon fmt` succeed with no public API change.

Native `0925e7e8ae15e1e06d4fa171fdcf5b251e42f68f627ef7955a10bf032570748f` versus baseline `b084365e0bd4b2bc98457da7eb8773504b5cf2720665dea7ae5b961d30c41a06`, isolated alternating samples after one warmup:

- 1,000 store-heavy functions requiring signature rewrites: seven-pair pipeline `359.096ms → 322.358ms` (**10.2% faster**).
- 1,000 unchanged store-heavy functions: three-pair pipeline `114.711ms → 81.794ms` (**28.7% faster**).
- Small compiler: seven-pair `19.742ms → 19.508ms`, a small difference.
- Large compiler: an apparent three-pair `8,292.333ms → 8,176.763ms` gain did **not** repeat. Seven pairs give `8,200.787ms → 8,222.452ms`, with mixed per-pair deltas. This establishes no meaningful large-artifact speedup.

Every paired raw output is identical. Evidence: `.tmp/dae2-lazy-flow-paired-<fixture>-final-20260926/`, `.tmp/dae2-lazy-flow-confirm-large/result.json`, and the [fuzzing page](./fuzzing.md). Source/tests: [`dead_argument_elimination2.mbt`](../../../../../src/passes/dead_argument_elimination2.mbt), [`dae2_lazy_flow_wbtest.mbt`](../../../../../src/passes/dae2_lazy_flow_wbtest.mbt), and [command fixture](../../../../../src/cmd/dae2_lazy_flow_wbtest.mbt). Initial lifting and actual local-flow solving remain performance targets.

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

## September 27, 2026: retain identical child spans during rewriting

**Timing supersession:** the [nested-timer correction](../../../tooling/tracing-playbook.md#september-27-2026-nested-timing-scope-correction)
reparses the same saved traces and supersedes the optimizing pipeline totals
below: small **26.037 → 25.455 ms**, large **8,517.890 → 8,502.036 ms**,
and active wide fixture **60.813 → 58.127 ms (4.4%)**. The previous totals
included nested cleanup twice. Plain DAE2, exact-byte checks, active signature
changes and runtime evidence are unchanged; large optimizing performance
remains open.

DAE2 compares replacement children with the node's current span and skips the
write when their order and count are identical. Calls and control rewrites can
reset a span before this point, so comparing against the originally captured
children would be incorrect. Real changes still use the shared mutation API;
unchanged spans avoid copying old children, appending duplicate arena storage
and invalidating revisions. Tuple memoization, ordering and signature rules
remain unchanged.

The unchanged-span test failed before implementation. Both bounded storage/order
invariants, the active kept/discarded call fixture and 86 other focused DAE2
checks pass (89 total), including tuples and handlers. Native batches improve
**3.12 → 1.40 µs** for 64 repeated writes and **37.76 → 11.54 µs** for 1,024.
Both controls create a fresh small function per batch because the former write
appends arena storage; setup is included equally and storage cannot accumulate
across benchmark iterations.

Compiler pipeline medians are effectively flat: large DAE2 **5,172.277 →
5,199.715 ms**, large DAE2-optimizing **11,435.083 → 11,431.747 ms**; small
DAE2 17.493 → 17.614 ms and optimizing 33.900 → 32.941 ms. These large
budgets remain open. A new 50,413-byte fixture with 64 private helpers, two
parameters and 256 live additions each measures an active rewrite: the unused
second argument disappears from every helper signature. DAE2 is 51.720 →
51.196 ms and optimizing improves **68.743 → 64.668 ms (5.9%)**. This is a
dedicated workload, not a claimed compiler-artifact gain.

All six one-warmup/three-pair comparisons retain exact before/after bytes,
traced/untraced agreement and independent validation. Original and both pass
outputs from both binaries return identical values at five inputs including
32-bit overflow boundaries. Final aggregate renewal remains pending.

Evidence: `.tmp/pass-perf-next-20260927/dae2-child-{checks.json,bench-1.log}`,
`dae2-child-pairs-{small,large,wide}/result.json`, and
`dae2-child-wide-{input,runtime,signatures}.json`. The first benchmark round
was rejected for foreign CPU contention. Native SHA-256: `928989c8aaf2b1a390fb5493571d8b746ac7536ab750d295be5cc7990b30bb08`.
Sources: [rewriter](../../../../../src/passes/dead_argument_elimination2.mbt),
[span invariants](../../../../../src/passes/dae2_child_rewrite_wbtest.mbt),
[native controls](../../../../../src/passes/dae2_child_rewrite_perf_wbtest.mbt),
and [dispatcher fixture](../../../../../src/cmd/perf_dae2_child_rewrite_wbtest.mbt).

## September 27, 2026: reject retained analysis bodies

Retaining analyzed HOT bodies until rewrite avoided a second lift and improved
the dedicated 64-function benchmark from 792.82 to 624.50 µs. It did not
improve the large compiler workload: one warmup and three alternating pairs
measured plain DAE2 **5,489.948 → 5,695.433 ms (+3.7%)** and optimizing DAE2
**9,154.678 → 9,429.039 ms (+3.0%)**. Peak resident memory increased from
302,124 to 394,520 KiB (+30.6%). All four small/large paired comparisons
retained identical bytes, traced/untraced agreement and independent validation.

A smaller 32,768-node cache also regressed large plain DAE2, **5,459.205 →
5,584.159 ms (+2.3%)**. That variant's remaining optimizing measurements were
stopped after rejection; they do not constitute a completed matrix. Production
retention code was removed. A later attempt must reduce live memory or shorten
retention lifetime, rather than assume fewer lifts imply faster full passes.

The bounded [fixture test](../../../../../src/passes/dae2_retention_wbtest.mbt)
checks active rewriting and source reuse. The retained [native benchmarks](../../../../../src/passes/dae2_retention_perf_wbtest.mbt)
measure the current uncached implementation at 64 and 1,024 functions; they
are controls for future work, not a shipped retention optimization. Local
evidence is under `.tmp/pass-perf-reuse-20260927/`: `dae2-retention-pairs-*`,
`dae2-retention-memory.json`, `dae2-retention-small-cache-pairs-*`, and rejected
source snapshots. The initial ownership/work regression failed before the
prototype; 74 focused checks passed before its performance rejection.

## September 28, 2026 performance reuse contracts

Compact indexed-control family summaries let unchanged functions avoid a second lift when every referenced signature family is unchanged; unresolved families retain the conservative rewrite path. Handler admission avoids rebuilding handler-free bodies and preserves untouched sibling bodies. Legacy adaptation still canonicalizes grouped local declarations when another function changes, preserving the original encoded output. Whole-HOT retention remains rejected.

Tests and native controls: [dae2_control_summary_wbtest.mbt](../../../../../src/passes/dae2_control_summary_wbtest.mbt), [dae2_control_summary_perf_wbtest.mbt](../../../../../src/passes/dae2_control_summary_perf_wbtest.mbt), [dae2_handler_admission_wbtest.mbt](../../../../../src/passes/dae2_handler_admission_wbtest.mbt), [dae2_handler_admission_perf_wbtest.mbt](../../../../../src/passes/dae2_handler_admission_perf_wbtest.mbt). The [campaign report](../../../tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign) owns frozen-binary artifact timings, verified-v133 evidence and final correctness outcomes; helper timings alone do not close the remaining pipeline or parity gaps.


## September 28, 2026 shared follow-up controls

Shared initialization ownership and HOT result queries retain their semantic
contracts in the [IR ownership rules](../../../ir2/architecture-rules.md#performance-reuse-ownership-contracts).
The [follow-up report](../../../tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign)
separates new helper evidence from this pass's enclosing timings and final
aggregate status. Prior signoff does not automatically cover the new sources;
guarded paths and remaining size/parity gaps retain their existing limits.

The V21 expansion validates 3,172 modules and records 13,776 observations.
DAE2/O now agree with original and v133 on both old stacked-read witnesses;
V18 incorrectly returned 11. SL full/nostructure still return 22, so shared
cleanup signoff remains blocked. The V24 shared source-order repair is under
full/native/runtime confirmation; see the [failure and repair trial](../../../tooling/tracing-playbook.md#v21-stacked-block-runtime-failure-and-v24-repair-trial).
Historical 79-fixture V18 evidence does not cover these new witnesses.
