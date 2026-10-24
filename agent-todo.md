# Agent Tasks

Active unreleased work only, reviewed October 20, 2026. Follow
[the docs schema](docs/README.md). Completed mechanisms, measurements and
rejected experiments belong in the linked wiki dossiers and git history.
New comparisons require verified
[Binaryen 133](docs/wiki/binaryen/release-horizon-and-oracles.md); historical
oracle versions and checkpoints do not sign current source.

Completed October 7 default-gate and ten-item audit repairs are recorded in
[the wiki log](docs/wiki/log.md). They are removed from this active backlog.


## Next unreleased patch — Coverage and output quality [IR2-REVIEW-LIMITS]

### Native command fixture baseline [IR2-CMD-FIXTURE-BASELINE]

- **Goal / why:** restore the native command gate's known-red carried-guard
  fixture; the extraction gate passes 824/825 command tests.
- **Deliverables / tasks:** investigate the existing `wasm-opt` fixture-lowering
  failure independently of the extracted pass fixes; retain its regression.
- **APIs / invariants:** preserve the carried-guard validity assertion and the
  native WAT helper's fixture meaning; no production workaround is authorized.
- **Dependencies / exit / tests:** reproduce against the pristine baseline and
  current environment, then pass the existing test and native command package.
  See the [extraction gate record](docs/pass-audit-extraction.md#final-gates).

### Cast aggregate coverage [IR2-CAST-PROFILE]

- **Goal / why:** repair a pre-existing generator configuration collapse; seven
  cast profile labels currently select the later-reuse body.
- **Deliverables / tasks:** give each intended leaf a distinct configuration
  and assert its actual opcode/type shape, not only its label or any cast.
- **APIs / invariants:** preserve valid generation, deterministic seeds and
  exported runtime targets; do not weaken the repaired function/GC hierarchy.
- **Dependencies / exit / tests:** red-first leaf-shape tests, native generator
  renewal and the required 10,000-case verified-v133 aggregate with actual
  family coverage. The current hierarchy repair has independent direct tests.
  See the [review record](docs/wiki/tooling/validation-gates.md#october-19-2026--pass-review-follow-up).

### Shared-object handle lifetime [IR2-MSO-HANDLE-LIFETIME]

- **Goal / why:** bound retention for escaping handles without changing later
  loads; current private table entries live for the module lifetime.
- **Deliverables / tasks:** establish an explicit module ownership/release
  contract before changing escaping-handle storage. Adjacent conversion pairs
  already avoid handles and unused table/helpers.
- **APIs / invariants:** exported externrefs do not expose internal handle
  liveness; a host-only release function is insufficient. Preserve cross-call
  stores, loads, aliases, nullability, and both host conversion calls.
- **Dependencies / exit / tests:** an approved ownership contract and explicit
  release points, with store/load across exports and escaping-alias controls;
  retain the paired-conversion regressions. See the [lifetime contract](docs/wiki/binaryen/version-133-upgrade.md#shared-object-handle-lifetime).

### Generic inlining raw output [IR2-INLINING-RAW-QUALITY]

- **Goal / why:** reduce the general-profile raw-byte gap while preserving
  canonical semantics. Each 10,000-case general lane adds 42,899,612 raw bytes
  despite canonical equality; the dedicated optimizing aggregate is exact.
- **Deliverables / tasks:** inspect retained unreachable code, type/local
  declarations and cleanup placement; choose a measured smaller output without
  losing the pass analysis gains.
- **APIs / invariants:** preserve effects, traps, debug names, pass stop points
  and explicit entry operands; smaller canonical output alone is insufficient.
- **Dependencies / exit / tests:** direct bounded IR/byte regressions, exact
  baseline provenance, paired size/runtime/allocator controls and renewed
  documented aggregates. See the same review record for scope and samples.

## Missed-optimization follow-ups [IR2-MO-STATIC]

- [ ] **Goal / why:** extend the bounded static marker lane only where replay proves a missed optimization; opaque markers can change pass decisions.
- **Deliverables / tasks:** preserve candidate marker identities during automatic reduction; add supported exception/control instrumentation; qualify the separate post-pass dynamic detector in issue #19 using the existing runtime/reducer tools.
- **APIs / invariants:** canonical parser/encoder and native pass flags; actual call-site survival, unchanged original module, exact ordered effects/traps, bounded work, explicit unsupported features.
- **Dependencies / exit criteria:** candidate-preserving reducer predicate, validated instrumented/output modules, uninstrumented replay and paired size/runtime/cost measurements; keep presets unchanged until held-out schedule evidence supports a change.
- **Tests:** lost parent marker, remapped import identity, nested typed/multivalue branches, ordered load/store and trap controls. See [fuzz runner](docs/wiki/tooling/fuzz-runner.md).
- **Open raw RUB parity:** the October 13 aggregate compares 10,000 cases with no canonical size loss, but raw Starshine output is larger in 8,110 cases (+159,331 total bytes versus v133). Twenty retained cases reproduce byte-identical baseline outputs. Keep this encoding gap open; see [evidence](docs/wiki/raw/tooling/2026-10-13-missed-optimization-evidence.json).

## Package follow-ups [NPM-WASMGC-BETA]

- npm `starshine@0.2.0` and Mooncakes `jtenner/starshine@0.2.0` are published.
  Registry archives match the qualified bytes. The default npm install, nine
  exports, Node25/26 strict TypeScript/API/CLI consumers and Mooncakes source
  consumers passed. All six master workflows at `27a6ec81e` passed. Coverage
  is 28,075 / 227 against unchanged 28,138 / 196. Earlier failures and bypass
  warnings stay in [release evidence](docs/wiki/tooling/release-process.md).
- Mooncakes `0.2.1` is published and its registry archive matches the qualified
  bytes. Registry-only tutorial/API consumers pass. The root module overview
  renders the archived MoonBit tutorial, including at the unversioned latest URL.
  GitHub default master still has the `0.2.0` guide until protected advancement.
- Mooncakes `0.2.2` is published. The downloaded registry ZIP has 2,157
  members, all byte-identical to source checkpoint `0f9460d32`. Its tutorial
  is the baseline for the [0.3.0 release notes](docs/releases/0.3.0.md).
- The owner authorized `0.3.0` for both registries, a full local test, and an
  annotated tag with a detailed GitHub changelog. This supersedes the old
  restriction that treated synchronized npm `0.2.2` as a private candidate.
  Its runtime/dependency guidance is superseded by the published `0.2.2` tutorial.
- Mooncakes `0.2.2` is published and its default/latest overview renders the
  complete reviewed MoonBit tutorial. The registry ZIP exactly matches the
  qualified archive; literal registry tutorial/API consumers pass on WasmGC and
  native targets, including Node-free MoonGC, file/error checks and answer 42.
  All three eligible exact-head protected checks and package CI pass. Normal
  master advancement to `0f9460d32` completed without bypass or force; ordinary
  master workflow repeats are separate from preparation qualification.
  npm remains `0.2.0`; synchronized npm `0.2.2` is an unpublished candidate.
- The automatic FFI-backed declarations, six-pass self-build and packed runtime
  boundary remain qualified as described in [the handoff](docs/npm-beta-handoff.md).
  Unsupported ABI mappings fail generation; root/subpaths share async ESM
  initialization and GC-managed ownership. Ordinary consumers need no build tools.
- Preserve [upstream terms](docs/wiki/tooling/license-provenance.md). The author
  confirmed source use. Josh-owned original portions are scoped MIT; upstream
  Binaryen/Core/x rights and change notices remain. Exact per-file derivation is
  incomplete; do not claim clean-room or MIT-only compiled bundles.
- P1 memory, broader MSF audit and raw serialization/parity gaps stay open.
  Ordinary MSF 10k normalized/semantic comparison passes but raw bytes grow
  28,329. Record-copy 10k has smaller outputs and semantic matches but retained
  structural comparison exit 1; tiny-copy runtime costs are accepted locally.
  Current six-pass gzip grows 7,294 bytes despite unpacked reduction.
- Targeted unread-tee 10k has all runtime matches and no invalid outputs, but
  7,747 structural differences and raw total growth 25,882 remain open parity
  gaps. Preserve saved aggregate's zero-tee coverage limit and targeted profile
  evidence in [Vacuum signoff](docs/wiki/binaryen/passes/vacuum/fuzzing.md).
- The `0.3.0` registry release, tag and GitHub release are authorized. Preserve
  other worktrees, held optimizer refs, and the open memory/parity follow-ups.
  Account permissions and branch protections are unchanged.

### P1 BLOCKER — reduce GC canonicalization and wrapper peak memory [NPM-GC-MEMORY-P1]

- **Goal / why:** recover the incremental native peak memory from bounded GC
  canonicalization and immutable TypeIdx/concrete-HeapType wrapper sharing while
  preserving its artifact benefit and correctness. The user temporarily accepts
  the overhead for integration; this acceptance does not close the P1 blocker.
- **Same-input evidence:** on preserved ORIGINAL GC SHA-256
  `059555428f569dcd57275757be8453a4f4881eb80592f9f80e402b4987072de3`
  (7,452,107 bytes), three serial fixed-order samples gave first-checkpoint
  equivalent median 265,612 KiB (range 261,400–265,952), memory-repair control
  324,776 KiB (324,236–326,352), and final `680fd66c` 303,164 KiB
  (302,828–303,492). Final saves 21,612 KiB versus repair, but retains 37,552 KiB
  (~36.7 MiB) above first. Output 7,232,524 -> 6,960,836 bytes retains 271,688
  bytes of additional benefit. These are historical same-original cohorts, not
  measurements of fresh unlike-input npm builds or current a2 source.
- **Limits / invariants:** native peak RSS and occupied rounded heap blocks are
  different measurements; allocator-retained RSS remains after logical data
  releases. No upper-peak, general leak, repeated-JavaScript retention or speed
  guarantee. Keep immutable source ownership, complete type/exact/nullable
  operands, retained recursive-group/public identities, bounded per-CodeSec
  cache lifetime and unchanged preset admission. Exclude the no-benefit baseline
  route and unqualified RefType/global/mutable graph caches.
- [ ] **Tasks / deliverables:** attribute phase maxima and input/output live overlap,
  map/wrapper capacities and allocator retention; retain normal uninstrumented
  RSS cohorts and separately label diagnostic occupied-block snapshots. Exercise
  unchanged/changed typed widths and cache lifetime, then repeated initialize /
  parse / optimize / encode and reclamation in supported Node runtimes. Publish
  a reduced allocation/lifetime regression and explicit source/tool/input hashes.
- **Exit criteria:** agree a baseline-noise budget before measuring; run matched
  fresh actual-baseline/candidate cohorts directly from identical original bytes
  with controlled concurrency/order and retained samples (at least five pairs,
  median/MAD/ranges/maxima). Recover incremental RSS within that budget without
  losing the reviewed GC benefit, independent validation, runtime observations,
  nominal ownership or tarball behavior. Re-run focused regressions, full suite,
  generated ABI/type drift and isolated packed consumers. A cache microbenchmark,
  single favorable sample or temporary integration approval cannot close this
  blocker; partial reductions remain documented progress.
## Typed-if constant propagation [IR2-OPT-EXP01]

- **Goal / why:** remove the remaining equal-arm typed-if propagation gap;
  the equivalent branch-local form folds its final add.
- **Deliverables / tasks:** prove the typed-if local-flow eligibility before
  changing the existing unsafe-local guard; preserve condition/arm effects and
  traps; measure complete encoded output and downstream cleanup.
- **Required APIs / invariants:** current LocalGraph reaching-write facts and
  HOT result-region APIs; no fact may bypass alias/write or branch semantics.
- **Dependencies / exit criteria:** focused semantic proof and red optimizer
  regression, independently valid output, positive measured size/runtime cost.
- **Suggested tests:** equal/different arm values, arm writes, condition writes,
  traps and unreachable arms. The independent execution fixture and current
  direct-pass evidence are in [paired size diagnostics](docs/wiki/fuzzing/semantic-optimizer-campaigns.md#paired-optimization-size-diagnostics).

## v0.1.1 — GC effect scanner immediates [IR2-FUZZ-GC-SCANNER]

- **Goal / why:** parse GC prefix `0xfb` and its complete immediates so type
  and field index bytes do not become false standalone instruction hazards.
- **Deliverables / tasks:** failing-first scanner fixture for struct allocation
  and field access, bounded prefix decoding, and correct unsupported/truncated
  handling. Audit related reference/array opcodes before expanding coverage.
- **Required APIs / invariants:** existing effect-trap scanner and hazard
  provenance; no claimed unreachable coverage from GC subopcode or index bytes.
- **Dependencies / exit criteria:** independent decoded instruction evidence,
  focused scanner tests and renewed affected interaction evidence. The
  [DFE aggregate](docs/wiki/binaryen/passes/duplicate-function-elimination/fuzzing.md)
  reproduces two false hazards in a 78-byte executable GC module.
- **Suggested tests:** struct.new, struct.get, array instructions, zero indices,
  multi-byte indices, truncated input, actual unreachable and nullable traps.

## v0.1.1 — Ordinary RUME host function names [IR2-RUME-HOST-NAMES]

- **Goal / why:** resolve the pre-existing numeric JavaScript `Function.name`
  change when ordinary RUME removes an earlier function slot. A 42-byte module
  with an unused function 0 and retained `run` function 1 returns 42 before and
  after pruning, but its exported name changes from `"1"` to `"0"`.
- **Deliverables / tasks:** define ordinary optimizer host-observation policy,
  test exposed references/aliases and retained names, then measure an index
  preservation strategy across standard presets.
- **Required APIs / invariants:** existing RUME remap and reference liveness;
  do not treat core return equality as proof of all host observations.
- **Dependencies / exit criteria:** independent JavaScript name/identity checks,
  reviewed semantics and measured encoded size/time/memory tradeoffs.
- **Suggested tests:** earlier dead functions, late returned refs, exported
  tables/globals, imported callbacks and preset cleanup. The explicit
  [application root API](docs/wiki/binaryen/passes/remove-unused-module-elements/roots-reference-only-and-nullification.md#explicit-application-export-roots)
  preserves names relative to its input; it does not close ordinary RUME policy.

## v0.1.1 — Performance validation and remaining gaps [IR2-PERF-FOLLOWUP]

- **Goal / why:** make Starshine competitive before release by closing pass,
  pipeline, command and output-quality gaps without removing transformations.
- **Current execution checkout:** follow the user-requested verified `master`
  baseline and coordinate existing independent checkouts without resetting them.
  The October 5 correctness campaign is integrated from local `master`.
  Preserve historical branch measurements under their frozen source versions;
  follow the latest user-requested checkout for subsequent work.
- **Current execution priority (October 16 user request):** reach ≤1× for all
  four DAE passes: P08 `dae` / `dae-optimizing` and P03 `dae2` /
  `dae2-optimizing`. Preserve transformations, validation and output quality.
  CoalesceLocals, OptimizeInstructions and the other owners remain queued.
  Other project builds and benchmarks must remain running. Use larger
  alternating cohorts (101 large / 201 small samples per tool), retain all
  samples and CPU logs, and report timing spread and paired uncertainty.
  Do not stop that work or remove slow samples to obtain a parity claim.
  P12/P05/P11/P13 retain their shared dependency, lowering and cleanup work.
- **DAE campaign evidence:** [October 16 frozen trials](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-16-2026-dae-family-speed-campaign)
  records source/build identities, exact clocks, profiles, output and adverse
  controls. Trial 10 completes normal paired pass clocks: large S/B ratios
  2.200×/1.363×/22.896×/14.525× and small
  9.837×/11.808×/0.954×/1.846×, in DAE/DAE-O/DAE2/DAE2-O order.
  Only small DAE2 meets the timing target in this cohort. There are 51 large
  and 101 small measured pairs per pass, with every sample retained.
  Command/RSS and both raw component orders are complete. The component
  campaign retains 18,768 measured samples; final external review, current
  10,000-case aggregate lanes and full parity remain open.
  The frozen trial-11 default selection passes 14,779 tests; its
  source hashes are stable across the gate. Trial 10 retains its own 14,702
  baseline. Private native
  success-carrier allocation checks are bounded GREEN; this does not establish
  whole-pass allocation or memory gains. Full gate and unit details belong in
  the linked strategy instead of this active backlog.
  Remaining work targets the costly initial HOT cohort and scratch provenance,
  generic result-removal validation, repeated dependency-edge work and measured
  sparse/dense adverse cases. Prototypes have actual bounded RED/GREEN
  evidence; native speed/allocation checks and the full artifact demand census
  remain required. The writer-cut replay gate now releases its lift-journal owner before
  lowering, and keeps the old no-CFG verification path; 14 related controls pass.
  The full artifact census passes every node/writer/boundary bit in both worlds;
  native lifetime/peak and elapsed-cost evidence remain open.
  Sparse merging now uses bounded small-delta deduplication instead of all-local
  stamps. Sixteen controls and the two-body startup preservation test pass; the
  full 12,904-function artifact census preserves every old raw admission and
  admits two former HOT functions. Native timing/heap proof remains open.
  Writer cold-gate controls retain 3,264 raw samples: zero-write paths are near
  parity, but one-source-write/no-CFG paths still cost 5.5–15.9% more. Remove or
  justify that cost. The updated artifact census checks 599,480 HOT bits and
  76,336 source-writer slots across both worlds, with all twelve outputs valid.
  Syntax refinement retains 6,120 samples, with some estimator costs still open.
  Fresh whole-pass/native memory checks remain required. Claude's writer native
  review reached its session limit without an assessment; do not mark it done.
  Large DAE2-O still grows 284 bytes versus trial 5;
  eleven bodies grow versus trial 0 and seventeen versus trial 5. Keep these
  output gaps open. Correct flat Tee/held-effect handling, all source-write
  precision, callback barriers and the 8× raw-work bound must be preserved.
  Trial 11 now completes all normal clocks: large ratios
  2.109×/1.386×/21.830×/13.803×; small
  9.105×/10.964×/1.018×/1.927×. No current median meets ≤1×. All 1,216
  measured tool samples remain, and output checks pass. Command clocks finish.
  First-input early-return fusion passes all eight focused controls after four
  actual final-work failures; related sparse/manual tests and 14,787 default
  tests pass. Its fresh native controls now finish (see below). It is later than
  trial-11 native source. Its fresh full-artifact byte gate fails: all boundary
  and lexical-writer demand bits match, but 108 new raw admissions change five
  bodies (162 bytes smaller in total). Later frozen both-world checks prove
  complete masks, exact unaffected bodies and the capture/stack contract;
  3,844 reduced execution pairs match. Canonical downstream checks retain a
  28-byte gain with no growing body. Whole-pass speed and isolated heap remain open.
  All pass and command lanes now retain 2,432 measured
  tool samples plus 96 warmups, with both projects running and no sample removal.
  A later five-unit component run retains 10,914 measured batches and 642
  warmups, with both test orders and 214 whole-process RSS/CPU records. The
  boundary snapshot cache improves all nine control medians in both orders;
  this is not a large-pass gain because the large input uses the typed-loop
  batch route. First-input fusion has small/order-sensitive gains and a
  4.5–4.9% loop-control cost. Sparse startup costs 4.5–6.1% more on cold/one-change
  controls; Coalesce costs 6.3–6.7% more on multiple writes and 39.5–39.6% more
  on the read-before-write control. Numeric selected validation costs 3.4–4.1%
  more on its two-callee control. Keep these measured costs open. The formatted
  cache/fusion checkpoint passes 14,792 default tests with no public MBTI change.
  A later eager fallback-lookup fix passes four bounded tests after two actual
  resource failures. Its full-current gate passes 14,796 default tests with no
  source drift or public MBTI change; GCC O2 confirms removal of the unused
  Some-path lookup. A later component run retains 12,648 measured batches,
  744 warmups and 248 whole-process resource records. The first-child path
  cache and collector stamps improve large real component controls in both
  orders; the full large DAE route bypasses those snapshot collectors. Combined
  Coalesce removes its earlier multiple-write and read-before-write regressions,
  but its sparse control still costs about 3% more. The eager cold control costs
  4.7–5.6% more; the typed dead-carrier trial has no established net native gain
  and remains unintegrated. The integrated checkpoint passes 14,810 default
  tests with no source drift or public MBTI change. Fresh whole-pass timings
  and all four parity targets remain open. Fresh trial-12 normal clocks now
  retain 2,416 measured tool timings plus 48 warmups: 201 small/101 large pairs
  per pass. Small ratios are 8.159×/11.145×/0.992×/1.892×; large ratios are
  2.074×/1.352×/21.451×/13.934×. Small DAE2's interval crosses one; no all-family
  parity claim is supported. Both whole-command/RSS phases also complete:
  1,216 measured tool timings plus 48 warmups, for 3,632 measured timings and
  96 warmups across all three phases. Fixed-block uncertainty analysis is
  complete. The independent audit checks all timings, 2,504 resource records
  and source/build bindings. Fresh independent validation passes all 25 distinct
  saved wasm artifacts (34 path aliases); this is structural validation, not
  semantic parity. Both projects stay running and every slow sample is retained.
  The next component audit retains 5,916 measured batches and 348 warmups.
  Locals and packed-node controls include adverse cases; neither is live.
  The packed node has a verified 12-byte payload, but its clock run has no
  process RSS record. Coalesce's one-row change is now live with three focused
  tests passing. The effect-family guard is also live; 10 focused tests and
  all 14,815 default behavior tests pass. Ordinary compiled-work evidence has
  177 collected instructions on direct Instruction-array Eq edges before and
  zero after. Its old call counts mix collected and uncollected work; do not
  use them as scoped calls. This is not a whole-pass timing gain. A fresh
  DAE/DAEO pass run retains 1,208 measured tool timings and 24 warmups; small
  ratios are 7.949×/10.654× and large ratios are 2.022×/1.323×. All 3,167
  independent audit checks pass. Small DAE has a material tool-order effect
  (7.486× versus 8.479×); external compilation overlaps the large cases.
  These shared-host results do not isolate the helper gains. Ordered numeric core batching
  passes its private behavior/resource tests after a four-versus-one physical
  commit/refresh failure. HOT writer replay passes five private tests after
  four final resource failures. Native gains and full-artifact gates remain
  open. Numeric guard-cost tests expose four full-definition row allocations
  on rejected trials and repeated shared-caller scans; their private fixes
  pass the focused gate. Actual artifact activation and native costs remain
  open. The graph-only worker trial fails three new resource tests. The later
  private owned-array accessor fixes the bounded worker controller failure;
  all 26 native controls pass. Broad mixed/large admission and worker speed
  or memory gains remain open. A separate
  final-remapper fix is now live after six payload-ownership failures and
  14 focused pass/command tests passing. It copies typed Select, BrTable and
  TryTable vectors only in newly rebuilt bodies. Interface generation and
  formatting pass; the corrected full gate passes 14,829 default behavior
  tests. Native costs remain open. The numeric artifact census confirms no
  accepted batch on either input: small DAE/DAEO rejects 4/12 offers and large
  DAE/DAEO bypasses that core. Its baseline refresh hook was absent; those
  counts and deltas are unavailable, not zero. Do not promote that candidate
  or run its synthetic timing campaign as evidence for the active corpus.
- **Latest DAE limits:** the separate-process effect proof confirms three
  equality calls / 177 collected instructions before and zero after. The
  corrected frozen-reference payload suite passes 22 pass and four command
  tests on formatted live source; its full gate passes all 14,841
  default behavior tests with stable source hashes. A later typed table
  initializer repair passes four focused tests and all 14,845 default tests.
  The direct baseline has two failures; active DAE fails while DAE-O already
  passes. Type pruning now remaps retained initializer instructions. The new frozen native
  CPU/wall cohort completes 2,416 measured tool values and 48 warmups, with
  neither project paused. Wall S/B ratios are small
  7.741×/10.891×/1.013×/1.872× and large
  2.074×/1.272×/21.451×/13.700×. The small DAE2 interval crosses one;
  all four wall-parity targets remain open. Large CPU S/B ratios are
  0.470×/0.233×/2.261×/1.098×. These CPU ratios do not establish useful
  parallel speedup or replace the wall target. The independent audit checks
  every raw pair, tool order, output and archived build identity; source/review
  activity and shared-host bias remain limits. A general worker candidate is
  source-reviewed and built; its mixed-96 and all 27 native controls pass; its 96-function baseline completes behavior
  then fails the required zero-parent-producer resource count. Broad large
  admission, refusal tests, native lifecycle, frame retention and speed/memory
  checks remain open. HOT symbolic transfer
  has 220 positive large functions per world with exact artifact facts/output;
  native preflight and the ordinary compiled positive-route proof pass;
  the complete native acquisition retains 2,448 raw values and 144 warmups.
  Actual small controls cost 3.2–8.0% more; large ratios are 0.999×/1.033×
  in opposite command orders. No artifact gain is established, so the
  candidate stays private. The worker Claude review hit its session limit
  without an assessment; independent source review is complete.
  Tail-only raw fallthrough carry passes the measured sibling undo-capacity
  bound and all original controls; native cost and artifact coverage remain
  open, so it stays private. See the campaign page for exact receipts and limits.
- **October 17 DAE follow-up:** bit-aware plan comparison repairs seven actual
  NaN/signed-zero baseline failures; nine focused and four existing command
  controls pass, with a renewed full gate pending. The private pruning campaign
  retains 3,060 raw values and improves actual pruning snapshots, but its
  original-large no-prune cost is 7.1–7.5% worse, so it stays private. All four
  large worker routes pass complete functional checks; retained frames, refusal,
  native speed and memory remain open. Smaller compiled-work checks do not close
  full-pass parity. See the campaign page for source-bound receipts and limits.
  The pruning follow-up now passes 26 bounded controls and both ordinary work
  checks. Its actual first-mark census is complete; the new 4,080-value
  native cohort and independent audit pass. Original-large component ratios
  are 0.983/0.978 and actual snapshots 0.525–0.560, but adverse controls still
  cost up to 16% on tiny adverse cases. Independent source review finds no
  correctness defect. The targeted unit is now integrated with those costs
  recorded; all 26 focused and 14,873 bounded default tests pass, source stable.
  Fresh integrated native timing and aggregate GenValid remain open.
  Vacuum's full actual census has zero removed calls on all four input/pass
  lanes, so its synthetic clocks are deferred and it stays private. The opaque
  guard's 2,448-sample run has small component gains and adverse cold costs;
  it does not qualify the broader private algorithm for integration.
  The formatted NaN repair now passes both new command controls, 17 focused
  tests and all 14,856 default tests with stable source. The private worker
  consumption unit passes all 31 native controls, but generated C adds a
  per-frame success allocation; large, allocation and memory gates remain open.
  The nullable-error successor now passes all 41 native controls and eight
  ordinary allocation checks: zero success boxes after 96 complete commits,
  with pinned FuncTypes and the exact dynamic error retained. Ordinary
  counter-free routing, native speed and process-group memory stay open.
  The writer's twelve saved outputs pass structural/canonical checks and an
  independent nineteen-body semantic review. Its strict-byte gate still fails;
  its 2,856-value native campaign and independent audit pass, but actual small
  timing is flat and large timing changes direction between orders. It stays
  private. Unresolved-read preflight passes six bounded tests and ten controls;
  malformed-input checkpoint tests have a compiler setup failure. Actual
  artifact eligibility and ordinary compiled work remain open.
- **DAE exit criteria:** remove the remaining replay and repeated-validation
  costs without losing effects, source-write precision, metadata or scalar
  cleanup. Check small, large and active component controls, output size and
  memory (including the adverse single-sample small DAE/DAE2 RSS controls);
  finish bounded/default tests and fresh 10,000-case dedicated-profile
  comparisons with the verified v133 oracle. Command ratios alone do not close
  the active pass-local target.
- **October 17 checkpoint:** campaign stopped at the user's request after
  preparing the repository for a remote checkpoint. All four speed targets,
  final integrated native timings and renewed aggregate GenValid lanes remain
  open. Private malformed-arena setup passes, but its native build was stopped.
  The ordinary worker diagnostic baseline needs `<stddef.h>` before compilation;
  its resource checks and counter-free implementation remain unrun.
  The merge with current `origin/master` passes 15,078 bounded behavior tests.
  Native checking and all 740 IR tests pass after stack representation fixes.
  The direct default runner hits its argument-length limit; the compact
  default-selection runner supplies the bounded behavior result.
- **October 17 fact-reuse follow-up [P08/P03]:** the current request resumes
  work from `f1393ac`. Four bounded changes remove discarded result metadata,
  reuse capture counts and liveness, and defer unchanged signature/type arrays.
  All 15,102 default tests pass; subtype variance and changed-record ownership
  have red-first controls. Normal native timing and process-memory checks now
  complete: large wall new/base is 0.98474 / 0.98999 / 0.99444 / 0.97345.
  The adverse small DAE row remains; its new-process repeat crosses parity.
  Six dedicated 10,000-case GenValid lanes complete with no detected Starshine
  validation or runtime mismatch; continuation-runtime blocks, structural
  parity gaps and raw/canonical size losses stay open. All 1,366 retained raw
  outputs match the saved pre-edit CLI. The current census
  and [worker source gate](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-17-reuse-of-existing-dae-analysis-facts)
  keep larger task/refusal/wire/resource contracts and all four speed targets
  active. No parallel rewrite implementation is claimed.
- **October 17 further reductions [P08/P03]:** reuse DAE's required scan for
  body references, copy private HOT lowering arrays only after changes, skip
  local-throw setup without local tags, and try the existing type-only size
  proof before body encoding. All 15,119 default tests pass. Retained source
  hashes match the tested snapshot and all 1,366 prior residual outputs stay
  exact. Full normal large wall new/before ratios are
  0.95825 / 0.97661 / 0.92517 / 0.95696. Small DAE stays near parity in the
  full and control cohorts. External requested allocation bytes fall 3.25%
  for large DAE2 and 2.12% for large DAE2 optimizing; tracked usable peaks
  stay unchanged. This does not prove a total heap or RSS reduction.
  The four-slot arm-map trial is removed after dense controls regress.
  Current conditional rollback has only 47 duplicate restore rows in 228,245;
  count forward restores before a new coalescing trial. Source-write tuple
  storage, a bounded cache for repeated initial-HOT/rewrite lifts, summary reuse,
  cleanup context and owned workers still need their
  activation and resource gates. See the
  [current evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-17-2026--further-scan-and-lowering-reductions).
  Six fresh 10,000-case lanes complete: no validation or observed primary
  semantic mismatch; 2,752 original-runtime continuation blocks and 1,250
  Binaryen-only exact-type compile blocks remain. All 1,366 new retained raw
  outputs match the before CLI. Lossless seed sidecars preserve exact replay
  metadata; fix the separate UInt64 manifest parser under P14.
  All family speed targets and existing Binaryen parity/size gaps remain open.
- **Correctness takes release priority:** the independent October 3 baseline
  audit has reproduced validator, DAE and OI failures. Keep performance patches
  isolated and preserve their evidence; do not treat existing passing tests or
  unchanged output hashes as release signoff. See P00 below before publication.
- **Speed target:** match or beat verified Binaryen 133 (≤1×) on comparable
  active pass-local timings; track full-command time independently. Neither a
  helper gain nor a guarded/no-op path closes this target.
- **Earlier committed all-four checkpoint:** native `8eac37f6…`→`1c6d69ab…`,
  expression local-read success removes 1,612,632 DAE2 / 1,485,697 CL requests;
  complete pass work −0.3299% / −0.2394%, exact output retained.
  CPU 6 n5/warmup 1 full-command median±MAD:
  dae2: 3076.883±3.385 / B 1105.807±5.303 ms (2.782×);
  dae2-optimizing: 5340.747±5.013 / B 2294.815±9.034 ms (2.327×);
  coalesce-locals: 3496.929±11.865 / B 1925.688±11.188 ms (1.816×);
  optimize-instructions: 1914.338±15.181 / B 1105.949±6.649 ms (1.731×).
  Foreign activity and adverse samples retained; no general clock/RSS or 1× win.
  [Full checkpoint](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-local-read-success-without-result-boxes).
  13,531 tests; 324 validations/944 observations in 20 fixtures/pass. Existing
  typed-block failure was open at that checkpoint; the reachable abort is now
  repaired in the current checkpoint linked below. Full aggregate gates
  remain open.
- **Earlier typed-entry checkpoint:** native `5bf4a1f5…` retains typed-block
  entry operands, preserves each discarded entry effect exactly once, and
  removes unnecessary branchless wrappers. 13,549 wasm-gc tests, native release
  and README/API sync pass; 27 fixtures/pass match original and verified 133
  execution (434 validations / 1,272 supported side-observation comparisons).
  All pre-existing staged/untracked candidates and the audit report remain.
  [Repair, rejected trials and current measurements](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-retain-typed-block-entry-producers).
  The separate stack-polymorphic entry repro remains in P00; all four 1× goals,
  large canonical deficits and deferred final aggregate/CI/coverage gates remain.
- **Later CL-only checkpoint:** native `1c6d69ab…`→`776cef03…` inline
  private scan results remove 2,311,558 requests and 0.7461% complete CL work.
  CPU 6 warmup 1/n5 full-command 3464.471±30.545 / B
  1944.056±32.251 ms (1.782×), paired -0.728%.
  Foreign activity and adverse nested controls remain; no other pass is refreshed.
  [Evidence](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md#october-4-2026-inline-path-disjoint-scan-results).
  All bytes exact; 13,535 tests, 82 validations/240 observations. All 1× goals open.
- **Historical OI-only checkpoint:** native`b1ef48ca…`→`3f74dc4b…`, complete
  process work−.8188%,340,195 fewer requests and unchanged bytes. N5 CLI
  2030.554±7.049 / B1054.366±22.744ms (1.926×); paired+0.650% is adverse,
  with all rows contended. No command win is established. The large directization
  scan finds no rewrite, but all141,252 discovery visits remain and OI transforms
  elsewhere.13,503 tests and 1,172 validations/3,440 supported observations;
  all four1× and release gates stay open. [Evidence](docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md#october-4-2026-copy-directization-output-only-after-a-rewrite).
- **OI quality checkpoint:** native`4c20bc54…` retains guarded adjacent constant
  folds. One large function shrinks3 B; the current normalized gap is33,494 B.
  CLI2013.416±17.913 / B1030.112±22.296ms (1.955×), paired+0.698%; no speed
  win is established.13,507 workspace tests and 1,220 validations/3,584 runtime
  observations pass supported cases. [Evidence](docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md#october-4-2026-retain-constant-folds-under-the-effect-guard).
- **DAE correctness checkpoint:** native de85d92e… passes all 16 reduced
  DAE/O runtime rows and retains six large hashes. Its n3 CLI medians are
  DAE 1420.340/B1063.695 and DAE-O 1656.129/B2425.725 ms.
  [Spreads and limits](docs/wiki/binaryen/passes/dead-argument-elimination/starshine-strategy.md#october-3-2026-parameter-reads-in-control-operands).
- **Earlier complete DAE2 profile:** native ea4e5887… pass 28.757b instructions.
  The preceding c98 profile attributes dependencies9.355b, analysis lift6.366b,
  rewrite lift2.372b, lower4.647b and final validation2.495b; these remain
  larger owners, with source versions explicit and inclusive costs not additive. [Full source breakdown](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-own-the-incremental-type-validation-prefix).
- **Preserved quality and completed work:** V83 saves 79,962 canonical bytes
  across 4,968 shrinking functions. DAE2-O remains **99,251 canonical bytes
  larger** than v133 despite **9,949 fewer raw bytes**; CL/SL/OI canonical
  deficits remain 78,800 / 373,507 / 33,494 bytes. Keep the normalization
  protocol explicit and do not classify smaller raw DAE2 output as a proven win.
  Completed storage, discovery, replay, source-query and cleanup mechanisms,
  rejected trials and all historical timing cohorts are retained in the
  [DAE2 dossier](docs/wiki/binaryen/passes/dae2/starshine-strategy.md),
  [CL dossier](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md)
  and [tracing history](docs/wiki/tooling/tracing-playbook.md).
- [ ] Attribute the type-prefix checkpoint's adverse DAE2 peak RSS median
  (+9,928KiB, overlapping ranges) and CL paired command movement (+.966%).
  Preserve the original n5 cohort; use a bounded follow-up and phase evidence
  before claiming memory or CL clock gains. No new allocation-byte cause is
  established by allocator-call counts.
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

### P00 — Remaining correctness and verification blockers [IR2-RELEASE-CORRECTNESS]

- [ ] **Later-delta Claude review:** the restricted October 15 Opus review
  completed after the usage reset and inspected every scoped path. It reported
  four confirmed evidence or coverage gaps and six unverified risks, with no
  high-severity defect. The deep-child, memory64-boundary, Precompute-result,
  byte-reuse, and documentation findings now have direct fixes or renewed
  evidence. Refresh the packet and obtain one final read-only delta review
  after the remaining aggregate campaigns. Raw stdout, stderr, exit status,
  request, scope, and manifests are under local
  `review/claude-later-current-20261015/` in the report evidence root.

- [x] **Precompute generated execution renewal:** all 11 fixed
  `precompute-all` leaves previously lacked exports and a start function, so
  node-v2 observed compilation and instantiation without executing pass target
  bodies. Current source exports bounded scalar, control, effect, and GC
  targets; records all seven local-facts values in an exported wrapping
  checksum; and calls the GC atomic target through a no-argument Wasm wrapper.
  Five observability tests and the existing profile tests pass. NaN
  integer-bit probes and negative or about 171 MiB GC allocations remain
  compile-only. Fresh native generator `4c85b7ec` and optimizer `8438fdd8`
  complete all 22 explicit leaf/pass smokes. Twenty observations match under
  the default Node feature set; the two GC atomic leaves also match when the
  required shared-GC flag is explicit. All outputs validate and pass
  determinism and codec checks. Twelve are exact, ten retain reviewed output
  shape differences, and aggregate canonical output is 23 bytes smaller than
  Binaryen 133 despite two larger cases. `moon info` and all 14,328 default
  tests passed before this generator-only renewal.
  The WasmGC CI-profile full gate passes 14,324 target tests and all 100,750
  configured fuzz attempts.
  The first plain aggregate exposed a checksum-nested constant-select gap
  (80 versus Binaryen 75 bytes). Its red-first admission fix now replays exact
  at 75 bytes. Current optimizer `cecc7ac9` and generator `0845db24` then
  complete both 10,000-case Binaryen 133 aggregates. Plain Precompute has
  7,369 exact, 1,751 cleanup-normalized, and 880 stronger constant-control
  folds; PrecomputePropagate has 5,543 exact, 3,577 cleanup-normalized, and
  the same 880 folds. All 20,000 Node-v2 observations, determinism checks, and
  codec checks match without blocks or failures. Starshine has zero larger
  output and saves 13,191 and 16,371 canonical bytes respectively.

- [x] **HSO generated execution renewal:** current optimizer `8438fdd8…` and
  generator `4c85b7ec…` complete the 10,000-case dedicated Binaryen 133 lane
  with strict custom-descriptor and shared-GC flags. All 10,000 Node-v2
  observations are checked and three-way equal; determinism and codec are
  10,000/10,000. The lane has 2,155 exact and 7,845 documented
  `local-cleanup-debris` matches, zero residuals or failures, and canonical
  output 15,762 bytes smaller in aggregate.

- [ ] **Shared tuple lowering carried-read signoff:** a new source-order
  regression retains an old scalar read above an already evaluated tuple.
  The inherited fallback replays all32 producer imports; a fresh read also
  exposes wrong published64 instead2. The narrow zero-result/one-input
  LocalSet repair moves one physical typed row; generic/multi-input guards
  stay intact. Early/middle/late overwrite controls pass focused checks.
  The red-first middle capture allocates32 temporary locals; bounded typed
  pair reuse reduces this to2. Three two-capture layouts preserve old reads,
  new stored values and one ordered import sequence. Typed rows, refs,
  multi-cover moves and cache ownership pass 13 focused checks. Current native
  `5d8ea74e` passes all 14,300 full tests, 58,840 runtime comparisons and GC
  CLI arguments. Earlier B4→B6 wide512 pairs improve 31.868→26.044 ms
  and mixed wide512 38.023→32.313 ms, with identical bytes and all pairs
  faster. Fresh changed-consumer aggregates are running. The new
  store-run shortcut separately has red-first496-root-visit and590-stack-scan
  controls; its negative admission now checks run length before stack rows.


- [ ] **October 15 Tuple current-source signoff:** bulk publication and
  ascending-copy native `193e58a7` passed 14,267 WasmGC tests and 13,440 Tuple
  runtime comparisons. Current native `5d8ea74e` includes the later lowering
  repairs and passes 14,300 full tests and 17,080 Tuple runtime comparisons.
  The fresh callable Tuple aggregate now completes 10,000 matching runtime
  cases with all second-pass, determinism and codec checks passing. Its
  retained four drift families have source/expected-value/operation evidence;
  other changed-consumer aggregates remain open. The older `972c897d`
  exportless observations stay historical.
  Seven paired loop1024 samples preserve bytes and improve command medians
  60.307→25.767ms and child peak RSS81,732→24,400KiB. Check latest wide/control
  costs and all changed shared consumers before general claims. The private
  fused-stack stale-branch hypothesis remains unverified. Weighted pass/command
  and native separate-lane fixtures cover both store orders and overlap.
  [Contracts and measured scope](docs/wiki/binaryen/passes/tuple-optimization/index.md).
- [ ] **October 14 correctness repairs awaiting final signoff:** the
  [Heap2Local owner publication repair](docs/wiki/binaryen/passes/heap2local/index.md#october-14-2026-owner-publication-repair-under-validation)
  stages all constructor operands before publishing new fields. Red-first
  tests also exposed removed result labels, wrapper ownership, and lost array
  tee constructor effects. Array old-owner reads now use the prior allocation
  epoch; constant bounds traps retain constructor and stored-value effects.
  A combined non-null reference failure required a
  [SimplifyLocals pending-write repair](docs/wiki/binaryen/passes/simplify-locals/structure-result-lifting-and-carrier-cleanup.md).
  [Tuple captured aliases and nested overlapping copies](docs/wiki/binaryen/passes/tuple-optimization/index.md)
  and CoalesceLocals shared-body ownership also have confirmed red-first repairs.
  Final default tests, fresh native runtime, generated v133 comparisons, and
  footprint measurements remain required. New element-effect and segment-fallback
  controls found no original valid-input defect; memory packing separately has
  an exact-cost guard against byte growth. Export-only review of retained
  MemoryPacking families proves Starshine preserves memory64 full-range
  trap-before-write behavior in nine cases where Binaryen 133 partially writes;
  a profitable-split regression locks the destination preflight order. The
  1,284 blocked active-start observations remain unverified. Preserve all
  earlier release blockers.

- **Goal / why:** finish release correctness checks without losing optimizer
  coverage, source order or valid output. The immutable October 3 audit remains
  the source; its earlier failure counts do not describe current source.
- **Earlier repair record:** [October 7 checkpoint](docs/wiki/tooling/validation-gates.md#october-7-2026--p00-control-exception-and-ownership-repairs)
  covers all virtual typed-entry controls, targeted OI exits, CodeFolding holders,
  full-flow MergeLocals/full SSA, caught-call CFGs, CL liveness, source-order and
  Flatten captures, shared Precompute holders, legacy SSA scans and DCE catch
  targets, repeated scratch escapes and parameter If continuations. The current
  pre-audit default wasm-gc gate passed 13,787/13,787 tests, including all 498 existing
  SSA-nomerge tests. Fresh native execution now covers exception identity,
  forced-HOT effect/trap order and pair/triple suffixes in both capture modes.
- **October 7 bounded evidence:** native `f8c5b53a…` passes 24 fixtures / 476
  observations (110 diagnostic earlier-binary rows), seven rethrow fixtures / 90
  observations, 27 forced-HOT fixture names / 188 observations and six adapter
  checks. `moon info`, `moon fmt`, default wasm-gc and README/API sync pass.
  The n3 command cohort has −0.669% to +2.038% median time changes, with
  background activity retained. Helper gains do not close enclosing command
  parity or any of the four 1× goals. All output hashes validate; SSA-nomerge's
  +9 raw / +6 canonical bytes repair inspected local dataflow and match v133 in
  the growing bodies. Full-function runtime replay of those bodies remains open.
- [ ] Attribute the P00 Precompute-propagate peak-RSS movement. The first n3
  cohort has +6.179% and fails the chosen 5% follow-up budget. The fresh n3
  cohort passes at +2.474%; a separate n5 repeat is +1.859%, with overlapping
  ranges. The smaller CFG index reduces scratch payload, but current RSS does
  not fall versus the first cohort; changing baseline medians explain much of
  the smaller delta. Preserve all repeats and do not claim an RSS cause or win.
- [ ] Obtain the missing SGO #11 and abort/undeclared-scratch #26 reduced
  artifacts. The exact #9 select, #10 empty-then and #20/#25 nested-control
  fixtures no longer reproduce; this does not close their broader families.
- [ ] Coordinate the remaining SSA-nomerge EH overlay phis, typed loop values
  and copy insertion inside operands. Ordinary repeated block escapes,
  parameter If continuations and legacy catch reads now have focused repairs;
  the wider mutation-policy boundaries remain explicit.
- [ ] Reduce remaining full-SSA caught-call shape drift: the bounded validated
  runtime fixture is 2 canonical bytes larger than v133 because conservative
  try-entry edges retain an extra source. It remains a parity gap, not a win.
- [ ] Reduce the retained bounded size gaps: SGO empty-then is 7 canonical bytes
  larger, SSA-nomerge parameter If continuations are 8 bytes larger and the
  rethrow-zero Vacuum/DAE2-O controls are 14 bytes larger than v133. Their
  execution checks pass; no intentional shape win closes these parity gaps.
- **APIs / invariants:** preserve exception identity, all-label depths, raw
  source-access ordinals, typed entry/result lanes, handler liveness and local
  defaults. LabelStack now carries a shared catch scope; review the generated
  validator API diff. Ordinary control frames must not copy catch ancestry.
- **Deliverables / exit / tests:** finish the deferred broad gates; validate
  every final module and compare observable effects/traps against the
  original and verified v133. Preserve failure bundles and measured size/RSS
  deltas. Keep deferred aggregate/CI/coverage signoff and every 1× target open.

#### P00a — Eight-agent audit repair queue [IR2-MASS-AUDIT]

- **Goal / why:** finish broad correctness, parity and resource signoff after
  the bounded audit repairs. Completed wrong-value, type/byte/IR, harness and
  positive-coverage fixes are recorded in the
  [October 8 checkpoint](docs/wiki/tooling/validation-gates.md#october-8-2026--mass-audit-repairs-and-green-default-suites).
  Keep the October 7 audit (local-only record)
  under its original binaries, failure counts and oracle versions.
- **Current default gate:** 13,890 Moon tests pass. The full Bun lane has
  343 passes, zero failures and one existing opt-in Chromium skip. Source
  repairs and corrected invalid fixtures preserve optimizer features and
  strict parser/type/IR checks. No default passing test was disabled.
- [ ] **Complete Binaryen `i64-to-i32-lowering` (IR2-I64-ABI):** the canonical
  name is boundary-only. The active `i64-trunc-sat-float-lowering` pass covers
  only four saturating float-to-i64 opcodes and must not be used as evidence for
  i64 ABI, locals, globals, calls, returns, memory, arithmetic, comparison,
  shift, helper, or atomic lowering. Implement the staged module rewrite in the
  pass dossier, preserve explicit unsupported families, and require verified
  Binaryen 133 reduced-oracle evidence before activating the canonical name.
- [ ] **Occurrence and lifetime admission (P00/P11/P12):** extend beyond the
  repaired repeated linear tuple flow to complex control/call occurrences,
  occurrence-specific SSA rewrites and typed-loop backedge values. Preserve
  explicit conservative boundaries until sources, copies and effects can be
  selected per evaluation. Add dynamic-value, trap/order and sibling controls.
- [ ] **Complete shared legacy remapping (P08/P09):** the original DAE/caller
  walkers and ordinary legacy siblings now work, but shared raw compact-local
  reference remapping still lacks complete legacy traversal. Retain the DFE
  grouping guard until every affected reference/index walk is complete. Test
  handlers, payloads, delegation, metadata and mixed ordinary/legacy functions.
- [ ] **Frontend/byte breadth (P13):** represent quote fragments as owned bytes
  before UTF-8 decoding; current Array[String] storage cannot retain arbitrary
  escaped bytes or a UTF-8 sequence split across fragments. Add a bounded
  nested function-body reader rather than relying only on final span checks.
  Extend ordinary unfolded legacy try/delegate authoring; current parser uses
  explicit do clauses. Keep valid binary delegate/lift coverage independent.
- [ ] **Oracle/proposal contracts (P00/P11):** renew external evidence for Core
  frame-local initialization and aggregate atomic storage/reference rules.
  Preserve the recorded v133/wasm-tools conflicts and explicit proposal scope.
  Imported callable-reference boundaries now retain original observations;
  narrowing that conservative protection requires a proved flow contract.
- [ ] **DAE2 general shape and identity (P03/P03f):** general referenced/GC/
  recursive-group fixed-point costs remain separate from the narrow private
  scalar path. The singleton witness gap is closed in the bounded canonical
  fixture: 59 bytes in both modes, versus original/before 60 and intermediate
  63. Matching and mismatching indirect calls pass. Extend identity and root
  rewrite evidence before widening scalar admission or closing general parity.
- [ ] **Current resource checks (P03/P10):** preserve every matched native
  cohort. The first expanded LocalCSE build added 44.776% wall time and
  12.468% RSS for 849 fewer canonical bytes. Current `ee57fe32…` retains those
  byte savings but costs 18.911% time / 8.027% RSS above the old narrow pass in
  its matched cohort. Shared dependency rows retain exact output; their time
  is +0.010% and RSS +0.338% versus packed `3c348752…`, with overlapping ranges.
  No new clock or peak-memory win is established for that storage change.
  The dedicated 4,098-function private-scalar fixture is 8.991% / 6.833% faster
  than the witness build in DAE2/O, with four fewer canonical bytes. These are
  complete-command results on fixed inputs, not general pass-local or allocation
  results. Continue arena lifetime/profile work and preserve noisy control rows.
- [ ] **Measured resource leads (P01–P14):** attribute remaining graph/source
  queries, history/interner lookups, nested RSE probes, caller rebuilds,
  per-allocation deletion, type-group/branch-state rebuilds, text flattening,
  label copies, shallow-hash tail groups, discarded preset work and post-lift
  CoalesceLocals dense storage. Keep HSO ownership-index cost and harness
  report/solver preparation, subprocess slot release and Worker termination
  visible. Source bounds alone do not establish current time/RSS/allocation cost.
- **APIs / invariants / dependencies:** function-owned analyses, revision
  invalidation, owned intern rows, tuple occurrence and lexical initialization,
  trap/effect/handler order, type identity, metadata and valid encoded modules.
  Reuse primitive bounded scratch; avoid per-use full scans and global caches.
  Coordinate P01/P03/P05/P08/P11/P12/P13 before widening shared consumers.
- **Deliverables / exit / suggested tests:** complete the remaining owners,
  retain bounded positive/adverse controls and original/optimized execution,
  classify every canonical difference from verified v133 with actual benefit
  evidence, and renew affected aggregate 10000 GenValid profiles when the
  campaign schedule permits. Final CI/coverage/aggregate gates, retained size
  gaps and all four 1× goals remain open. Green unit tests do not close them.

#### P00b — October 9 optimizer and IR follow-up [IR2-EFFECT-CORRECTNESS]

- **Goal / why:** finish signoff for the [October 9 repairs](docs/wiki/tooling/validation-gates.md#october-9-2026--optimizer-and-ir-repairs).
  The direct-pass SIMD and string effect defects, IR side-table aliasing,
  exact-instruction mismatch, compact-CFG typed-loop SSA omission and repeated
  entry definitions, dead loop membership, batch-rewrite preflight, and bounded
  carried-local access query now have focused regressions and source fixes.
  This queue keeps only work that still needs evidence.
- **Deliverables / tasks:** classify the current generated output families and
  benchmark the source-level scaling leads below. Keep the verified v133 report
  paths and direct runtime fixtures linked from the repair checkpoint.
- [x] Run verified Binaryen 133 aggregate 10,000-case comparisons for each
  affected pass with the freshly built native CLI. All four runs completed
  without validation, generator, property, or command failures.
- [x] Classify the current generated SL effect/cleanup and OI tuple families
  with source contracts, complete replay, observed traps/state, and identical
  common downstream output. Repair the MergeBlocks, descriptor and branch-value
  spill encoding losses. The [output checkpoint](docs/wiki/tooling/validation-gates.md#october-9-2026--classify-and-repair-generated-output-differences)
  records the exact finite profiles; it does not close general pass parity.
- [ ] Close the separate 6 MB compiler-artifact SL gap: current output is
  368,910 bytes larger than v133. Native full-preset runs exceed the 60-second
  probe limit on both baseline and an earlier post-fix build; downstream
  artifact parity remains unverified. Five quiet pairs still show 165.892 ms (13.0%) added
  pipeline cost for 20 bytes saved after the measured cost repairs. Keep this
  performance gap open and retain samples under their exact executable hashes.
- [ ] Keep the known multi-pass optimizer fixed-point gap visible. The bounded
  failure-retention tests still detect changed bytes and retain the reduced
  pass sequence; encoding cleanup now needs both MergeBlocks and
  RemoveUnusedBrs to reproduce it. Single-pass aggregate size and behavior
  evidence does not close combined-pass idempotence.
- [x] Replay the three direct-pass SIMD modules in independent Node instances
  after the native build; all match the input behavior and validate with
  `wasm-tools`. The available stringref runtimes and the CLI WAT frontend do
  not accept that proposal syntax, so its null-trap contract remains
  source-backed until a compatible independent runtime is available.
- [ ] Benchmark full-arena effect and rethrow query allocations, nested changed
  struct constructor rewriting, the exact-instruction setter's per-call
  typecheck allocation, repeated bounded carried-local queries, and other
  source-level scaling leads. Measure pass time and allocated bytes on
  doubling fixtures before assigning performance severity. Keep historical
  Binaryen 133 timings under their original source versions.
- **Required APIs / invariants / dependencies:** keep exact instruction effects,
  owned side-table accessor results, revision-bumping mutations, typed-loop
  entry definitions, and valid encoded modules. Use the pinned Binaryen 133
  oracle, fresh native Starshine binary, and independent validator for new
  parity evidence; a compatible stringref runtime is still unavailable.
- **Exit / suggested tests:** classify every current residual family with
  source and semantic evidence plus canonical and downstream size deltas;
  measure pass time and allocated bytes on doubling fixtures. Keep direct SIMD
  trap/value replay, null-string trap retention, and the full default suite
  green. Do not mark pass-local speed closed from this repair alone.

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

- [ ] Profile remaining dependency/source-query work after completed descendant
  reuse. Existing lists still require materialization; do not add a new summary
  cache or claim globally linear behavior. Preserve immutable snapshot lifetime,
  first-visit order, shared operands and dead-tail truncation. The earlier 28.757b
  DAE2 scoped row is historical: the later checked-child candidate `97a7d1cf…`
  measured 28.281b. The typed-block repair renews command clocks, not scoped
  instruction counts; profile current source before claiming further savings.

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

- **Completed live-control storage reuse:** descendants rewrite first; a live
  Block/Loop/If with unchanged child IDs skips a redundant copy/comparison.
  Keep in-place edits, dead controls and call/result handling intact.
  [Proof and measurements](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-keep-unchanged-live-control-child-storage).
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

- **October 18 cleanup follow-up:** [bounded read-only predicates and deferred capture copies](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-18-2026-bound-cleanup-predicates-and-defer-capture-copies) retain all transforms and validation. All 15,165 default tests pass; public interfaces are unchanged. On the current powersave cohort, 21 paired large optimizing commands improve 4.873→4.771 s (2.1%); traced pass time is 4.174 s. Quiet small controls remain near parity; the adverse traced mixed cohort stays recorded. The **sub-second target remains open**. Four fresh 10,000-case verified-v133 lanes finish with no validation or observed semantic failures; all 80 retained outputs match baseline. Existing parity, size and runtime-blocked gaps remain. Final profiling shows 40.179b whole instructions, 15.961b on nested SimplifyLocals/Vacuum and 16.087b on DAE2 core; final capture cleanup falls 14.2% to 1.989b. Reduce the remaining pipeline costs and keep generated parity, size losses and runtime limits explicit.

- **October 17–18 demand-flow follow-up:** [demand-driven raw local flow](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-17-2026-demand-driven-raw-local-flow) removes eager whole-local-state transport while preserving bounded eager/HOT fallbacks. Large DAE2O improves from 4.512 to 4.222 s at command scope and 3.871 to 3.587 s at pass scope; plain DAE2 command time improves 12.6%. All 15,155 default tests and full artifact demand checks pass. The **sub-second target stays open**: nested SimplifyLocals/Vacuum alone takes 1.824 s. Reduce its representation/analysis/validation work without skipping transforms or checks; preserve the exact canonical/downstream output evidence and track small-control/RSS costs.

- **October 17 follow-up:** [visited-predecessor reuse](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-17-2026-reuse-visited-predecessors-in-read-source-queries) removes 25% of large-input last-write lookups and 3.1% of read-source instruction work without new storage. Default tests pass, and four fresh 10,000-case lanes finish without validation or observed runtime failures; blocked runtimes and parity/size gaps remain. Large-command clocks remain near parity and small cohorts move both ways, so P03 stays open.

- **Completed entry-source finalization:** use existing reverse DAG order to
  finalize rows after child propagation; no second arena scan or new storage.
  Preserve complete-flow fallbacks and caller-owned rows.
  [Proof, resource RED/GREEN and measurements](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-finalize-entry-sources-during-propagation).
- [ ] Attribute remaining entry-source discovery/interval work before adding
  metadata: the source owner still costs 725.870m instructions. Retain the
  unchanged single-write control's 1.89→1.94µs overlapping adverse movement.
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
  bytes; singleton native queries improve 12–86%. The October 11 repair removes
  the temporary root-write list and changes repeated unknown-local fallback
  dependencies from an R×W edge product to shared linear graph edges.
  Multiple-admission interval rows, source traversal and complete fallback
  still allocate.
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
- **Renewed cleanup attribution:** nativee9f225ec… complete per-function
  cleanup16.294b instructions; raw SL9.907b and Vacuum3.896b are disjoint.
  Reachable reads now share one traversal (946.6m→35.1m worker instructions);
  do not repeat that fix. Preserve owner branches, handler barriers, ordered
  state, NaN/signed-zero termination and complete fixed-point work.
  [Read-count mechanism](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-count-reachable-cleanup-reads-in-one-traversal).
- **Completed probe formatting:** one shared checker now omits only the
  discarded outer error context for suffix probes. Same169,849 checks, no
  validation/admission change; cleanup16.969b instructions (−4.1607%). Do not
  repeat this fix; normal diagnostics and remaining nested errors are retained.
  [Contract and measurements](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-omit-discarded-speculative-diagnostics).
- **Completed nop-run scaling:** consume homogeneous runs once; independent
  output ownership and barrier order retained. Resource scaling8× width now
  costs7.15×/7.65×, with no heap-saving or enclosing-clock claim. Do not repeat
  this fix. [Evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-consume-homogeneous-nop-hoist-runs-once).
- **Completed subtree-read reuse:** adjacent-pair cleanup returns original
  read deltas using existing owned storage. Preserve both-arm isolation, loop
  seeds, original removed reads and flat/legacy fallback. No repeated tree cache
  is needed. [Measured contract](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-reuse-original-subtree-reads-during-adjacent-pair-cleanup).
- [ ] Attribute remaining distinct-local union costs and nested-loop prewalks;
  retain the small flat unchanged cost and +1,453 allocation-request tradeoff.
  The depth128 WasmGC stack-overflow boundary is resolved: HOT lifts consecutive
  void blocks with explicit storage, lowered canonicalization carries explicit
  change bits, adjacent cleanup and command byte reuse use identity change
  signals, and the SIMD sink uses its documented identity contract. The
  iterative unwind no longer allocates an unused label-stack-head row. Depth
  31/32/33/128, block/middle/function labels, invalid labels, live prefixes,
  label-owner, sibling-label, conditional-exit, observable-value,
  root-terminator, segmented-change and CLI roundtrip regressions pass. Four
  external depth128 SL/SLNS replays validate under wasm-tools. Fresh generated
  renewal for this later source remains required before a general deep-scaling
  claim; separate setup/reference from the actual worker.
- [ ] Profile remaining recurrence/adjacent/effectful rewrites, raw Vacuum
  preclean, preparation, mutation safety, child-use queries and writeback on
  one frozen source. Completed absent-if census, initial control rejection,
  tag size bounds, flat recurrence storage, initialized read indexes, unchanged
  suffix storage and bounded initial dupable-copy discovery must not be repeated.
- [ ] **October15 statement-seed renewal:** the four-store128-local resource
  regression fails at2,560 initialized slots; shared immutable statement seeds
  reduce this to128. Positive, invalid/escape and terminal-no-query controls
  pass. All 14,300 full tests and native `5d8ea74e` runtime checks pass.
  Cost, memory and generated renewal remains open; remaining statement scans
  and the separate terminal-value setup are still open.
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

- **October 15 current-source aggregate renewal:** native optimizer `fbfc16a5`
  and generator `3dfffa7e` complete four 10,000-case `dae2` lanes with both
  required normalizers. Each has 9,312 matching node-v2 observations, 688
  blocked continuation cases, and zero observed semantic, validation, property,
  generator, command, determinism, or codec failures. Open plain/optimizing
  have no canonical size loss. Closed plain retains 706 larger cases and closed
  optimizing retains 2,133; these and the blocked runtime cases stay open.
  [Exact counts and artifacts](docs/wiki/binaryen/passes/dae2/fuzzing.md#october-15-current-source-normalized-renewal).
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
- **October 16 prefix-copy result:** destination write counts now reject dead
  candidates before suffix work, and whole-body source counts omit the suffix
  scan for immutable sources. Frozen-to-counted helper means improve 250.81 µs
  to 841.07 ns at 128 copies and 16.04 ms to 6.50 µs at 1,024 copies. The
  written-source 128-copy control remains 264.53 versus 257.14 µs with
  overlapping ranges. Four resource/reference tests, 189 Coalesce tests, one
  command test, and 12 native benchmarks pass. This is helper evidence; full-
  pass time, allocation bytes, RSS, and written-source quadratic scans remain
  open. Fresh native `2f393f99` also completes the 10,000-case verified-v133
  aggregate with its prior 3,750 exact / 6,250 smaller distribution, zero larger
  output, and zero validation or observed semantic failure. The 1,250 original
  start traps remain blocked in the harness and retain their independent replay.
- **Historical copy-barrier checkpoint:** main7a5676ba9/natived08c→dbbaefbe CL normal
  4416.546±70.418ms/B1963.489±27.857 (2.249×), n5 alternating/one warmup;
  paired−.699%, foreign activity every row. Complete CL work40.823b (−2.930209%).
  Safe-copy owner−98.240377%, structural visits12.219m→12209; exact outputs.
  13,391 tests/10 controls/185 modules/540 observations pass. No quiet-host1×
  or memory win; raw/canonical quality unchanged. DAE2/O/OI retain the d08c
  checkpoint at that date; do not extrapolate the CL-only gain.
  [Copy-barrier evidence and ownership](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md#october-2-2026-reject-globally-blocked-copy-pairs-once).
- **Historical shared CFG checkpoint:** main3631c1d0c/native43feef6e CL normal
  4311.431±54.395ms/B1947.387±23.953 (2.214×), all contended. Complete work
  40.483b (−.832954%) with identical bytes and graph counts; P12 owns this
  completed representation change. Remaining interference/lower work stays open.
- [ ] Reduce or justify current safe-copy clear/no-edge control costs without
  regressing the large consumer: clear8+1.21µs (overlapping dispersion), no-edge
  512+29.02ns. Lazy preflight already preserves O(locals) with no body scan when
  rows are empty; do not repeat the completed global rejection mechanism.
- **Historical CL-only follow-up:** branch-row reuse, main `25f8eaad0`, native
  c06f4a76→923a4908. Complete work38.583b→38.404b (−.4634%);74,415 copies and
  148,830 requests removed, all label snapshots/hazard writes retained.
  CPU6 n5 normal CLI4034.524±72.495ms/B2560.703±287.585ms (1.576×), paired−.624%.
  All15 rows contended, ranges overlap and the slower oracle is not a Starshine
  improvement. Keep preceding all-four cohort separate. Wide branch control
  31.24→19.78µs; no-branch movement adverse/overlapping, no peak-RSS win.
  13,483 tests,285 validations/840 observations and exact bytes; no API diff.
  [Proof and limits](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md#october-4-2026-reuse-branch-liveness-rows).
- **Latest CL-only follow-up:** native66f924ab…→312bb103…, packed structured
  liveness/active-bit hazards reduce complete work37.981b→37.016b (−2.5407%).
  N5 CLI3823.079±19.822 / B1902.545±35.637ms (2.009×), paired−.534%, all
  rows contended. Tiny dense controls regress and allocation requests+8,812;
  RSS overlaps.42 reference cases and76 runtime fixtures preserve all fields,
  effects and exact output. [Full evidence](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md#october-4-2026-packed-structured-liveness-rows).
- [ ] Revisit packed-liveness tiny dense cost952ns→1.05µs only with a measured
  enclosing improvement; retain sparse-row savings, masked tails and owned
  branch/exception snapshots. Do not repeat the old all-local hazard scan.
- **Tasks:** profile repeated dependency/action rows, source-order/label setup,
  capture/conflict walks and weighted/wider coloring on the current revision.
  Reduce unused block-write metadata only with complete full-graph semantics.
  Retain raw liveness copy weights and measure sparse/dense crossover.
- [ ] Represent call-origin exceptional edges in CFG coloring before admitting
  call-bearing `try_table` loops again. The current guard preserves the
  catch-visible destination across a throwing copy; prove first-iteration and
  nested-handler values with the focused red-first regression before removing
  that guard.
  Attribution precedes new retained metadata or analysis reuse.
- **Active controls / memory:** retained strip storage active-tee16+30.90ns,
  weightless-search weighted63+.34µs, scalar-clique wide fallback+10.47ns;
  preserve these source-specific tradeoffs in the linked dossier. Current RSS
  median+4200KiB has overlapping low/high modes and needs phase/lifetime
  attribution; no memory win. Canonical gap78,800B and final signoff remain.
- **Completed mechanisms:** shared reachability, unchanged strip/spill storage,
  weightless first-valid slot, scalar one-word cliques, checked lift reads,
  compact lower counts/direct results, block-only liveness and packed structured
  liveness are implemented.
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

- [ ] **October 15 declaration grouping signoff:** all seven writeback paths
  have guarded numeric grouping; `193e58a7` includes the named-unused-local
  repair and checked plain-type cleanup. It passes14,267 full tests and12,288
  typed numeric runtime comparisons. The older972c10,000-case aggregate has
  9,342 raw-smaller/504equal/154raw-larger (306B total losses). All20 retained
  bundles have fresh451calls per variant across91functions. Replay the four
  exact type-overhead loss/control cases and renew10,000 generated comparisons
  before closing losses. Native193e exact replays close cases496/4475/5132
  individually (148/351/243B versus Binaryen152/366/253B); control3 stays88B. Data counting reduces 2MiB/one-function command
  8.120→7.317ms and child peak RSS30,584→26,900KiB. Mixed128 regresses
  7.179→7.558ms in all seven pairs; repeat/inspect this cost. Full O4z1000
  remains about1.75s versus Binaryen's different preset policy at61ms.
  Claude's later restricted review completed after the usage reset. It found no
  high-severity defect. New native helper measurements bound unchanged and
  active final-size cleanup plus cached SIMD admission. Final native
  `fbfc16a5` renews plain and no-structure 10,000-case aggregates with no larger
  output or observed semantic failure. A 4,096-root carrier benchmark exposed
  and removed quadratic prefix rescanning, improving 24.86/28.21 ms controls to
  298.83/289.92 µs without changing aggregate bytes. Allocation, RSS,
  artifact-scale cost, the other SimplifyLocals modes, and final delta review
  remain open.
  [Evidence and limits](docs/wiki/binaryen/passes/simplify-locals/structure-result-lifting-and-carrier-cleanup.md).

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
  V25 bounded repair evidence is complete; plain and no-structure current-source
  aggregate renewal is complete. Other shared consumers remain separate.
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
- [ ] Continue profiling OI's remaining sizing/validation allocation owners.
  Completed empty-pool reuse removes 212.689m string-scan instructions; the
  remaining five scans cost332.655m. Mandatory first/final scans and validation
  remain necessary. Do not extend the shortcut to nonempty pools or persistent
  mutable-module caches without a new lifetime/order proof. Prefer larger
  evidenced owners over repeating this completed scan optimization.
- [ ] Verify portable native compiler configuration before adopting O3.
  The completed same-C n5 screen observes paired command gains 2.36–4.69%,
  but executable +19.395% and higher median RSS; foreign activity is retained.
  [Evidence](docs/wiki/tooling/tracing-playbook.md#october-4-2026-bounded-native-o3-build-experiment). Defaults remain O2.
  Custom cc-flags replace defaults and GCC/MSVC differ; preserve wrapv/aliasing
  behavior and generic targets. Repeat against current sources before adoption;
  do not add build-screen gains to later source measurements.
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

- [ ] **October 15 discovery/setup signoff:** source-invariant sink scans reuse
  one context; empty adjacent roots and result worklists skip unused snapshots
  and graphs. Preserve source/current import and definition bounds, prior
  touched/changed state, effects and trace. Independent review's missing-code
  unwrap regression has a red-first repair. All14,279 full tests and8 focused
  checks pass. Native baseline adds1,960 expected-value/effect/trap comparisons;
  fresh native, paired enclosing cost and open/closed generated133 renewal are
  in progress. Do not remove portfolio slots or claim the1.75–1.79s full-preset
  gap closed from source work counts.
  [Contract and evidence](docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md#october-15-immutable-sink-discovery-and-empty-worklists).


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
- **Compiler-fact boundary:** version-1 function `Never` and `Always` policies
  now use the existing `binaryen.inline` path under `HintsOnly` or
  `TrustAssertions`. `Default`, `Prefer`, and `Ignore` remain inert. A measured profile input, stale-profile
  identity contract, preference tier, and profile-aware partial inlining remain
  open; this bridge does not close that work.
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

- **October 15 bounded result:** try-table mask borrowing retains expression
  copy-on-write ownership. Two order-balanced native rounds improve first-write
  medians 459.74 to 435.22 ns (256 entries) and 516.61 to 468.95 ns (4,096).
  Unchanged and idempotent controls also improve. The earlier sequential cohort
  had a clock shift and does not establish a regression. This helper result
  does not close complete validation or memory work; see the
  [measurement limits](docs/wiki/tooling/tracing-playbook.md#october-15-report-experiments).
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
- **Completed lower-stack trial:** inline records plus saturating discard and
  direct peek remove627k/1.033m DAE2/CL requests with exact outputs; the
  annotation-only variant regressed and was rejected. Contended command pairs
  remain adverse; do not claim1× or repeat the rejected representation alone.
  [Evidence](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-inline-lower-stack-without-optional-discard-boxes).
- [ ] Profile remaining high-depth collision scans after scalar membership masks.
  Full CL still spends 276.838m instructions in 207,330 exact searches; worst-case
  quadratic work remains. Wide colliding overlap costs 260.07→293.09ns. Consider
  a strictly bounded exact word row only if saved full-pass work justifies its
  allocation/setup cost; preserve sparse/huge depths, shifts and insertion order.
- [ ] Measure private if-exit normalization handoff in the validator. Complete
  DAE2 still attributes 2,099,043 allocator requests to the private branch-exit
  worker; only source-backed elimination may count as progress. Before tests
  cover scalar/reference results, all reachability/escape kinds, virtual bottom,
  exact stack failures, then-before-else error order, initialization ownership
  and shifted escape observations. Keep public Result/tuple wrappers, mandatory
  stack validation and every control decision. Require bounded controls, actual
  native removal, complete DAE2/CL work, DAE2/O clocks and focused runtime checks.
- [ ] Attribute dense CL member-query work: frozen243a8e03 coloring1.570b
  instructions includes31.721m member bit probes. The matrix is upper triangular,
  so the existing sparse row scatter cannot be copied directly; a transpose adds
  quadratic storage. Preserve exact coloring/weights/parameter/type decisions,
  use the existing dense reference and measure an explicit storage model before
  changing this path. No dense query optimization is implemented yet.
- **Next measured shared targets:** current CL root34.066b instructions;
  prior nested lower5.956b after explicit effect/ordering demand removes unused rows.
  Full lower source factories4565→297; no duplicate implementation of that
  completed mechanism. Reduce measured carried fallback+140ns/+6.93µs without
  regressing large consumers or adding speculative region caches. Cold optional stack pops
  and unused block-write metadata still allocate. DAE2 dependency/lift
  and optimizing cleanup remain larger owners; field attribution retains its
  exact earlier snapshots.
- **Completed mixed-band DAG trial:** exact node/local/direction memoization
  cuts CL recursive calls14.419m→684 and complete work7.5544%, while DAE2
  +.0175% remains adverse. Lazy storage, cold-tree/leaf costs and all1× goals
  stay explicit; do not repeat this completed cache or extend its lifetime.
  [Evidence](docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md#october-4-2026-memoize-exact-mixed-band-lift-conflicts).
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
  worker removes2,928,709 requests. Reverse signature, unary/binary and local-set/tee consumers
  are complete;1,376,254 adapter calls remain in loads/stores,
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
- [ ] Measure the remaining enclosing CFG verification cost after the completed
  wide-edge reciprocal-membership repair. The historical dependency snapshot
  attributes .280b instructions to all CFG verification, without proving degree
  dominance. The October 7 checkpoint already has the sparse index, wide-edge
  controls and invalid/asymmetric/duplicate-kind tests; do not implement them
  again. Retain every check and the bounded no-map path. Renew complete-pass
  time and memory evidence; helper gains do not close this remaining cost.
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

- **Completed incremental prefix ownership:** `validate_typesec` now copies
  the caller's rows once and keeps all group checks and original scopes.
  Resource scaling70.60×→8.91× for8× groups; complete DAE2 work-1.736%.
  Preserve ownership/failure/forward-reference regressions. No additional
  validation skipping is justified. [Measured scope](docs/wiki/binaryen/passes/dae2/starshine-strategy.md#october-4-2026-own-the-incremental-type-validation-prefix).
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

- **October 12 O4z fallback checkpoint:** input-candidate validation is now
  deferred until smaller candidates fail. Three paired Wago runs lowered wall
  median 54.078→45.278 s and size-portfolio median 18.401→10.740 s with exact,
  valid output and collection enabled. The original input is still decoded a
  second time for portfolio candidate generation; reusing the first module
  needs proof that pipeline passes cannot mutate its shared arrays. The selected
  encoded result still requires validation.

- **Owner / why:** [cmd.mbt](src/cmd/cmd.mbt) and [encoder](src/binary/encode.mbt);
  end-to-end costs must include work outside optimizer timers.
- **Deliverables / tasks:** use renewed empty/unchanged/active phase controls to
  target remaining decode/final-validation/encode materialization. Reuse input
  facts only under invocation-local unchanged-result contracts; preserve option,
  proposal, metadata, portfolio and output-selection semantics. Prove module
  ownership before reusing an original module in cleanup paths that currently
  require a separate decode. Large modules without those paths now skip that
  decode; selected encoded-candidate validation remains a measured bottleneck
  after redundant eager validation was removed from normal O4z.
- **Validation reuse constraint:** DAE2 prunes/cleans types after its internal
  validation; normal CLI final-module validation sees that later result. Extra
  post-encode decode/validation is debug-serial-only, not part of normal-command
  work. Retain checks in their enabled modes; timer labels alone do not prove
  a branch executed. Input fallback validation now runs only if selection reaches
  it; no selected-candidate or final-module validation is removed.
- **Invariant / dependencies:** direct sequence-leaf encoding, scoped string
  indexes and unchanged-NaN input-byte reuse with conservative encoding-cleanup
  admission remain required.
  Empty CLI reuses encoded input and does not measure full optimizer decode/
  validation work. Shared P06/P11; tracing must preserve exact untraced bytes.
- **Exit / suggested tests:** lower untraced command wall time without omitted
  checks; extend [encoder controls](src/binary/encode_sequence_cursor_perf_wbtest.mbt)
  and both-size empty/unchanged/active commands with independent validation.

### P14 — Remaining active coverage and unmeasured owners [IR2-PERF-COVERAGE]

- **October 17 discovery refresh:** the [rough verified-v133 matrix](docs/wiki/tooling/tracing-playbook.md#october-17-2026-rough-comparison-across-active-passes) covers 61/61/59 standalone pass sequences on small/mixed/compiler inputs. Include raw-path work when prioritizing SSA/RSE/Vacuum; retain whole-command costs separately. Host contention and three-sample cohorts do not replace quiet owner signoff or the DAE 1× target. Large Flatten/MergeLocals remain guarded coverage gaps; four direct flags lack matching oracle contracts, and policy flags need pattern-specific fixtures. Use the evidence's changed/unchanged rows to target active fixtures and preserve unclassified size/parity drift.

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
- **GenValid replay metadata:** preserve native UInt64 seed tokens through
  [manifest parsing and bundle writing](scripts/lib/pass-fuzz-compare-task.ts).
  Ordinary `JSON.parse` rounds seeds above 2^53; the October 17 first DAE lane
  has 1,262 rounded retained entries. Exact native manifests and byte-based
  replay remain valid. Require bounded round-trip cases above 2^53 and at
  UInt64 maximum before the fix; retain original manifests as the authority.
  Report distinct module hashes separately from comparison count and primary
  runtime blocks separately from Binaryen-only blocks.

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
validation and freshly executed Node-v2 observations. New runs regenerate inputs
and oracle outputs without persistent caching; clean consumed artifacts and retain
semantic differences. Do not add `--wasm-smith` unless requested.
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

### Call-origin exception edges in full SSA [IR2-SSA-EH-CALL]

- **Goal / why:** restore safe full-SSA rewrites in call-bearing `try_table`
  regions. The current public guard leaves these functions unchanged because
  a call can throw after a local write while the merge plan selects the
  pre-try value at the catch continuation.
- **Deliverables / tasks:** materialize call-to-handler exceptional edges in
  the full-flow local graph, use them in merge inputs, then remove the narrow
  dispatcher guard only when the red-first catch-value fixture stays green.
- **Required APIs / invariants:** retain call effects, traps, handler labels,
  source local values and validated lowering; keep no-throw SSA behavior and
  public `.mbti` stable unless a deliberate API change is required.
- **Dependencies / exit / tests:** coordinate with the Coalesce CFG edge owner;
  rerun focused public/HOT exception tests, the bounded default suite, and the
  verified-v133 `ssa-all` aggregate. An unchanged valid module remains the
  safety boundary until the graph proof is complete.

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
- **Globally unread tee Vacuum:** the numeric 4/1 wrapper and targeted
  `vacuum-unread-tee` profile preserve producers, stack values, read/legacy
  boundaries and COW ownership. Keep duplicate-type raw serialization losses
  open despite measured canonical tee-removal gains and actual runtime parity;
  retain the multivalue raw/canonical win separately. Integrated coverage,
  generated FFI/npm consumers and CI still require exact-head renewal.
  [Targeted evidence and limits](docs/wiki/binaryen/passes/vacuum/fuzzing.md#october-10-targeted-globally-unread-tee-coverage).
- **Native generator I/O:** fresh absolute/relative output directories work;
  a preexisting empty output directory aborts with SIGABRT (`-6`), including
  under corrected process permissions. Reduce and repair the shared
  `src/fs/fs.mbt` / xfs create-directory error path with a failing-first native
  regression. Do not count this as a profile validation or semantic failure;
  existing successful fresh-directory campaigns remain unchanged.
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
  (+2,052 canonical bytes) and trap-relaxed OI's 30 `direct-tiny-bulk` cases
  (+300), both historical v132 figures. The no-structure SimplifyLocals
  tee-control loss is closed: final optimizer `fbfc16a5` is smaller than
  Binaryen 133 in all 10,000 aggregate cases, including the former 1,662
  size-losing rows. Ten SSA fixture families still differ in typed-loop proxies,
  reference/cast lowering and branch-table cleanup. Keep compact-import policy,
  name-metadata size gaps and unsampled tuple/downstream cases visible.
- **Host-visible identity guards:** measure preset DFE/DIE size and performance
  costs. October 10 DFE admission uses conservative per-materialization protection
  for exports, tables, globals and callbacks; qualify its measured deltas. Keep
  DIE host getter/lookup effects protected. Preserve
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

- [ ] **October15 direct-GC graph reuse signoff:** red-first no-commit graph
  bounds3/5/9→1 and inactive1→0, plus productive/rejected-attempt controls,
  preserve exact signatures, effects and original ownership. The7273e2ab
  trace attributes391ms to this batch on1,000 public numeric functions. Run
  generated comparisons before signoff. All 14,300 full tests and 58,840
  native runtime comparisons pass on `5d8ea74e`. Seven paired mixed DAE
  medians improve 437.241→30.071 ms; full O4z data1000 improves
  1814.577→635.642 ms. Bytes agree and all seven pairs improve. Controls
  remain mixed and no peak-RSS gain is established. Expanded GC coverage uses
  Node26 for Binaryen's nullable exact output and preserves Node24 failures.

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

### Wago debug-artifact execution [IR2-WAGO-RUNTIME]

- **Goal / why:** complete Wago execution of the release GC CLI on the full
  debug O4z input before reporting a Wago speed ratio.
- **Evidence:** canary cea8f83f forces collection off after exact root admission
  rejects the MoonBit externref ABI. The 2 GiB run exhausts its heap. Diagnostic
  owners include 13.324 million byte calls, 7.22 GiB host scratch allocation
  and a 34.72% inclusive GC struct-helper CPU path.
- **Correctness blocker:** artifact serialization omits start metadata. Fresh
  2/3 GiB runs start; cached repeats trap. A reduced module returns 42 fresh
  and 0 cached; its behavior regression fails. The earlier heap-size hypothesis
  is superseded.
- **Deliverables / tasks:** preserve start metadata with codec compatibility
  and imported/trapping-start tests; make reference-result scratch lazy;
  add proven exact native roots for the MoonBit ABI; measure remaining GC
  helper and bulk-transfer costs.
- **Required APIs / invariants:** retain host ABI, callback lifetime and exact
  GC reference behavior. Do not enable collection with incomplete native
  root maps. Host ABI admission may expose further caller gaps.
- **Dependencies:** upstream Wago codec, host dispatch, root admission and
  GC helper implementation. No upstream source patch has been applied.
- **Exit criteria / suggested tests:** fresh/cached start parity; allocation
  and retained-callback controls; complete O4z, externally validate and compare
  bytes with native; repeat wall and phase measurements.
  [Investigation](docs/wiki/tooling/tracing-playbook.md#october-11-2026-wago-wall-time-and-collection-investigation).

### Npm runtime comparison blocker [IR2-NODE-RUNTIME]

- **Goal / why:** make the installed npm CLI execute the current optimizer so
  Node and Bun package timings measure the requested work.
- **Evidence:** October 11 registry E404; local tarball installation succeeds,
  but both hosts fail on the missing GC adapter. The command wrapper currently
  returns the decoded module after pass expansion.
- **Deliverables / tasks:** restore an active adapter build and package its
  artifact; connect command optimization to the current pass pipeline; verify
  registry access or publication separately.
- **Required APIs / invariants:** preserve the public JS command API; O4z must
  run the requested passes and write valid output.
- **Dependencies:** current command adapter, package generation and release
  packaging. See [the package record](docs/wiki/tooling/node-package-surface.md).
- **Exit criteria / suggested tests:** install a fresh tarball in a temporary
  project; run an exact constant-fold fixture and the debug artifact under both
  Node and Bun; validate outputs and compare bytes with native Starshine.

### Wago GC helper performance [IR2-WAGO-RUNTIME]

- **Goal / why:** reduce the remaining Wago validation and portfolio cost. The
  corrected bulk host completes O4z in one 176.354 s traced run, while native's
  three-process median is 2.341 s on the same input. Both produce identical bytes.
- **Deliverables / tasks:** profile the bulk path; isolate reference-heavy GC
  field/helper and native-transition cost; measure changes against the exact
  artifact with repeated fresh processes and phase timers.
- **Required APIs / invariants:** preserve GC reference behavior, barriers,
  callback lifetimes and exact roots. Keep validation and the collection guard.
  Do not repeat the fixed cache-start, scalar scratch, import ABI, dead-loop
  mask, callsite lookup or per-byte I/O work.
- **Dependencies:** [Wago PR 948](https://github.com/wago-org/wago/pull/948),
  generic GC helper/backend proof and source-qualified native/JS controls.
- **Exit criteria / suggested tests:** lower whole-command and relevant phase
  time; stress collection/re-entry; validate and byte-compare outputs; retain
  the semantic and allocation checks. Package comparisons are complete for
  published `starshine` 0.2.0 and locally packed 0.2.2 under Node and Bun.
  [Completed record](docs/wiki/tooling/tracing-playbook.md#october-11-2026-bulk-host-and-wago-fixes).


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
  The October 19 portable v133 lane also leaves 3,844 raw-larger cases and
  +2,768 total raw bytes, despite 29,981 canonical bytes saved. Reduce the
  writer losses and classify the unsaved differences; the 20 retained
  empty-else samples match baseline bytes. The
  [scoped repair record](docs/wiki/tooling/validation-gates.md#october-19-2026--pass-review-corrections)
  preserves this current encoding work and the separate DAE2 size gaps.
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

### Report-derived optimization extensions [IR2-REPORT-OPT]

- **Goal / why:** evaluate the supplied report without duplicating implemented
  facilities or displacing current v0.1.1 correctness/performance owners.
- **Deliverables / tasks:** the local, untracked 56-task assessment records the
  intake; durable contracts remain in the linked pass dossiers.
  Existing P00–P14 retain time/memory work. Future slices cover exact local
  packing, function/type remapping, callsite/profile costs, feature contracts,
  memory proofs, SIMD/GC/tuple extensions and measured segment/layout work.
  October 16 test-only segment probes find byte wins for equal no-drop passive
  payloads and fixed internal-table images. Production remains open: independent
  `data.drop` states, GC data users, initialization traps, declaration sources,
  runtime segment indices, names and metadata need complete proofs and remaps.
- **APIs / dependencies:** reuse EffectMask, revision-bound analysis, exact
  encoder sizing, current range domains and module-index remappers. Function
  packing retains the existing `IR2-REORDER-REF-FUNC-9160` owner below.
- **Invariants / exit / suggested tests:** reduced red-first trigger, exact
  bytes, effects/traps/state and feature preservation; measured enclosing time,
  allocation/RSS and downstream cost; current verified v133 aggregate signoff.
  Report impact ratings and source opportunities are hypotheses, not wins.

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
- **Measured reopening condition:** the 2026-10-13 private-call frequency
  prototype reduced two large modules by 28–32 KiB, but added approximately
  0.2–0.35 seconds and 11–35 MiB peak RSS. It was withdrawn. A new slice must
  reduce the exact-size/remap cost before preset admission. Preserve import
  lookup order and the indices of exports and every addressable function;
  JavaScript exposes those indices through `Function.name`. Preserve unknown
  name records and annotation multiplicity. See the
  [experiment assessment](docs/wiki/binaryen/passes/reorder-functions/starshine-strategy.md#measured-private-call-experiment).

## Backlog hygiene

- Remove an item when its exit criteria are met; keep durable evidence in the
  relevant wiki dossier and git history, not completion diaries here.
- Keep unresolved release blockers, failures and evidence limits visible.
- New implementation slices need a concrete goal, owner, dependencies, invariants,
  exit criteria and suggested tests. Preserve existing fixes and assertions.
- On new mismatches, save and minimize artifacts, classify with evidence, add a
  failing focused regression, repair the owning layer and update its dossier.
