# Agent Tasks

Active unreleased work only, reviewed October 1, 2026. Follow
[the docs schema](docs/README.md). Completed mechanisms, measurements and
rejected experiments belong in the linked wiki dossiers and git history.
New comparisons require verified
[Binaryen 133](docs/wiki/binaryen/release-horizon-and-oracles.md); historical
oracle versions and checkpoints do not sign current source.

## v0.1.1 — Performance validation and remaining gaps [IR2-PERF-FOLLOWUP]

- **Goal / why:** make Starshine competitive before release by closing pass,
  pipeline, command and output-quality gaps without removing transformations.
- **Execution priority:** finish P03 DAE2/DAE2-O first, especially remaining HOT
  field reads, temporary-buffer churn, reaching-definition/source-order work and
  optimizing cleanup setup. P12/P05/P11/P13 are shared owners of those costs.
  P08 DAE/DAEO and the other performance owners remain in scope afterward.
- **Historical performance checkpoint:** lean-v59 passes 13,101 default tests and
  10,269 bounded runtime observations across 1,442 modules. Final-index bounds
  save 26,177 canonical compiler bytes; sparse replay visits body/callee
  consumers and owns only boundary bits. This frozen checkpoint predates the
  remote correctness integration; V62 renews optimizing size and descriptive
  timings below, while plain and broader signoff still need renewal.
  The saved binary `ref.eq` defect is repaired; historical V32–V37 fixture counts
  are not general correctness evidence. Final aggregate/release signoff remains.
  The [DAE2 strategy](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#september-30-2026-final-index-bounds-for-reverse-aliases)
  owns hashes, paired measurements, costs and limitations.

- **Post-integration component checkpoint:** V61 passes 13,176 default tests,
  16 native rows and 160 bounded runtime observations. Immutable statement
  seeds improve wide balanced cleanup 5–24% with exact predecessor bytes;
  enclosing large pipelines stay flat. See the
  [query-seed evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-1-2026-immutable-statement-query-seeds).

- **Current size checkpoint:** V62 saves 7,968 raw / 8,146 canonical compiler
  bytes in 151 functions with no function growth. The renewed writer projection
  leaves **210,159 canonical / 95,465 raw bytes** against v133. V59's 232,292-byte
  gap uses its historical projection; only 8,146 bytes are saved by this fix.
  All 13,180 tests and 256 fixed runtime observations pass. Small/large enclosing
  times stay flat; the repeated active-tee cost (+1.40%) remains open.
  [Sole-reader evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-1-2026-profitable-sole-reader-reverse-copies)
  records current descriptive DAE2-O ratios (3.29× small / 4.17× large) and scopes.

### Historical V59 DAE2/O oracle baseline

The frozen v59 open-world compiler comparison uses verified release v133,
CPU 6, one warmup and three samples. These are pass-local medians, not
untraced command times or a causal comparison with earlier cohorts.

| Pass | Small Starshine / v133 ms | Ratio | Large Starshine / v133 ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| `dae2` | 3.753 / 1.012 | 3.71× | 3,998.720 / 563.604 | 7.10× |
| `dae2-optimizing` | 11.972 / 3.232 | 3.71× | 7,479.616 / 1,835.960 | 4.07× |

- **Release blockers:** current large DAE2-O adds **210,159 canonical / 95,465 raw
  bytes** against v133; V59 above retains its original writer scope. Smaller plain DAE2 output alone is not a proven win.
  Classify the V25 plain-output drift of **+458 bytes in 41 functions** against
  V18; preserve the correctness repairs and avoid using broken V18 behavior as
  a performance baseline. Both investigations are explicit P03 tasks below.
- **Evidence limits:** V59 proves wider reverse aliases with final-index
  bounds, saving 25,453 raw / 26,177 canonical bytes in 238 functions without
  per-function growth or non-code section changes. Matched large optimizing
  time is +0.15% (MAD 11.222 / 80.654 ms); this is a size win, not an enclosing
  speedup. Wider admission adds one lazy body/local scan; short-index controls
  remain flat. V58 replaces all 399 full-boundary replay resets on the
  large plain artifact and retains exactly 46,613 boundary bits. Native rows
  improve 27–99.95%; large rewrite saves 91 ms, but enclosing plain is -1.23%
  with material spread and optimizing stays flat. The first small optimizing
  wall cohort costs 58.79% with substantial wall/CPU separation; a seven-pair
  repeat retains +3.73% versus +0.53% whole-command CPU. Keep this cost open.
  Plain RSS is lower in this cohort; historical bimodality prevents a universal
  memory win. The rejected V57 retaining trial and zero-sample profiles remain
  documented. V56 active controls improve 31–81%; its repeated large cost and
  smaller native flat/loop costs remain historical tradeoffs to resolve.
  V55 removes intermediate alias trees, improving wide
  active native controls 12–21% with exact artifact bytes. Enclosing optimizing
  time stays flat. Small plain and RSS cohorts are noisy; repeats retain
  dispersion and reverse RSS medians, so no general speed/memory win is claimed.
  V54 saves 39,161 raw / 40,806 canonical bytes with no
  raw function growth or nonlocal/semantic-section drift. Compiler optimizing
  pairs cost +0.58% small / +0.80% large within candidate MADs; active tee
  costs +1.66% beyond MAD and stays open. Plain timing/RSS is close to flat.
  V53 avoids single-leaf suffix state construction. Large
  optimizing matched pairs improve 5.00%; small/tee optimizing stay flat.
  Large plain costs 1.44% and plain RSS has a higher median with wide ranges;
  keep these costs open. Fallback native controls cost about 2–8%.
  V52 retains unchanged balanced control storage with exact
  artifact bytes. Matched optimizing is −4.93% small / −2.54% large /
  −2.60% active tee, with material spread. Large plain is +1.33%, within
  MAD; keep costs open. Plain RSS medians are higher in both cohorts
  with bimodal ranges/calibration; this remains unresolved. The dossier
  owns native and timing/RSS evidence.
  V51 removes terminal suffix searches and caller tail
  copies with exact output bytes. Matched optimizing is −0.84% small /
  −0.29% large, with +0.81% active-tee cost. Large plain costs +8.93%;
  independent repeat is +1.76% with spread versus −1.74% identical-binary
  calibration. Keep these costs open; the dossier retains all cohorts.
  V50 removes producer/statement copies, improving wide
  native controls 66–99% with exact output bytes. Small optimizing instruction
  work falls 0.69%; matched compiler optimizing times remain flat (−0.04% small,
  +0.27% large), with +0.55% on active tee. Plain costs +1.66% small and +2.83%
  large; an independent large repeat is +1.59% with substantial spread, while
  identical-binary calibration is +0.29%. Keep the measured costs open.
  V47's 54,687 raw / 56,875 canonical byte saving is retained. Earlier V32/V38/
  V43/V45/V47 control, lifetime and plain-pipeline costs remain P03g concerns;
  the [DAE2 dossier](docs/wiki/binaryen/passes/dae2/starshine-strategy.md) preserves
  complete cohorts, rejected trials and uncertainty. The
  [priority report](docs/wiki/tooling/tracing-playbook.md#v18-complete-enclosing-evidence-and-remaining-gaps)
  owns historical DAE/O cohorts and V25 correctness repairs; do not label
  superseded timings current or use broken V18 behavior as a performance baseline.
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

- [ ] Attribute remaining source/reader/access rows, comparator closure
  construction, array growth and reference-count/destruction work. Trial reuse
  where enclosing gains justify lifetime costs. Five loop-scoped raw visitors are
  now hoisted; the toggled native profile records 43,495,605 allocator calls
  across the large command, not solely final capture cleanup. Obtain honest
  scoped allocation attribution before targeting individual query families. V29's
  toggled profile records 651,397 whole-command sort calls; any cached comparator must capture its order
  row without a facts backpointer or reference cycle.
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
  last-write and source queries on actively transforming inputs. Demand compact
  facts only where full-pipeline evidence supports their storage cost.
- [ ] Gate immutable-entry reachability on an observed never-written read,
  rather than the presence of an unused never-written local. Reuse admission's
  existing nearest-write/read tags to avoid a redundant final node-header scan.
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
- [ ] Reduce repeated body/revision queries and representation allocation;
  extend the read-source snapshot to demand only unresolved reads when measured
  gains justify it. Preserve
  conservative dependencies when control/signature information is unknown.
- [ ] Evaluate compact affected-function/revision summaries for remaining
  unavoidable work; invalidate on body, node/span/region/local/type/signature
  changes. Whole-HOT retention and its smaller budget remain rejected.
- **Tests / measures:** active signature changes, indirect/recursive calls,
  indexed/multivalue/branched control, grouped locals, tuple/GC producers,
  handlers/continuations and captures; frozen before/after bytes, phase time,
  native work and RSS. Extend existing control/handler benchmark lanes.

#### P03e — Optimizing cleanup setup [IR2-PERF-DAE2-CLEANUP]

- [ ] Reduce remaining plain no-work compaction costs while retaining all
  legacy and effect-spanning candidates. Optimizing admission now uses counted
  capture/unused-local/alias facts; plain still takes its original scan path.
  Preserve the V47 quality gain and resolve its measured plain-pipeline cost.
- [ ] Reduce remaining shared suffix-wrapper and repeated future-read/next-if
  scans after V51 removes terminal searches and caller copies. Preserve source
  write/read barriers, typed admission and exact output; use active and no-work
  controls before adopting cached facts or additional admission scans. V53 closes
  numeric-constant/valid-local leaf state construction. Reduce remaining
  compound/unknown suffix-query initialized-local arrays without sharing mutable
  state across callers. V61 closes repeated wide balanced-statement mask setup
  with immutable seeds; full-function native rows improve 5–24%, enclosing
  compiler times stay flat. Preserve full typing and measure other query owners.
  Balanced flat cleanup repeatedly scans an immutable original tail, but the
  simple distinct/reused/nested capture pipeline probe scales roughly linearly.
  Profile actual compiler query density and preserve direct-write/recursive-read
  and terminator semantics before adding sparse tail-event caches.
- [ ] Remove duplicated balanced-capture scan/materialization work while keeping
  legacy smaller-overlap decisions. V32 native controls cost 12–21% more and
  matched small optimizing is +6.39%; retain these costs until measured away.
- [ ] Attribute whole-code-section and per-function setup, raw Vacuum preclean,
  SimplifyLocals admission/mutation safety, child-use queries, lower and
  writeback guards separately from the actual transform timers.
  Follow the native profile into skipped-effectful-carrier and balanced-
  statement-local-get scans; trial body-revision facts or owned scratch for
  repeated suffix/effect queries before tuning the much smaller inner rewrite.
- [ ] Reduce remaining pure/effectful/carrier recursive control and array
  reconstruction after V52 closes unchanged balanced storage. Prove input
  ownership and preserve all active rewrites; measure enclosing gains before
  generalizing reuse. Reuse compact module/body facts and mutation-scoped
  suffix/effect work where costs remain repeated. Refresh after splices or
  type/import/signature changes; preserve all five SimplifyLocals variants.
- [ ] Keep Binaryen's cleanup breadth, including functions unchanged by DAE2.
  Guarded, unchanged or skipped cleanup does not count as a speedup. Coordinate
  remaining Vacuum indexed-input and label-guard work with IR2-VACUUM-9155.
- **Tests / measures:** active tee, GC/entry/pure, nested/effectful/multivalue,
  dirty rounds, one-arm branch exits and stacked operands; source-order,
  branch-label and alias lifetimes; enclosing DAE2-O and standalone cleanup.

#### P03f — Output quality and artifact correctness [IR2-PERF-DAE2-QUALITY]

- [ ] Reduce and attribute the remaining **210,159-byte canonical optimizing gap**
  by function/diff family. V32 removes 32,070 balanced capture pairs and saves
  147,876 raw / 53,470 canonical bytes without per-function pair regressions.
  V38 removes immutable parameter aliases without per-function raw size losses,
  saving another 12,417 raw / 12,850 canonical bytes. V47 removes dominated
  local copies, saving 54,687 raw / 56,875 canonical bytes. Reduce remaining
  reused/nonparameter
  captures: the imported-call loop remains 244 raw / 248 writer bytes versus
  220, while symmetric extra cleanup reaches 220 on all outputs. Compare direct DAE2,
  ordered SimplifyLocals/Vacuum and
  downstream cleanup; close indirect-family, typed-control, parameter/result
  and local/capture debris gaps without weakening behavior.
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
  Reduce the extra admission-wrapper cost on cheap nonwidening aliases: active
  tee costs +1.57%, confirmed +1.40% in a seven-pair repeat; native wide/rejection
  controls cost about 0.6–2.5%. Retain final-index bounds and one lazy scan.
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
- **Deliverables / tasks:** profile repeated dependency/action rows and query
  ordering on one revision; try demand-built facts or bounded scratch where
  repeated work remains. Refresh conflict, control-boundary and slot-query
  attribution before extending metadata. Keep raw liveness's copy-weight
  contribution; measure sparse/dense crossover across both fixture families.
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

- **Owner / why:** [OI cleanup](src/passes/optimize_instructions_cleanup.mbt),
  [exact sizing](src/binary/encoded_size.mbt) and full validation; the pipeline
  remains much larger than its rewrite timer.
- **Deliverables / tasks:** attribute compatible candidate batching, remaining
  body encoding and final validation. Try one assembled body-only batch under
  an unchanged environment, retaining individual fallback for invalid or
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

- **Owner / why:** [DAE](src/passes/dead_argument_elimination.mbt); the renewed
  September 30 diagnostic cohort retains the small oracle gap and large
  optimizing output-size gap. Target at most 2× verified v133 pass time: about
  1.322 / 28.835 ms on small DAE/O. Large DAE/O already meets this timing target
  in that cohort; output parity and cleanup breadth remain open.
- [ ] Reduce full boundary/call-fact snapshot reconstruction across productive
  core and selected-lane rounds. Evaluate the existing
  `dae_refresh_changed_caller_function_infos` and lightweight batch-adoption
  helpers for proved same-shape mutations, extending topology/exposure facts
  and deterministic caller order as needed. Retain full rebuild for unproved
  body, signature, control-type, import, numbering or module-shape changes.
- [ ] Investigate batching compatible rewrite plans and candidate validation.
  The small whole-command profile records 66 / 125 full snapshots and 35 / 39
  whole-module validations for DAE/O; wrapper and inner counts must not be
  added. Preserve candidate rollback, stale-plan rejection, every intermediate
  state's required checks and complete final-module validation.
- **Deliverables / tasks:** profile uniform actuals, parameterized operand/slice
  construction, droppable pure-value need-stack allocation and solving on active
  inputs. Reuse literal/forwarding facts and owned recursive scratch, rather
  than complete copied operands. Prioritize recursive forwarded-uniform answers
  and value-slice reuse: the small full-command profiles record 12,106 / 52,033
  slice-construction calls for DAE/O. Key reuse to relevant body/signature/type
  revisions and preserve cycle handling and exact floating-point identities.
- **Admission invariant:** establish fallthrough eligibility before an early
  exit: `None` and `Some([None])` differ, and later unsupported control can change
  admission. Rebuild facts on body, callee boundary, numbering, arity or relevant
  type changes. Preserve NaN identity, effects/traps and input ownership.
- **Evidence still needed:** measure the enclosing benefit of existing exact-
  owner graph reuse on active small/large rounds; its native nonconstant control
  gain does not prove an active speedup. Use
  `.tmp/dae-all-speed-20260930/investigation.md` and its frozen manifests for the
  renewed ratios, phase/native profiles and size deltas; require paired gain,
  MAD and RSS evidence before adopting the next trial. Classify
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

- **Owner / why:** [cmd.mbt](src/cmd/cmd.mbt) and [encoder](src/binary/encode.mbt);
  end-to-end costs must include work outside optimizer timers.
- **Deliverables / tasks:** use renewed empty/unchanged/active phase controls to
  target remaining decode/final-validation/encode materialization. Reuse input
  facts only under invocation-local unchanged-result contracts; preserve option,
  proposal, metadata, portfolio and output-selection semantics.
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
