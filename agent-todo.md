# Agent Tasks

## v0.1.1 — Performance validation and remaining gaps [IR2-PERF-FOLLOWUP]

- **Goal / why:** close the remaining command, pipeline and oracle gaps before
  release while preserving active transformations, output quality and ownership.
- **Current DAE2/O checkpoint:** reverse expanded flow repairs the dense-solver
  regression introduced by the stacked-read correctness fix. Subsequent slices
  remove repeated opcode formatting, predecessor walks, region-root lookup,
  quadratic source unions and reader-list searches, source-row copies and a
  duplicate operand-order traversal and walks through proven pure subtrees,
  boxed private CFG segment rows, growth of fixed-size CFG maps and empty
  continuation-query allocations and vacuous catch-layout scans.
  Accepted changes and rejected cache trials
  are recorded in the [DAE2 strategy](docs/wiki/binaryen/passes/dae2/starshine-strategy.md).
  All 12,946 default tests, 126 bounded modules / 1,029 original/v133
  observations and measured before/after bytes pass. The new active-reader
  fixture adds one passing bounded guard and four dedicated native controls;
  its matched 8192-reader pipelines improve 57.40%/49.80%. This deliberate
  scalability workload does not establish a compiler-artifact gain. Pure-subtree
  pruning reduces dependency-analysis instructions 0.77% and paired large
  DAE2 time 1.44%; optimizing compiler time is near flat and control costs
  remain recorded. The new active pure-tail pipeline fixture adds one focused
  passing default guard and four native benchmarks; matching frozen-binary
  DAE2/O comparisons improve 45.76%/45.33%, with 28 original/v133 observations.
  Compiler competitiveness remains open.
- **Remaining DAE2/O work:** close the multi-second compiler gap by reducing
  source-order scans, CFG/reaching-definition work, lift/lower and optimizing
  cleanup. The 32-root dependency-index threshold trial is rejected; sparse
  helper wins did not carry into compiler pipelines. Single-predecessor row
  reuse and its known-write revision are also rejected: helper gains accompany
  near-flat active workloads and +2.41%/+1.77% revised large timings, with only
  0.15% fewer dependency instructions. Dedicated candidate controls remain;
  production keeps the v13 query. Packed private CFG segments remove 490,847
  allocator requests in dependency analysis (1.19%) with near-flat compiler
  timings and recorded active-control costs. Fresh v133 ratios remain
  9.19×/4.39× on the large v19 input. Fixed-size CFG maps remove another
  63,326 requests and 0.34% of dependency instructions, with recorded control
  costs and near-flat compiler timings. Own-effect reuse removes repeated
  descriptor work and another 0.99% of dependency instructions without an
  extra retained node array; compiler timings and standalone mask controls
  remain near flat. Empty continuation guards remove 4,340,384 requests
  (10.66%) and 2.62% of dependency instructions, with paired large gains
  of 0.96%/1.46% and control costs recorded. Catch-layout preflight removes
  another 2.05% of dependency instructions and 38,154 requests, with paired
  large gains of 1.43%/1.27%. Inspect duplicate all-verifier core calls,
  preceding-query allocations, LocalGraph writer metadata scans, quadratic
  distinct-source unions and field-specific HOT reads next. The initial proposal-feature allocation
  interpretation is superseded by generic array-growth attribution. Verified-v133
  ratios, cumulative timing, memory and instruction
  attribution are owned by the strategy page. Keep small/control costs and
  identical-binary calibration limits explicit. Long aggregate fuzz remains
  deferred at the user's request; earlier generated results do not sign current
  source. Exit criteria remain valid output, measured improvement on active and
  compiler workloads, classified size/parity differences, and final renewal.
