# Agent Tasks

Active unreleased work only, reviewed October 4, 2026. Follow
[the docs schema](docs/README.md). Completed mechanisms, measurements and
rejected experiments belong in the linked wiki dossiers and git history.
New comparisons require verified
[Binaryen 133](docs/wiki/binaryen/release-horizon-and-oracles.md); historical
oracle versions and checkpoints do not sign current source.

## v0.1.1 — Performance validation and remaining gaps [IR2-PERF-FOLLOWUP]

- **Goal / why:** make Starshine competitive before release by closing pass,
  pipeline, command and output-quality gaps without removing transformations.
- **Current execution checkout:** work directly on `main` in the primary local
  repository, as requested October 2. The performance branch and latest remote
  correctness fixes are integrated; preserve historical branch measurements
  under their frozen source versions. Do not create another performance worktree.
- **Execution priority:** reach ≤1× for DAE2, DAE2-O, CoalesceLocals and
  OptimizeInstructions; finish P03 DAE2/DAE2-O first, especially remaining HOT
  field reads, temporary-buffer churn, reaching-definition/source-order work and
  optimizing cleanup setup. P12/P05/P11/P13 are shared owners of those costs.
  P08 DAE/DAEO and the other performance owners remain in scope afterward.
- **Correctness takes release priority:** the independent October 3 baseline
  audit has reproduced validator, DAE and OI failures. Keep performance patches
  isolated and preserve their evidence; do not treat existing passing tests or
  unchanged output hashes as release signoff. See P00 below before publication.
- **Speed target:** match or beat verified Binaryen133 (≤1×) on comparable
  active pass-local timings; track full-command time independently. Neither a
  helper gain nor a guarded/no-op path closes this target.
- **Latest matched large checkpoint:** inline instruction-lift state/error,
  mainb34c4d0a4 nativeec2a0ed4…→5132736f…. Complete DAE2 instructions−0.545%,
  2,925,466 fewer direct instruction-worker allocator requests; calls/output exact.
  CPU6 n5/warmup1 normal CLI medians±MAD (milliseconds):
  dae2 3839.607±51.388/B1252.725±2.362 (3.065×);
  dae2-optimizing 6688.206±89.721/B2626.305±35.897 (2.547×);
  coalesce-locals 4238.988±43.593/B2027.743±58.606 (2.090×);
  optimize-instructions 2503.762±157.348/B1146.393±91.841 (2.184×).
  All rows flag foreign load; paired/cross-cohort disagreement and RSS overlap
  prevent a universal clock/memory claim.13,451 tests/2400 comparisons pass.
  [Scopes, controls and limits](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-inline-instruction-lift-state-and-error).
