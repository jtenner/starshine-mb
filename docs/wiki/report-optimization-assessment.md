---
kind: concept
status: working
last_reviewed: 2026-10-16
sources:
  - raw/2026-10-14-starshine-optimization-report.md
  - ../../agent-todo.md
  - ../../src/passes/optimize.mbt
  - ../../src/ir/effects.mbt
  - ../../src/binary/encoded_size.mbt
related:
  - tooling/tracing-playbook.md
  - tooling/validation-gates.md
  - tooling/pass-fuzz-compare.md
  - binaryen/release-horizon-and-oracles.md
---

# Optimization report assessment and task map

The supplied [Starshine WebAssembly Optimization Research Report](raw/2026-10-14-starshine-optimization-report.md)
contains useful experiments. It states that its source audit is incomplete.
Its impact ratings are estimates. They do not establish missing implementations,
defects, or performance gains.

This assessment maps its suggestions to selected current source and the existing
[active backlog](../../agent-todo.md). The source baseline is
`a61c3e418f43a469b480febc4ad590310c1451a1`. Existing command and documentation
worktree changes were also checked for integration constraints and retained.
This is not an exhaustive review of every pass. The initial assessment made no
performance measurements or transform changes. Execution now includes confirmed
Heap2Local and tuple repairs, regression coverage, and bounded cost experiments.
The table below retains the original task scope; it does not claim completion.

## Execution status


Frozen campaign native build `5d8ea74e` passes all 14,300 WasmGC tests and 58,840
independent runtime comparisons, plus GC CLI argument checks. It includes the
carried-read tuple repair, bounded store admission, shared statement type seeds,
lazy DAE boundary graphs, and command candidate proof reuse. Runtime checks
cover host effects, host exceptions, Wasm traps, exact values and public
signatures. The expanded GC lane uses Node 26 because Binaryen 133 emits
nullable exact types which Node 24 cannot execute.