- **Correctness and size limits:** V25 repaired the stacked-read and one-armed
  branch-exit failures exposed after V18. Its 96-fixture replay validates 3,302
  modules / 25,018 observations with no candidate/oracle failures; eight V18
  semantic failures and six V18 aborts remain historical evidence. V18's 79-
  fixture results do not cover the new witnesses, and its faster timings are
  not a correctness-equivalent baseline. The V25 large DAE2 output is 458 bytes
  larger across 41 functions than V18; finish classifying that drift. Current
  performance changes preserve V25-based bytes. Binaryen optimizing output-size
  gaps remain open; smaller plain DAE2 output alone does not prove a win.
  See the [priority evidence](docs/wiki/tooling/tracing-playbook.md#v18-complete-enclosing-evidence-and-remaining-gaps)
  and the strategy page for supersession, oracle hashes and unresolved limits.
- **Historical next-v9 checkpoint:** next-v9 passes 12,745 wasm-gc tests,
  473 native IR tests, interface generation, formatting and native CLI build.
  The iteration has 174 unique passing native helper cases; this latest slice
  adds 46 topology/influence benchmark cases. All measured artifact bytes match
  before/after; 1,628 bounded runtime observations across 18 passes match original
  and verified Binaryen 133 behavior. The
  [next campaign](docs/wiki/tooling/tracing-playbook.md#september-28-2026-next-performance-campaign)
  records source hashes, dispersion, RSS, rejected experiments and exact limits.
- **Completed mechanisms / remaining scope:** fused DAE topology reduces small
  DAE native instructions 4.32%; the private operand-query value record removes
  six heap sites; small private source rows avoid an extra growth; influence
  rows allocate only for observed writes. The latter improves helper controls
  58–87% and reduces small DAE2/propagation instructions 0.99%/0.38%. These do not
  close the remaining multi-second pipelines or establish Binaryen competitiveness.
  The stack value-array layout is rejected for a native debug compiler limitation.
- **Current large attribution:** fresh v9 Callgrind profiles against the pinned
  large input reduce whole-command instructions 11.9% for DAE2 and 6.6% for
  Coalesce against the saved `before.exe`, but include decode, validation,
  lift/lower and encoding. DAE2's largest self costs are object destruction
  17.96%, frees 8.19%, and HOT node reads 5.59%; Coalesce's are destruction
  12.34%, HOT node reads 6.28%, frees 5.81%, and HOT value/local conflicts
  2.09%. See the [v9 attribution](docs/wiki/tooling/tracing-playbook.md#v9-large-dae2-and-coalesce-attribution).
  Next, isolate P03's lift/analysis/lower costs and evaluate field-specific HOT
  reads in P12; don't extend graph metadata based only on helper timings.
- **Active tradeoffs / renewal:** singleton/four-merge source observations still
  cost 68.82 → 93.77 ns for one read; the current 128-read control improves, but
  earlier costs remain relevant. Two small topology controls regress; large
  wall-time cohorts record foreign CPU activity and remain diagnostic. An initial
  +1,576 KiB large OI RSS change reverses in seven renewed pairs; preserve both
  runs without claiming a firm RSS win or regression. Quiet timing and final
  affected-consumer aggregate renewal remain required after performance work.
- **Historical checkpoint:** the frozen v8 candidate passes 12,693 default tests, interface
  generation, formatting, native CLI/generator builds and README/API sync.
  The follow-up adds 386 native benchmark cases in 19 files. Completed mechanisms,
  rejected experiments and their tradeoffs live in the
  [follow-up report](docs/wiki/tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign);
  the [first campaign](docs/wiki/tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign)
  retains its original measurements and 230,000-case signoff.
- **Historical v8 correctness checkpoint:** all 230,000 final v133 comparisons completed with
  zero validation or observed original/Starshine semantic failures. The
  101,860 shape residuals, 2,368 canonical size losses and 9,717 runtime
  blocks remain unresolved. All 230,000 recorded cohort outcomes match the first
  campaign; all 360 retained residual outputs and 2,368 size-losing outputs are
  byte-identical to their first-campaign replays.
  v8 fixes the v7 encoding-cleanup bypass; the rejected candidate remains in the
  report, and its favorable unchanged-command timing is superseded.
- **Measured tradeoff:** the v7 large DFE traced pipeline is 4.05% slower (MAD 2.54%)
  than the first-campaign binary. Its 17-pair untraced command time is within
  dispersion (+1.20%, MAD 1.30%), while median peak RSS falls 7.21%. Retained for
  memory/work reduction and other measured gains; this is not a DFE speedup.
  Final v8 active nested-handler Coalesce adds 0.103 ms (+4.11% paired, MAD 1.14%);
  one large propagation RSS sample adds 4,612 KiB and DAE2-optimizing adds
  18,724 KiB. Preserve these costs in future controls.
- **Required APIs / invariants / exit:** use the owner contracts and affected
  consumer matrix below. New public APIs include `tc_state_fork_body`, checked
  LocalGraph source count/enum/scalar-value queries, and reusable module/body
  validation accessors and `hot_node_op`; review their `.mbti` contracts. Shared masks require
  expression-scoped ownership. Require material enclosing-pass or
  command gains with bounded memory, active coverage, exact size guards and full
  final validation. Long fuzz/perf checks remain outside default tests.

Active unreleased work only, reviewed September 29, 2026. Follow
[the docs schema](docs/README.md). New comparisons require verified
[Binaryen 133](docs/wiki/binaryen/release-horizon-and-oracles.md); older oracle
versions and checkpoints retain their historical labels and scope.

### Latest measured baseline

The latest complete DAE-priority oracle sweep is priority-v18 `6ee77894…`,
using verified v133, CPU 6, one warmup and three alternating samples.
Pass-local ratios are:

| Pass | Small Starshine ms / v133 ratio | Large Starshine ms / v133 ratio |
| --- | ---: | ---: |
| `dae` | 43.616 / 58.46× | 831.609 / 1.94× |
| `dae-optimizing` | 124.685 / 8.18× | 1,090.860 / 0.61× |
| `dae2` | 4.546 / 4.44× | 4,169.155 / 9.03× |
| `dae2-optimizing` | 13.152 / 4.08× | 7,538.402 / 4.42× |

Large optimizing outputs remain size-losing against v133: DAEO adds 28,201
raw / 41,427 canonical bytes; DAE2-O adds 382,584 raw / 422,019 canonical.
Runtime checks do not close these parity gaps. Current source still requires
affected aggregate renewal after performance work. The [priority report](docs/wiki/tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
records exact source/binary/input hashes, timing scope and limitations.

The historical complete thirteen-pass sweep is `bbde3e9e…` (v8). These diagnostic sweep medians use CPU 6,
five small and three large samples, warmup and reference brackets. Inner ratios
exclude surrounding pipeline/command work. The small Precompute timer is missing,
shown as n/a. Different tracing and host conditions prevent subtracting historical
absolute times. The [v8 results](docs/wiki/tooling/tracing-playbook.md#v8-final-results)
own hashes, MAD, command ratios, canonical sizes and limitations.

| Pass | Small pipeline ms | Large pipeline ms | Small inner/v133 | Large inner/v133 | Remaining owner |
| --- | ---: | ---: | ---: | ---: | --- |
| `precompute` | 1.663 | 837.585 | n/a | 0.28× | P02, P11, P12 |
| `precompute-propagate` | 6.118 | 1,736.038 | 0.65× | 0.75× | P01, P02, P12 |
| `dae2` | 15.224 | 4,726.612 | 15.03× | 10.12× | P03, P01, P12 |
| `dae2-optimizing` | 25.040 | 8,174.386 | 7.75× | 4.78× | P03, P05 |
| `coalesce-locals` | 9.591 | 4,844.430 | 1.72× | 3.93× | P04, P12 |
| `simplify-locals` | 7.026 | 2,186.084 | 0.39× | 0.15× | P05, P02 |
| `optimize-instructions` | 4.826 | 2,539.513 | 1.29× | 0.66× | P06, P11 |
| `duplicate-function-elimination` | 0.510 | 742.713 | 1.95× | 9.85× | P07, P06 |
| `dae` | 52.470 | 884.529 | 74.79× | 1.99× | P08 |
| `dae-optimizing` | 143.095 | 1,117.779 | 8.69× | 0.56× | P08, P05 |
| `inlining` | 2.712 | 1,786.330 | 1.02× | 2.01× | P09 |
| `inlining-optimizing` | 98.710 | 677.465 | 1.72× | 0.04× | P09, P05 |
| `simplify-globals-optimizing` | 23.151 | 62.529 | 17.55× | 0.04× | P10, P05 |

Large DAE/DAEO, optimizing inlining and SGO include guarded/fallback work;
these timings do not establish full cleanup breadth. Active CA and nested-handler
controls remain separate. All five SimplifyLocals modes require independent
active coverage. Significant canonical size losses remain even where an inner
timer is competitive.

### Priority readout

The V18 four-pass oracle ratios are the last complete measurements; the full thirteen-pass
v8 sweep remains historical until other owners and affected v133 aggregates are
renewed. P08 plain DAE has the worst recorded
small pass ratio (58.46×) at 44 ms; P10 SGO's historical ratio is 17.55× at 23 ms. P03 is
the largest multi-second pass-local target: large DAE2 is 4.17 s at 9.03× and
DAE2-optimizing is 7.54 s at 4.42×. P04 Coalesce's historical result is 4.84 s at 3.93×. P07 DFE
is under one second but still 9.85× on the large input. These targets need
active transforming fixtures; guarded or unchanged paths do not count as
coverage.

Pipeline time also remains high when the inner pass is faster than Binaryen:
large Precompute is 838 ms at 0.28×, propagation 1.74 s at 0.75×, and OI
2.54 s at 0.66×. Keep those on P02/P06/P11/P12/P13's shared lift, validation,
lowering and command path rather than making the pass-local algorithms more
complex without phase evidence. The v9 profiles below sharpen P03/P04/P12;
they do not refresh these oracle ratios.

## v0.1.1 — Remaining performance owners [IR2-PERF-NEXT]

**Goal / why:** close the measured pipeline/oracle gaps while preserving active
transformation breadth, valid output, runtime behavior and canonical output
quality. The [follow-up campaign](docs/wiki/tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign)
and its linked first campaign own completed P01–P14 mechanisms, all benchmark sources, rejected designs and
measurement limits. The tasks below describe the remaining costs, rather than
asking another implementation run to repeat those mechanisms.

**Shared requirements / APIs:** preserve input ownership, deterministic source
order, parameter slots, effect/trap behavior, handler/loop liveness, capture
lifetimes, tuple producers, metadata and exact encoding/errors. No new public API
is required by these slices; review `.mbti` if a concrete caller requires one.
Body/revision facts and environments must invalidate on every relevant mutation.
Retain complete final-module validation and exact whole-module size guards.

**Dependencies / exit criteria:** use frozen native binaries, verified Binaryen
133, pinned input hashes, alternating artifact pairs, MAD and peak RSS. Require
material full-pass or end-to-end gains with no important behavior, size, memory
or active-coverage regression. A subsecond inner timer does not close a
multi-second pipeline cost. Guarded or unchanged paths do not establish cleanup
breadth. Shared changes require all affected consumers in the matrix below.

### P01 — Write-heavy propagation state [IR2-PERF-PC-FLOW]

- **Owner / why:** [local_graph.mbt](src/ir/local_graph.mbt), transfer and
  predecessor merge; large propagation still includes substantial state/CFG work.
- **Deliverables / tasks:** profile remaining write-heavy transfer allocations
  and predecessor scans; try mutation-scoped changed-local sets only when all
  predecessor deltas can be represented. Keep exceptional/full-scan fallback,
  ordered sources and semantic-change successor scheduling. Wide tuple branch
  journals are implemented; remaining expanded predecessor work needs separate
  evidence.
- **Invariant / dependencies:** expanded read-only borrowing and first-write
  ownership are implemented; do not reimplement queues, sparse tuples, borrowed
  predecessors or thresholded unions. DAE2/OI/MergeLocals/SSA consume this owner.
- **Exit / suggested tests:** improve enclosing propagation/DAE2 artifacts with
  tiny, write-heavy, asymmetric-subset, join/backedge and sibling-isolation
  controls; extend [transfer controls](src/ir/local_graph_transfer_borrow_perf_wbtest.mbt).

### P02 — Remaining Precompute scheduling and cleanup [IR2-PERF-PC-PIPELINE]

- **Owner / why:** [pass_manager.mbt](src/passes/pass_manager.mbt) and
  [precompute.mbt](src/passes/precompute.mbt); pipeline cost remains much larger
  than the recorded inner rewrite.
- **Deliverables / tasks:** use the renewed enclosing timer and self-instruction
  profile to target remaining raw cleanup, body allocation and lift/lower work.
  Reuse body-scoped facts only within a proved version, rebuilding after splices.
- **Invariant / dependencies:** unchanged-function reuse, deferred statistics,
  tail admission and streamed snapshot-prefix scans are implemented. Keep active
  folds, infinite-loop tails, NaN/signed-zero, metadata and proposal boundaries.
  Propagation depends on P01; plain Precompute does not.
- **Exit / suggested tests:** repeat an enclosing-pipeline gain without tiny
  active-body regression; extend [raw reuse](src/passes/precompute_raw_identity_perf_wbtest.mbt)
  and [tail/prefix controls](src/passes/precompute_tail_admission_perf_wbtest.mbt).

### P03 — Remaining DAE2 graph, lift and lower costs [IR2-PERF-DAE2]

- **Owner / why:** [DAE2](src/passes/dead_argument_elimination2.mbt); both large
  modes remain multi-second with substantial verified-v133 gaps.
- **Deliverables / tasks:** profile dependency solving, demanded LocalGraph,
  location lookup and unavoidable lift/lower allocation separately. Reuse
  compact affected-function/revision facts or bounded scratch only with measured
  benefit; preserve conservative dependencies for unknown control information.
  Lean-v5/v5b source-order caches are rejected: strong synthetic gains did
  not improve compiler pipelines, and v5b regressed small/large DAE2. Preserve
  the bidirectional controls; overlapping access lists remain an open quadratic
  family. Existing CFG root snapshots are now reused (lean-v6); avoid
  rebuilding region/label/type lookup per operand before adding more caches.
  The fresh lean-v2 dependency-only profile puts CFG construction at 56.38%
  and LocalGraph at 32.81% inclusive, with node reads at 15.46% self. Target
  repeated last-write decoding and source-order scans next; do not confuse
  this scoped profile with whole-command attribution.
  The v9 large whole-command profile puts DAE2 analysis at 0.58% self and the
  LocalGraph source/build/join helpers at 2.53% combined; isolate lift, analysis,
  lower and final validation before pursuing more graph metadata.
  Compact locations, fused metadata, validated first-lift admission, symbolic
  flat-body dependencies, reusable replay scratch, mandatory scalar/GC producers
  and direct scalar mutation including tees are implemented. V14 keeps exact
  full-HOT output by retaining tees according to surviving local reads; immutable
  solved-graph transfer releases adjacency without mutable-field edge overhead.
  Their evidence and rejected experiments live in the priority report.
  Branchless scalar-block admission is implemented under trial, retaining full
  HOT for indexed/multivalue/branched control. Profile remaining HOT mutation safety,
  child-use queries and final validation before adding more graph metadata.
  P05 dominates the active tee optimizing fixture; its V18 reuse trials are
  passes full/default (12,877), focused native (112) and 62 benchmark cases.
  Its 79-fixture shared-consumer matrix validates 2,730 modules with 12,008
  matching observations and unchanged V14/V18 bytes. Complete enclosing/oracle/RSS
  evidence retains the large gaps and small/mutable/entry control costs.
  Branchless-block trials expose old stacked-read errors in the full-HOT
  reference; V21 expanded operand flow fixes DAE2/O in the new runtime matrix.
  Shared SL/lowering fixes pass V25 full/native checks; bounded runtime and
  enclosing performance confirmation remain pending.
  Quiet GC/entry/pure costs require renewal.
- **Invariant / dependencies:** compact control summaries, unaffected second-lift
  admission, handler admission and immutable-local read admission are implemented.
  Preserve grouped-local bytes,
  recursive callers, signature/call remaps and open/closed-world behavior.
  Whole-HOT retention and its smaller budget already lost pipeline/RSS controls;
  do not restore them without a new work/memory model. Shared owners P01/P11/P12.
- **Exit / suggested tests:** lower plain and optimizing artifact costs with
  bounded RSS; cover distant reads, indirect/recursive calls, typed blocks,
  multi-handler/continuation boundaries and source ownership in
  [control](src/passes/dae2_control_summary_perf_wbtest.mbt) and
  [handler controls](src/passes/dae2_handler_admission_perf_wbtest.mbt).

### P04 — Remaining Coalesce CFG, interference and lower work [IR2-PERF-COALESCE]

- **Owner / why:** [Coalesce](src/passes/coalesce_locals.mbt), expanded CFG,
  liveness, interference and raw branch-depth/lowering queries; the large pass
  still costs several seconds.
- **Deliverables / tasks:** profile repeated dependency/action rows and query
  ordering on one revision; try demand-built facts or bounded scratch where
  repeated work remains. v9 shows HOT value/local conflict checks at 2.09%,
  control-instruction analysis at 1.94%, control-body boundaries at 1.66%, and
  slot-interference queries at 1.14% self. Keep raw liveness's copy-weight contribution and
  measure sparse/dense crossover across both fixture families.
- **Invariant / dependencies:** compiled source-hazard replay, fused copy/remap,
  sparse cliques, preorder control summaries, occupied-bit/live-member extra
  interference, direct indexed node liveness and dense score bounds are implemented. The final
  nested-handler control retains a measured +0.103 ms pipeline cost; preserve
  it alongside sparse/deep-control gains. Preserve parameter conflicts, tees, loop carriers,
  handlers, capture-aware output and deterministic coloring; shared P12.
- **Exit / suggested tests:** materially improve large pipeline time without
  enlarging the recorded canonical gap or losing the small control; extend
  [hazard controls](src/passes/coalesce_source_hazards_perf_wbtest.mbt), full-pass
  nested handlers and the owner's [rejection record](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md).

### P05 — Mutation-scoped SimplifyLocals cleanup [IR2-PERF-SL]

- **Owner / why:** raw cleanup in [pass_manager.mbt](src/passes/pass_manager.mbt)
  and lift/lower around [SimplifyLocals](src/passes/simplify_locals.mbt); the small
  inner timer omits substantial pipeline work and existing shape gaps.
- **Deliverables / tasks:** profile remaining suffix/effect rescans and unchanged
  cleanup rounds. The V14 tee profile attributes 34.89% of whole-command
  instructions to first-use/local-write stack-order queries and 8.04% to checked
  unreferenced-node assertions. V18 tests revision-guarded read counts, retained
  effect-scan visited rows and memoized minimum value-producing node IDs, with
  tiny/sparse direct fallback. Complete native, enclosing all-variant/shared-owner, size and RSS evidence
  establishes a 31.29% active tee DAE2-O gain, with large compiler DAE2/O flat
  and other costs retained. Next address remaining
  mutation safety and child-use scans while preserving checked API contracts.
  Fresh wrapper retirement passes full/native tests and helper controls in V21;
  enclosing evidence stopped at the new stacked-read semantic failures above.
  V25 source-position/branch-label repairs pass full/native checks; bounded
  runtime and enclosing measurements remain pending.
- **Invariant / dependencies:** incremental prefixes and arity prechecks are
  implemented, as is lazy zero-read-set cleanup; possible/unknown suffixes
  retain full checking and earliest split.
  Two eager continuation indexes already regressed full passes. Preserve all
  five variant rules and typed-loop/call alias lifetimes. Optimizing P03/P08/P09/P10
  depend on this owner.
- **Exit / suggested tests:** reduce enclosing time and shape/size gaps with
  [suffix controls](src/passes/value_suffix_reuse_perf_wbtest.mbt), candidate-free,
  nested/multivalue/effectful, dirty-round and all-variant dispatcher fixtures.

### P06 — Remaining OI validation and exact guard work [IR2-PERF-OI]

- **Owner / why:** [OI cleanup](src/passes/optimize_instructions_cleanup.mbt),
  [exact sizing](src/binary/encoded_size.mbt) and full validation; the pipeline
  remains much larger than its rewrite timer.
- **Deliverables / tasks:** attribute compatible candidate batching, remaining
  body encoding and final validation. Try one assembled body-only batch under
  an unchanged environment, retaining individual fallback for invalid or
  unprofitable candidates. A counting sink requires shared opcode/immediate
  definitions and full exact-size/error equivalence.
- **Invariant / dependencies:** identity admission, one-buffer body framing, exact
  local-remap expression sizes and shared string-pool/index lookup are implemented;
  one-buffer framing's
  isolated wide control was flat. Keep exact names,
  facts, strings, section LEB framing and complete final validation. Shared P11/P13.
- **Exit / suggested tests:** lower enclosing time without worsening canonical
  output; extend [identity](src/passes/local_group_identity_perf_wbtest.mbt) and
  [body-size controls](src/binary/encoded_size_body_perf_wbtest.mbt), mixed accepted/
  rejected candidates, string 127→128 and body/count/section LEB boundaries.

### P07 — Remaining DFE hashing, remapping and type cleanup [IR2-PERF-DFE]

- **Owner / why:** [DFE](src/passes/duplicate_function_elimination.mbt); subsecond
  absolute time still has a substantial large oracle ratio.
- **Deliverables / tasks:** profile collision equality, unchanged-body hashes,
  caller remaps and type cleanup within a remap epoch. Extend existing changed-
  target/fixed-point facts only where repeated work is measured.
- **Invariant / dependencies:** unchanged grouping admission, fused roots and
  incremental worklists, identity remap epochs and lazy body remapping are
  implemented. The profile puts shape-array hashing below 1% of self instructions.
  Retain exact collision checks, rec-group,
  descriptor/tag/continuation roots and host-visible identity; guard work shares P06.
- **Exit / suggested tests:** improve large time without tiny cost or output loss;
  use unique bodies, adversarial collisions, recursive remaps and
  [fixed-point controls](src/passes/duplicate_function_fixed_point_perf_wbtest.mbt).

### P08 — Remaining DAE uniform-actual, slice and solver work [IR2-PERF-DAE]

- **Owner / why:** [DAE](src/passes/dead_argument_elimination.mbt); count-only
  facts and loop signature indexing do not close the small oracle gap.
- **Deliverables / tasks:** profile uniform actuals, parameterized operand/slice
  construction and solving on actively transforming inputs. Establish a
  fallthrough/admission summary before an early exit: `None` and `Some([None])`
  differ, and later unsupported control can change eligibility. Reuse existing
  literal/forwarding facts, not complete copied operand arrays.
- **Invariant / dependencies:** count-only facts preserve all call/use counts;
  rebuild on body, callee boundary, numbering, arity or relevant type changes.
  Borrowed dead suffixes, lazy dropped-result cleanup and shared-code snapshot
  guards are implemented; preserve their measured scan-path tradeoffs.
  Singleton trap summaries now share the call scan and reduce small-artifact
  instructions 3.97%, with identical output. V1's three-pair active mutable
  fixture showed a 6.52% plain-DAE regression. V3's reusable recursive path scratch
  resolves the selected candidate's regression: seven quiet pairs improve
  37.385 → 36.180 ms (-3.22%), with 3.38% fewer native instructions and identical
  bytes. Preserve both results. The active profile still spends 8.66% self in
  the droppable pure-value suffix scanner; isolate its need-stack allocations.
  V7b closes the reduced complex unused-argument capture gap: an owned operand
  boundary plus borrowed nontrapping suffix proof removes arithmetic before
  allocating scratch, preserving effects and plan reuse. The two runtime
  fixtures save 11/18 raw bytes and lower canonical sizes. The V6/V8 wide
  pure-argument fixture improves DAE/DAEO 30.00%/44.65% with three of twelve
  rows observing foreign CPU activity; compiler DAE changes -0.41% in the
  contended V8 renewal. Seven quiet V6/V10 pairs renew the earlier V8 costs:
  small DAE/DAEO improve 2.71%/2.55%, and active improve 3.43%/0.43%.
  The original directional costs remain in the report. V9 repairs shared-NaN candidate
  identity so a valid pruning transaction can commit beside a NaN body.
  V18 reuses the graph snapshot's indexed function signatures in reverse
  exact-literal candidate scanning; active pruning and unchanged heap/import
  fixtures pass. Native nonconstant scanning improves 39.45 → 32.02 µs,
  active scanning remains near dispersion, and enclosing large DAE/DAEO gains
  are below 0.5%; the small artifact improves 4.17%/0.84%.
  Do not infer closure from faster scan microbenchmarks.
  Reusing the exact module graph across reverse candidate scanning and commit
  planning passes seven focused checks, including active pruning, foreign-owner
  fallback, input ownership and unchanged graph epochs. Eight native controls
  and enclosing confirmation remain pending. V24 native controls show
  heavy nonconstant full-round work improves 51.67 to 33.50 us, while active
  rounds are near dispersion (2.03 to 2.00 ms); no active speedup is claimed.
  Large guarded DAEO does not prove cleanup breadth; P05 supplies nested cleanup.
- **Exit / suggested tests:** improve active small and large parameterized cases
  with effects, traps, recursive forwarding, multi-value and typed-loop fixtures;
  extend [call facts](src/passes/dae_count_only_facts_perf_wbtest.mbt) and
  [stable operands](src/passes/dae_stable_operands_perf_wbtest.mbt).

### P09 — Remaining called-body planning and round updates [IR2-PERF-INLINING]

- **Owner / why:** [Inlining](src/passes/inlining.mbt); active large plain and
  small optimizing paths still need lower cost or oracle parity.
- **Deliverables / tasks:** profile called-body fallback classification,
  profitability/reachability, copying and repeated rounds. Key touched caller/
  callee facts to body/signature revisions; rebuild ambiguous partial-split or
  remap cases and reconsider eligibility when a callee changes.
- **Invariant / dependencies:** lazy context, scratch cursor, called-only ordinary
  classification, typed scratch cursors and plain body-measurement reuse are
  implemented. Full partial/
  named-main classification and all global/RefFunc references remain required.
  Keep actual helper deletion, metadata, recursion and thresholds; optimizing P05.
- **Exit / suggested tests:** reduce active costs without losing cleanup/size;
  extend [called planning](src/passes/inlining_called_planning_perf_wbtest.mbt),
  deep chains, SCCs, dirty rounds and active named-main runtime/tail fixtures.
  Consult the [rejected designs](docs/wiki/binaryen/passes/inlining/starshine-strategy.md).

### P10 — SGO nested cleanup and typed-loop breadth [IR2-PERF-SGO]

- **Owner / why:** [SGO](src/passes/simplify_globals_optimizing.mbt) and nested
  cleanup in [pass_manager.mbt](src/passes/pass_manager.mbt); active small cases
  retain an oracle gap and production typed-loop guards limit breadth.
- **Deliverables / tasks:** target measured nested cleanup and changed-global
  users, with body-revision facts and conservative imported-alias invalidation.
  Broaden typed-loop cleanup only with path-sensitive runtime/lifetime proof.
- **Invariant / dependencies:** early candidate admission and active full-pass
  controls are implemented; imported-alias facts and runtime-trace reuse already
  existed. Large unchanged/guarded timing is not an active optimization win;
  plain SimplifyGlobals remains a boundary. Shared P05.
- **Exit / suggested tests:** improve active global/local tails with mutable
  aliases, clean/dirty rounds and loop carriers; extend
  [full SGO controls](src/passes/sgo_full_pipeline_perf_wbtest.mbt).

### P11 — Write-heavy validator ownership [IR2-PERF-VALIDATE]

- **Owner / why:** [typecheck.mbt](src/validate/typecheck.mbt), writing control
  forks and unavoidable final validation; allocation remains prominent.
- **Deliverables / tasks:** separate writing masks from environment/body checking;
  an internal persistent/sparse mask needs explicit fork/set/intersection/
  materialization and a public writable-array compatibility design. Reuse module
  facts only under proved type/import/signature/global/table/tag/data/element
  dependencies; retain all feature/error/metadata checks.
- **Invariant / dependencies:** expression-scoped copy-on-write masks, unchanged
  join borrowing, HOT body forks, direct typed pops and CA environment reuse are
  implemented. The standalone intersection helper still returns an owned array;
  writes must never leak initialization to a parent/sibling. Public-array writers
  must clone first. Larger allocated proofs already lost controls. Consumers
  P02/P06/P07/P14.
- **Exit / suggested tests:** improve measured pass validation with tiny and
  dirty-fork controls; cover non-null locals, loops, EH and ownership in
  [alias controls](src/validate/tc_initialized_alias_perf_wbtest.mbt) and
  [branch forks](src/validate/tc_branch_fork_perf_wbtest.mbt).

### P12 — Remaining IR query and allocation costs [IR2-PERF-IR-COST]

- **Owner / why:** [lift](src/ir/hot_lift.mbt), [lower](src/ir/hot_lower.mbt),
  [source order](src/ir/hot_source_order.mbt) and [CFG](src/ir/cfg.mbt).
- **Deliverables / tasks:** profile repeated immutable type/effect/dependency/
  ordering queries and representation allocations; reuse compact facts or
  bounded scratch by revision, invalidating node/span/region/local/type changes.
  Lowered-output reuse needs unchanged captures, tuple producers and metadata too.
  The v9 whole-command profiles put the inlined HOT node getter at 5.59% of
  DAE2 and 6.28% of Coalesce self instructions. Its proven-live fast path is
  already implemented, so first compare direct field reads with full-node reads
  in bounded controls and the dominant consumer artifacts; keep deleted-node
  and incomplete-arena checks exact. V7b scalar opcode/type/child reads pass
  479 native IR tests and 2,420 shared-consumer runtime observations with
  identical bytes. Corrected V8 child controls improve 34.09 → 29.66 µs at
  width 16 and 38.69 → 30.44 µs at width 4,096. V8's quiet small shared
  pipelines range from -7.19% to +0.52%; large shared changes range from
  -1.96% to +1.55% with six of thirty rows observing foreign CPU activity.
  These controls do not establish a material compiler-wide query win.
- **Invariant / dependencies:** the getter already returns the existing node;
  deletion-bitmap reads, bulk root splices, indexed CFG membership and prior
  borrowed operands/effect caches, direct arity and small structural type-table
  lookup are implemented. Avoid whole-arena retention
  and production instrumentation wrappers. Separate P01/P03/P04 consumer controls.
- **Exit / suggested tests:** reduce actual consumer time/RSS; extend
  [liveness](src/ir/hot_indexed_liveness_perf_wbtest.mbt),
  [root splice](src/ir/hot_root_splice_bulk_perf_wbtest.mbt), mutation invalidation,
  deep/shared/effectful multivalue and handler fixtures.

### P13 — Remaining decode, validation and command encoding [IR2-PERF-COMMAND]

- **Owner / why:** [cmd.mbt](src/cmd/cmd.mbt) and [encoder](src/binary/encode.mbt);
  end-to-end costs must include work outside optimizer timers.
- **Deliverables / tasks:** use renewed empty/unchanged/active phase controls to
  target remaining decode/final-validation/encode materialization. Reuse input
  facts only under invocation-local unchanged-result contracts; preserve option,
  proposal, metadata, portfolio and output-selection semantics.
- **Invariant / dependencies:** direct sequence-leaf encoding, scoped string
  indexes and unchanged-NaN input-byte reuse with conservative encoding-cleanup
  admission are implemented.
  Empty CLI reuses encoded input and does not measure full optimizer decode/
  validation work. Shared P06/P11; tracing must preserve exact untraced bytes.
- **Exit / suggested tests:** lower untraced command wall time without omitted
  checks; extend [encoder controls](src/binary/encode_sequence_cursor_perf_wbtest.mbt)
  and both-size empty/unchanged/active commands with independent validation.

### P14 — Remaining active coverage and unmeasured owners [IR2-PERF-COVERAGE]

- **Owner / why:** [registry](src/passes/optimize.mbt),
  [performance sweep](scripts/lib/pass-performance-sweep.ts) and owner dossiers.
  Current exact-name inventory is 74 direct names plus two presets, 67 paired
  names, and 171 Binaryen optimization-section flags of which 115 are unpaired.
  Aliases/policies/tool flags prevent interpreting that as 115 missing passes.
- **Deliverables / tasks:** add valid asserted triggers before new performance
  claims for uncovered families; preserve active small DAE/DAEO, SGO, optimizing
  inlining, MergeLocals, named-main and nested-handler controls alongside guards.
  Unknown owners remain unmeasured. Resolve CA/handler precision and proposal
  parity separately from the completed CA environment setup work.
- **Invariant / dependencies:** registry census, 67 small-input command probes,
  active registry benchmarks and CA profiling/10k renewal are implemented.
  Policy masks are observable in memory even when encoded bytes are unchanged.
- **Exit / suggested tests:** each claim names input, owner and measured enclosing
  cost; extend [active controls](src/passes/registry_active_perf_wbtest.mbt) and
  [CA environment controls](src/passes/constraint_lower_module_env_perf_wbtest.mbt).

### Validation for further candidates

Write bounded semantic/ownership tests first and observe the intended failure;
implement, run the focused test, active canonical dispatcher fixture, native
controls and before/after artifacts. Serialize Moon commands and heavy evidence
with `/tmp/starshine-perf-sweep-heavy.lock`. Keep long stress in benchmark/fuzz
lanes. After **all** performance iteration is settled, run `moon info`, `moon fmt`,
`moon test --target wasm-gc`, review interfaces and explicitly rebuild both tools.

Require a verified v133 oracle, then each affected 10,000-case aggregate with
explicit `_build/native/release/build/cmd/cmd.exe` and
`_build/native/release/build/fuzz/fuzz.exe`, `--require-binaryen-version 133`,
`--jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20`, independent
validation and Node-v2 observations. Keep the default deterministic oracle cache;
Starshine outputs are regenerated. Do not add `--wasm-smith` unless requested.
Exact commands and hashes for the completed campaign are in the report.

| Canonical pass/lane | GenValid aggregate | Cleanup normalizers / extra flags |
| --- | --- | --- |
| `precompute`, `precompute-propagate` | `precompute-all` | `drop-consts`, `unreachable-control-debris`, `local-cleanup-debris` |
| `dae2`, `dae2-optimizing` | `dae2` | `drop-consts`, `unreachable-control-debris`; also `dae2 --closed-world` |
| `dae` | `dead-argument-elimination` | `drop-consts`, `unreachable-control-debris` |
| `dae-optimizing` | `dae-optimizing` | `drop-consts`, `unreachable-control-debris` |
| `inlining`, `inline-main` | `pass-inlining` | none; active named-main runtime fixture also required |
| `inlining-optimizing` | `inlining-optimizing-all` | none |
| `simplify-globals-optimizing` | `simplify-globals-optimizing-all` | `drop-consts`, `unreachable-control-debris` |
| `optimize-instructions` | `pass-oi-all` | `drop-consts`, `local-cleanup-debris` |
| `merge-locals` | `merge-locals-all` | none |
| `ssa` | `ssa-all` | `local-cleanup-debris`, `ssa-local-allocation-debris` |
| `ssa-nomerge` | `ssa-nomerge-all` | none |
| `coalesce-locals` | `coalesce-locals-all` | `local-cleanup-debris`, `unreachable-control-debris` |
| `duplicate-function-elimination` | `duplicate-function-elimination` | none |
| All five `simplify-locals` modes | respective `*-all` | none |
| `constraint-analysis` | `constraint-analysis` | none |
| `heap-store-optimization` | `heap-store-optimization` | `local-cleanup-debris` |
| `heap-store-optimization` broad control | `random-all-profiles` | no dedicated cleanup normalizer |

Shared P01/P11/P12 changes and the typed-control consumer repair require this
25-lane matrix, including both HSO lanes below. Report validation,
command, semantic, parity and size outcomes separately. Runtime-blocked cases
remain unverified; baseline byte identity establishes provenance. Classify
residuals with source/semantic/downstream evidence and measured benefits, or
retain them as parity/size gaps.

## v0.1.1 — Parity and safety [IR2-PARITY / IR2-SAFETY]

### Vacuum PR #9155 signoff and indexed inputs [IR2-VACUUM-9155]

- **Goal / why:** keep dropped call results visible inside concrete If arms for
  upstream cleanup and DAE; finish the requested current-main parity fix.
- **Current:** HOT/raw two-arm sinking and guarded indexed-result admission
  pass red-first checks, 12,907 default tests, native CLI build, API sync and six
  benchmarks. Four superseded packing fixtures now lock the per-arm contract.
  Sixty modules / 744 fixed observations match original and current main;
  13/15 canonical modules match. Nested cleanup is eight bytes smaller in
  Starshine; indexed input capture remains an open transform gap.
  Active 128/256-root controls cost 1.50/5.06 ms, showing wider growth; attribute repeated label and detached-use checks
  before broad performance signoff.
- **Remaining tasks / APIs:** normalize/capture input parameters before
  demoting indexed If signatures; reduce repeated label-guard scans with
  validated ownership/branch evidence and repeat the matched active controls.
  Reuse public HOT control/local builders and existing module type resolution.
- **Invariants:** evaluate the condition once, execute only the selected arm,
  preserve operand effects/traps/branch payloads, never re-hoist matching drops.
- **Dependencies / exit:** frozen current-main PR commit for reduced parity and
  verified release v133 for release evidence; default suite and bounded runtime
  must pass. Long aggregate renewal follows the other performance trials.
- **Tests:** existing/new `vacuum_pr9155_wbtest.mbt`, f2369/f3752/f4824/f1903,
  indexed signatures with zero/input parameters, ordered imported calls,
  integer/null traps, unreachable paths and nested downstream cleanup.


**Goal:** resolve outstanding output-quality gaps and extend evidence without
turning unsupported runtime or validator cases into successful comparisons.
Historical counts below identify saved work; renew against v133 before claiming
current aggregate results. The
[architecture audit](docs/wiki/ir2/architecture-rules.md) and
[semantic campaign dossier](docs/wiki/fuzzing/semantic-optimizer-campaigns.md)
retain the detailed provenance.

- **Saved campaign classification:** classify the 537 artifact-suppressed pairs
  from the seven-pass 1,000-case campaign. Remaining unretained EH control,
  legacy-EH locals, RemoveUnusedBrs switch/multi-function and constraint-loop
  siblings need reproduction and family-level evidence. Do not extrapolate
  retained representative fixes to the historical aggregate.
- **EH/Vacuum:** renew the dedicated 10,000-case aggregate and resolve raw-size
  losses. The historical 256-case campaign had 128 differences. Layouts 1/7
  have canonical projection wins but raw losses; 54 of their 64 rows have only
  saved size/status evidence. Layouts 3/6 need aggregate renewal after bounded
  repairs. Preserve trap, catch-reference and null-`throw_ref` behavior.
  [Vacuum evidence](docs/wiki/binaryen/passes/vacuum/fuzzing.md).
- **Descriptor, continuation and local-subtyping encoding:** inspect OI
  descriptor37 type residue, descriptor27 producer/result structure and
  descriptor52/74 exact-null encoding. Complete continuation reference traversal
  and remapping, including expression-form declarative elements, before type
  pruning/interning. Local-subtyping cases23/35/36 retain a historical +3 raw /
  −1 canonical bytes per case across 765 cases; prove a benefit or remove the
  overhead. Preserve recursive-group and handler semantics.
- **Other saved shape gaps:** replay code-pushing's 513 `br-if-value` cases
  (+2,052 canonical bytes), no-structure SimplifyLocals' 1,662 tee-control cases
  (+16,636), and trap-relaxed OI's 30 `direct-tiny-bulk` cases (+300), all historical
  v132 figures. Ten SSA fixture families still differ in typed-loop proxies,
  reference/cast lowering and branch-table cleanup. Keep compact-import policy,
  name-metadata size gaps and unsampled tuple/downstream cases visible.
- **Host-visible identity guards:** measure preset DFE/DIE size and performance
  costs; narrow broad guards only with escape analysis protecting exports,
  tables, globals, imported callbacks and host getter/lookup effects. Preserve
  `tests/optimizer/regressions/host-identity.test.ts`; require exact runtime
  observations and measured output deltas for any broader merge.
- **Runtime coverage:** extend concurrent AcqRel, general wait/notify liveness,
  memory64 above 4 GiB, broader atomic/shared-GC operations, mixed-memory and
  schedule families. Find an independent runtime accepting Relaxed order 2;
  capability probes are not concurrency conformance. Shared-function types,
  GC arguments without exact producers, non-null `exnref`/`contref` crossings and
  arbitrary relaxed-SIMD outcomes retain explicit observation limits.
- **Runtime exclusions:** twelve known original/output SSA nontermination cases
  remain outside runtime signoff. Never execute the known Node resume-throw
  crash fixture; use terminating fixtures or a compatible alternate engine.
  Keep independent-validator exclusions separate from matches.

**Exit / tests:** bounded red-first IR/byte fixtures for each repair, exact
original/optimized observations where supported, classified size deltas and
fresh dedicated v133 aggregate evidence. No unexplained semantic or validation
failure; no unproven output-shape exception.

## v0.1.1 — Frontend and index contracts [IR2-CORRECTNESS]

- **Parameterized HOT if signoff:** lift/lower now preserves entry operands,
  evaluation order, tuple producers and both arm stacks; constant selection
  retains entries through block demotion. Leading scalar entries now avoid
  duplicated constants and scratch locals. Finish independent runtime checks and
  shared-consumer aggregate renewal; the old stack-underflow regression is closed.
- Function-label depth/payload and name-section boundary fixtures pass.
  [AUDIT]006 global function-index documentation and fixtures are complete;
  [validator documentation](docs/wiki/validate/type-section-and-subtyping.md)
  owns their contract.
- **Exit:** focused tests demonstrate the required behavior, malformed inputs
  remain rejected, public interface diffs are reviewed and docs match the code.
  [Source context](docs/wiki/ir2/architecture-rules.md).

## v0.1.1 — Pipeline, artifacts and tooling [IR2-SIGNOFF]

- **[SEMANTIC-OPT]001 — campaign acceptance:** rerun the full original-primary
  semantic campaign with explicit verified v133; the old accidental-PATH-v116
  aggregate is not acceptance evidence. Renew the historical random-all Vacuum
  lane after accumulated fixes. Verify machine-readable source-of-truth contracts,
  feature floors, replay/reduction fingerprints and required semantic CI results.
  Report runtime-blocked/tool cases explicitly; structural agreement cannot
  excuse an original/optimized behavior difference.
- **[REVIEW-20260822]001 — final22 refresh:** replay all 1,330 WAGO files and the
  exact ifs state oracle on current source; establish the stable cohort and
  measure changed-bit encoding cost against eliminated finish work. Preserve
  historical hashes/counts as historical until fresh artifacts exist. Require
  valid outputs, exact supported state observations and nonregressing wall time.
- **[REVIEW-ARTIFACT]001 — broader self-hosting:** run the repaired self-hosted
  optimizer across all 842 externally valid WAGO inputs, validate every output,
  compare native bytes and execute supported runtime/WIPC checks. Distinguish
  unsupported input decoding/types from produced invalidity or wrong behavior.
- **[O4Z-STARTUP]001 — smaller guard fixtures:** reduce the production startup-map
  repro into generated fixtures covering initializer convergence, giant post-inline
  call builders, lowered preflight, dynamic nonzero-offset stores and typed/untyped
  loop carriers. Recover precision in SimplifyLocals loops, CoalesceLocals parameter
  interference, CodePushing carrier placement and typed-loop nested cleanup one
  owner at a time. Keep the production repro until all families are covered;
  broader admission requires runtime proof, not validation alone.
- **[JSON-AS]001 — repeatable artifact lane:** add an opt-in clone/build/replay task
  in existing Bun tooling; measure every public level/preset on medium-naive,
  medium-simd and large-swar artifacts. Keep validation, process runtime and exact
  report-protocol execution as separate gates. Require fresh current-source
  optimize/validate and exact WIPC across all 105 modules for release evidence.
- **[SIZE]001 — transformation breadth:** reduce structured local-tee, typed-loop,
  sparse path-sensitive interference, nested inlining cleanup/profitability and
  helper-deletion gaps alongside the timing work. Refresh older direct-pass and
  ordered-cleanup size comparisons against v133 before treating them as current.
  O1/O2/O3/O4/Os/Oz/O4z must validate, execute and meet their size goals; retained
  shape differences need a measured benefit without important regressions.
- **[TOOL]001 — symmetric normalization:** canonicalize corresponding native,
  self-hosted and Binaryen paths symmetrically while preserving raw artifacts.
  The historical v131 O4z corpus has 163 raw size losses totaling 3,491 bytes despite
  common-Oz equality; retain them as parity gaps pending fresh measurement or a
  demonstrated benefit. Do not normalize away semantic, validation, size or
  scheduler/fallback differences.
- **[STRIP-DEBUG]001 — final artifact measurements:** measure custom-section size,
  validation and runtime effects on final large/generated artifacts. Report
  strip-debug separately from optimizer transformations.

**Dependencies / exit:** fresh native and self-hosted binaries, verified v133,
explicit fixture identities and deadlines; exact runtime/size/wall evidence for
changed owners and repository validation before release. Preserve recursive
bootstrap and fixed-point checks. See
[semantic campaigns](docs/wiki/fuzzing/semantic-optimizer-campaigns.md),
[startup boundaries](docs/wiki/tooling/o4z-debug-startup-trap.md) and the linked
pass dossiers; historical green checkpoints do not replace current signoff.

## v0.2.0 or later — Oracle and proposal follow-ups [IR2-V133]

- **v133 residuals:** classify the historical 1,253 GTO, 2,216 shared-object, 2,632 CA
  and 1,080 OI differences with semantic and size evidence; reduce GTO's 935
  canonical size losses. Shared-object-specific differences need proof or
  alignment; its 86 historical size losses came from older RemoveUnusedBrs
  profiles. Keep the 167 released-oracle command failures separate from comparisons.
  The current CA renewal classifies twenty scoped wins; its other 2,612 residuals
  remain open in the [current review](docs/wiki/tooling/tracing-playbook.md#ca-residual-inspection).
  Finish remaining exception, descriptor, subtype, atomic, `struct.wait` and i64
  wasm2js variants with red fixtures. The i64 implementation covers only the four
  new saturating conversions. [Inventory](docs/wiki/binaryen/version-133-upgrade.md).
- **Inherited proposal/analysis gaps [IR2-V132]:** preserve legacy multi-handler
  DAE2 representation and descriptor size gaps; broaden descriptor/module-remap
  cases and classify residual fence/atomic shapes. Resolve remaining CA/handler
  precision and parity gaps using the renewed [v133 evidence](docs/wiki/tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign); cost profiling is complete. Public source
  spans and WAST continuation grammar remain tooling boundaries; distinguish
  structural proposal checks from independent execution.
  [Historical intake](docs/wiki/binaryen/version-132-upgrade.md).
- **Shared-Everything Threads:** finish missing WAST shared declarations/aggregate
  forms and proposal-specific shared/unshared domain, subtype, mutability and
  ordering rules. `pause` remains unsupported. Extend full-proposal generators,
  shrinking and independent runtime/host coverage only as layers become supported;
  preserve directional effects through HOT and complete type remapping. Work from
  the [current boundary](docs/wiki/wasm-shared-everything-threads-boundary.md), not a
  blanket reimplementation of represented types, codec or aggregate atomics.
- **[V02-INL]001 — inlining publication:** regenerate interfaces, run README/API
  sync, focused/full validation and v133 direct lanes; resolve or explicitly retain
  large typed-loop fallbacks with source and runtime evidence before publication.
- **[INL]020–021 — deferred breadth:** consider tiny struct/array allocation
  inlining only with measured size/wall benefit. Table/indirect callee recovery
  remains deferred. Expression metadata, branch hints, source maps and copied
  debug names depend on a shared metadata substrate.
- **[HOT]001–004 — structural work:** stronger source provenance where exact spans
  are insufficient, unknown/custom metadata roundtrips and smaller opaque-lowering
  boundaries. Require concrete fixtures and correctness evidence before widening;
  startup-specific work stays under `[O4Z-STARTUP]001`.

## Backlog hygiene

- Remove an item when its exit criteria are met; keep durable evidence in the
  relevant wiki dossier and git history, not completion diaries here.
- Keep unresolved release blockers, failures and evidence limits visible.
- New implementation slices need a concrete goal, owner, dependencies, invariants,
  exit criteria and suggested tests. Preserve existing fixes and assertions.
- On new mismatches, save and minimize artifacts, classify with evidence, add a
  failing focused regression, repair the owning layer and update its dossier.
