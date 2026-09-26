---
kind: comparison
status: supported
last_reviewed: 2026-09-26
sources:
  - ./index.md
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
related:
  - ./index.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./parity.md
---

# `simplify-locals` Performance And Artifact Frontiers

> **Comparison baseline — September 26, 2026:** new comparisons use [Binaryen 133](../../release-horizon-and-oracles.md). Historical v131/v132 sources, commands, artifacts and results retain their original versions and do not establish v133 signoff.

## 2026-09-26 shared validation module facts

Five raw SimplifyLocals cleanup paths now use the existing lazy validation module environment instead of reconstructing it for each function. Function parameters, locals and return types are still layered independently. The cache belongs to one function-pass application across a module; existing lower/writeback paths invalidate it when new type-section entries are installed. This follows Binaryen 133's use of a shared module object during its per-function SimplifyLocals traversal.

The [bounded regression](../../../../../src/passes/simplify_locals_module_env_wbtest.mbt) rewrites both i32 and i64 local captures and checks one module environment construction. It failed before reuse with no cached environment, then passed with distinct function types preserved. The earlier full default test run exposed five unrelated existing Heap2Local sentinel-index aborts; their repair and focused evidence are recorded in [the Heap2Local strategy](../heap2local/starshine-hot-ir-strategy.md#september-26-root-index-sentinel-regression).

Three alternating paired samples after one warmup on the 6,211,596-byte fixture reduce full SimplifyLocals pipeline time from `20,408.653ms` to `2,145.008ms` (9.51x) and command time from `21,289.988ms` to `3,031.984ms`. All before/after outputs in this lane are byte-identical. Baseline SHA-256 is `2a1772b917dcd61d58b6949524243dec37903c36f7761d8500cef0850b935552`; updated native SHA-256 is `3063c88915ccf04bdcbc8d85d4b134bc3860f24d3a19775336a411c9de416278`. Artifacts: `.tmp/module-env-paired-large-20260926/`. All 1,251 focused family tests pass, as do `moon info`, formatting and the native release build. The subsequent full default renewal passes `12,451/12,451`, resolving all five earlier Heap2Local aborts; log: `.tmp/module-env-full-tests-20260926.log`. A fresh bracketed v133 sweep measures full SimplifyLocals command `2,919.127ms` versus `1,493.013ms` (1.96x); its HOT-only timers are `92.463ms` versus `1,059.230ms`, so the remaining pipeline overhead must still be counted. The oracle sweep is `.tmp/pass-sweep-v133-module-env-large-20260926/`. No other paired timing movement is claimed as a material gain, and output parity gaps remain open.

The eight affected dedicated aggregates completed another 80,000 v133 comparisons at seed `0x5eed`, using explicit native binaries and eight subprocesses. Normalized/residual/size counts exactly match [the preceding renewal table](../inlining-optimizing/starshine-strategy.md#v133-aggregate-comparison-renewal), with zero validation, property, generator or command failures. All 140 saved residual outputs remain byte-identical to the pre-change compiler. The existing parity gaps and 1,662 no-structure canonical size losses remain open; runtime semantic execution was not enabled. Reports and selected-profile counts: `.tmp/pass-fuzz-<pass>-module-env-v133-10000-20260926/`; replay ledger: `.tmp/module-env-residual-replay-20260926.json`.

## 2026-09-26 raw child continuation reads

The shared raw cleanup now accumulates original sibling reads in reverse order instead of scanning the remaining suffix at every instruction. Flat bodies avoid continuation sets; loops retain self-reads for later iterations. The [four bounded regressions](../../../../../src/passes/simplify_locals_liveout_perf_wbtest.mbt) assert preserved captures, removed dead captures, and one sibling-root traversal. Structured scaling first failed with 8,384 visits for 130 roots.

Three alternating native before/after samples on the 6,211,596-byte artifact reduced full SimplifyLocals pipeline time from `27,115.200ms` to `22,658.906ms` (16.4%) and command time from `28,074.252ms` to `23,681.449ms`. All five canonical variants keep byte-identical output. The small compiler fixture's nested inlining pipeline improves 8.81x. Full measurement provenance, the no-structure seven-sample confirmation, and shared test coverage are recorded in [the inlining strategy](../inlining-optimizing/starshine-strategy.md#september-26-2026-raw-cleanup-suffix-scans).

The remaining roughly 23-second full pipeline cost is outside its short HOT pass timer. Twelve debugger samples found ten in repeated custom-descriptor module scans reached through `Env::with_module`, one in validation, and one in allocation. The repeated construction originates in the skipped-effectful-carrier raw rewrite's function environment. This identifies the next investigation; debugger samples do not establish a speedup. Local evidence: `.tmp/liveout-linear-profile-large.log`.

## 2026-09-25 future-call suffix preflight (Binaryen 133)

The shared HOT scan previously revisited every later root for each void call, searching for effectful value operands allocated before that call. A lazily built suffix minimum now proves when no such earlier operand exists. The index is used only while the function revision is unchanged; mutations fall back to the existing dependency scan. This removes quadratic work from dense unchanged call regions while preserving dependency order. Binaryen 133 uses a [linear execution walker](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/SimplifyLocals.cpp); Starshine retains its extra HOT dependency repair only where the operand ordering requires it. The [whitebox tests](../../../../../src/passes/simplify_locals_wbtest.mbt) cover a dense no-dependency region and an older effectful value nested below a newer call.

On the 189 KB fixture, `simplify-locals-nonesting` fell from `54.111ms` to `2.421ms` pass-local (`22.4x` faster), versus verified Binaryen 133 at `1.786ms`. Its raw output hash is unchanged: `cc12ddcada04bd3d30196c72e25e10ab9cc7059e0ffe963f23a0dc673fca2bde`. All eight canonical/alias names were swept; the other canonical medians are full `0.486ms`, no-tee `0.908ms`, no-structure `0.384ms`, and no-tee/no-structure `0.178ms`. Every available small baseline and all five large canonical outputs remain byte-identical.

The 6.2 MB sweep still has substantial command overhead: full SimplifyLocals is `26,003ms` command / `104.658ms` pass-local, no-nesting is `4,277ms` / `620.267ms`, and no-tee is `3,362ms` / `898.619ms`. This preflight does not close the raw-dispatch, lift/lower, or output-size gaps. Evidence is local at `.tmp/pass-sweep-v133-simplify-locals-suffix-{small,variants,large}-20260925/`.

All five aggregate GenValid lanes compared `10000/10000` with verified v133 and the prebuilt native Starshine. Full/no-nesting/no-tee/no-structure/no-tee-no-structure had `380/5026/0/0/0` normalized matches and `9620/4974/10000/10000/10000` residuals respectively, with zero validation, property, generator, or command failures. Agent classification remains open parity gaps for the smaller residuals; smaller size alone is not semantic evidence. No-structure also has `1662` canonically larger residuals, classified as size-losing. These are not green parity lanes. The 335 focused family tests pass. Artifacts are `.tmp/pass-fuzz-<canonical-pass>-suffix-v133-10000/`.

## 2026-09-25 loop-carrier preflight summaries

Two raw SimplifyLocals loop-carrier guards previously searched the same loop body for each preceding initializer. After the first negative query, they now collect ordinary local writes and result-control local writes once per loop body, then query those maps for later initializer candidates. The first query retains the direct scan, avoiding summary work for one-candidate loops. The collector traverses nested blocks, loops, try tables, and if arms with the same coverage as the previous predicates.

The [native white-box benchmark](../../../../../src/passes/simplify_locals_loop_guard_perf_wbtest.mbt) uses 512-instruction loop bodies that write an unrelated local. Parameter-initialized result-loop checks improved from `37.64 → 2.65 µs` at 64 initializers and `74.85 → 3.01 µs` at 128; ordinary initialized-loop checks improved from `29.13 → 1.60 µs` and `58.19 → 1.85 µs`. Two positive focused tests, 130 no-structure tests, and 105 main SimplifyLocals tests pass. These are helper timings; full-pass and Binaryen-v132 effects remain unmeasured.

## 2026-08-28 no-tee direct-pass checkpoint

On the canonical production artifact, `simplify-locals-notee` fell from `15,124.449ms` to `906.936ms` pass-local while Binaryen v131 measured `787.321ms`, reducing the pass ratio from `19.06x` to `1.152x`. The command fell from `17,507.965ms` to `2,980.543ms` versus Binaryen `1,284.329ms`. Exact output remains 4,893,604 bytes, SHA-256 `058f0ee1fe372c253f30b5ab7fc23464ce647caeefc86d87b4c0dc1ac941fe27`.

The dominant repair replaces recursive shared-DAG effect recomputation in the large-local tee/write guard and pending-set summaries with one-visit traversals. Exact large tee/store no-ops also return at the raw SLNT fallback after all raw rewrites, reducing HOT lift from a 567ms baseline to a 217ms median. The pass body is now approximately Binaryen speed; remaining direct-command work is shared lowering, function envelope, batch validation, and command validation/encoding.

The 2026-07-27 v131 renewal is a behavioral, validity, idempotence, and canonical-size closeout. It does not replace the historical large-artifact timing caveat below; renewed wall-time work remains owned by `[WALL]001` and is not a simplify-locals v131 parity blocker.

## 2026-08-16 O4z encoded-size portfolio

The Wasm CLI now treats full O4z output as one candidate rather than an unconditional final choice. At O4z shrink levels it compares the normal encoded module with the original valid Wasm bytes, a conservative level-zero late cleanup result, an original-module `simplify-locals-nostructure` result, and validated final-only structural candidates. The structural lane removes unbranched typed/void wrappers with complete escaping-label rebasing, excludes owner-targeted and stack-polymorphic-unreachable bodies, folds exact sign-extension/boolean/terminal-return and fresh packed-array shells, strips nonsemantic branch-hint metadata, then runs either `ssa-nomerge -> remove-unused-brs -> vacuum` followed by two bounded local-cleanup waves and a cheap precompute/reorder/vacuum finish, or, for small dense-i64 modules, `simplify-locals -> simplify-locals -> coalesce-locals`. Stable ties prefer the normal result. Direct pass behavior and the locked normal schedule are unchanged.

The expensive alternatives are skipped when the normal result is below 10 KiB and already compresses the input by more than four times. The red-first admission regression covers the 837 → 118-byte 1793d family and preserves its 45-second corpus bound. Exact runtime execution found that externally valid level-zero cleanup output trapped startup JSON, made both AssemblyScript binary-tree variants nonterminating at `run(0)`, and later made a 25,572-byte JSON-SIMD continuation nonterminating. Observable AssemblyScript JSON/startup modules now skip the entire late-cleanup branch. Observable `run`/memory modules additionally exclude normal O4z and choose only validated input or original-module SimplifyLocals candidates; minimal/incremental binary trees therefore settle at runtime-safe 3,604/4,115 bytes. On the fixed 766-file cohort the parity-closed result saves 7,373 bytes from the 422,820-byte checkpoint and emits 415,447 bytes versus Binaryen at 415,485, a 38-byte / 0.009% aggregate win. Seventy-eight final6 outputs shrink and none grow. Scalar f32/f64 select 3,048/3,100-byte candidates, scalar i64 reaches 5,820, JSON selects runtime-safe 23,408/25,574, startup JSON remains 22,340, and the four embenchen modules reach 23,690/24,082/22,493/21,991. The full sweep retains 807/807 valid successful outputs, zero valid-input timeouts or output-validation failures, and the same 35 compatibility failures. Native SHA-256 is `f73de433e82591f26c68fedb77277dd1468aa6a3f5dad2787b3263489ce6fabf`; 1,394 ISA/SIMD calls, all 37 stateful probes, and the fannkuch event/trap/memory oracle pass.

## 2026-08-15 WAGO cleanup-expansion boundaries

The full 1,330-file WAGO O4z audit found two valid inputs that stalled through repeated raw/HOT SimplifyLocals cleanup expansion: `tests/regressions/fuzzcases/1793b.wasm` and `tests/regressions/runtime/core/winch/issue-424666628/commands.0.wasm`. Reduction disproved deferred batch-writeback equality as the cause; the work was repeated simplify-locals scans plus cleanup/lowering growth across O4z rounds.

`run_hot_pipeline_raw_simplify_locals_has_wago_expansion_hazard(...)` now fails closed only for the observed signatures: broad SIMD/global carrier bodies derived from `1793b`, and broad countdown/clamp bodies with repeated local writes derived from the Winch regression. These are bounded representation/performance boundaries, not claims that the source modules are invalid or that broad SimplifyLocals is unsafe. Focused regressions require the no-structure pass to bound both families. Complete O4z now finishes in about 8.9 ms / 250 bytes for `1793b` and 38.1 ms / 252 bytes for the Winch fixture, with externally valid outputs. Across the 842 externally valid WAGO inputs at or below 2 MiB, total Starshine timeouts fell from five to zero. A follow-up experiment admitted universally exact adjacent `local.set X; local.get X -> local.tee X` rewrites before this boundary and reduced several corpus artifacts, but it made the 1793b prefix test exceed its bound; the experiment was removed rather than weakening the fail-closed contract.

## 2026-08-15 initial structural-expansion admission

A second fixed-cohort audit found that the first top-level Flatten slot often creates structured/local traffic that later SimplifyLocals and coalescing spend substantial work undoing. The module-specific O4z roster now omits only that first slot for no-function-import modules unless GC, complex or zero-minimum memory, table-copy, dense integer arithmetic, protected WAGO SIMD, Winch countdown, or other measured lifetime shapes require it. Nested inlining and SGO rosters remain unchanged. A separate first-SSA omission is limited to modules with at least two function imports. AssemblyScript startup keeps the initial slot but skips Flatten per function except for the measured three-`i32.ctz` allocator-search body.

The fixed 766-file cohort saves 5,024 bytes with no per-fixture size regressions. Blake SIMD falls from 24,269 to 23,435 bytes and its serial whole-command median falls from about 2,118 ms to 515 ms; scalar i32 falls from 5,680 to 4,908, scalar i64 from 6,338 to 6,014, ISA control from 2,114 to 1,623, and startup JSON from 22,684 to 22,384. The final 1,330-file sweep retains zero valid-input timeouts or output-validation failures, and both the 1,394-call ISA lane and 37-probe stateful lane remain green.

## 2026-08-15 alternating recurrence stack carrying

Binaryen's remaining ISA SimplifyLocals payoff centered on long repeated recurrences shaped `A = op(A, B); B = op(B, A)`. Starshine now recognizes at least two contiguous pairs whose operations are same-type i32/i64 binaries or pure two-input v128-result SIMD operations. It keeps the current `B` on the operand stack, uses `local.tee` for intermediate assignments, and restores stack neutrality with a final `local.set B`. Operation order, operand order, local assignment timing, and trap order are unchanged; nonmatching or mixed-type sequences remain untouched. This reduces the eight non-reduction ISA SIMD fixtures by 7,080 bytes and scalar `isa_i32`/`isa_i64` by another 708 bytes. Focused tests cover noncommutative SIMD narrowing plus i32 subtraction and i64 xor recurrences.

Runtime differential execution of `embenchen_fannkuch/commands.1.wasm` then exposed two validating lifetime errors. Full SimplifyLocals converted `_memset` loops so a parameter `local.get; i32.const; i32.add/sub; local.set` update moved after an unconditional backedge; nonzero work no longer advanced and `_main` hung. The fail-closed boundary is deliberately limited to same-parameter updates immediately preceding the branch, so local-only loop-carrier and redundant self-tee cleanup remains enabled. A later post-SSA no-structure wave dropped an old stack-pointer `global.get` carried to a final `local.tee; return` across intervening writes to that global; Vacuum had the same unsafe root shape. The shared root-global-snapshot/tee-return guard preserves `stackAlloc(32) == 0`. Focused tests cover the scalar pointer loop, the earlier SIMD countdown loop, safe local-only loops, no-structure global snapshots, and Vacuum's corresponding stack root.

## 2026-08-14 commutative SIMD carrier forwarding

- After dead inlined-local initialization reduced BLAKE3 SIMD O4z to 45,654 bytes, the dominant remaining raw family was 811 stack-adjacent carriers shaped as `producer; local.set X; local.get Y; local.get X; op`, primarily `v128.xor` and `i32x4.add`.
- Full SimplifyLocals now rewrites only those two exact commutative integer-vector operations to `producer; local.tee X; local.get Y; op`. The assignment remains available to later reads, while commutativity makes the stack operand reversal exact. Noncommutative SIMD operations remain unchanged, and focused tests cover nested control plus a later read of the assigned local.
- Complete O4z output initially fell from 45,654 to 44,062 bytes (`-1,592`). A follow-up moved the same exact SIMD rewrites ahead of the generic loop-carried-local fallback, allowing source kernels to shed carriers before inlining; the extracted compression kernel shrinks by 796 bytes and complete O4z reaches 44,017 bytes. The late O4z convergence suffix now runs two `simplify-locals-nostructure -> coalesce-locals-cfg -> reorder-locals -> vacuum` waves after stripping debug metadata. The second wave reaches the measured local-coloring fixed point; CFG per-definition ineffective set/tee cleanup brings validated output to 42,032 SIMD bytes. A subsequent bounded stack-carried local-get rewrite runs before the oversized raw preflight for 6,144..16,384-instruction functions with at most 64 locals: `local.set X` becomes `local.tee X` and the next `local.get X` is removed only when the intervening unstructured sequence typechecks independently from an empty operand stack within a 256-instruction scan. Producer timing, effects, traps, and the assignment remain unchanged. This lowers SIMD to 41,796 bytes while JSON remains 114,460 bytes and SWAR remains 22,214 bytes. Two bounded late `ssa-nomerge` plus local-cleanup waves reach 41,621 SIMD bytes, 114,114 JSON bytes, and 22,163 SWAR bytes. Exact raw/HOT Vacuum recognition of dropped pure `i8x16.shuffle` trees lowers SIMD to 41,109 bytes. Extending the same proven stack-carried-get rewrite to O4z-only small functions after the module falls to at most 128 definitions then reaches 40,903 SIMD bytes and 21,963 SWAR bytes; JSON remains 114,114 bytes because its optimized module stays above that bound. Verified Binaryen v131 emits 39,484 SIMD bytes, leaving 1,419 bytes / 3.6% of P1 SIMD gap.
- Regular GenValid is exact at `10000/10000`. The dedicated `simplify-locals-all` lane retains its known profile behavior: 5,000 exact matches, 1,875 pre-existing `simplify-locals-structure-result` residuals, and 3,125 Binaryen command failures on `simplify-locals-family-coverage`, with zero validation, property, or generator failures.

## 2026-08-13 guarded SIMD rotate scratch elimination

- The as-blake BLAKE3 SIMD audit exposed repeated complementary `i32x4.shr_u` / `i32x4.shl` temporaries joined by `v128.or`. The dominant function retained hundreds of local indices because full SimplifyLocals intentionally fails closed under the historical large-local tee plus memory-write hazard.
- A raw full-pass rewrite now removes only split rotate scratch locals whose shifts are nonzero, below 32, sum to 32, and whose complete local-read inventory is accounted for by recognized rotate patterns. This permits repeated reuse of the same scratch indices across distinct definitions while rejecting any local with an extra observer.
- The rewrite does not remove `simplify_locals_should_skip_large_local_tee_memory_write_hazard`; the TLSF memory-map regression and a later-read negative SIMD regression remain green.
- On the retained 88,394-byte post-DAE SIMD artifact, direct `simplify-locals` now emits 82,999 bytes. In the complete O4z schedule, the original 1,136,839-byte input emits 63,927 bytes instead of 88,366, recovering 24,439 bytes. The output externally validates with `wasm-tools --features all`; verified Binaryen v131 emits 39,484 bytes, so 24,443 bytes of P1 gap remain.
- JSON and SWAR release artifacts remain 114,673 and 22,496 bytes. A focused `simplify-locals-all` 1,000-case probe reports 500 normalized matches, 189 known `simplify-locals-structure-result` residuals that are 2..4 bytes larger, zero validation/property/generator failures, and 311 Binaryen command failures on the deterministic family-coverage leaf. This probe did not expose a new residual family attributable to the SIMD rewrite.

## 2026-08-03 owner-priority, breadth, and scan-cache recovery

- A nested SGO fixture exposed false progress on byte-identical `f32.const nan`: structural float equality treats NaN as unequal to itself. Lowered root forwarding, nop hoisting, and finalization now report explicit mutation facts, and no-local-write functions avoid equality-based local rewrites. The 321-test SGO file completes in normal repository-test time instead of exceeding 1,200 seconds.
- Broad production convergence guards had shadowed older bounded raw owners. Specific multivalue ladders, call-heavy ladders, adjacent local tee/drop builders, structured pure-call tails, stringview trim loops, low-local decision ladders, and branch-dense walkers now run first. Safe deep result-if unread-tee cleanup remains early; generic convergence fallbacks still own unmatched hazardous shapes.
- One shared lowered shape inventory now replaces the duplicate generic/shape scans and records instruction/control counts plus local-write, local-tee, global-state, memory-size, and stack-effect facts. The small-local 6,144-instruction preflight uses that same scan. A proposed post-lift local-get cache and an extra no-root-candidate scan had no measured payoff and were reverted.
- The full-pass 2,048-definition cutoff is removed. Production runtime recovery extended local-alias, call-result, and call-local-tee lifetime protection to full SimplifyLocals, but keeps those broad guards behind specific bounded raw owners. The O4z prefix exposed one additional wrong-code family where an early parameter read was replaced by a later result-if alias; `parameter-result-if-late-alias-lifetime` protects that ownership boundary.
- The default suite is green at `10230/10230`. Four multivalue stress tests plus the synthetic 2,048-function breadth test are explicitly skipped manual lanes under `passes_perf_long`; all five direct index replays are green. Fresh regular GenValid runs for full and no-structure SimplifyLocals each report `10000/10000` normalized matches with zero validation, property, generator, command, or mismatch failures.
- On the 4,977,401-byte canonical production artifact, direct `simplify-locals-nostructure` emits 4,956,239 bytes, a 21,162-byte reduction. The original August 3 measured median was 1.710 seconds, down from 3.792 seconds; the August 4 reconstruction emits byte-identical output and rechecks at a 1.867-second median on the current machine. Full `simplify-locals` emits 4,923,190 bytes (−54,211); the original median was 2.047 seconds and the reconstruction rechecks at 2.093 seconds. Both artifacts validate externally and pass Node/WASI runtime.
- Full O4z on the 13,118,096-byte debug-WASI artifact originally completed in 115.435 seconds and emitted 5,912,452 bytes, improving the prior 129.709-second / 5,993,829-byte result without changing the locked schedule. The August 4 reconstructed source emits a byte-identical 5,912,452-byte artifact that validates externally and passes runtime.

## Scope

- This page keeps the performance-specific simplify-locals facts that are too detailed for the main parity page but too durable to leave only in `agent-todo.md`.
- It covers:
  - how the repo measures simplify-locals runtime
  - which raw skip reasons exist and why
  - which hotspot families have already been retired
  - which artifact frontiers still matter as of 2026-04-15

## Measurement Sources

### Perf Timers

- `src/passes/perf_test.mbt` asserts on:
  - `perf:timer name=pass:simplify-locals`
  - `perf:timer name=detail:simplify-locals:equivalent-cleanup`
  - `perf:timer name=detail:simplify-locals:late-dead-cleanup`
- `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt` keeps the intentionally slower multivalue ladder stress shapes on a separate opt-in command lane.
- Interpretation:
  - the top-level pass timer tells us the lifted pass actually ran
  - the detail timers tell us which late cleanup phases were still exercised
  - a raw-skip family that correctly avoids lift should usually avoid these timers entirely
  - the default `moon test src/passes` loop should stay lean even when one stress family still needs a larger synthetic witness

### Raw Trace Reasons

- `src/passes/pass_manager_wbtest.mbt`, `src/passes/perf_test.mbt`, and `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt` assert on `pass[simplify-locals]:skip-raw reason=...` trace text.
- These reasons are not cosmetic logging.
- They are the stable contract for the exact artifact families the pass manager is allowed to bypass.

### Artifact Replay

- The canonical large-artifact comparison remains the self-opt compare lane on `tests/node/dist/starshine-debug-wasi.wasm`.
- That lane is the only place where:
  - wide artifact parity
  - real skip distribution
  - real runtime concentration
  can all be seen together.
- The 2026-06-04 O4z audit closeout did not refresh a successful large-artifact timing lane. In this worktree the checked-in debug artifact was absent; a locally rebuilt debug artifact validated, but direct `self-optimize-compare --simplify-locals` hit Starshine's `skip-large-module reason=large-module-simplify-locals-noop funcs=6874` path and then the compare helper failed to parse pass timing for `skip-large-module`. Treat that as a harness/artifact/raw-gate caveat, not a semantic mismatch. Keep renewed artifact timing under `[WALL]001` unless new evidence pins the cost to `simplify-locals` itself.

### Backlog Snapshot

- `agent-todo.md` is still the live scratchpad for the newest frontier reductions.
- This page only carries conclusions that were stable enough to survive one session.

## Skip-Reason Taxonomy

### Large Structured Call-Heavy Families

- `giant-structured-call-heavy`
  - very large structured helpers where lift cost dominates and the reduced evidence says the pass is effectively no-op
- `medium-structured-call-heavy`
  - smaller but still expensive structured helpers
- `transformer-structured-call-heavy`
  - transformer-shaped walkers with heavy local churn
- `decode-structured-call-heavy`
  - decode-shaped helpers with repeated structured call traffic
- `branchy-decode-structured-call-heavy`
  - decode helpers where branch fanout makes the hot lift cost even worse
- `dense-structured-call-heavy`
  - dense low-loop helpers with enough call and local churn that raw skip wins
- `branch-dense-structured-call-heavy-noop`
  - branch-dense helpers with many `if`s, low block counts, and enough repeated calls and local reads that lift is mostly wasted work
- `block-rich-structured-call-heavy-noop`
  - block-heavy structured helpers with moderate writes and repeated calls where traced and synthetic evidence say simplify-locals is effectively no-op
- `call-dense-structured-walker-noop`
  - structured walkers dominated by repeated calls and local reads rather than profitable local cleanup
- `validator-structured-call-heavy`
  - validator-shaped loop-heavy structured walkers
  - this family mattered both for performance and correctness because several retained parity fixes were implemented as narrow raw rewrites that run before the skip
- `loop-heavy-structured-call-heavy`
  - compact and medium loop-heavy walkers that are still not good lift candidates
- `parser-structured-call-heavy`
  - parser-shaped structured local churn
- `giant-structured-local-churn`
  - very large helpers dominated more by local traffic than by meaningful simplify-locals wins

### Linear Builder And Churn Families

- `straight-line-builder-churn`
  - straight-line local churn that does not justify lift
- `huge-straight-line-call-builder`
  - even larger builder initializers with enough tee and call traffic that the raw lane should bail immediately

### Specialty Families

- `stringview-trim-loop-churn`
  - dedicated stringview trim family
- `multivalue-call-heavy-ladder`
  - special-case raw gate for i32-pair result ladders
  - this one is not only a performance family; it also marks an explicit semantic boundary because the repo intentionally avoids the broader multivalue tee/sink surface
- `low-local-decision-ladder-noop`
  - low-local decision ladders with many structured comparisons and later calls where raw skip is cheaper than relifting an unchanged helper

## What The Skip Families Are For

- They are not "give up on parity" switches.
- They exist only when the project has evidence that:
  - the function family is effectively a no-op for simplify-locals, or
  - a very narrow raw rewrite plus cheap cleanup captures the meaningful win without paying full lift cost
- If a family still contains real exact-path parity work, the correct fix is usually a narrower rewrite or a better lifted rule, not a broader skip.

## Raw Rewrite Families That Matter To Performance

- `structured-pure-copy-call-tail`
  - narrow raw cleanup of copied locals and later pure tails
- effectful suffix local-get sinking
  - narrow validator-heavy family that now sinks single-use effectful temps through safe pure barriers
- pure suffix local-set sinking
  - copied-local cleanup that avoids waking the full pass for known artifact tails
- adjacent local-tee cleanup
  - cheap exact rewrite for obvious local churn
- straight-line lane-builder rewrite
  - targeted cleanup for builder-shaped local traffic

## Retired Hotspot Families

### Artifact Families Retired For Correctness And Cost

- Old `Func 216`
  - single-use `if (result i32)` call-argument sink family retired in-tree
- `StringView.make_init_no_rc`
  - loop-carried initializer wrong-code family retired
- old `moonbit.malloc` sibling-order drift
  - retired by better nested local-effect collection and leading-path restrictions
- old `Func 41`
  - tee-backed alias drift retired
- old `Func 50` validator-skip temp drift
  - retired by raw validator-skip cleanup that now sinks effectful temps across safe local-copy barriers

### Artifact Families Retired Primarily For Runtime

- `Func 1800`
  - now covered by `huge-straight-line-call-builder`
- `Func 395`, `430`, `818`, `2083`, `2098`
  - now covered by `dense-structured-call-heavy`

## Current Frontier Snapshot

### Dated Status

- The statements in this section are a dated snapshot from 2026-04-15.
- They should be refreshed when the current compare frontier or raw-skip roster moves materially.

### Remaining Exact-Path Frontier

- The old first mismatch was narrowed down far enough that the active frontier is no longer only the old validator raw-skip family.
- `agent-todo.md` records that:
  - the unreduced artifact frontier still references absolute `Func 71` / WAT `$50`
  - the old loop-temp `$273 / $276` drift is gone
  - the old validator condition-temp `$5` drift is gone too
  - the old `$928 -> $549` store shuttle is gone too after the new validator-skip pure-copy cleanup
  - the rebuilt-binary replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2522582` no longer shows the returning-statement `$739 -> $18` copied-local carrier
  - the same replay retires the sibling `$735 -> $24` condition-copy carrier too
  - the first remaining diffs there now start at the nested `$930/$931/$932/$933` branch-carrier and constant-fanout groups
  - the older block-result `local.tee $7` carrier is no longer the first reported diff

### Later Unchanged Exact-Path Drifts

- The newer important finding is that unchanged exact-path functions such as `Func 386` and `Func 399` still differ even when Starshine reports `changed=false`.
- That means the next work bucket is not automatically another raw-skip tweak.
- Some of the remaining work is exact-path canonical-shape parity.

### Remaining Hotspot Cluster

- The generic branchy helper hotspot cluster is no longer only an implicit trace note.
- The repo now carries explicit raw-skip contracts for:
  - `branch-dense-structured-call-heavy-noop`
  - `block-rich-structured-call-heavy-noop`
  - `call-dense-structured-walker-noop`
  - `low-local-decision-ladder-noop`
- That means the next default-lane no-op helper family is pinned in-tree by wbtests and perf witnesses instead of living only as an unnamed artifact hotspot.
- The active cluster still called out in `agent-todo.md` is now led by:
  - `Func 473`
  - `Func 308`
  - `Func 1488`
- These are the functions most likely to determine the next runtime reduction after the already-retired builder, dense structured helper, and newer helper-ladder no-op families.

## Current Runtime Snapshot

- `agent-todo.md` records a traced native checkpoint of `pass:simplify-locals total_us=2278863`.
- The same dated snapshot records a self-opt compare checkpoint where Starshine was still far slower than Binaryen on the large artifact.
- The latest direct native-binary sample on 2026-04-14 is:
  - `.tmp/self-opt-sl-current-2026-04-14`
  - Starshine `5316.608ms` total / `2190.921ms` in-pass
  - Binaryen `519.714ms` total / `264.709ms` in-pass
  - `starshinePassSkippedRaw=true`
  - `normalizedWatEqual=true`
  - `canonicalFuncPrettyEqual=true`
  - but `wasmEqual=false` and `normalizedWatTextEqual=false`
- So the current keep-state has closed the canonical per-function artifact mismatch on the checked-in debug artifact, but it is still far over the project runtime budget and still not byte/text identical to Binaryen.
- The latest dated sample on 2026-04-10 is still useful as historical progression data:
  - earlier same-day replay: Starshine `6069.134ms` total / `2733.866ms` in-pass, Binaryen `645.476ms` / `307.434ms`
  - latest replay after the pure-copy cleanup: Starshine `5484.740ms` total / `2394.874ms` in-pass, Binaryen `575.087ms` / `287.154ms`
  - latest replay after the rebuilt-binary returning-condition copy fix: Starshine `5618.329ms` total / `2572.867ms` in-pass, Binaryen `608.776ms` / `289.612ms`
  - latest replay after the clean native rebuild and the reduced dupable-fanout batch cleanup: Starshine `5122.776ms` total / `2333.173ms` in-pass, Binaryen `532.565ms` / `265.177ms`
- The new validator-heavy recursive pure-call-tail fix broadens the skip-lane work:
  - the reduced heavy regression is green and fuzz-clean at `2000/2000`
  - the earlier `5957`-case `moon run` launcher failure is now historical noise, not the current state
  - the same family now has a clean long lane: `.tmp/pass-fuzz-sl-validator-call-tail-gated-10k` finished at `10000/10000` normalized matches with `0` mismatches in `575.34s`
- The 2026-04-10 follow-up performance containment step narrowed that cost without changing the known frontier:
  - the recursive validator-skip pure-call-tail fixpoint now checks a cheap nested candidate scan before rerunning another full rewrite pass
  - `.tmp/pass-fuzz-sl-validator-call-tail-gated` stayed green at `2000/2000` normalized matches with `0` mismatches
  - the same gated 2k lane took `144.79s` wall clock on the local machine
  - the later pure-suffix containment step applies the same idea to the recursive pure-suffix fixpoint; `.tmp/pass-fuzz-sl-pure-suffix-gated-2k` stayed green at `2000/2000` in `147.61s`
  - the binary-backed long lane for that current keep-state, `.tmp/pass-fuzz-sl-pure-suffix-gated-10k-binary`, stayed green at `10000/10000` in `452.56s`
  - do not read the `452.56s` binary-backed number as a pure pass speedup over the earlier `575.34s` `moon run` lane; it also removes launcher overhead
  - the durable claim is only that the current keep-state is parity-clean on long lanes and that long compare-pass signoff should prefer a fixed native binary when the goal is to measure pass work instead of `moon run`
  - the newer returning-condition copy fix is also long-lane clean on a rebuilt binary: `.tmp/pass-fuzz-sl-next-if-condition-10k` finished at `10000/10000` normalized matches with `0` mismatches in `435.77s`
  - the dupable-fanout batch cleanup is also long-lane clean on the rebuilt binary: `.tmp/pass-fuzz-sl-fanout-batch-10k-clean` finished at `10000/10000` normalized matches with `0` mismatches in `432.24s`
  - the newer terminal-value pure-suffix cleanup is also long-lane clean on the rebuilt binary: `.tmp/pass-fuzz-sl-terminal-value-10k` finished at `10000/10000` normalized matches with `0` mismatches in `423.58s`
- The same 2026-04-10 follow-up also reinforced one process rule:
  - when native artifact timing is the thing being measured, force a clean native rebuild if the replay output looks unchanged in a suspicious way
  - the incremental native build produced a replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2832774` that kept the old timing envelope and old frontier text
  - the forced clean rebuild moved the timing snapshot materially, so `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3176570` is the authoritative replay for this checkpoint
- The newer returning dense fanout fix changed the interpretation of the remaining cost:
  - `.tmp/pass-fuzz-sl-returning-const-fanout-2k` is green at `2000/2000` in `105.16s`
  - `.tmp/pass-fuzz-sl-returning-const-fanout-10k` is green at `10000/10000` in `478.26s`
  - `_build/native/release/build/cmd/cmd.exe --simplify-locals --print-func 71 ...` now shows the in-memory `Func 71` tree without the old `$930..$934` carriers or the `$540` / `$557` dense const webs
  - but the authoritative replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1018195` is still red and slower than Binaryen: Starshine `6454.014ms` total / `2883.642ms` in-pass versus Binaryen `688.875ms` / `326.287ms`
  - so the remaining budget problem is now tied to the encoded-output / Binaryen-reparse frontier, not to the newly-fixed in-memory raw reducer
- The terminal-value follow-up on the same day improved the runtime envelope again without retiring the encoded frontier:
  - the new whitebox terminal-value regressions are green and the direct short lane `.tmp/pass-fuzz-sl-terminal-value-2k` is green at `2000/2000` in `94.88s`
  - the authoritative latest replay is now `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3772265`
  - that replay is still red on the same first `Func 71` line-`4860` `$930` carrier, but the timings improved materially versus the immediately preceding replay `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2841891`
  - previous replay: Starshine `8285.709ms` total / `3432.549ms` in-pass, Binaryen `937.833ms` / `466.100ms`
  - latest replay: Starshine `6455.017ms` total / `2593.016ms` in-pass, Binaryen `582.593ms` / `294.366ms`
  - the durable interpretation is that the narrower terminal-value rewrite removed real validator-heavy pass work, but it did not retire the encoded-output parity family that still dominates the first visible mismatch
- The later sentinel-and-branch follow-up changed the envelope again:
  - the Binaryen-sentinel alignment for terminal dupable tails stayed clean on `.tmp/pass-fuzz-sl-terminal-sentinel-2k` and `.tmp/pass-fuzz-sl-terminal-sentinel-10k`, with the long lane finishing at `10000/10000` in `467.03s`
  - the branch-terminated carrier guard stayed clean on `.tmp/pass-fuzz-sl-branch-terminated-carrier-2k` and `.tmp/pass-fuzz-sl-branch-terminated-carrier-10k`, with the long lane finishing at `10000/10000` in `404.01s`
  - the authoritative current replay is now `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3936664`
  - that replay is still red on the same remaining `Func 71` subgroup, now visible at line `5313`, where Binaryen still has `nop` and Starshine still has `local.set $930`
  - but the timings improved materially versus the immediately previous replay `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2445261`
  - previous replay: Starshine `6558.878ms` total / `2761.565ms` in-pass, Binaryen `677.653ms` / `326.029ms`
  - latest replay: Starshine `5556.185ms` total / `2380.989ms` in-pass, Binaryen `552.845ms` / `269.518ms`
  - the durable interpretation is that the newer reduced proofs and guards are cutting real validator-skip work on the artifact, but the surviving `$62 -> $930 -> $38` branch carrier still keeps parity red
- Treat those numbers as evidence of direction, not as eternal constants.
- The durable conclusion is:
  - the pass has improved significantly
  - recent validator raw-skip parity fixes keep moving the frontier, but the debug artifact is still far over budget
  - it is still not within the desired steady-state budget on the debug artifact

## 2026-09-25 child-use threshold scan

`simplify_locals_child_use_count_capped_at_two` stops after the second live use. All four call sites only compare the result with one, so later uses cannot change their decisions. The native-release helper benchmark in `src/passes/simplify_locals_use_count_perf_wbtest.mbt` measured **3.95 µs → 22.24 ns** with 1,024 trailing live nodes and **15.69 µs → 22.48 ns** with 4,096. The focused SimplifyLocals tests and zero/one/multiple-use check pass. This isolates an early shared child; full-pass impact remains unmeasured.

## Project Performance Rule

- Per `AGENTS.md`, parity bugs are primary and performance work is secondary.
- The performance target remains:
  - under one second wall time where possible, or
  - at least half of Binaryen wall time where possible
- A performance shortcut that introduces a Binaryen parity regression is not a valid simplify-locals win.

## Maintenance Rule

- When a new skip family is added, record:
  - the helper that implements it
  - the trace reason string
  - the owning perf or whitebox test
  - whether it is a pure skip or a narrow raw rewrite plus skip
- When a hotspot is retired, remove it from `agent-todo.md` and fold only the durable result into this page.