- **DAE correctness checkpoint:** native de85d92e… passes all 16 reduced
  DAE/O runtime rows and retains six large hashes. Its n3 CLI medians are
  DAE 1420.340/B1063.695 and DAE-O 1656.129/B2425.725 ms.
  [Spreads and limits](docs/wiki/binaryen/passes/dead-argument-elimination/starshine-strategy.md#october-3-2026-parameter-reads-in-control-operands).
- **Latest complete DAE2 profile:** native5132736f… pass30.636b instructions.
  Dependency9.417b, analysis/rewrite lift6.366b/2.372b, lower4.647b and mandatory
  validation3.032b remain dominant disjoint owners. Nested attribution is not
  additive. Prioritize repeated optimizing-cleanup queries and dependency work;
  transient provenance tuples and remaining typed-pop adapters are smaller leads.
  OI encoding cleanup is a separate5.352b historical command owner; preserve its
  exact size guards and validation. Do not duplicate completed result workers.
- **Preserved quality and completed work:** V83 saves 79,962 canonical bytes
  across 4,968 shrinking functions. DAE2-O remains **99,251 canonical bytes
  larger** than v133 despite **9,949 fewer raw bytes**; CL/SL/OI canonical
  deficits remain 78,800 / 373,507 / 33,497 bytes. Keep the normalization
  protocol explicit and do not classify smaller raw DAE2 output as a proven win.
  Completed storage, discovery, replay, source-query and cleanup mechanisms,
  rejected trials and all historical timing cohorts are retained in the
  [DAE2 dossier](docs/wiki/binaryen/passes/dae2/starshine-strategy.md),
  [CL dossier](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md)
  and [tracing history](docs/wiki/tooling/tracing-playbook.md).
- **Remaining tradeoffs:** P03b/c/g retain tiny, empty, tee, reused-capture,
  small-compiler and large plain/optimizing control costs from V32–V83;
  retain original spread, contradictory repeats and RSS modes when renewing.
  P03f owns plain-output drift (+458 bytes in 41 functions against V18) and
  the canonical gap; preserve correctness repairs and never use broken V18
  behavior as a performance baseline. P03/P04/P12/P13 own dependency/lift,
  cleanup, CFG/lower and command-envelope costs. Completed mechanisms must
  not be reimplemented from old checkpoint descriptions.
- **Fuzz scheduling:** long randomized/aggregate fuzz, broad artifact replays
  and final shared-consumer renewal remain deferred until the performance
  bottleneck trials are settled, as the user requested. Use focused regressions,
  bounded runtime comparisons and measured performance commits during iteration.

## v0.1.1 — Remaining performance owners [IR2-PERF-NEXT]

**Goal / why:** close the measured pipeline/oracle gaps while preserving active
transformation breadth, valid output, runtime behavior and canonical output
quality. The [follow-up campaign](docs/wiki/tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign)
and its linked first campaign own completed P01–P14 mechanisms, benchmark
sources, rejected designs and measurement limits. The tasks below describe the remaining costs, rather than
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

**Current comparison:** use the latest matched checkpoint at the top of this
file and its linked dossier. Earlier direct-result-row/CFG/iterator cohorts have
different source and host conditions; they remain historical evidence, not
current speedup totals. Prioritize absolute large-module dependency/cleanup,
CFG/lower and validation-envelope costs, preserving the 1× target and canonical
quality gates. Keep traced inner and normal command measurements separate.

### P00 — Correctness blockers from the October 3 baseline audit [IR2-RELEASE-CORRECTNESS]

- **Goal / why:** restore validation and observable behavior before release;
  baseline 3d46f7e52 and iterator candidate 8bfe3761 reproduce the same failures.
- **Source / owner:** [reduced cases and classifications](docs/wiki/tooling/validation-gates.md#october-3-2026-reproduced-baseline-correctness-blockers);
  local author-owned `claude_review_10_3_6.md` contains the broader 26-item audit.
  Preserve the author's untracked report and check active repair ownership.
- [ ] Repair control-frame validation after nested unreachable code: missing,
  extra and wrong-typed values are accepted by Starshine but rejected by
  wasm-tools/Node. Review runtime escape versus frame-polymorphism invariants.
- [ ] Repair merge-blocks invalid carried-value/drop output (reproduced). Triage
  reported code-folding/vacuum/DAE2/DAE2-O invalid-output families and DAE2
  rewritten-module aborts (#2–4); obtain the review's reduced d93r artifact.
- DAE audit #5–6 reduced cases are repaired by expanded operand-control CFGs;
  [regressions and original/v133 execution](docs/wiki/binaryen/passes/dead-argument-elimination/starshine-strategy.md#october-3-2026-parameter-reads-in-control-operands)
  cover scalar branch values, constant self-tee and GC payload traps. Other
  audit families and final DAE signoff remain open.
- [ ] Repair OI effect ordering around intervening local.set/select (reproduced
  [1,2]→[2,1]); triage SL/notee/inlining-optimizing ordering (#7–8).
- [ ] Triage remaining reported precompute/SGO semantic errors (#9–11), native
  aborts (#12/#26), legacy rethrow validation (#13), CLI parse exit status (#14),
  EH/CFG/scanner/SSA/merge-locals failures (#15–19/#22/#24), and nested control
  operand/return movement or invalid result shapes (#20–21/#23/#25). These
  families are reported, not yet independently replayed in this campaign.
- **APIs / invariants / dependencies:** existing validator, CFG, scanner, HOT
  lift/lower and raw-pass contracts; preserve checks, frame types, branch-value
  reads, effect/trap order and exception edges. No admission or coverage waiver.
- **Deliverables / tests / exit:** focused failing regressions, minimal repairs,
  valid wasm and original/Starshine/verified133 execution agreement, plus required
  affected-suite checks. Classify every report and keep unresolved failures
  visible; performance and canonical-size parity do not close semantic defects.

### P01 — Write-heavy propagation state [IR2-PERF-PC-FLOW]

- **Owner / why:** [local_graph.mbt](src/ir/local_graph.mbt), transfer and
  predecessor merge; large propagation still includes substantial state/CFG work.
- **Deliverables / tasks:** profile remaining write-heavy transfer allocations
  and predecessor scans; try mutation-scoped changed-local sets only when all
  predecessor deltas can be represented. Keep exceptional/full-scan fallback,
  ordered sources and semantic-change successor scheduling. Keep wide-tuple branch
  journals while measuring remaining expanded predecessor work separately.
- **Invariant / dependencies:** preserve expanded read-only borrowing, first-write
  ownership, queues, sparse tuples, borrowed predecessors and thresholded
  unions. DAE2/OI/MergeLocals/SSA consume this owner.
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
  tail admission and streamed snapshot-prefix scans remain required. Keep active
  folds, infinite-loop tails, NaN/signed-zero, metadata and proposal boundaries.
  Propagation depends on P01; plain Precompute does not.
- **Exit / suggested tests:** repeat an enclosing-pipeline gain without tiny
  active-body regression; extend [raw reuse](src/passes/precompute_raw_identity_perf_wbtest.mbt)
  and [tail/prefix controls](src/passes/precompute_tail_admission_perf_wbtest.mbt).

### P03 — DAE2/O priority work [IR2-PERF-DAE2]

- **Goal / owner:** reduce the multi-second compiler gap in
  [DAE2](src/passes/dead_argument_elimination2.mbt),
  [LocalGraph](src/ir/local_graph.mbt),
  [source order](src/ir/hot_source_order.mbt) and
  [pipeline cleanup](src/passes/pass_manager.mbt).
- **Shared dependencies / APIs:** P01/P05/P11/P12/P13; prefer existing checked
  field getters, immutable facts and owned scratch. A public projected/lazy
  graph API needs an explicit contract and consumer review, not incomplete
  fields presented as a complete LocalGraph.
- **Invariants / exit:** preserve complete source/influence/writer metadata,
  deterministic source order, unknown rows, exceptional edges, recursive and
  indirect calls, open/closed worlds, scalar/GC producers, captures, metadata
  and grouped-local bytes. Require measured enclosing gains, bounded memory,
  valid output and classified size/parity differences before closing P03.
  [Evidence and rejected designs](docs/wiki/binaryen/passes/dae2/starshine-strategy.md).

#### P03a — Remaining HOT field reads [IR2-PERF-DAE2-FIELDS]

- **Completed scope:** the two private lift local-access workers now read the
  existing arena record after unchanged checked admission; actual native
  public/private complete-header calls disappear, with no new view or cache.
  [Consumer evidence](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-checked-arena-reads-for-lift-local-conflicts)
  records CL instruction savings and flat normal clocks. Do not duplicate it.
- [ ] Profile remaining local-access/source and region-root queries returning
  complete node headers. Extend checked field reads where the caller needs
  only those fields; preserve single admission in shared label/body selection.
- [ ] Prove generated native code removes the actual public **and private**
  complete-header boundary. Getter annotations or renamed calls are insufficient.
  Preserve deleted-node, invalid-index, incomplete-arena and error-order checks.
- **Tests / measures:** bounded field/error equivalence and native work guards;
  shallow/deep/shared inputs; both DAE2 modes and affected P12 consumers; scoped
  instructions, allocator calls, enclosing time and RSS.

#### P03b — Query scratch and object churn [IR2-PERF-DAE2-SCRATCH]

- [ ] Attribute remaining source/reader/access rows, wider-row comparator closure
  construction after V65 bypasses empty/singleton sorts, array growth and reference-count/destruction work. Trial reuse
  where enclosing gains justify lifetime costs. Five loop-scoped raw visitors are
  now hoisted; the toggled native profile records 43,495,605 allocator calls
  across the large command, not solely final capture cleanup. Obtain honest
  scoped allocation attribution before targeting individual query families. V29's
  toggled profile records 651,397 whole-command sort calls; any cached comparator must capture its order
  row without a facts backpointer or reference cycle.
- [ ] Reduce tiny cleanup owner overhead (13/30ns cold) without reintroducing
  wide quadratic work. V71 removes the 275 scoped optional boxes with unboxed
  overflow words; follow remaining map construction/bucket retention and
  small/tee control costs (optimizing +1.50%/+1.21%, plain tee +1.36%).
- [ ] Clear temporary state on every exit, avoid allocating it on no-work paths,
  bound retained high-water capacity and measure lifetime/RSS costs. Preserve
  carried-buffer clearing, independently owned selections and pure/empty fast
  paths. Keep expression/body revisions and concurrent workspaces isolated.
- **Tests / measures:** cold/warm and alternating-width queries, held prior
  results, pure/empty/early exits, sibling snapshots, effects/traps and ownership;
  native controls plus compiler/active pipelines. Allocation call counts are
  not bytes or net live objects.

#### P03c — Remaining quadratic and repeated flow work [IR2-PERF-DAE2-FLOW]

- [ ] Reduce overlapping local-access-list rescans and repeated predecessor,
  last-write and source queries on actively transforming inputs. V68 closes
  repeated singleton-writer scans of one wide consumer; overlapping subtree
  enumeration and other writer-source walks remain. Demand compact
  facts only where full-pipeline evidence supports their storage cost.
- [ ] Resolve V64 small-plain and large-optimizing control costs; preserve both
  native/cold and enclosing repeats. Tag reuse removes two header boundaries
  and improves native entry rows, but does not establish enclosing speed/RSS
  gains. Continue reducing repeated writer-source traversal on written selectors.
- [ ] Refine tiny-row overhead in the bounded/linear writer-source union while
  retaining linear wide-row scaling, ordered uniqueness, loop-root writes and
  clean workspace reset. Preserve shared-action sparse fallback and unknown
  unreachable/closed-cycle rows.
- **Tests / measures:** complete graph-field equivalence in both operand modes;
  unused locals versus real entry reads; joins, loops, exceptional/backedges,
  shared actions; tiny/wide writer rows and overlapping access-list pipelines.
  Do not restore rejected eager source-order, region-threshold or predecessor
  caches without a new enclosing-work and memory model.

#### P03d — Lift, dependency planning and lower [IR2-PERF-DAE2-PIPELINE]

- **Completed presence scan:** verified empty branch-table arena skips the initial
  continuation search; nonempty arena retains the full fallback.2.161m fewer
  node probes, no allocation/verification omission and complete DAE2 work−.482%.
  Keep empty/table/resume costs and mixed clocks visible; do not reimplement.
  [Proof and evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-3-2026-prove-absent-cfg-continuations-from-verified-side-tables).

- **Current attribution:** main ddd0053b9/e57d9b45… plain dependency-only
  capture exits normally with exact validated output: root9.909b instructions,
  direct CFG5.224b (52.72%), read sources2.018b (20.37%), entry proof.790b
  (7.97%). CFG's nested region3.742b, mandatory HOT/CFG verification.971/.280b
  and read rows' nested reverse-query.915b remain. Getter exclusive1.064b and
  destruction.896b are not additional phase totals or allocation bytes.
  [Current source breakdown and next experiments](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-2-2026-current-large-dependency-cost-after-checked-lift-reads).
  Prioritize region storage and reverse-query lifetimes; existing predecessor
  compression is linear, long last-write rows already indexed. Do not duplicate
  those repairs or remove verification to improve timers.

- **October 2 CFG checkpoint:** an immutable operand-order proof retains all
  7,926 CFG/read-source builds while reducing source-order factories 7,926→411.
  Scoped dependency instructions fall 19.60%; shared-call-site allocation
  totals do not prove a scoped allocation gain. Large plain CLI paired −2.56% with exact bytes. Optimizing −1.40% is diagnostic
  under heavy foreign CPU load; renew that cohort. Tiny carried fallback
  costs 1.97→2.28 µs. Complete graph/verification, lift/lower and cleanup costs
  remain open; this does not implement projected or incomplete flow facts.
  [Proof and evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-2-2026-prove-empty-cfg-ordering-demand-before-constructing-facts).

- **Segment storage checkpoint:** exact-sized owned copies reduce measured large
  segmentation instructions 3.35% and improve all eight helper controls.
  Both-mode/CL bytes and 252 execution observations remain exact. Enclosing
  timing is **not closed**: two fully host-contended plain cohorts give paired
  +13.99% and −.05%, with wide spread. Renew quiet full-pass/command and memory
  evidence; do not promote scoped work savings into a command-speed claim.
  [Storage evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-2-2026-exact-sized-owned-cfg-segment-copies).

- [ ] Isolate remaining lift/admission, dependency solve, location lookup,
  rewrite/lower, capture repair, writeback and final-validation costs on the
  same frozen source. Do not add overlapping inclusive profile percentages.
  Prioritize dependency construction, analysis/rewrite lifts, lower and final
  validation: the September 30 diagnostic solver cost is too small for
  solver-only changes to close the enclosing gap. Require complete graph-field
  equivalence for a demand projection; retain conservative HOT fallback.
- [ ] Reduce the remaining admission/provenance and scratch costs around the
  implemented structured call-suffix replay. V43 small/tee optimizing controls
  cost 1.55%/1.06%; preserve exact writer demand, effects, control normalization
  and HOT fallback. Extend supported families only with a measured benefit.
- [ ] Profile remaining per-body call-summary/provenance and expression work
  after sparse replay. Reduce repeated callee consumer enumeration only with
  measured enclosing gains; preserve recursive self-call parameters, tail/type
  families, mask ownership, reset/epoch semantics and full HOT fallback.
- [ ] Extend raw analysis beyond current no-input void/single-value fallthrough
  controls only with a measured enclosing benefit. Loops, branches, handlers,
  indexed controls, nested returns and unsupported opcodes/signatures remain
  HOT. Preserve sparse branch writes, stack floors, observed conditions,
  unwritten entry values and separate raw rewrite admission. Compare all solved
  function/type and source-write demand bits, including unchanged bodies.
- [ ] Reduce remaining body/revision queries, representation allocation and
  selected-mask setup; V72 closes eager source rows for DAE2-resolved reads.
  Keep default graph facts complete, ordered selected sources and conservative
  dependencies when control/signature information is unknown. Shared-action
  fallback still computes complete forward rows before projection.
- [ ] Reduce remaining root-write list, source traversal and enclosing costs.
  V79 closes duplicated live-node census; V80 closes zero/singleton local-index
  entry-row allocation. All 13,255 tests and 1,376 observations pass with exact
  bytes; singleton native queries improve 12–86%. Root-write list ownership,
  multiple-admission interval rows and complete fallback still allocate.
  Preserve exact ordered sources, shared/repeated root rejection, complete CFG
  and exceptional fallback. Measure tiny, wide unused-local, zero/many admission
  and complete analysis controls. No new public API is required. V80 enclosing
  large plain/O +.89%/+1.13% and tee O +1.21% remain open; the focused gain does
  not close the compiler gap. Retain V79 dispersed controls and host bands.
- [ ] Reduce remaining CFG/source work on locally ordered mutable writes.
  A bounded exact-output V80 compiler probe counts 8,354 HOT dependency
  functions, 8,187 entry-proof attempts and 7,926 read-source graph builds
  (`.tmp/dae2-graph-counts-20261001/`); these are counts, not timing percentages.
  Evaluate conservative per-region/root source proofs before graph construction,
  comparing every proved read against complete LocalGraph flow. Preserve shared
  node epochs, loops/backedges, branches, source-write order, exception handlers
  and unknown reads; keep complete CFG fallback for all unproved reads. Avoid
  dense row clearing per region or rescanning each subtree/read. Measure actual
  compiler graph admission and enclosing pass time, not only helper speed.
- [ ] Evaluate compact affected-function/revision summaries for remaining
  unavoidable work; invalidate on body, node/span/region/local/type/signature
  changes. Whole-HOT retention and its smaller budget remain rejected.
- **Tests / measures:** active signature changes, indirect/recursive calls,
  indexed/multivalue/branched control, grouped locals, tuple/GC producers,
  handlers/continuations and captures; frozen before/after bytes, phase time,
  native work and RSS. Extend existing control/handler benchmark lanes.

#### P03e — Optimizing cleanup setup [IR2-PERF-DAE2-CLEANUP]

- **Goal / owners:** reduce remaining raw SimplifyLocals/Vacuum normalization,
  query/typechecking and function-envelope work without losing V47/V69/V83
  quality gains. Complete profiles have nested scopes: named pass transforms
  omit substantial preparation; never sum inclusive edges with roots.
  [Attribution](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-2-2026-complete-optimizing-cleanup-instruction-attribution),
  [accepted mechanisms and rejected cache](docs/wiki/binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md#october-2-2026-rejected-per-flat-statement-boundary-cache).
- **Current Vacuum scan checkpoint:** three pure preservation predicates now
  reject fixed-prefix mismatches before recursive unreachable queries; complete
  cleanup work−5.300%, nested Vacuum−20.962%, exact outputs/API. Standalone
  Vacuum1377.093→1265.246ms/B859.986ms (1.471×, n5); DAE2-O paired−.268% and
  repeat+.009% remain within spread.13,447 tests/1296 observations pass.
  Admitted-helper costs, all foreign-activity flags and unchanged byte gaps
  remain documented; do not repeat these three predicate reorderings.
  [Proof, full matrix and limits](docs/wiki/binaryen/passes/vacuum/starshine-hot-ir-strategy.md#october-3-2026-reject-mismatched-vacuum-prefixes-before-recursive-scans).
- **Renewed cleanup attribution:** main15255efd6/nativefd2af4bd… complete
  cleanup19.663b instructions: raw SL12.227b, Vacuum4.929b (disjoint children).
  Pure-copy flat work1.230b is nested within SL; its quadratic synthetic control
  does not establish dominant compiler cost. Exact local cleanup3.067b includes
  reachable-get counting.947b and adjacent-pair cleanup1.177b. Investigate shared
  read/fallthrough traversal while preserving owner branches, handlers, ordered
  state, NaN/signed-zero termination and full fixed-point work. No projected
  savings yet; avoid adding recursive inclusive costs.
  [Attribution and source-backed next experiment](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-3-2026-renew-optimizing-cleanup-priorities).
- [ ] Profile remaining recurrence/adjacent/effectful rewrites, raw Vacuum
  preclean, preparation, mutation safety, child-use queries and writeback on
  one frozen source. Completed absent-if census, initial control rejection,
  tag size bounds, flat recurrence storage, initialized read indexes, unchanged
  suffix storage and bounded initial dupable-copy discovery must not be repeated.
- [ ] Reduce remaining pure-copy tail scans/typechecking: blocked width64→256
  still costs.882→14.21ms (≈16× for4× width). Measure actual query reuse and
  materialization cost on compiler bodies before another cache. The per-flat
  statement-end cache lost whole cleanup work (+.175%) and is rejected.
  Preserve escaping statements, source/target writes, terminal/conditional
  helpers and env/label/init facts; never retain facts across mutations/callers.
- [ ] Reduce plain no-work compaction costs while retaining legacy/effect-spanning
  candidates. Optimizing counted capture/unused-local/alias admission must not
  narrow the original plain scan or remove necessary V69 effectful cleanup.
- [ ] Reduce first-query initialized-local/suffix-candidate setup, repeated
  future-read/next-if and ancestor/subtree scans between distinct cleanup owners.
  Existing immutable query seeds, wide compound masks, unboxed optional words,
  terminal-search removal and normalized continuation reuse remain required.
  The compiler currently builds zero future-read masks: prove actual query
  density before adding sparse event caches. Keep direct-write/recursive-read,
  terminator, original continuation and legacy semantics.
- [ ] Resolve remaining tiny/tee/deep costs under matched controls: bounded
  discovery+10.30ns; shared suffix-seed tiny+3.01ns/leaf-batch+49.66ns;
  normalized future-query tiny+6.67ns, reused+30/+810ns, unchanged+170ns;
  sparse32 constant-store scratch+8.5%; duplicated capture scans12–21%.
  Historical enclosing control costs retain source/date in the DAE2 dossier;
  attribution is required when the suspected helper is never called by a lane.
- [ ] Measure lazy adaptation and normalization prepare/lift/typechecking costs
  on tiny/tee and deep/shared-control pipelines. Preserve every child rewrite,
  original continuation, balanced-capture overlap decisions and stored-byte win.
  Demand-built proof/scratch requires an enclosing time/RSS benefit; whole-HOT
  retention and the rejected eager/per-flat caches remain rejected.
- [ ] Attribute descriptor/inference whole-body scans, skipped-effectful-carrier
  and balanced-statement-local-get queries. Body-dependent facts must invalidate
  on changed bodies and type/import/exact-or-descriptor signatures; historical
  bounded stack samples are leads, not per-phase counts or allocation bytes.
- [ ] Reduce remaining recursive pure/effectful/carrier array/control rebuilding
  only with proved input ownership and all active rewrites retained. Preserve
  all five SimplifyLocals variants and cleanup on functions unchanged by DAE2;
  guarded/no-op/skipped cleanup does not count as equivalent faster work.
  Coordinate remaining Vacuum indexed/label guards with IR2-VACUUM-9155.
- **Invariants / tests / exit:** no cleanup-coverage reduction, mutable-state
  sharing, verification shortcut or byte regression. Test active/blocked dense,
  nested scalar/reference/SIMD, handlers, traps/effect order, stale-query barriers,
  sibling snapshots and tiny controls. Require complete matched consumer gains,
  bounded storage and both DAE2 modes; focused measurements now, aggregate
  parity/full CI/coverage after the performance campaign.

#### P03f — Output quality and artifact correctness [IR2-PERF-DAE2-QUALITY]

- [ ] Reduce the continuation fixture's3B raw code-shape excess (84/81B after
  name removal), preserving resume handler target depths and nullable/GC types.
  Verified133 one-write strip-debug output is exactly81B on both sides; this is
  not a new canonical/semantic gap.46B of retained name metadata is separate.
  No measured Starshine raw-shape benefit; keep the writer lead open.
  [Inspected sections and normalization](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#continuation-probe-follow-up).

- [ ] Reduce and attribute the remaining **99,251-byte canonical optimizing gap**
  by function/diff family. V32 removes 32,070 balanced capture pairs and saves
  147,876 raw / 53,470 canonical bytes without per-function pair regressions.
  V38 removes immutable parameter aliases without per-function raw size losses,
  saving another 12,417 raw / 12,850 canonical bytes. V47 removes dominated
  local copies, saving 54,687 raw / 56,875 canonical bytes. Reduce remaining
  reused/nonparameter
  captures: preserve the historical imported-call loop evidence at 244 raw /
  248 writer bytes versus 220. A current frozen V80 / verified-v133 replay
  (`.tmp/dae2-loop-capture-probe-20261001/`) is 235 vs 215 canonical bytes;
  raw 325 vs 215 includes retained name metadata and is a separate scope.
  V83 removes the unused tees 10/12: current output is 231 vs 215 canonical
  bytes, with 148 fixed original/v133 observations and a smaller command loop
  reaching 93 vs 93. Multiply-written counter snapshots into locals 11/16,
  set/get versus tee 18 and the load-result capture 9 survive. Close these
  families with original-primary event/trap/result replay and per-function
  non-growth; source-write and control barriers must preserve snapshot values.
  Compare direct DAE2,
  ordered SimplifyLocals/Vacuum and
  downstream cleanup; close indirect-family, typed-control, parameter/result
  and local/capture debris gaps without weakening behavior.
- [ ] Separate raw cleanup gaps from writer-added captures before broadening
  aliases. Projection adds 762 get/set pairs in function 7292, 227 in 7293 and
  458 in 10435; the latter has no raw adjacent get→set/tee copies. Binaryen
  adds none in those functions. Reduce raw get/set versus tee differences and
  inspect statement-spanning stack/control-result shapes and downstream
  cleanup. Require raw/canonical/per-function and runtime evidence; the
  observed projected-copy counts are not raw alias coverage. V65's simple
  load-order and changing-counter reductions already win two normalized bytes
  each; include their structural surroundings to reproduce large-function gaps.
  The repaired rooted compiler witness confirms
  `call-argument-structured-release-simplify-locals-noop` on function 7318
  (extracted root 24). V69 closes raw effectful forwarding beside this guard while retaining release
  lifetimes and repairing nested read/legacy write barriers. Its scalar/reference
  reductions match or beat v133 canonical size. V73 closes the six-byte
  nested-read case by sinking numeric constant assignments into first flat reads
  as tees; later nested/release reads and trap/throw barriers remain intact.
  V78 closes the legacy body witness (135 → 131, v133 131), and its tagged/
  catch-all variants beat v133 by four canonical bytes with original-primary
  replay. Sole root numeric captures save 931 canonical / 882 raw compiler bytes
  in 87 shrinking functions, with no growth or non-code changes. Large optimizing
  is flat (+.01%); native added costs, tee +.50% on repeat and the larger writer/
  capture families remain active. V70 repairs the exposed
  legacy-only read/count/bounds defect (100 → 1); current body/catch/catch-all
  replay matches original and v133. Keep the HOT guard;
  other large witnesses still need admission attribution.
- [ ] Reduce the V83 added active unread-write cleanup work and tee control
  cost while preserving its 79,962 canonical / 75,580 raw compiler-byte saving.
  Both final remappers now retire unread body writes with complete handler/alias
  demand, preserving producer effects, traps and stack values. 4,968 compiler
  functions shrink without growth; raw output wins 9,949 bytes against v133,
  while the canonical deficit remains 99,251. Native cold/handler controls are
  approximately flat; active 64-tee/set controls add .931/.745 µs for new work.
  Matched large O improves 1.18%; tee O initially costs 1.75% and
  its bounded repeat costs .39%. See [unread-write evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-1-2026-retire-unread-optimizing-body-writes).
- [ ] Close multiply-written source snapshot aliases only within proved flat
  source-value epochs. Account for every adjusted target read before a source
  clobber, structured/branch/terminal barrier or a 256-instruction budget; keep
  immutable discovery, source demand, LEB profit guards and exact remap replay.
  Counter snapshots 11/16 remain in the 231-vs-215 canonical loop witness.
  Test read-before-write, clobbers, other scopes/legacy handlers, repeated loops,
  refs/GC and width/budget boundaries; measure full compaction, compiler time,
  per-function non-growth and original/v133 events/traps. The local draft in
  `.tmp/dae2-mutable-source-snapshots-20261001/` is not implemented or signoff.
- [ ] Profile remaining alias admission/counting, replay and remap costs after
  V55 removes intermediate trees and instruction-option roots. Wide native
  active controls improve 12–21%, but enclosing optimizing times remain flat;
  follow larger dependency/lift/cleanup costs rather than assuming more alias
  micro-optimizations will close the compiler gap.
  V59 closes the conservative wide-index admission trial. Its new prefix
  builder uses two boxed scalar counters in generated native C. V60's zero-filled
  scalar-loop trial is rejected: the 4096-copy native row costs 4.81% and a
  seven-pair enclosing optimizing repeat is +0.59%, contradicting the early
  -7.92% cohort. Consider avoiding both zero-fill and boxing only with renewed
  local/enclosing evidence. Keep one scan per body and release bounds before
  final remap. The three largest size-losing functions show immutable
  sole-reader reverse copies, not multiwritten-source or top-level partial-copy
  witnesses. Prioritize those observed candidates.
- [ ] Broaden remaining alias coverage only with root/dominance, iteration and
  per-function byte evidence. V62 closes sole-reader width-changing admission
  using strict eliminated-byte accounting; immutable/dominating guards still
  leave compiler functions 7292/7293 unchanged and save only 137 bytes in 10435.
  Multi-reader width-changing partial aliases remain unsupported; do not widen
  them without proving retirement or accounting for retained writers.
  V63 closes the cheap admission-frame bypass, improving matched tee 1.80%.
  Attribute remaining wide/rejection costs (V62 native rows cost about
  0.6–2.5%) with renewed native controls; keep final-index bounds and one lazy scan.
  Keep the equal-size unused-declaration difference in reduced v133 examples
  explicit; fewer locals alone do not establish an output-shape win.
- [ ] Inspect and replay the **41 V25-changed functions / +458 bytes**, preserving
  the stacked-read and branch-exit repairs. Validity, byte provenance or smaller
  output alone cannot establish semantic equivalence or an intentional win.
- [ ] Classify current open/closed-world residual families, including indirect
  type-family retained parameters/dropped results. Keep legacy multi-handler
  and descriptor representation/size gaps explicit; unsupported runtime cases
  remain unverified.
- **Tests / exit:** red-first reduced transform regressions, original-primary
  runtime/state/trap observations, independent validation and raw/canonical/
  downstream size deltas. Align to the oracle unless a documented measured
  Starshine benefit justifies retaining the shape.

#### P03g — Control costs and cumulative evidence [IR2-PERF-DAE2-EVIDENCE]

- [ ] Resolve or justify remaining tiny-row, small-compiler, tee, joined-reader,
  pure-tail, conditional-writer and GC/entry control costs; review buffer lifetime
  and peak RSS alongside work reduction. Preserve rejected trials and dispersion.
- [ ] Measure cumulative gains directly against a correctness-equivalent frozen
  baseline; do not multiply percentages or subtract different oracle cohorts.
  Refresh paired enclosing and untraced-command comparisons against v133 after
  the next material changes and at the final performance checkpoint.
  Use the all-DAE diagnostic freeze in `.tmp/dae-all-speed-20260930/` to select
  experiments, not to replace corrected-v38 correctness evidence or claim a
  causal speedup. Its v133-based 2× targets are about 2.004 / 6.914 ms on small
  DAE2/O and 924.872 / 3,419.400 ms on large DAE2/O. Renew after the in-progress
  structured-suffix work changes; retain output-size and cleanup-breadth gates.
- **Tests / exit:** existing active cold/warm controls plus pinned small/large
  compiler artifacts, independent reference brackets, identical-binary
  calibration, source/binary/input hashes, MAD, RSS and exact traced/untraced
  bytes. No important hidden behavior, size, memory or active-coverage regression.

### P04 — Remaining Coalesce CFG, interference and lower work [IR2-PERF-COALESCE]

- **Owner / why:** [Coalesce](src/passes/coalesce_locals.mbt), expanded CFG,
  liveness, interference and raw branch-depth/lowering queries; the large pass
  still costs several seconds.
- **Historical copy-barrier checkpoint:** main7a5676ba9/natived08c→dbbaefbe CL normal
  4416.546±70.418ms/B1963.489±27.857 (2.249×), n5 alternating/one warmup;
  paired−.699%, foreign activity every row. Complete CL work40.823b (−2.930209%).
  Safe-copy owner−98.240377%, structural visits12.219m→12209; exact outputs.
  13,391 tests/10 controls/185 modules/540 observations pass. No quiet-host1×
  or memory win; raw/canonical quality unchanged. DAE2/O/OI retain the d08c
  checkpoint at that date; do not extrapolate the CL-only gain.
  [Copy-barrier evidence and ownership](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-reject-globally-blocked-copy-pairs-once).
- **Current shared CFG checkpoint:** main3631c1d0c/native43feef6e CL normal
  4311.431±54.395ms/B1947.387±23.953 (2.214×), all contended. Complete work
  40.483b (−.832954%) with identical bytes and graph counts; P12 owns this
  completed representation change. Remaining interference/lower work stays open.
- [ ] Reduce or justify current safe-copy clear/no-edge control costs without
  regressing the large consumer: clear8+1.21µs (overlapping dispersion), no-edge
  512+29.02ns. Lazy preflight already preserves O(locals) with no body scan when
  rows are empty; do not repeat the completed global rejection mechanism.
- **Tasks:** profile repeated dependency/action rows, source-order/label setup,
  capture/conflict walks and weighted/wider coloring on the current revision.
  Reduce unused block-write metadata only with complete full-graph semantics.
  Retain raw liveness copy weights and measure sparse/dense crossover.
  Attribution precedes new retained metadata or analysis reuse.
- **Active controls / memory:** retained strip storage active-tee16+30.90ns,
  weightless-search weighted63+.34µs, scalar-clique wide fallback+10.47ns;
  preserve these source-specific tradeoffs in the linked dossier. Current RSS
  median+4200KiB has overlapping low/high modes and needs phase/lifetime
  attribution; no memory win. Canonical gap78,800B and final signoff remain.
- **Completed mechanisms:** shared reachability, unchanged strip/spill storage,
  weightless first-valid slot, scalar one-word cliques, checked lift reads,
  compact lower counts/direct results and block-only liveness are implemented.
  Do not duplicate them; their frozen evidence is in the existing dossier.
- **Invariant / dependencies:** compiled source-hazard replay, fused copy/remap,
  sparse cliques, preorder control summaries, occupied-bit/live-member extra
  interference, direct indexed liveness and dense score bounds remain required.
  Recheck historical nested-handler costs alongside sparse/deep-control
  controls. Preserve parameter conflicts, tees, loop carriers,
  handlers, capture-aware output and deterministic coloring; shared P12.
- **Exit / suggested tests:** materially improve large pipeline time without
  enlarging the recorded canonical gap or losing the small control; extend
  [hazard controls](src/passes/coalesce_source_hazards_perf_wbtest.mbt), full-pass
  nested handlers and the owner's [rejection record](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md).

### P05 — Mutation-scoped SimplifyLocals cleanup [IR2-PERF-SL]

- **Owner / why:** [raw cleanup](src/passes/pass_manager.mbt) and lift/lower
  around [SimplifyLocals](src/passes/simplify_locals.mbt); inner transform timers
  omit substantial pipeline setup and existing shape gaps.
- **Deliverables / tasks:** reduce remaining suffix/effect rescans, dirty/unchanged
  rounds, mutation safety and child-use checking. Attribute setup separately;
  reuse revision-scoped facts only after proving invalidation and full breadth.
- **Invariants / dependencies:** preserve checked mutation APIs, earliest suffix
  splits, all five variants, source positions, one-arm exit labels, typed-loop/
  call aliases and capture lifetimes. Keep tiny/sparse fallbacks; eager
  continuation indexes remain rejected. P03/P08/P09/P10 depend on this owner.
  V25 bounded repair evidence is complete; final current-source shared-consumer
  aggregate renewal remains deferred, not the old bounded repair replay.
- **Exit / tests:** improve enclosing time and shape/size without regressing
  candidate-free, nested/multivalue/effectful or dirty-round controls. Extend
  [suffix controls](src/passes/value_suffix_reuse_perf_wbtest.mbt) and all-variant
  dispatcher/runtime fixtures; P03e owns DAE2-O integration.

### P06 — Remaining OI validation and exact guard work [IR2-PERF-OI]

- **Completed root-storage experiment:** native11e04de3…→f3167b00… packs
  immutable private root rows while retaining the six already-static flow facts.
  All3,852,088 classifications remain; exactly3,852,088 requests disappear.
  Complete OI work−1.702%, command2039.368→2010.081ms/B902.056ms (2.228×,
  n5, paired−1.383%). Packed array/index construction and wasm-gc controls
  cost more; no pass-local or peak-memory win claimed.13,441 tests/2400
  observations and exact outputs/API pass. Do not repeat the root/flow boxing
  hypothesis; flow never dynamically allocated in this native baseline.
  [Full construction/lifetime tradeoffs and matched four-pass checkpoint](docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md#october-3-2026-pack-immutable-oi-root-records).

- **Historical complete-command attribution:** native62e79f73…20.611b instructions;
  module encoding cleanup5.826b inclusive (simple type cleanup3.938b, numeric
  local grouping1.142b, control cleanup.659b). These include nested checks and
  destruction, not just OI rewrite. Unchanged type-remap output storage is now lazy; do not repeat it.
  Inspect remaining complete cleanup owners; descriptor bridges already use revision guards.
  Retain both enabled module validations; do not add nested scopes as time.
  [Source-backed profile](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-3-2026-prove-absent-cfg-continuations-from-verified-side-tables).

- **Owner / why:** [OI cleanup](src/passes/optimize_instructions_cleanup.mbt),
  [exact sizing](src/binary/encoded_size.mbt) and full validation; the pipeline
  remains much larger than its rewrite timer.
- **Current large checkpoint:** local grouping's changed-body guard reduces
  matched untraced command median 2,832.710 → 2,510.143 ms (five pairs;
  paired median -11.96%), with exact output bytes. Verified v133 command is
  982.686 ms; the remaining 2.55x command gap stays open. Callgrind instructions
  fall 12.0% and allocator calls 13.4%. Every timing row observes background
  activity; instruction evidence corroborates the improvement. See the
  [OI dossier](docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md#october-1-2026-large-module-local-group-validation).
- **Deliverables / tasks:** reduce the remaining type-cleanup sizing/validation
  round and exact body encoding. Preserve global validation for type-index
  remaps and complete final validation. Profile compatible candidate batching
  outside local grouping, retaining individual fallback for invalid or
  unprofitable candidates. A counting sink requires shared opcode/immediate
  definitions and full exact-size/error equivalence.
- **Invariant / dependencies:** identity admission, one-buffer body framing, exact
  local-remap expression sizes and shared string-pool/index lookup remain required;
  the previous framing control does not prove a speedup. Keep exact names,
  facts, strings, section LEB framing and complete final validation. Shared P11/P13.
- **Exit / suggested tests:** lower enclosing time without worsening canonical
  output; extend [identity](src/passes/local_group_identity_perf_wbtest.mbt) and
  [body-size controls](src/binary/encoded_size_body_perf_wbtest.mbt), mixed accepted/
  rejected candidates, string 127→128 and body/count/section LEB boundaries.

### P07 — Remaining DFE hashing, remapping and type cleanup [IR2-PERF-DFE]

- **Completed type-output storage:** allocate only after an actual change;
  all visitor/reference/identity-map contracts retained. OI complete command
  work−.638%,599,151 fewer requests with13,439 tests/2400 observations passing.
  Tiny sparse/dense controls and normal clock costs stay visible. Remaining
  type/reference scans and separately duplicated rume work require actual
  consumer evidence; no blanket cross-package refactor or validation elision.
  [Constructor proof and cost scope](docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md#october-3-2026-allocate-type-remap-output-only-after-a-rewrite).

- **Owner / why:** [DFE](src/passes/duplicate_function_elimination.mbt); subsecond
  absolute time still has a substantial large oracle ratio.
- **Deliverables / tasks:** profile collision equality, unchanged-body hashes,
  caller remaps and type cleanup within a remap epoch. Extend existing changed-
  target/fixed-point facts only where repeated work is measured.
- **Invariant / dependencies:** unchanged grouping admission, fused roots and
  incremental worklists, identity remap epochs and lazy body remapping are
  required. Profile hashing before extending caches; retain exact collision
  checks, rec-group and descriptor/tag/continuation roots and host-visible identity; guard work shares P06.
- **Exit / suggested tests:** improve large time without tiny cost or output loss;
  use unique bodies, adversarial collisions, recursive remaps and
  [fixed-point controls](src/passes/duplicate_function_fixed_point_perf_wbtest.mbt).

### P08 — Remaining DAE snapshots, uniform actuals and transactions [IR2-PERF-DAE]

- **Owner / why:** [DAE](src/passes/dead_argument_elimination.mbt); the October 1
  isolated pilot removes recursive contiguous-root slicing (small untraced
  DAE/O paired −4.93%/−14.73%, exact fixed artifact bytes). Current small traced
  inner medians are 61.216/152.455 ms versus v133 0.890/18.193; these diagnostic
  runs include trace overhead and are not the untraced improvement pairs.
  Target at most 2× matched v133 time while preserving output/cleanup breadth.
  Large optimizing takes the productive but restricted typed-loop-safe path.
  Historical September 30 timings remain in their original evidence below.
- [ ] Reduce full boundary/call-fact snapshot reconstruction across productive
  core and selected-lane rounds. Evaluate the existing
  `dae_refresh_changed_caller_function_infos` and lightweight batch-adoption
  helpers for proved same-shape mutations, extending topology/exposure facts
  and deterministic caller order as needed. Retain full rebuild for unproved
  body, signature, control-type, import, numbering or module-shape changes.
- [ ] Investigate batching compatible rewrite plans and candidate validation.
  The October 1 plain small profile still records 66 full snapshots and 35
  whole-module validations after the slicing fix (optimizing historical counts
  125/39 are not renewed in this pilot); wrapper and inner counts must not be
  added. Preserve candidate rollback, stale-plan rejection, every intermediate
  state's required checks and complete final-module validation.
- **Deliverables / tasks:** profile uniform actuals, parameterized operand/slice
  construction, droppable pure-value need-stack allocation and solving on active
  inputs. Reuse literal/forwarding facts and owned recursive scratch, rather
  than complete copied operands. Prioritize recursive forwarded-uniform answers
  and remaining value-slice reuse: the October 1 plain profile falls from
  12,106 to 4,899 slices without fewer scans/checks; optimizing historical
  52,033 calls remain a lead, not a new count. The contiguous-root mechanism
  is complete; do not duplicate it. Key further reuse to body/signature/type
  revisions and preserve cycle handling and exact floating-point identities.
- [ ] Reduce computed-operand proof/wrapper overhead if enclosing evidence
  justifies it. Native full-slice/fallback means are 306.24/349.68 ns with large
  fallback spread; three bounded repeats remain noisy (quietest 306.00/318.93).
  Keep complex slicing and ownership/admission intact; scalar1/16 controls gain
  84.84%/93.61%, but do not claim every operand family improves.
- **Admission invariant:** establish fallthrough eligibility before an early
  exit: `None` and `Some([None])` differ, and later unsupported control can change
  admission. Rebuild facts on body, callee boundary, numbering, arity or relevant
  type changes. Preserve NaN identity, effects/traps and input ownership.
- **Evidence still needed:** measure the enclosing benefit of existing exact-
  owner graph reuse on active small/large rounds; its native nonconstant control
  gain does not prove an active speedup. Use
  `.tmp/dae-all-speed-20260930/investigation.md` and its frozen manifests for the
  renewed ratios, phase/native profiles and size deltas; require paired gain,
  MAD and RSS evidence before adopting the next trial. The October 1 pilot
  records 2,698,405→2,399,936 malloc calls, near-flat two-sample RSS and a noisy
  large command control (+0.26%/+1.65% paired); do not claim a large gain.
  Next, test caller-local answers within an exact unchanged graph epoch before
  broad retained reuse or compatible validation batching. Classify
  uniform-actual/capture and generated cleanup residuals.
  [Priority evidence](docs/wiki/tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
  owns completed fixes, native controls and prior tradeoffs. Large guarded DAEO
  does not prove cleanup breadth; P05 supplies nested cleanup.
- **Exit / tests:** active recursive forwarding, multi-value, typed loops,
  foreign-owner fallback, effects/traps, unchanged epochs and plan reuse;
  extend [call facts](src/passes/dae_count_only_facts_perf_wbtest.mbt) and
  [stable operands](src/passes/dae_stable_operands_perf_wbtest.mbt). Require an
  enclosing improvement and classified output gaps, then deferred final renewal.

### P09 — Remaining called-body planning and round updates [IR2-PERF-INLINING]

- **Owner / why:** [Inlining](src/passes/inlining.mbt); active large plain and
  small optimizing paths still need lower cost or oracle parity.
- **Deliverables / tasks:** profile called-body fallback classification,
  profitability/reachability, copying and repeated rounds. Key touched caller/
  callee facts to body/signature revisions; rebuild ambiguous partial-split or
  remap cases and reconsider eligibility when a callee changes.
- **Invariant / dependencies:** lazy context, scratch cursor, called-only ordinary
  classification, typed scratch cursors and plain body-measurement reuse are
  required. Full partial/
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
  controls, imported-alias facts and runtime-trace reuse remain required.
  Large unchanged/guarded timing is not an active optimization win;
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
  required. The standalone intersection helper still returns an owned array;
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
- **Deliverables / tasks:** reduce repeated immutable type/effect/dependency/
  ordering queries and representation allocation. P03a–d specify immediate
  DAE2 work; measure Coalesce, propagation, SSA, MergeLocals and other affected
  consumers before accepting shared changes.
- **Next measured shared targets:** current CL root40.483b instructions;
  prior nested lower5.956b after explicit effect/ordering demand removes unused rows.
  Full lower source factories4565→297; no duplicate implementation of that
  completed mechanism. Reduce measured carried fallback+140ns/+6.93µs without
  regressing large consumers or adding speculative region caches. Stack-value
  objects and unused block-write metadata still allocate. DAE2 dependency/lift
  and optimizing cleanup remain larger owners; field attribution retains its
  exact earlier snapshots.
- [ ] Reduce remaining mixed/unknown lift-conflict walks only with measured
  complete consumers: completed single-band proofs are implemented. Current
  recursive visits14.419m and saturated native costs+9.55/+92.04ns remain.
  Investigate bit-negative query ordering or a stronger bounded summary only
  after attribution; retain exact fallback, immutable snapshot lifetime,
  collision/read/write/append/mutation/admission checks and width/allocations.
  No speculative extra per-node array or persistent cache is justified.
- [ ] Bound remaining descending stack-prefix mismatch work after proving a
  wide active consumer: repeated lanes with final mismatch remain quadratic,
  but current CL entry work25.405m instructions (~.0585%) is lower priority.
  Keep full matches/tiny cases allocation-free and longest-suffix semantics.
  Existing dedicated512-lane mismatch controls are available; no new cache is
  justified merely by synthetic ratio.
- **Memory / contracts:** keep immutable function lifetimes, complete graphs,
  public ownership and recorded controls/RSS modes. Positive-mask traversal and
  region/canonicalization storage remain active; prove benefits before widening.
  Separate destruction work from allocated bytes/RSS. Plain/CL modes and
  optimizing≈138MiB excess require attribution; no whole-arena cache is justified.
- **Completed scalar CFG storage:** immutable CfgEdge values now occupy inline
  eight-byte array slots. Fields, kinds/order/duplicates, owned and borrowed
  queries, all verification and exceptional flow remain. Public .mbti has no
  diff; native representation changes and cross-package consumers are rebuilt.
  [Measured complete consumers](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-3-2026-inline-scalar-cfg-edge-storage) preserve graph counts/output bytes.
  Do not repeat this allocation trial or infer a universal RSS/clock win.
- [ ] Reduce remaining typed-pop consumer wrappers after the measured error-only
  worker removes2,928,709 requests. Reverse signature and unary/binary consumers
  are complete;2,713,068 adapter calls remain in local writes, loads/stores,
  controls and other consumers. Preserve state identity, pop/error ordering,
  subtype/bottom/unreachable rules and final Result contracts. Measure complete
  consumers and cold paths; retain current OO/OI+1.062/+.581% paired clock
  movements as unresolved. The earlier annotation-only
  and unused-parameter trials remain rejected. [Actual native boundary proof](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-3-2026-keep-validation-state-across-typed-operand-pops).
- **Completed declaration success storage:** the private walker now returns
  a nullable error; external Result contracts and all validation remain. Complete
  DAE2 and OI-command evidence is in the [current checkpoint](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-3-2026-allocation-free-declaration-scan-success).
  Do not repeat this pilot or infer a CL-inner gain from command validation work.
- **Completed lift shape storage:** both private direct/exact factories return
  an inline scalar record with payload construction/order intact. The [current
  evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-3-2026-inline-private-lift-node-shapes)
  proves one allocation removed per factory call; do not count required constant
  or signature payloads as removed. Keep CL's clock/control tradeoffs visible.
- [ ] Reduce remaining empty-child and generic/multi-result storage only with
  actual native elimination. Private lift validation wrapping is now inline;
  scalar/empty result rows already borrow function-owned scratch. Preserve
  owned multi-results and generic fallback. Direct zero-child lift now removes1,393,373 requests; do not repeat it.
  Remaining exact/generic/public default sites account for242,157 requests in
  the current DAE2 profile; measure them before extending the private factory.
  Preserve payload/flag/order/revision and append/free-node behavior. Do not repeat rejected annotation trials. Preserve
  all cold/multi/error and enclosing costs in the [adapter evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-3-2026-inline-the-private-lift-validation-adapter).
- [ ] Measure the checked HotNode return boundary: the earlier snapshot's
  getter-exclusive1.482b instructions includes a full32-byte native return.
  The annotation-only getter trial produced an identical native binary and is
  rejected; test other scalar-use changes with every range/deleted/incomplete fallback
  intact, fresh mutation reads, actual consumers and complete pass measurements.
  No widened admission or persistent snapshots; wrapper disappearance alone
  does not prove a throughput win.
- [ ] Measure high-degree CFG reciprocal-edge verification: nested neighbor
  scans can be quadratic on wide joins/switches. Current dependency snapshot
  attributes.280b instructions to all CFG verification, without proving degree
  dominance. Add bounded dedicated wide-edge controls and invalid/asymmetric/
  duplicate-kind correctness tests before choosing an index; retain every check,
  error admission and sparse no-map path. Avoid speculative heap caches.
- **APIs / invariants:** use checked scalar field getters and complete admission
  proofs; remove remaining full-header boundaries only with generated-native
  evidence. Invalidate compact facts or scratch on node/span/region/local/type
  changes; output reuse also needs unchanged captures, tuples and metadata.
  Preserve deleted-node and incomplete-arena errors, deterministic source order
  and result ownership. Avoid whole-arena retention and default-path boxing.
- **Exit / tests:** material actual-consumer time/RSS gains, not only query
  microbenchmarks; extend [liveness](src/ir/hot_indexed_liveness_perf_wbtest.mbt),
  [root splice](src/ir/hot_root_splice_bulk_perf_wbtest.mbt), invalidation,
  deep/shared/effectful multivalue and handler fixtures. Keep historical getter
  controls and rejected annotation/value-layout trials in their dossiers.

### P13 — Remaining decode, validation and command encoding [IR2-PERF-COMMAND]

- **October 2 encoder checkpoint:** bulk leaf/SIMD success no longer boxes a
  Result; public boundaries and cold errors remain. Direct worker instructions
  fall 11.78%; roughly seven million worker success boxes disappear on the
  compiler OI fixture. Five OI pairs improve 2.37% paired, but overlapping
  command medians and host flags remain explicit. DAE2-O paired −1.91% is
  diagnostic; CL/plain DAE2 gain is unproved. All four output hashes are exact,
  13,297 default tests and 336 fixed execution observations pass.
  [Scope, controls and limits](docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md#october-2-2026-avoid-boxed-success-in-sequence-leaf-encoding).
- **Completed scalar LEB pilot:** nativef3167b00…→fd2af4bd… shares nullable
  workers with unchanged public adapters/checks. Five local/integer leaves
  remove4,549,621 OI requests; all6,011,833/975,957 writer calls remain.
  Complete OI work−2.541%, command2002.469→1982.797ms/B898.648ms (2.206×,
  n5, paired−1.400%). Tiny wasm-gc costs and contradictory DAE2/CL traces
  remain; no extrapolated pass-local or peak-memory win.13,443 tests/2400
  observations and exact outputs/API pass. Do not repeat the worker pilot.
  [Full scope and four-pass checkpoint](docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md#october-3-2026-avoid-boxed-leb-success-in-scalar-leaves).
- [ ] Attribute and reduce remaining unsigned public-adapter packaging only
  in measured private consumers: fd2af4bd… retains2,435,782 unsigned/2,377
  signed request edges. Preserve recursive/nonstandard type-index rejection,
  proposal-specific immediates, every width/range/limit/error and prefix order;
  keep public Result boundaries. Verify native elimination and all4 consumers.
- [ ] Trial private value results for unsigned decoding after ownership/count
  attribution: current OI4,402,894 requests; native success allocates tuple
  and Result. Preserve public results, offsets, EOF/error precedence, width,
  maximum-byte/unused-terminal-bit and permitted padded LEB admission. Add
  truncated/noncanonical/invalid/cold controls before conversion; no cache,
  widened admission or API/IR replacement. Preserve exact Float/GC bytes.
- [ ] Renew quiet CL/plain DAE2 controls and profile remaining unsigned/signed
  immediate result boxing, declaration-validation scans and stack iterator
  churn. Keep every LEB width/range/error check, exact NaN bits, complete
  verification and unchanged public result contracts; do not infer exclusive
  allocation totals from shared Callgrind counters.

- **Owner / why:** [cmd.mbt](src/cmd/cmd.mbt) and [encoder](src/binary/encode.mbt);
  end-to-end costs must include work outside optimizer timers.
- **Deliverables / tasks:** use renewed empty/unchanged/active phase controls to
  target remaining decode/final-validation/encode materialization. Reuse input
  facts only under invocation-local unchanged-result contracts; preserve option,
  proposal, metadata, portfolio and output-selection semantics.
- **Validation reuse constraint:** DAE2 prunes/cleans types after its internal
  validation; normal CLI final-module validation sees that later result. Extra
  post-encode decode/validation is debug-serial-only, not part of normal-command
  work. Retain checks in their enabled modes; timer labels alone do not prove
  a branch executed. No redundant-check removal is justified by current evidence.
- **Invariant / dependencies:** direct sequence-leaf encoding, scoped string
  indexes and unchanged-NaN input-byte reuse with conservative encoding-cleanup
  admission remain required.
  Empty CLI reuses encoded input and does not measure full optimizer decode/
  validation work. Shared P06/P11; tracing must preserve exact untraced bytes.
- **Exit / suggested tests:** lower untraced command wall time without omitted
  checks; extend [encoder controls](src/binary/encode_sequence_cursor_perf_wbtest.mbt)
  and both-size empty/unchanged/active commands with independent validation.

### P14 — Remaining active coverage and unmeasured owners [IR2-PERF-COVERAGE]

- **Owner / why:** [registry](src/passes/optimize.mbt),
  [performance sweep](scripts/lib/pass-performance-sweep.ts) and owner dossiers;
  guarded or unchanged paths cannot establish active transformation coverage.
- **Deliverables / tasks:** add valid asserted triggers for uncovered families;
  retain active small DAE/DAEO, SGO, optimizing inlining, MergeLocals, named-main
  and nested-handler controls. Renew the broader multi-pass performance readout
  after owner work; historical inventories/timings stay in the campaign dossier.
  Resolve CA/handler precision and proposal parity separately from setup costs.
- **Invariants / dependencies:** keep policy masks observable in memory even
  when encoded bytes are unchanged; aliases and tool/policy flags are not
  automatically missing optimizer implementations. Shared P11/P12/P13.
- **Exit / tests:** each claim names input, owner, active transformation and
  enclosing cost; extend [active controls](src/passes/registry_active_perf_wbtest.mbt)
  and [CA environment controls](src/passes/constraint_lower_module_env_perf_wbtest.mbt).

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
Historical commands and hashes live in the campaign report; regenerate source
and binary identities for the final candidate. Also complete the repository
release gates after iteration: `bun validate full --profile ci --target wasm-gc`,
README/API sync and applicable coverage checks. Review public `.mbti` diffs,
refresh the owner docs/backlog, and preserve validation or runtime blockers.

| Canonical pass/lane | GenValid aggregate | Cleanup normalizers / extra flags |
| --- | --- | --- |
| `precompute`, `precompute-propagate` | `precompute-all` | `drop-consts`, `unreachable-control-debris`, `local-cleanup-debris` |
| `dae2`, `dae2-optimizing` | `dae2` | `drop-consts`, `unreachable-control-debris`; each mode in open and `--closed-world` |
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

Shared P01/P11/P12 changes and typed-control repairs require the affected
consumer matrix above, including both HSO lanes and both DAE2 modes/worlds.
Report validation,
command, semantic, parity and size outcomes separately. Runtime-blocked cases
remain unverified; baseline byte identity establishes provenance. Classify
residuals with source/semantic/downstream evidence and measured benefits, or
retain them as parity/size gaps.

## v0.1.1 — Parity and safety [IR2-PARITY / IR2-SAFETY]

### Engine-profile follow-up [FZG036 / IR2-PARITY]

- **Goal / why:** resolve the actionable Starshine findings from the September
  23 [engine-profile deep dive](docs/wiki/fuzzing/engine-profile-deep-dive.md)
  without treating validation or sampled semantic agreement as parity proof.
  The exact 59-pass/four-profile matrix leaves 1,984 unclassified structural
  differences. The original scaled OptimizeInstructions property lane found
  48 one-invocation fixed-point failures across three leaves; focused pass and
  dispatcher tests and repairs landed in `7fe999fcc`, `204114e05`, and
  `373c4fbc7`. The scaled aggregate has not been rerun. Its other 657 strict
  differences are unclassified because the broad lane suppressed artifacts.
- **Deliverables / tasks:** after the performance trials settle, rerun the
  scaled OptimizeInstructions property lane on the repaired build, then rerun
  targeted pass/profile cells with retained
  mismatch artifacts. Group the 1,984 historical structural rows by
  fingerprint, and either align each family or document a measured Starshine
  size/performance/downstream win with semantic proof.
- **Required APIs / invariants:** all outputs validate and preserve results,
  traps, effects, imports/exports, and state. Semantic equality does not close
  structural parity. Binaryen's `try_table` Flatten assertion, Node compact-
  import rejection, and the intentional `ssa-loop` timeout remain separately
  classified external/workload boundaries rather than Starshine failures.
- **Dependencies / exit:** local evidence is under
  `.tmp/engine-profile-deep-dive/`. Exit the OptimizeInstructions slice with
  structural and semantic idempotence plus convergence on a renewed scaled
  aggregate. Exit the parity slice only when every retained fingerprint is
  fixed or has a source-,
  runtime-, size-, and downstream-backed classification; finish with the
  repository's required verified-v133 10,000-case lanes for changed passes.
  Historical v132 counts retain their original scope and do not sign the merged
  source; long aggregate renewal remains deferred during performance work.
- **Suggested tests:** exact `flatten:if-results`, loop, and SSA merge IR/byte
  fixtures; one-pass-versus-two-pass canonical equality; Node result/state
  replay; independent validation; targeted compare-pass lanes with
  `--max-mismatch-artifacts 20` and no automatic reduction.


### Vacuum PR #9155 remaining gaps [IR2-VACUUM-9155]

- **Goal / why:** complete indexed-input drop sinking and eliminate repeated
  whole-arena guard work. Concrete-arm HOT/raw sinking is already implemented;
  its [evidence](docs/wiki/binaryen/passes/vacuum/starshine-hot-ir-strategy.md#september-29-2026--pr-9155-concrete-arm-drop-sinking)
  owns the original failures, tests and fixed/runtime comparisons.
- **Tasks / APIs:** capture indexed If input parameters before void demotion
  through existing HOT control/local builders and module type resolution.
  Reduce repeated label/detached-use checks with validated ownership and branch
  evidence; renew matched 128/256-root controls, including cold lift cost.
- **Invariants:** evaluate the condition once and only the selected arm; preserve
  input/arm effects, traps, unreachable behavior and live branch-result payloads;
  never re-hoist matching arm drops. Smaller bytes alone do not close the indexed
  transform/downstream gap. Keep the established nested-cleanup win documented.
- **Dependencies / exit:** retain the frozen PR-main oracle for reduced parity
  and verified release v133 for release evidence. Resolve/classify remaining
  shapes, pass default/bounded runtime checks and include original failure,
  implementation, tests, oracle outputs and remaining gaps in the final report.
  Long Vacuum aggregate renewal follows the performance trials.
- **Tests:** extend existing pass/dispatcher PR9155 regressions with indexed
  input signatures, ordered calls, scalar/GC inputs, traps, unreachable/branch
  paths, ownership and nested downstream cleanup.



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

### Latest Binaryen main follow-ups

The order below is the follow-up priority; current P03 DAE2/DAE2-O performance
work stays first. Pin and identify a current-main oracle for the upstream probes;
keep those results separate from verified release-v133 signoff.

#### DAE never-returning reference results [IR2-DAE-BOTTOM-9169]

- **Goal / why:** important semantic parity follow-up from Binaryen
  [PR #9169](https://github.com/WebAssembly/binaryen/pull/9169),
  [commit `13b6e64b`](https://github.com/WebAssembly/binaryen/commit/13b6e64b).
  No reachable normal return is positive evidence for a non-null bottom
  reference result. Current [DAE](src/passes/dead_argument_elimination.mbt)
  appears to treat no reachable returned value as no refinement evidence:
  `dae_direct_gc_result_candidate_body(...)` requires a value candidate, and
  the single-result refinement path ignores `None`. Confirm against current
  Binaryen main with reduced outputs before implementing.
- **Tasks / APIs:** initially support only a single reference result. Reuse
  existing DAE signature mutation, callsite repair, result refinement and
  bottom-type machinery; consult hierarchy handling in
  [RemoveUnusedBrs](src/passes/remove_unused_brs.mbt) and
  [types](src/lib/types.mbt), preserving hierarchy, sharedness and non-nullability.
- **Invariants / dependencies:** prove no reachable normal return rather than
  interpreting unsupported analysis as bottom. Preserve fail-closed open or
  unsafe boundaries. Coordinate P08; defer actual implementation until current
  P03 DAE2/DAE2-O performance work is ready.
- **Tests / exit:** bounded pass and dispatcher fixtures for `throw`, explicit
  `unreachable`, infinite non-returning loops, `eq -> none`, `func -> nofunc`,
  `extern -> noextern` and caller/tail-caller propagation; open-boundary and
  multivalue negatives. Require valid repaired callers and reduced Binaryen
  output comparisons; retain the gap until that evidence exists.

#### ConstraintAnalysis sparse-state investigation [IR2-PERF-CA-SPARSE]

- **Goal / why:** investigate the substantial upstream pass-time gains from
  compact sorted state in
  [PR #9154](https://github.com/WebAssembly/binaryen/pull/9154) /
  [commit `53bf1f8e`](https://github.com/WebAssembly/binaryen/commit/53bf1f8e),
  with sorted-order API protection in
  [PR #9171](https://github.com/WebAssembly/binaryen/pull/9171) /
  [commit `6f8d66d9`](https://github.com/WebAssembly/binaryen/commit/6f8d66d9).
- **Tasks / APIs:** profile current
  [ConstraintAnalysis](src/passes/constraint_analysis.mbt) structures first:
  `CaState` uses dense local/version arrays and a relation array; joins scan
  locals and intersect relations with `filter`/`contains`. Identify sparse
  `HashMap` costs in proofs, conflicts and holder-slot accounting separately
  from branch-join/state-copy costs. Coordinate P14 and its existing CA setup
  controls rather than assuming Starshine has Binaryen's former map layout.
- **Benchmarks / measures:** focused many-basic-block, many-locals/few-constrained,
  sparse-state, repeated-branch-join and repeated-merge fixtures; measure pass
  time and allocations where possible, with tiny/dense controls.
- **Prototype / invariants:** only if profiling supports it, trial compact
  contiguous sorted storage and linear merge/intersection without per-entry
  heap allocation. Avoid quadratic insertion or merging; consider reusable
  scratch or append-then-sort when direct sorted insertion is expensive. Protect
  sorted order through the API and preserve branch ownership, reachability,
  version invalidation and constraint precision. Choose a MoonBit-appropriate
  representation; copying Binaryen's C++ container design is not required.
- **Exit:** require before/after benchmark data and unchanged semantic behavior
  before production adoption; upstream improvements alone do not prove a local gain.

#### StackIR-equivalent local temporary elimination [IR2-LOCAL-TEMP-9162]

- **Goal / why:** probe final-Wasm parity with
  [PR #9162](https://github.com/WebAssembly/binaryen/pull/9162),
  [commit `39cd18ac`](https://github.com/WebAssembly/binaryen/commit/39cd18ac),
  even though Starshine has no component named StackIR. The target is removing
  a `local.set` / `local.get` temporary across exactly one independent stack
  value when their consumer safely permits operand interchange: for example,
  `call $produce; local.set $tmp; i32.const 3; local.get $tmp; i32.add` can become
  `call $produce; i32.const 3; i32.add` when the temporary has no other needed use.
- **Tasks / APIs:** first trace whether
  [SimplifyLocals](src/passes/simplify_locals.mbt),
  [CoalesceLocals](src/passes/coalesce_locals.mbt), [RSE](src/passes/rse.mbt),
  [expression reconstruction/lowering](src/ir/hot_lower.mbt), or another local
  propagation/peephole stage already produces that final Wasm. Existing adjacent
  set/get and SIMD-carrier rewrites in [raw cleanup](src/passes/pass_manager.mbt)
  are starting points, not proof of full coverage. Coordinate P05/P04/P03f.
- **Tests / invariants:** reduced probes based on upstream `optimize-stack-ir.wast`:
  positive candidates `i32.add`, `ref.eq`, `f32.min`; negative cases `i32.sub`
  and more than one intervening independent stack value. Preserve evaluation
  order, producer timing, side effects and traps. Interchange operands only
  when Wasm semantics permit it; check floating-point NaNs and signed zero
  carefully rather than assuming apparent commutativity is sufficient.
- **Exit:** compare reduced outputs against Binaryen and measure final Wasm byte
  size, including local declarations and downstream cleanup. Add production
  logic only if Starshine retains the unnecessary temporary, in its natural
  IR/lowering layer; do not invent a StackIR subsystem.

#### Waitqueue execution-fuzz safety audit [IR2-SAFETY-WAITQUEUE-9012]

- **Goal / why:** small audit of existing support, following
  [PR #9012](https://github.com/WebAssembly/binaryen/pull/9012),
  [commit `6c1a3cb7`](https://github.com/WebAssembly/binaryen/commit/6c1a3cb7);
  execution-oriented fuzzing must not hang indefinitely on generated `struct.wait`.
- **Tasks / APIs:** the existing
  [waitqueue generator](src/validate/gen_valid_waitqueue.mbt) already emits
  timeout `0`, and the [Node-v2 executor](scripts/lib/optimizer-runtime-executor.ts)
  kills workers at a deadline supplied by the
  [compare harness](scripts/lib/pass-fuzz-compare-task.ts). Audit applicable
  execution-oriented generators and replay paths for zero/other bounded wait
  timeouts or a harness-level execution timeout; verify coverage of blocking
  waits rather than assuming these starting protections cover every lane.
- **Invariants / dependencies:** reuse existing generation/validation support
  and the runtime-coverage owner above. Do not weaken validation coverage to
  avoid blocking. If protection is incomplete, add a bounded strategy similar
  in intent to Binaryen's zero-timeout approach, preserving timeout-operand effects.
- **Exit / tests:** demonstrate bounded completion or worker termination in
  focused execution probes. If current protection suffices, document the audit
  evidence and close this TODO when performed; no feature reimplementation is needed.

## v0.1.1 — Frontend and index contracts [IR2-CORRECTNESS]

- **Parameterized HOT if signoff:** finish current-source independent runtime
  checks and shared-consumer aggregate renewal for parameterized control,
  tuple entries and constant selection/demotion. Preserve entry evaluation
  order, both arm stacks and source positions; do not reimplement the closed
  stack-underflow, duplicate-entry or function-index fixes.
- **Dependencies / exit:** focused bounded IR/byte fixtures, exact supported
  original/optimized observations, malformed-input rejection and reviewed
  `.mbti` contracts. Shared long renewal is deferred until performance work
  settles. [Source context](docs/wiki/ir2/architecture-rules.md) and
  [index/validator contracts](docs/wiki/validate/type-section-and-subtyping.md).

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

- **v133 residuals:** classify the historical GTO, 2,216 shared-object, 2,632 CA
  and 1,080 OI differences with semantic and size evidence. The remote GTO
  renewal supersedes the older 1,253/935 counts with 1,201 random-all mismatches
  and 864 canonical size losses; the historical v132 subtype lane has 10,000
  mismatches and 6,250 losses. Hierarchy-aware fixes have since landed; renew
  those families against verified v133 before treating the counts as current.
  Shared-object-specific differences need proof or alignment; its 86 historical size losses came from older RemoveUnusedBrs
  profiles. Keep the 167 released-oracle command failures separate from comparisons.
  The current CA renewal classifies twenty scoped wins; its other 2,612 residuals
  remain open in the [current review](docs/wiki/tooling/tracing-playbook.md#ca-residual-inspection).
  Finish remaining exception, descriptor, subtype, atomic, `struct.wait` and i64
  wasm2js variants with red fixtures. The i64 implementation covers only the four
  new saturating conversions. [Inventory](docs/wiki/binaryen/version-133-upgrade.md).
- **Inherited proposal/analysis gaps [IR2-V132]:** preserve legacy multi-handler
  DAE2 representation and descriptor size gaps; broaden descriptor/module-remap
  cases and classify residual fence/atomic shapes. Resolve remaining CA/handler
  precision and parity gaps using the renewed [v133 evidence](docs/wiki/tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign); public source spans and WAST continuation grammar remain tooling boundaries; distinguish
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

### Future ReorderFunctions usage accounting [IR2-REORDER-REF-FUNC-9160]

- **Goal / why:** future implementation requirement from
  [PR #9160](https://github.com/WebAssembly/binaryen/pull/9160),
  [commit `5bcf1359`](https://github.com/WebAssembly/binaryen/commit/5bcf1359).
  `reorder-functions` remains [boundary-only](src/passes/optimize.mbt);
  this is the fifth main-review follow-up, not an immediate pass implementation.
- **Tasks / APIs:** when implementing the module-level reorder/remap pass,
  count `ref.func` usage in function bodies, global initializers and other
  applicable module expression locations, including expression-form elements.
  Reuse the existing future
  [port map](docs/wiki/binaryen/passes/reorder-functions/starshine-strategy.md).
- **Stale research:** that port map and
  [count-surfaces research](docs/wiki/binaryen/passes/reorder-functions/count-surfaces-ordering-and-omissions.md)
  still say Binaryen does not count `ref.func`; those claims are stale for main
  after this commit. Refresh them with versioned provenance when this work begins.
- **Invariants / exit / tests:** preserve complete function-index remapping;
  add body-only and initializer-only reference usage/order fixtures and reduced
  Binaryen comparisons when the pass is implemented. Keep this deferred behind
  the four v0.1.1 main follow-ups and current DAE2/O performance work.

## Backlog hygiene

- Remove an item when its exit criteria are met; keep durable evidence in the
  relevant wiki dossier and git history, not completion diaries here.
- Keep unresolved release blockers, failures and evidence limits visible.
- New implementation slices need a concrete goal, owner, dependencies, invariants,
  exit criteria and suggested tests. Preserve existing fixes and assertions.
- On new mismatches, save and minimize artifacts, classify with evidence, add a
  failing focused regression, repair the owning layer and update its dossier.
