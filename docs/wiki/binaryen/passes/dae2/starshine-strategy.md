---
kind: entity
status: working
last_reviewed: 2026-09-29
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