Paired native measurements preserve all 32 fixture output hashes. The
1,000-function DAE command median improves 437.241 to 30.071 ms; full O4z
with 2 MiB data and 1,000 mixed functions improves 1814.577 to 635.642 ms.
All seven pairs improve for each of these fixtures. Other controls are mixed;
no material peak-RSS gain is established. The executable grows 4,664 bytes.
[Raw measurements and limits](tooling/tracing-playbook.md#october-15-shared-batch-and-statement-work)
retain adverse results. Fresh 10,000-case changed-pass comparisons have started
against verified Binaryen 133. Heap2Local completes all 10,000 cases with
matching runtime results, deterministic bytes and valid output; there are no
blocked executions or tool/property failures. All raw/canonical outputs are
smaller, with source/replay limits in the
[Heap2Local evidence](binaryen/passes/heap2local/fuzzing.md#october-15-shared-work-build-renewal).
TupleOptimization also completes 10,000 matching runtime cases, with no
blocks or validation/property/tool failures; its second-pass semantic,
determinism and codec checks pass. The ordinary generated bodies now return
both lanes and execute. There are 2,225 normalized matches and 7,775 reviewed-
family structural differences, with no canonical size loss.
[Coverage and limits](binaryen/passes/tuple-optimization/fuzzing.md#october-15-callable-aggregate-renewal).
Final native SimplifyLocals and SimplifyLocalsNoStructure campaigns each
complete 10,000 semantic comparisons with all available runtime observations,
determinism checks, and codec checks matching. Plain SimplifyLocals has 9,620
smaller and 380 equal raw and canonical outputs. NoStructure is smaller in all
10,000 cases. Its former 1,662 size-losing `tee-control` cases now remove the
dead carrier across inert control while preserving effects, traps, and needed
later reads. Raw totals are 2,148,567 Starshine bytes against 2,318,603
Binaryen bytes; canonical totals are 2,163,592 against 2,316,920. Validation,
property, generator, and command failures are zero in both lanes. A focused
correction also removes WasmGC stack overflow on depth-128 void blocks. Added
coverage checks iterative thresholds, block and function label depths, invalid
labels, live stack prefixes, sibling and conditional exits, deep changed and
unchanged pass paths, and change accumulation across command segments. The
iterative unwind omits an unused per-depth integer allocation. Four release-
command replays validate. The completed source reviews find no confirmed defect
in the selected earlier deltas. Claude's later restricted review completed
after the usage reset and inspected every scoped file. It found no high-
severity defect. Its confirmed evidence and coverage gaps and unverified risks
now have direct fixes, bounded evidence, or explicit open scope. A final delta
review remains required. These checks do not close the full report backlog or
establish a general memory gain.

The independent no-structure review inspects all 20 retained bundles and finds
no confirmed semantic or validation defect. Four retained exportless modules
also pass bounded replay. The lane still has 9,511 suppressed shapes, 44
equal-size structural differences, and one extra memory-capture operation, so
this review does not close those coverage and output-shape gaps.

The frozen current-work campaign also completes both inlining modes. Plain and
optimizing inlining each compare 10,000/10,000 exact normalized outputs against
Binaryen 133. All 20,000 node-v2 observations, determinism checks, and codec
checks match without blocked cases or failures. Raw and canonical sizes are
equal in every case. This closes aggregate parity for the frozen inlining
source identity; it does not establish a compiler-time or memory gain.

ReorderLocals also completes 10,000 cases with no blocked observation or
failure. Starshine removes a retained `nop` in 1,019 cases and a branch-free
single-execution loop in 985 cases. All 20 retained artifacts belong to those
two reviewed families. Canonical output is smaller by 3,974 bytes in aggregate
and never larger. Raw output preserves names at an 84,070-byte cost; 945
legacy-EH cases retain an equivalent function type for another 2,835 bytes.
That type duplication remains an open raw representation parity gap.

ReorderGlobals completes 10,000 cases with matching runtime observations,
determinism, codec checks, and valid output. Its 7,010 exact normalized cases
cover every non-import leaf. The other 2,990 cases are exactly the documented
stable-import contract: Binaryen moves hot imported global 128 to index 0,
while Starshine preserves host-observable import getter order. The 1,161
imported-global outputs cost one canonical byte each. The 1,829 module-code
outputs have equal canonical size. This is a measured correctness tradeoff,
not a size win; no retained artifact has a second diff family.

Directize completes 10,000 cases with matching runtime observations,
determinism, codec checks, and valid output. Its 9,441 structural differences
are canonically smaller by 10,696 bytes in aggregate; every retained WAT diff
only omits one or two empty-body `nop` instructions. This is a pass-independent
canonical encoding win. The other 559 cases are exact normalized matches.

OptimizeCasts completes 10,000 exact normalized comparisons. Raw and canonical
sizes are equal in every case, and all runtime observations, determinism checks,
codec checks, and validations pass without blocks or tool failures. This closes
the frozen source identity's behavior and output-shape lane; it makes no speed
or memory claim.

The frozen HSO aggregate exposed a generator coverage defect: custom
descriptors and invalid active segments leaked into ordinary leaves, blocking
all runtime observations. The repaired generator confines descriptors to the
descriptor leaf and emits no unrelated active element or data segments.
Current optimizer `8438fdd8` and generator `4c85b7ec` complete a new 10,000-case
Binaryen 133 aggregate with explicit custom-descriptor and shared-GC flags. All
10,000 Node-v2 observations are checked and three-way equal. Determinism and
codec are 10,000/10,000. The lane has 2,155 exact plus 7,845 documented
cleanup-normalized matches, zero residuals or failures, and 15,762 fewer
canonical Starshine bytes in aggregate.

Direct DAE completes matching 10,000-case open- and closed-world lanes. Each
has 3,750 exact cases and 6,250 canonically smaller cases, for a 20,000-byte
aggregate reduction. The 1,250 argument/return refinement cases are
Binaryen-only runtime discrepancies; Starshine matches the original. The other
5,000 cases are established stronger-cleanup families. DAEOptimizing also has
matching open/closed results: 5,153 exact, 1,212 cleanup-normalized, and 3,635
retained established cleanup differences. Starshine is smaller in all 4,847
non-exact cases, by 42,132 canonical bytes. All 40,000 runtime observations,
determinism checks, codec checks, and validations pass without blocks or tool
failures.

Independent review of the completed frozen MemoryPacking, Precompute and
OptimizeCasts lanes finds no confirmed Starshine defect. Review-only export
copies preserve all non-export sections and execute 492 calls. Original and
Starshine match expected values, traps, memory and globals. Nine memory64
copies prove that Starshine preserves the source `memory.init` full-range
trap-before-write contract where Binaryen 133 writes one leading byte before a
later trap. A focused profitable-split regression locks that ordering. The
1,733 blocked campaign observations remain unverified, and the export copies do
not replace the original harness results.

The review also confirms that all 11 fixed `precompute-all` generator leaves
had no export or start function. The current generator now exports bounded
targets, records the seven local-facts values in a visible checksum, exports
effect-boundary state, and calls the GC atomic body through a no-argument Wasm
wrapper. NaN-bit probes and negative or about 171 MiB GC allocations remain
compile-only. Five tests pass. Current native generator `4c85b7ec` and optimizer
`8438fdd8` complete all 22 explicit leaf/pass cases against Binaryen 133. All
22 node-v2 observations match; the two GC atomic leaves use the required
explicit shared-GC flag. Every output validates and passes determinism and codec
checks. Twelve outputs are exact. Ten retain output-shape differences: eight
are smaller and two are larger, with a 23-byte aggregate canonical win and no
observed semantic mismatch. The later current-source aggregates below replace
this leaf smoke for broad execution evidence.

The preceding source checkpoint passes `moon info` with 0 errors and all
14,328 default tests. The full WasmGC CI-profile gate separately passes 14,324
target tests and 100,750 configured fuzz attempts across 14 suites. The later
Precompute observability change passes its five focused generator tests;
current native release binaries have optimizer SHA256
`fbfc16a56d71e191eb9a08d6509c681c3b70664128c8905a4b460cdee919c030`
and generator SHA256
`3dfffa7e563132bec9e379172f1c3a2f411acb488aa3301f24a2d755cef9b646`.
The current WasmGC command is `85f3c1354ff67dd55d9cfb570438b3783db673a8361297f82786bc8dd531af42`.
The final SimplifyLocals and DAE2 campaigns use these binaries.

The four current-source DAE2 lanes each compare 10,000 cases with both required
cleanup normalizers. Open plain is 2,879 exact / 667 cleanup-normalized / 6,454
residual; closed plain is 0 / 100 / 9,900. Open optimizing is 2,233 / 1,313 /
6,454; closed optimizing is 100 / 0 / 9,900. Every lane has 9,312 matching
node-v2 observations and 688 blocked continuation cases. Validation, property,
generator, command, observed semantic, determinism, and codec failures are
zero. All blocked records belong to the `dae2-continuations` profile and mark
the original runtime as blocked. Open lanes have no canonically larger
Starshine output. Closed plain
retains 706 individual canonical size losses, and closed optimizing retains
2,133. Those cases remain output-quality parity gaps despite smaller aggregate
Starshine totals. The retained sample includes an open indirect-signature gap:
Binaryen rewrites fixed table targets and their `call_indirect` type together,
while Starshine keeps the original family. The October 16 classification below
groups every recorded size loss by profile; direct output inspection still
covers only retained samples. The blocked continuation cases remain
runtime-unverified.

The command byte-reuse review now includes every 28 pass spellings reported by
the current CLI on one valid 41-byte NaN-bearing wasm fixture. Twenty-seven
no-op results are byte-identical to the input. `flatten` is the one active pass
and emits a valid 47-byte changed result, which confirms that accumulated
segment change state prevents stale input-byte reuse. Existing active cleanup
regressions retain coverage for encoding-cleanup candidates; this bounded
survey is not an exhaustive active fixture for every pass.

Eleven native release microbenchmarks now bound four later-review cost risks.
On 128 functions, Precompute vector sizing takes 9.67 ns when shrink is off,
662.65 ns when no vector candidate exists, and 67.32 µs for 128 admitted
candidates including full encoded comparison. SimplifyLocals cleanup takes
10.00 ns for unchanged identity and 603.80 µs for 128 changed numeric-local
candidates. A 128-query SIMD admission batch takes 771.77 ns with one cold
metadata parse and 665.39 ns after caching. A 4,096-root constant-control scan
takes 2.39 µs without a candidate and 2.56 µs with a trailing candidate. The
new structured-tee controls exposed a quadratic inert-prefix scan: observable-
read and dead-carrier fixtures took 24.86 and 28.21 ms before the fix. One
incremental prefix fact reduces them to 298.83 and 289.92 µs, improvements of
83.2x and 97.3x with unchanged final 20,000-case SimplifyLocals results. These
are helper measurements. They do not establish allocation, peak-RSS, artifact-
scale, or whole-command gains.

Final validation after the structured-tee repair and incremental-prefix change
passes `moon info`, `moon fmt`, and all 14,335 default tests. The pinned
Binaryen 133 script-library lane passes 344 tests, with one documented opt-in
Chromium skip. The full WasmGC CI-profile gate passes 14,333 target tests and
all configured fuzz suites, including 86,820 binary round trips, 5,000 valid
module checks, 4,096 command cases, and the invalid-input, WAST, WAT, linking,
metamorphic, and GenValid lanes. README/API synchronization and `git diff
--check` also pass. A read-only Claude delta-review packet contains the exact
files, patch, build identities, campaign results, replay data, and benchmark
logs. Claude could not perform that final review because its session usage
limit was reached. Earlier completed independent reviews retain their stated
scope; the final delta therefore has no completed Claude assessment.

The first observable Precompute aggregate found a concrete output gap rather
than accepting it as representation drift. Plain Precompute retained a constant
`select` inside the new checksum and emitted 80 bytes; Binaryen 133 emitted 75.
A red regression now owns this case. Literal-condition selects enter HOT through
the existing recursive constant-control scan, so unrelated selects retain the
no-candidate fast path. The saved case is now equal at 75 bytes and validates.
The post-fix plain and propagating aggregates each compare 10,000/10,000 cases
against verified Binaryen 133. Plain has 7,369 direct matches, 1,751
cleanup-normalized matches, and 880 retained stronger constant-control folds.
Propagation has 5,543 direct matches, 3,577 cleanup-normalized matches, and the
same 880 folds. All 20,000 Node-v2 observations, determinism checks, and codec
checks match without runtime blocks or failures. Starshine has no larger
output and saves 13,191 and 16,371 canonical bytes respectively. Every retained
residual is the same literal-true checksum `if` removal, saves 13 bytes, and
has an all-equal execution result.

A separate replay-tool repair now accepts the full promised UInt64 root range.
Its three command tests fail before the fix; all 25 focused seed tests and
14,308 full WasmGC tests pass afterward. The exact failed root generates the
original owner input/hash in one slot in the bounded test. Native CLI replay
passes on generator `821975b0`, including 15 validated outputs, exact low-root
manifest/byte agreement and invalid-root rejection before writes. The generator
grows 4,632 bytes; no optimizer timing or memory gain is claimed. The optimizer
campaigns keep their frozen identities; this parser fix does not replace their
evidence. See the
[seed contract](tooling/fuzz-runner.md#full-unsigned-seed-range-october-15-2026).

This file remains untracked at the user's request. Durable repair contracts live
in the existing [Heap2Local](binaryen/passes/heap2local/index.md) and
[TupleOptimization](binaryen/passes/tuple-optimization/index.md) dossiers.

- Shared-lowering native831b053c passes14,288 tests and58,336 runtime
  comparisons. Wide512 command median improves31.839→25.711ms and mixed
  numeric wide51238.156→32.301ms; child peak RSS falls about2MiB and all28
  fixture output hashes agree. The executable grows6,248B. Repeated SL
  mixed1000 controls retain a small adverse cost; full-preset controls are
  also mixed/adverse. The next small-function admission guard is under
  renewal. These bounded results do not establish a general optimizer gain.
- The preceding frozen DAE checkpoint `59c02734` passes all14,279 WasmGC tests and
  54,696 runtime comparisons plus GC CLI arguments. It includes immutable DAE
  discovery-context reuse and empty-worklist guards. The preceding shared
  first-emission checkpoint `58491a9e` passes14,271 tests and52,736 comparisons. It preserves
  every measured fixture byte; paired command results are mixed, so no general
  speed or memory gain follows from the first-emission guard.
- A further bounded DAE repair reuses immutable source contexts in two discovery
  scans and avoids unused graph/snapshot setup for empty roots and result
  worklists. Previously uncovered acceptance/rejection, public signatures,
  exact host-call placement and changed/touched preservation controls pass
  before the cost repair. Independent review exposes a missing-code unwrap;
  that invalid-input regression fails first, then all8 focused checks pass.
  The native baseline adds1,960 independent i32/i64/effect/trap comparisons.
  The full14,279-test gate and native/runtime renewal pass. Seven paired
  1,000-function preset command medians improve1760.135 to1731.859ms; other
  controls are mixed and peak RSS does not improve. See the
  [DAE contract](binaryen/passes/dae-optimizing/starshine-strategy.md#october-15-immutable-sink-discovery-and-empty-worklists).
- The preceding source checkpoint passes all 14,271 WasmGC tests. Native checkpoint `193e58a7`
  passes 52,736 independent runtime comparisons and GC CLI argument checks.
  It includes bulk Tuple publication, data-size counting with UInt64 overflow
  guards, and checked SL plain-type cleanup. Later first-emission lowering
  controls pass the full suite; native/performance renewal is in progress.
- The 1,024-copy loop fixture improves command median 60.307 to 25.767 ms
  and compiler child peak RSS 81,732 to 24,400 KiB, with identical bytes.
  The 2 MiB data/one-function fixture improves 8.120 to 7.317 ms and
  30,584 to 26,900 KiB. Seven alternating pairs, controls, exact hashes,
  raw engine checks and host-noise records are retained. These bounded wins
  do not establish broad runtime or memory gains. The mixed 128-function
  SL fixture regresses 7.179 to 7.558 ms; full O4z remains about 1.75 s
  against Binaryen's different full-preset policy at about 61 ms.
- The following checkpoint records remain historical. Fresh callable Tuple,
  SL and other changed-pass aggregates are still required. The new type
  finalizer does not close old raw losses until exact replay and renewal.
- Correctness first: tasks 49–50 have red-first Heap2Local owner-publication
  and tuple alias-capture repairs. Further reduced tests exposed Heap2Local
  label ownership and array tee effects, SimplifyLocals stale read/write facts,
  overlapping tuple copies, and CoalesceLocals shared-body mutation. The earlier
  `b29aee1d` Heap2Local aggregate completes 10,000 semantic comparisons with no
  empty bodies; 11,568 native runtime checks include unsigned packed reads.
  All 15 ordinary generator hashes and one missing constant-first owner shape
  also have independent expected-value replay.
- Native checkpoint `972c897d` completes both 10,000-case Tuple and
  SimplifyLocals aggregates with no observed semantic differences. Ordinary
  Tuple spill/tee/copy-chain inputs in that campaign have no callable exports;
  their original runtime observations cover instantiation. Separate export-only
  copies execute all 20 retained Tuple bundles. The later generator adds callable
  ordinary lane results after three red-first tests; its fresh aggregate remains
  required. SimplifyLocals has 9,342 raw-smaller, 504 equal and 154 raw-larger
  cases. Those losses total 306 bytes and remain open output-quality gaps.
  Four exact replays identify extra type-section bytes; canonical size alone
  does not close them. Fresh export-only replay of all 20 retained SL bundles
  checks all 91 functions, 451 calls per variant, with no differences.
- Checkpoint `5e20bf86` passes all 14,247 WasmGC tests and 51,728 native
  Tuple/SL, Heap2Local, memory16 and numeric-group comparisons, plus GC CLI argv
  checks. This includes the repair for Claude's confirmed named-unused-local
  loss above index 128 and the callable generator change. Later red-first
  caller fixes cover touched/stack Precompute splats, discarded compiler facts
  in global size decisions, late passive packing after Directize finish, and
  trusted facts at the caught O4z command boundary. Wider tuple tests also
  expose ascending-store copies; a narrow owned/disjoint-local proof removes
  their wrappers. The 37 focused checks pass before a further weighted-lane
  test improvement. The current full suite passes all 14,259 tests; native renewal is pending.
- Batched Tuple control retirement reduces the 128-copy pass median from
  6,024 to 829 microseconds and preserves every fixture byte. Numeric local
  grouping saves 4,000 bytes on 1,000 mixed functions with an observed 1.019 ms
  added quiet command cost. These `972c897d` measurements predate the later
  declaration-only fix. Large data/name and nested-control measurements remain
  required. Independent GPT reviews find no confirmed defect in the later
  tuple/caller deltas; they identify coverage and whole-size-check cost limits.
  Claude completed the later restricted review after its usage reset. The
  confirmed deep-child and memory64-boundary coverage gaps are repaired; its
  remaining cost and scope risks stay explicit pending aggregate renewal and a
  final delta review.
- Frozen OptimizeInstructions completes 10,000 Binaryen 133 comparisons with
  8,623 exact matches and 1,377 reviewed, canonically smaller residuals. The
  residuals are exactly 1,080 established selected-lane tuple cases and 297
  pure constant result-`if` folds, for a 42,727-byte canonical reduction and
  no larger output. Node v2 matches 8,910 cases; all 1,090 runtime blocks are
  descriptor leaves. A separate flag-enabled exact replay executes 12,294
  descriptor calls with no differences. Coalesce completes
  10,000 comparisons; all four distinct start-trap families behind its 1,250
  blocked inputs have independent replay. These are scoped observations.
  The earlier library checkpoint passes 343 Bun tests with one existing
  opt-in Chromium skip.
- Tasks 51–52: bounded effect, trap, payload, nested-operand and memory32/64
  controls cover previously untested areas. These probes found no original
  valid-input production defect. Task 38 separately has a red-first complete
  encoded-cost rollback guard and ordered constant-trap cleanup.
- Implemented bounded slices under validation: task 03 checked DAE2 field
  queries; 09 validator initialization-mask borrowing; 12 leaf/HSO effect queries;
  15 changed-preset devirtualize/inline finish; 17/20 exact local/global costs;
  22 flat inline-fact cache with body identity; 28–29 SIMD feature admission;
  31 exact vector-constant cost; 34 a bounded fallthrough cast proof; 37 late
  profitable segment cleanup; and 53–56 padding, caught rollback, private DFE,
  and exact-arity Directize work.
- Native samples exist for selected fixtures. They identify both improvements
  and added compiler costs; they do not establish a general speed or memory gain.
  The historical Heap2Local aggregate checks 10,000 cases with native build `6184d267`
  and verified Binaryen 133: all semantic observations agree, all outputs validate,
  and no canonical size losses occur. The manifest has 1,758 empty bodies; those
  inputs do not exercise heap transforms. It has 8,242 structural differences, not
  zero parity differences. Independent review of all 20 retained bundles supports four scoped win
  families; the cap does not inspect every output shape. The later native
  checkpoint `a379e1a3` covers the earlier Tuple ordering repairs, but its broader
  tuple fixtures still grow on repeated passes. The next source fix passes
  bounded size/ownership controls; current native fixture measurements are
  recorded above. One pure arithmetic copy reduces again on pass two (102 to 99 bytes);
  that is additional folding, not repeated growth.
- Validator mask borrowing has a completed order-balanced native helper probe:
  first-write medians improve 459.74 to 435.22 ns for 256 entries and 516.61 to
  468.95 ns for 4,096. This does not prove complete validation or memory gains.
  Exact local packing reduces the hot fixture's output. The duplicate candidate
  validation repair preserves bytes and has an observed hot command median of
  43.409 to 40.047 ms over seven pairs, with two slower pairs and no established
  memory gain. Thirty-five selection controls and 15,440 native memory/trap
  checks pass. See the
  [raw-evidence map and limits](tooling/tracing-playbook.md#october-15-report-experiments).

### October 16 remaining-experiment disposition

- **Registry and runtime evidence, tasks 01–02 and 44–48:** the source audit
  confirms 29 hot entries, 45 module entries, two presets, 25 boundary-only names
  and eight removed names, including aliases. Frozen native `af9b6af2` supplies
  1,302 accepted V8/Wasmtime process samples, 140 quiet compiler samples and 62
  validated measured artifacts. All separated timing cells have seven samples.
  Raw samples, hashes, commands, adverse controls and corrected mode-separated
  analysis are retained in `.tmp/report-optimization-20261016-runtime/` and the
  [tracing record](tooling/tracing-playbook.md#october-16-output-runtime-and-bounded-candidate-experiments).
  This binary does not measure the later source changes below. The two Rust
  corpus controls preserve Starshine instruction text; their timings do not
  prove active-transform throughput.
- **Output trade-offs and engine limits:** portable GC input / Starshine /
  Binaryen / Binaryen-after-Starshine sizes are 159 / 124 / 163 / 128 bytes.
  Starshine changes the fixed 300-call Wasmtime median from 17.049 to 7.002 ms,
  but V8 from 0.753 to 0.843 ms. The original Binaryen exact-reference output
  causes 28 preserved feature rejections; the portable replay disables custom
  descriptors, while a separate V8 flag-enabled replay succeeds. Wasmtime also
  rejects legacy EH. The unreduced GC fixture makes Binaryen 133 abort in
  Flatten. TailCall passes bounded value checks in both engines; at greater
  depth it avoids the original stack exhaustion, so resource behavior is not
  identical. These observations do not establish general speed or memory gains.
- **Packing, tasks 18–20:** production ReorderGlobals now combines independent
  name-cost moves, reducing the reduced 130-global fixture from 756 to 754 bytes
  instead of 755. Its extra exact-cost candidate is bounded at 16,384 globals;
  import, initializer, metadata and identity controls remain. The
  [packing fixtures](../../src/passes/index_packing_experiments_wbtest.mbt)
  separately prove an eight-byte function-index saving and two-/four-byte
  private singleton-type savings. Those two are experiments using existing
  remappers, not public pass implementations. Recursive/subtype/descriptor
  graphs and the full metadata contract remain outside their scope. See the
  [global contract](binaryen/passes/reorder-globals/size-model-and-dependency-order.md#october-16-combined-name-cost-candidate)
  and [function boundary](binaryen/passes/reorder-functions/starshine-strategy.md#october-16-bounded-packing-experiment).
- **Coalesce, task 08:** the implemented whole-body set/tee count gate avoids
  unnecessary loop-prefix suffix queries while retaining scans for written
  sources. Four focused tests, 189 Coalesce tests and one dispatcher test pass.
  Native helper means improve 250.81 µs→841.07 ns at 128 immutable copies and
  16.04 ms→6.50 µs at 1,024. Mutable-source ranges overlap. These fixed-order
  helper measurements do not prove enclosing pass, allocation-byte or RSS
  gains; written-source quadratic work remains open. The fresh 10,000-case
  Coalesce aggregate preserves the prior 3,750 exact / 6,250 smaller output
  distribution, with zero validation or observed semantic failure. Native debug
  validation hits the existing non-null GC-array lowering error; native C
  release succeeds. [Evidence and limits](binaryen/passes/coalesce-locals/starshine-strategy.md#october-16-2026-omit-proved-unnecessary-loop-prefix-suffix-queries).
- **DAE2 closed-world losses:** all recorded loss rows group into 706 plain
  cases totaling 706 excess bytes and 2,133 optimizing cases totaling 11,198.
  Retained indirect and call-ref outputs show Binaryen removing unused
  parameters/results where Starshine retains the signature. Agent judgment
  keeps these as size-losing parity gaps, with no measured countervailing
  benefit. Only retained outputs were inspected directly; 688 blocked runtime
  cases per lane remain unverified. This is a classification of existing
  campaigns, not a new run. [Classification](binaryen/passes/dae2/starshine-strategy.md#october-16-2026-classify-retained-closed-world-canonical-size-losses).
- **Inline-policy bridge, tasks 23–24:** function `Never`/`Always` compiler
  facts now feed the existing annotation policy under `HintsOnly` and
  `TrustAssertions`. Eight focused tests and one command test pass, including
  repeated application and replacement of conflicting older recognized
  policies while opaque annotations survive. `Ignore`, `Default` and `Prefer`
  stay inert; hints supply no semantic proof. This is implemented policy
  plumbing, not profile collection, hot/cold profitability or profile-aware
  outlining. [Contract](binary/compiler-facts-v1.md#current-consumers).
- **Duplicate passive data, task 39:** a test-only no-drop candidate shares two
  equal passive payloads without new globals, locals or instructions. Payloads
  of 0, 1, 64 and 128 bytes reduce complete output from 94→92, 96→93,
  223→156 and 353→222 bytes. All 96 bounded copy/bounds observations match.
  A blind merge with independent `data.drop` users validates and saves bytes,
  but four of eight lifetime observations change. GC data users remain outside
  the proof. Production stays deferred until all data-index, metadata and
  lifetime surfaces have complete controls. [Experiment](../../src/passes/passive_data_sharing_experiment_wbtest.mbt).
- **Final table image, task 40:** test-only internal-table candidates merge
  adjacent segments from 84→79 bytes and overwrite debris from 85→79. A
  live `ref.func` needs a declarative segment and still saves two bytes. Naive
  deletion with `elem.drop` or `table.init` is invalid; removing an earlier
  out-of-bounds initializer changes an instantiation trap into success. The
  bounded candidates are profitable, but production stays deferred pending
  complete bounds, declaration, index, name and metadata handling.
  [Experiment](binaryen/passes/remove-unused-module-elements/retention-and-index-rewrites.md#october-16-final-table-image-experiment).

Tasks 25, 32, 41 and 43 have completed manual Wasm candidate probes, with 112
accepted samples and zero failures. They add no optimizer implementation:

| Candidate | Measured disposition |
| --- | --- |
| Repeated region → helper | 129→111 bytes; V8 regresses in all seven pairs. |
| Four scalar loads → SIMD load/extracts | 138→148 bytes; both engines regress in all seven pairs. |
| Hot function late → first | Same 1,003 bytes; no measured startup or execution gain. |
| Fixed scalar fill/copy → bulk memory | 154→101 bytes; both engines improve all seven warm pairs, but Wasmtime function-symbol bytes grow 400→579. |

The memory probes use fixed in-bounds ranges and disjoint copies. They do not
prove general bounds, overlap, wrap or partial-trap safety. General function/type
packing, profile-guided decisions, outlining, SLP and startup layout remain
broader work. Passive-data sharing and final table-image merging now have
bounded test-only evidence; neither has a production transform. Current full-
source validation remains distinct from these bounded experiments. The final
source passes 14,362 default Moon tests. The full WasmGC CI profile passes its
14,360-test lane and every bounded fuzz suite. Native optimizer `2f393f99` and
generator `34a136ac` each complete fresh ReorderGlobals and CoalesceLocals
10,000-case gates against verified Binaryen 133. Validation, generator,
command, determinism, codec, and observed semantic failure counts are zero;
the documented 1,250 Coalesce original-start-trap cases remain runtime-blocked.

Measure three separate results: Starshine command/pass time and memory use;
output Wasm size; output execution and startup cost. A gain in one does not prove
a gain in the others. Complete the current DAE2, DAE2-O, CoalesceLocals and
OptimizeInstructions performance owners before large new compiler projects.

## Existing mechanisms

| Report proposal | Current implementation | Remaining work |
| --- | --- | --- |
| Shared effect and trap model | [EffectMask](../../src/ir/effects.mbt) and [revision-bound analysis cache](../../src/ir/analysis_cache.mbt) | Reuse query scratch; audit coverage and resource precision where a consumer needs it. |
| Encoder-backed size estimation | [encoded_module_sizes](../../src/binary/encoded_size.mbt) includes names, compiler facts and section/body framing | Apply it to more profitability decisions and reduce measured estimator allocation. |
| Local stackification and frequency packing | [SimplifyLocals](../../src/passes/simplify_locals.mbt), [CoalesceLocals](../../src/passes/coalesce_locals.mbt), [ReorderLocals](../../src/passes/reorder_locals.mbt) and late convergence | Prove residual stack patterns; include declaration-group costs in final packing. |
| Table devirtualization | [Directize](../../src/passes/directize.mbt) handles immutable tables, constant/select targets, table64, tail forms and known traps | Flow-sensitive table facts and integration with later inline work. |
| Inlining and outlining | [Inlining](../../src/passes/inlining.mbt) has repeated planning, hints, partial splitting and touched-function cleanup; [pass manager](../../src/passes/pass_manager.mbt) has selected size outlining | Exact callsite cost, revision-scoped planning and measured profile use. |
| Range analysis | [constraint domain](../../src/passes/constraint_domain.mbt), [ConstraintAnalysis](../../src/passes/constraint_analysis.mbt), and OI maximum-bit facts | Expose useful no-wrap proofs to memory folding. |
| Global packing | [ReorderGlobals](../../src/passes/reorder_globals.mbt) uses frequency, ULEB cost and dependency-valid orders | Audit full encoded cost and candidate search before extending it. |
| Multi-value forwarding | [TupleOptimization](../../src/passes/tuple_optimization.mbt) supports spill/copy groups and forwarding | Find and measure residual producer/consumer forms. |
| GC casts, fields and allocation removal | [OptimizeCasts](../../src/passes/optimize_casts.mbt), [Heap2Local](../../src/passes/heap2local.mbt), [HeapStoreOptimization](../../src/passes/heap_store_optimization.mbt), [LocalCSE](../../src/passes/local_cse.mbt) | Extend precise proofs and supported owner/consumer forms. |
| Segment final-state optimization | [MemoryPacking](../../src/passes/memory_packing.mbt) handles overlaps, overwritten bytes, zero splitting, passive users and drop state | Measured merging, safe payload sharing and later cleanup admission. |
| Tail-call formation | [tail_call.mbt](../../src/passes/tail_call.mbt) supports direct/indirect/reference calls and target-feature bans | Policy review and runtime/size measurements. |
| SIMD simplification | [Precompute](../../src/passes/precompute.mbt), [OptimizeInstructions](../../src/passes/optimize_instructions.mbt), and LocalCSE | Additional nonconstant patterns, constant cost selection, and later SLP research. |
| Function/type packing | Names are [boundary-only](../../src/passes/optimize.mbt), not executable pass owners | Implement complete constrained remapping. |

## Initial correctness blocker (historical replay)

The independent Claude Code review identified a Heap2Local producer-order risk.
A native CLI replay confirmed it on the source snapshot recorded below. Two branch-selected
struct allocations write the same owner local. The second constructor reads a
field of the old object. Scalarization writes its shared field local before that
read, so the read observes the new field value.

**Classification (agent judgment): true semantic mismatch.** All three modules
validate independently, but Starshine returns the wrong values:

| Input to exported run | Original | Starshine heap2local | Binaryen 133 heap2local |
| --- | --- | --- | --- |
| 0 | 11 | 200 | 11 |
| 1 | 10 | 100 | 10 |

The trigger is:

```wat
(module
  (type $S (struct (field i32) (field i32)))
  (func (export "run") (param $flag i32) (result i32)
    (local $x (ref null $S))
    (local.set $x
      (if (result (ref $S)) (local.get $flag)
        (then (struct.new $S (i32.const 10) (i32.const 20)))
        (else (struct.new $S (i32.const 11) (i32.const 21)))))
    (local.set $x
      (if (result (ref $S)) (local.get $flag)
        (then (struct.new $S (i32.const 100) (struct.get $S 0 (local.get $x))))
        (else (struct.new $S (i32.const 200) (struct.get $S 0 (local.get $x))))))
    (struct.get $S 1 (local.get $x))))
```

Source owners are `h2l_find_variant_local_candidate`,
`h2l_variant_branch_roots` and `h2l_apply_variant_local_candidate` in
[heap2local.mbt](../../src/passes/heap2local.mbt), especially lines 3114,
3217–3226 and 3362–3447. Preserve the old owner's values until every constructor
operand has been evaluated. Add the failing implementing/dispatcher regression
before repair. The current repair stages every producer's fields before owner
publication; the original replay remains here as evidence of the defect.

Replay used Node `v24.21.0`, wasm-tools `1.251.0`, the native release CLI recorded
below, and the verified oracle `.tmp/v133-signoff-oracles/binaryen-version_133/bin/wasm-opt`
(`wasm-opt version 133 (version_133)`). Oracle SHA256:
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
Heap2Local source SHA256:
`8e576d19b4ea6bbb71bde9d565f476aeb1a4366dd1a343a744dc223e49e2ec26`.
The command flags were `--heap2local` for Starshine and
`--all-features --heap2local` for Binaryen. Each module passed
`wasm-tools validate --features all` and was instantiated separately in Node.
The reduced two-input replay is not broad pass signoff.

## Task list

This is the complete task map from this report and the directly related active
performance work, followed by eight independent-review follow-ups. It does not
replace existing owners. **P0** means current
measurement, correctness, or broad cost work; **P1** means a bounded extension;
**P2** means research or a larger feature. Priority is a judgment, not a measured
gain. Each task needs a reduced trigger and a stated success metric before code
work begins.

### Starshine time and memory

| ID | Priority | Task and source owner | Required result or control |
| --- | --- | --- | --- |
| 01 | P0 | Map the active registry, dispatcher, analyses, invalidation, feature gates and tests; refresh stale status claims. [Registry](../../src/passes/optimize.mbt), [pass tracker](binaryen/passes/tracker.md). | Distinguish active, partial, boundary and removed entries. Preserve versioned historical claims. |
| 02 | P0 | Renew exact-source active pass and full-command baselines. [Tracing playbook](tooling/tracing-playbook.md), backlog P14. | Verified Binaryen 133, source/binary hashes, raw samples, quiet controls and output sizes. No-op input timings do not prove transform speed. |
| 03 | P0 | Reduce remaining DAE2 HOT field-query and result costs. Backlog P03a/P12. | Actual native work/allocation removal; preserve all fields and error boundaries. |
| 04 | P0 | Reduce DAE2 scratch, temporary buffers and object churn. Backlog P03b. | Lower enclosing cost; measure retained capacity and RSS as well as allocation calls. |
| 05 | P0 | Reduce repeated and quadratic DAE2 reaching-definition/source-order work. Backlog P03c. | Exact ordered sources, mutation epochs, sparse/dense controls and complete fallback. |
| 06 | P0 | Reduce measured lift, CFG/dependency construction, lower and capture-repair cost. Backlog P03d/P12. | Complete graph-field and output equivalence; mandatory verification remains. |
| 07 | P0 | Scope optimizing cleanup to changed bodies and reduce repeated suffix/effect scans. Backlog P03e/P05/P08/P10. | Improve DAE2-O, DAE-O, SGO and inline consumers; preserve typed loops, aliases and capture lifetimes. |
| 08 | P0 | Improve CoalesceLocals interference, hazard queries and coloring. Backlog P04/P12. | Large active gains with bounded sparse/dense storage and no tiny-control regression. Preserve exception edges and copy weights. |
| 09 | P0 | Reduce validator state copying, high-depth collision work and private result packaging. Backlog P11. | Exact validation, diagnostic order and ownership; no removed checks. |
| 10 | P0 | Reduce remaining measured decode/encode result packaging and materialization. Backlog P13. | Keep LEB bounds, errors, offsets, padded encodings, exact NaN bits and public Result contracts. |
| 11 | P0 | Reduce exact-size estimator scratch and repeated encoding. [encoded_size.mbt](../../src/binary/encoded_size.mbt), backlog P06. | Compare a shared counting sink/body-cost API with actual encoding, including strings, names and framing. Avoid a second opcode-size implementation. |
| 12 | P0 | Reuse effect-query masks; extend resource precision only for measured consumers. [effects_for_node](../../src/ir/effects.mbt), [analysis_cache.mbt](../../src/ir/analysis_cache.mbt). | The current single-node query allocates a full-arena array and bitset. Test revisions, shared DAGs, resource conflicts, atomics and retained scratch. |
| 13 | P1 | Repeat the portable native compiler-flag experiment. Backlog P06 and [O3 evidence](tooling/tracing-playbook.md#october-4-2026-bounded-native-o3-build-experiment). | Include executable size and RSS; preserve wrap/alias contracts and compiler portability. Existing O3 evidence does not justify a default change. |

### Wasm output and bounded transforms

| ID | Priority | Task and source owner | Required result or control |
| --- | --- | --- | --- |
| 14 | P0 | Find reduced missed constant, peephole, DCE, CSE, LICM and branch patterns; close retained output-quality gaps. [Current owners](../../agent-todo.md). | Exact opcode/IR assertions, effect/trap controls, NaN/signed-zero cases and measured canonical bytes. Generic pattern ideas are not confirmed gaps. |
| 15 | P1 | Test a bounded devirtualize → inline → simplify cycle and revision-based scheduling. [optimize.mbt](../../src/passes/optimize.mbt), [cmd.mbt](../../src/cmd/cmd.mbt). | Library full preset places Directize after inlining. The current command has a conditional post-fixed-point inline finish. Audit both paths before adding rounds; preserve the intentionally short public presets. |
| 16 | P1 | Probe residual local temporary removal and late stackification. Existing [IR2-LOCAL-TEMP-9162](../../agent-todo.md#stackir-equivalent-local-temporary-elimination-ir2-local-temp-9162), P04/P05. | Intervening independent stack-value fixtures; preserve noncommutative operands, traps and lifetime rules. Measure stack depth and downstream compile/runtime. |
| 17 | P1 | Make final local packing choose exact encoded cost. [reorder_locals.mbt](../../src/passes/reorder_locals.mbt), [guarded grouping](../../src/passes/optimize_instructions_cleanup.mbt). | Count declaration runs, references and framing; fixed parameters, names, mixed types, 127/128 and 16383/16384 boundaries. Use bounded candidate search and retain explicit Binaryen-compatible ordering. |
| 18 | P1 | Implement function-index packing. [Existing future owner](../../agent-todo.md#future-reorderfunctions-usage-accounting-ir2-reorder-ref-func-9160). | Fixed import prefix; count calls and ref.func in bodies/initializers/elements. Remap code, start, exports, names, facts and metadata. Measure entire module. |
| 19 | P1 | Implement constrained type-index packing. [ReorderTypes dossier](binaryen/passes/reorder-types/index.md). | Preserve recursive groups, subtype/descriptor order, shared/public types and all references; include signed heap/block and unsigned type-index widths. |
| 20 | P1 | Audit and extend exact-cost global packing. [reorder_globals.mbt](../../src/passes/reorder_globals.mbt). | Prove a missed profitable order before changing the existing ULEB/dependency search; account for names and section framing. |
| 21 | P1 | Add post-simplification callsite cost to inline profitability. [inlining.mbt](../../src/passes/inlining.mbt). | Current combined-size ceiling estimates 2.5 bytes per expression. Test constant-exposure wins and growth controls; measure scratch-clone time/memory as well as output. Keep compatibility policy available. |
| 22 | P0 | Reuse inline body/signature facts across touched rounds. Backlog P09. | Reconsider changed callees; preserve recursion, partial splitting, named-main behavior, all references and metadata. |
| 23 | P1 | Define an optional measured profile input and metadata/remapping contract. [Compilation-hint boundary](wasm-compilation-hints-boundary.md). | Stale-profile rejection, stable identity and missing-data fallback. Hints are not semantic proof. |
| 24 | P1 | Make existing partial inlining and outlining profile-aware. [inlining.mbt](../../src/passes/inlining.mbt), [pass_manager.mbt](../../src/passes/pass_manager.mbt). | Compare hot/cold guards, cleanup exposure, call overhead, startup and bytes against current static policies. Preserve no-inline and EH/capture rules. |
| 25 | P2 | Test bounded general repeated-region outlining. [Existing selected outlining](../../src/passes/pass_manager.mbt). | Include helper signatures, locals, calls, index-width growth and downstream cleanup. Reject material hot-runtime/startup losses. |
| 26 | P1 | Extend table/reference target proofs when whole-module immutability is too conservative. [directize.mbt](../../src/passes/directize.mbt). | Writes before/after calls, joins, host reentry and table operations; retain argument order, null/bounds/type traps. Basic immutable-table directization is already present. |
| 27 | P1 | Feed proved unsigned bounds to dynamic memory-offset folding. [ConstraintAnalysis](../../src/passes/constraint_analysis.mbt), [OI](../../src/passes/optimize_instructions.mbt). | No-wrap proof for memory32/64; unknown-base boundary negatives, multi-memory identity and operand effects. Reuse the existing range domain. |
| 28 | P0 | Unify transform target-feature requirements and introductions. [Pipeline facts](../../src/passes/optimize.mbt), [existing feature bans](../../src/passes/merge_similar_functions.mbt). | Cover SIMD/relaxed SIMD, tail calls, memory64, bulk memory, references and GC. Test explicit bans and malformed metadata. |
| 29 | P0 | Complete feature-sensitive 16-byte memory.fill lowering. [OiTinyMemoryFillFact](../../src/passes/optimize_instructions.mbt). | Source documents the missing no-SIMD fallback. Select permitted forms by size policy. Two stores require proof of equivalent bounds, traps and partial writes; retain memory.fill when that proof fails. |
| 30 | P1 | Add reduced nonconstant SIMD peepholes. [OI](../../src/passes/optimize_instructions.mbt), [Precompute](../../src/passes/precompute.mbt). | Shuffle composition, extract/replace, masks, splats and reductions. Keep lane order, effects, float bits and relaxed SIMD semantics. |
| 31 | P1 | Choose vector constants by exact encoded cost. [Precompute](../../src/passes/precompute.mbt). | Compare v128.const with scalar splats; prevent canonicalization reversal/cycles and preserve exact float bits. |
| 32 | P2 | Add adjacent scalar-load recognition, then small-block SLP. Existing range/effect infrastructure. | Prove load bounds/alias safety; add stores only with equivalent trap/mutation behavior. Measure V8 and Wasmtime kernels and compile cost. |
| 33 | P1 | Extend residual multi-value producer/consumer forwarding. [TupleOptimization](../../src/passes/tuple_optimization.mbt). | First prove an existing call/block/loop bridge still uses avoidable locals; retain lane order and effect-bracketed spills. |
| 34 | P1 | Extend dominating GC type/null proof reuse across controls. [OptimizeCasts](../../src/passes/optimize_casts.mbt). | Branch joins/loops, descriptor/exact/shared types and exception timing; measure retained cast/test removal. |
| 35 | P1 | Extend GC field forwarding and alias-aware CSE. [LocalCSE](../../src/passes/local_cse.mbt), [HeapStoreOptimization](../../src/passes/heap_store_optimization.mbt). | Fresh/immutable fields across proved unrelated writes; exact array indices, owner identity and host calls. Bound analysis storage. |
| 36 | P2 | Extend scalar replacement and escape analysis from existing Heap2Local owners. [heap2local.mbt](../../src/passes/heap2local.mbt). | One unsupported consumer/flow family per slice; identity, aliases, bounds, constructor effects, packed fields and shared/atomic behavior. |
| 37 | P1 | Test cheap late segment cleanup after inlining/pruning. [Full scheduler](../../src/passes/optimize.mbt). | Memory packing currently runs early. Require a real newly dead user/data fixture before adding rerun cost. Pack entity indices after pruning/outlining. |
| 38 | P1 | Test adjacent active-data merging and exact split costs. [MemoryPacking](../../src/passes/memory_packing.mbt). | Compare the existing fixed split threshold with real header/offset costs. Start with one defined memory and proved bounds; preserve source order, initialization effects, failed-instantiation state and indices. |
| 39 | P2 | Test duplicate passive-data sharing. [MemoryPacking](../../src/passes/memory_packing.mbt). | Independent data.drop lifetimes and GC data users make blind index substitution invalid. Begin with read-only/no-drop cases; count added state/instructions. |
| 40 | P1 | Test final table-image segment merging and overwrite cleanup. [RUME](../../src/passes/remove_unused_module_elements.mbt), [element cleanup](../../src/passes/optimize_instructions_element_cleanup.mbt). | Internal tables, pure constant initializers and proved bounds first; preserve ref.func declarations, elem.drop lifetimes, table.init and imported-state effects. |
| 41 | P2 | Compare startup-aware function layout with index packing. Future ReorderFunctions owner. | Same functions with changed layout, cold processes and streaming controls; compile, instantiate, first call, bytes and steady state. No gain is yet established. |
| 42 | P1 | Review and measure existing tail-call policy and coverage. [tail_call.mbt](../../src/passes/tail_call.mbt). | Feature bans, handlers, signatures, table64 and recursion across engines. Review resource-exhaustion semantics against the specification and project contract before adding policy changes. |
| 43 | P2 | Recognize scalar copy/fill loops under complete safety proofs. Existing memory/range/effect owners. | Full bounds, address wrap, overlap direction, effect order and partial writes after traps. Begin with fixed in-bounds internal-memory loops. |

### Evidence and signoff

| ID | Priority | Task | Required result |
| --- | --- | --- | --- |
| 44 | P0 | Extend reduced and real-corpus benchmarks across V8 and Wasmtime. [Existing benchmark lanes](tooling/tracing-playbook.md). | Cold compile/instantiate/first call; baseline and warmed execution; raw, compressed and code-section bytes; RSS and allocations. Preserve feature/runtime support limits. |
| 45 | P1 | Run input / Starshine / Binaryen / Binaryen-after-Starshine comparisons. [Comparison harness](tooling/pass-fuzz-compare.md). | Identify missed transforms and downstream cleanup, then classify with semantic and measured evidence. |
| 46 | P1 | Run one-pass ablations, then selected pair/order experiments. Existing scheduler and sweep tools. | Attribute interactions and useful reruns without exhaustive pass-combination search. Include intentionally short presets and full O4z separately. |
| 47 | P0 | Keep raw paired samples, hashes, environment and separate metric limits. [Measurement rules](tooling/tracing-playbook.md). | Wall time, compiler time, allocation, RSS, native code/executable size and output size; uncertainty and adverse controls remain visible. Helper gains do not close full-command goals. |
| 48 | P0 | Sign off each implemented slice with red-first tests and current semantic/parity gates. [Backlog validation matrix](../../agent-todo.md#validation-for-further-candidates). | Bounded implementing/dispatcher tests; valid output; original-vs-optimized effects/state/traps; fresh native binary and verified v133, 10,000-case appropriate GenValid aggregate, up to eight subprocesses. External wasm-smith remains opt-in only when requested. |

### Independent-review follow-ups

At intake, only task 49 had a reproduced wrong result. Execution also confirmed
task 50 and adjacent Tuple effect/publication defects. Tasks 51–52 now have
bounded passing controls without a reproduced original production defect.
Tasks 53–56 have bounded implementations under validation; measured gains and
costs must be stated per fixture, not inferred from the report ratings.

| ID | Priority | Task and source owner | Required result or control |
| --- | --- | --- | --- |
| 49 | P0 | Repair Heap2Local reads of an old owner inside a replacement constructor. [Initial replay above](#initial-correctness-blocker-historical-replay). | Red-first pass/dispatcher regression, both branch values, constructor effect order and full affected GC signoff. The baseline default tests missed this case. |
| 50 | P0 | Probe loop-carried tuple aliases before forwarding them. [TupleOptimization](../../src/passes/tuple_optimization.mbt), alias resolver and result-block groups. | Reproduce a stale alias across producer re-execution. Do not change forwarding until the original-vs-optimized values prove a defect. |
| 51 | P0 | Probe element-segment effects and exact-payload validity contracts. [effects.mbt](../../src/ir/effects.mbt), [hot_verify.mbt](../../src/ir/hot_verify.mbt). | Check array.new_elem/array.init_elem with elem.drop in actual motion consumers. Valid IR flags already preserve scalar memory traps; malformed payloads are rejected by verification. The review did not prove a valid-input trap omission. |
| 52 | P0 | Prove the MemoryPacking operand-extraction fallback is unreachable or preserves remapped data semantics. [MemoryPacking](../../src/passes/memory_packing.mbt), lines 2874–2906. | Nested memory.init operand fixture after splitting/index changes; inspect preflight guarantees before replacing the fallback. No triggering input is confirmed. |
| 53 | P1 | Audit inlining's predicted-count padding, trimming and narrow shape rules. [Inlining](../../src/passes/inlining.mbt), lines 6592–7341. | Measure added unreachable helpers and reproduce each necessary rule against v133; replace stand-ins with general rules only with equivalent semantics and measured size/cost. |
| 54 | P1 | Reduce wasted work on caught-try-table O4z transaction rollback paths. [optimize.mbt](../../src/passes/optimize.mbt), lines 1531–1563. | Scope the artifact-policy condition exactly; preserve pass errors, option semantics and existing correctness guards. Do not widen the rollback or remove transforms. |
| 55 | P1 | Test private-function DFE under host-visible module boundaries. [Preset identity guard](../../src/passes/optimize.mbt), lines 1424–1438. | Prove which identities cannot escape through exports, tables, ref.func, globals or host callbacks before relaxing the whole-module guard. Preserve the intentionally short preset policy. |
| 56 | P1 | Bound Directize argument-suffix search and candidate scans. [directize.mbt](../../src/passes/directize.mbt), lines 714–731. | Current search repeatedly copies/typechecks suffixes. Prove stack/value equivalence before narrowing it; measure one candidate among many dynamic calls, wide arguments and no-candidate controls. |

## Evidence limits and local setup

MoonBit was installed from the [official installer](https://www.moonbitlang.com/download/)
after `mise registry moonbit` showed no registered tool. It is installed at
`/home/dev/.moon`, with links in `/home/dev/.local/bin` for commands that need the
local PATH. Installed versions: Moon `0.1.20261012`, moonc
`v0.10.15+943464bfa`, moonrun `0.1.20261012`. All 17 published binary hashes
passed verification. Dependency update and wasm-gc source checking passed.
The default wasm-gc suite passed 13,962 tests, with zero failures. The native
release CLI built successfully and its help command returned zero. Its build
hash is `cbda52bcfd4fe7fbc5258e3915b871c3794091322c143d5be4c6c869effc161e`.

Two separate GPT source reviews informed this map. Claude Code's authenticated
read-only retry completed with an assessment of all 18 listed snapshot files.
It used the fixed HEAD snapshot and did not inspect unrelated worktree edits.
It had no execution or benchmark evidence and could not inspect dependencies
outside its packet, including the validator, command dispatcher, full HOT
internals and pass-manager helpers. Parent source checks and the reduced
Heap2Local replay supplied the verification above.

Some review statements need narrower scope: type-stable local rewriting is used
by the pass manager; exact sizing already guards OI cleanup; current command
cleanup can inline after the library preset; signature caching already exists
in some inline paths. Invalid-input and guessed shape risks do not establish
defects on valid modules. Do not remove guarded paths based only on this review.

The report's integer-width and memory-safety hypotheses should be checked
against the [binary values specification](https://webassembly.github.io/spec/core/binary/values.html)
and [instruction semantics](https://webassembly.github.io/spec/core/exec/instructions.html).
Use [Binaryen 133](binaryen/release-horizon-and-oracles.md) for new evidence.
Historical v131/v132 results retain their original scope and do not sign off
current sources. The initial assessment established no speedup. Later bounded
measurements above show specific gains and adverse controls; they do not
establish general optimizer speed or close the remaining task scope.
