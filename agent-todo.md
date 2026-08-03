# Agent Tasks

## Scope And Rules

- Keep only active unreleased work, standing regression guards, or explicitly deferred future work. Durable closeout evidence belongs in pass dossiers and `docs/wiki/log.md`, not here.
- Preserve Binaryen v131's locked 56-slot O4z order plus Starshine-only `strip-debug` at slot 57.
- Every v131 compare must use an explicit verified binary. The current local oracle is `.tmp/binaryen-version-131-bin/bin/wasm-opt`, reporting `wasm-opt version 131 (version_131)` with SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.
- Build the native CLI before artifact lanes and use `_build/native/release/build/cmd/cmd.exe`; treat `target/native/...` as stale unless explicitly proven fresh.
- Validation and runtime execution are separate gates. A validating artifact is not signed off until its runtime smoke is green.
- Direct pass behavior comes before scheduler integration; artifact/runtime signoff comes last.
- Moon commands must run serially.

## Current Pipeline Facts

- Public non-O4z presets are intentionally wall-time-first. O1/O2 run `duplicate-function-elimination -> strip-debug`; O3/O4/Os/Oz add only `vacuum -> reorder-locals` between those slots. The CLI accepts literal Binaryen-style `-Os` as `(optimize=2, shrink=1)` and `-Oz` as `(2,2)`.
- O4z remains the full compatibility lane: Binaryen v131's exact 56 top-level slots plus Starshine-only `strip-debug` at slot 57.
- Direct passes remain available, and DAE, optimizing inlining, and SGO retain the full level/feature-aware nested function scheduler. DAE prepends `precompute-propagate`; SGO does not.
- Nested cleanup remains touched-function-scoped. SGO's former 192-local / 1,000-instruction broad filter is removed.
- Large typed-loop modules currently use focused fail-closed owner fallbacks where production smoke exposed path-sensitive gaps: DAE optimizing uses plain DAE at lower levels and a results-only fallback at O3+/Oz, optimizing inlining falls back to plain inlining, SGO no-ops, and flatten/merge-locals no-op in the affected large-module neighborhood. SimplifyLocals, TupleOptimization, DCE, Precompute, CodePushing, CoalesceLocals, CodeFolding, SSA, and OptimizeInstructions retain focused shape or guarded-writeback boundaries for reduced validation and runtime families.
- Optimizer registry/tracker/execution/release-horizon documentation has been reconciled with the live scheduler and registry.

## v0.1.1 Execution Order

1. Complete `[WALL]001` pass-local attribution so every slow-pass item separates optimizer work from the 0.615-second Starshine command floor.
2. Execute `[SIZE]001` together with the overlapping performance items: CoalesceLocals correctness first; SimplifyLocals with `[PERF-SLNS]001`; optimizing inlining with `[PERF-INL-OPT]001`; then DAE with `[PERF-DAE]001` and `[PERF-DAEO]001`.
3. Repair the remaining direct slow passes in descending measured cost: `[PERF-DCE]001`, `[PERF-OPTINST]001`, `[PERF-VACUUM]001`, `[PERF-CODEFOLD]001`, `[PERF-PRECOMPUTE]001`, `[PERF-RUB]001`, and `[PERF-PRECOMPUTE-PROP]001`; bound `[PERF-SGO]001` independently.
4. Run `[JSON-AS]001`, `[TOOL]001`, and `[STRIP-DEBUG]001` final release evidence.
5. Revisit focused startup fallbacks only with smaller regressions and runtime proof.

## v0.1.1 Pipeline Supporting Work

### [O4Z-STARTUP]001 - Preserve and reduce the startup-map regression guards

- Keep `tests/repros/o4z-debug-startup-map-init-repro.wasm` until smaller generated fixtures cover every production family.
- Preserve the focused regressions for startup initializer SimplifyLocals convergence, giant post-inline call builders, oversized lowered preflight, dynamic nonzero-offset stores, typed and untyped loop-carried locals, and typed-loop optimizing fallbacks.
- Recover precision one owner at a time only with source-backed tests plus validation and runtime evidence. Current recovery targets are path-sensitive SimplifyLocals loop reasoning, CoalesceLocals parameter interference, CodePushing local-carrier placement, and typed-loop nested cleanup.
- Do not remove a fail-closed owner fallback merely because a candidate output validates or is smaller.

### [JSON-AS]001 - Repeatable artifact correctness and size signoff

- Add a documented opt-in clone/build/replay task under existing Bun tooling; do not add shell scripts under `scripts/`.
- Re-measure final `strip-debug` custom-section wins.
- Measure each public level/preset on medium-naive, medium-simd, and large-swar artifacts.
- Keep validation and runtime execution separate; prefer `d8` when available, otherwise use the checked Node/WASI path.

### [WALL]001 - Cross-pass wall-time attribution

- Separate pass-local time from decode, validation, HOT lift/lower, parse/emit, buffering, caching, and process startup.
- The wall-time-first public presets clear the production blocker on the 13,118,096-byte / 11,999-function debug-WASI artifact: O1 1.944 seconds, O2 1.962, O3 5.578, O4 5.729, Os 5.611, and Oz 5.597. Every output validates externally and passes Node/WASI runtime.
- O1/O2 emit 4,889,183 bytes; O3/O4/Os/Oz emit 4,753,316 bytes. The speed-focused rosters intentionally trade some Binaryen size parity for practical wall time; direct passes remain available for targeted use.
- O4z remains the full 57-slot compatibility lane and is still the active aggregate wall-time owner: 142.144 seconds / 5,997,701 bytes on the same artifact versus verified-v131 combined `-O4 -Oz` at 17.795 seconds / 4,514,743 bytes. Preserve its exact order while attributing and repairing pass-local costs.

## v0.1.1 Pass Performance Work

The measurements below are whole-command medians on the 4,977,401-byte canonical production artifact, with one warmup and three serial measured runs. Starshine's no-op floor is 0.615 seconds and verified Binaryen v131's is 0.515 seconds. Each item must first separate pass-local work from decode, encode, validation, HOT lift/lower, and process startup under `[WALL]001`; size improvements do not excuse wall-time regressions, and timing improvements do not excuse validation or runtime failures.

### [PERF-DAE]001 - Bound plain DAE convergence

- **Evidence:** direct `dae` exceeds the 150-second limit; verified-v131 completes in 0.621 seconds in the diagnostic screen.
- **Work:** attribute graph reconstruction, repeated worklist scans, dropped-result transaction convergence, parameter-removal retries, and validation/writeback cost. Reuse stable call-graph and signature facts across iterations and prove every progress signal corresponds to a committed change.
- **Exit criteria:** the direct production lane completes in a practical bounded time, validates externally, passes Node/WASI runtime, preserves direct DAE behavior tests, and has a documented pass-local profile and explicit-v131 comparison.

### [PERF-DAEO]001 - Bound DAEOptimizing and nested cleanup

- **Evidence:** direct `dae-optimizing` exceeds the 150-second limit; verified-v131 completes in 0.888 seconds and saves 102,216 bytes.
- **Work:** separate plain DAE cost from touched-function optimizing cleanup; remove repeated scheduler/setup work; replace the large typed-loop full-parameter fallback with path-sensitive admission while retaining results-only correctness where required.
- **Dependencies:** `[PERF-DAE]001` for the shared DAE core; `[SIZE]001` for transformation-payoff evidence.
- **Exit criteria:** direct DAEO completes without timeout, emits a smaller artifact than plain DAE, validates, executes, and records per-phase timers for DAE analysis, mutation, nested cleanup, and writeback.

### [PERF-INL-OPT]001 - Reduce optimizing-inlining wall time

- **Evidence:** median 25.815 seconds versus verified-v131 3.380 seconds; approximately 25.200 seconds of Starshine time remains after subtracting the no-op floor.
- **Work:** profile planner scans, candidate rescoring, body copying, function-table/name repair, fixpoint iterations, touched-function nested cleanup, and typed-loop fallback behavior. Cache immutable call/cost facts and avoid rescanning unchanged callers.
- **Exit criteria:** direct production time is at most 5 seconds initially and trends toward verified-v131 parity, with no size, validation, runtime, metadata, or touched-function-isolation regression.

### [PERF-DCE]001 - Remove DCE whole-module overhead

- **Evidence:** median 10.686 seconds versus verified-v131 0.516 seconds; incremental Starshine cost is about 10.071 seconds while Binaryen is at the measurement floor.
- **Work:** profile repeated use/effect scans, call-result lifetime guards, HOT lift/lower, changed-function batching, and module validation. Cache per-function facts and avoid processing functions with no removable candidates.
- **Exit criteria:** direct production time is below 2 seconds, ideally below 1 second, while preserving call-result and multi-call lifetime regressions plus external validation/runtime.

### [PERF-OPTINST]001 - Reduce OptimizeInstructions traversal and writeback cost

- **Evidence:** median 6.327 seconds versus verified-v131 0.516 seconds; incremental Starshine cost is about 5.712 seconds.
- **Work:** attribute recursive visitor, fact recomputation, branch-label safety checks, repeated mutation rounds, lowering, and batch validation. Add cheap candidate preflights and retain stable HOT-label identity semantics.
- **Exit criteria:** direct production time is below 2 seconds, with duplicate-arm branch rebasing, guarded writeback, external validation, and runtime tests green.

### [PERF-VACUUM]001 - Reduce Vacuum cleanup cost

- **Evidence:** median 4.874 seconds versus verified-v131 0.565 seconds; incremental costs are about 4.259 versus 0.050 seconds.
- **Work:** profile raw preclean, recursive cleanup, fixpoint rounds, expression rebuilding, and unchanged-function emission. Avoid whole-tree rewrites when no cleanup candidate exists.
- **Exit criteria:** direct production time is below 1.5 seconds while retaining the measured 102,929-byte direct reduction, validation, and runtime correctness.

### [PERF-CODEFOLD]001 - Reduce CodeFolding recursive/fixpoint cost

- **Evidence:** median 4.873 seconds versus verified-v131 0.565 seconds; incremental costs are about 4.258 versus 0.050 seconds.
- **Work:** profile region discovery, repeated exit analysis, bottom-marker preservation, same-local distinct-call hazard scans, mutation rounds, and validation. Cache region/control facts without weakening the large structured lifetime guard.
- **Exit criteria:** direct production time is below 1.5 seconds, preserves result-loop and call-lifetime regressions, validates, executes, and retains or improves the current 13,030-byte direct reduction.

### [PERF-SLNS]001 - Reduce SimplifyLocalsNoStructure guard and rewrite cost

- **Evidence:** median 3.922 seconds versus verified-v131 0.618 seconds; incremental costs are about 3.307 versus 0.103 seconds.
- **Work:** combine duplicate raw ownership/control scans, cache local-use inventories, preflight functions before HOT lifting, batch writeback, and make guard evaluation proportional to touched candidates rather than all nested control.
- **Dependencies:** coordinate with `[SIZE]001` because reducing guard cost must not entrench the current 424,954-byte transformation gap.
- **Exit criteria:** direct production time is below 1.5 seconds while increasing or preserving safe transformation breadth and keeping all initialized-loop, local-tee, call-result, and multivalue lifetime regressions green.

### [PERF-PRECOMPUTE]001 - Reduce Precompute analysis cost

- **Evidence:** median 3.871 seconds versus verified-v131 0.517 seconds; incremental Starshine cost is about 3.256 seconds while Binaryen is at the measurement floor.
- **Work:** profile effect/ownership inventories, constant evaluation, call-argument ordering guards, repeated scans, and unchanged-function lowering. Reuse pass-owned facts and add cheap no-candidate preflights.
- **Exit criteria:** direct production time is below 1.5 seconds, preserves ownership and evaluation-order regressions, validates, executes, and retains or improves the current 15,832-byte direct reduction.

### [PERF-PRECOMPUTE-PROP]001 - Reduce PrecomputePropagation cost

- **Evidence:** median 2.920 seconds versus verified-v131 0.617 seconds; incremental costs are about 2.305 versus 0.102 seconds.
- **Work:** attribute propagation rounds, local/call ownership scans, argument-release ordering checks, and writeback. Share immutable analysis across propagation iterations and stop immediately when no committed substitution occurred.
- **Exit criteria:** direct production time is below 1.25 seconds while preserving all call/local-tee, structured lifetime, multivalue, argument-order, and parameter-read-before-write regressions.

### [PERF-RUB]001 - Reduce RemoveUnusedBrs control scanning

- **Evidence:** median 3.170 seconds versus verified-v131 0.566 seconds; incremental costs are about 2.555 versus 0.051 seconds.
- **Work:** profile label-use inventory, recursive control traversal, repeated branch-target rewriting, fixpoint convergence, and unchanged-function emission. Cache stable label facts per mutation round.
- **Exit criteria:** direct production time is below 1.25 seconds while preserving all three locked O4z slots, direct behavior, validation, and runtime correctness.

### [PERF-SGO]001 - Bound SimplifyGlobalsOptimizing tests and direct execution

- **Evidence:** the full `simplify_globals_optimizing_test.mbt` lane still exceeds 1,200 seconds even though focused SGO behavior is green; the large typed-loop production lane currently no-ops, so its apparently cheap direct timing does not represent implemented optimizing work.
- **Work:** identify unbounded synthetic cases, separate default behavior tests from dedicated fuzz/perf stress, profile nested touched-function cleanup and module/function rescans, and preserve the typed-loop fail-closed boundary until runtime-safe admission exists.
- **Exit criteria:** the bounded default SGO suite completes in normal repository-test time, stress cases live in explicit skipped perf/fuzz lanes, and any restored production transformation has pass-local timing, size, external validation, and runtime evidence.

### [SIZE]001 - Match or beat Binaryen output size

- **Measurement protocol:** use `.tmp/production-smoke/size-attribution-accurate/common-star-canonical.wasm` as the shared debug-free input. Compare every direct pass against its own tool's no-op `--strip-debug` roundtrip: Starshine 4,977,401 bytes, verified Binaryen v131 5,300,041 bytes. This removes the 322,640-byte codec/roundtrip bias before attributing pass savings. Validate every output externally; use one warmup plus three measured serial runs for timing claims.
- **Debug conclusion:** the 13,118,096-byte source contains only one custom section, `name`, occupying 7,841,984 bytes including framing. It is fully removed in the compared outputs. Remaining gaps are code transformations, not hidden DWARF or custom-section debris.
- **Priority 1 — local coalescing:** Binaryen direct `coalesce-locals` saves 517,553 bytes across 9,264 functions; Starshine saves 0 because one large structured function causes `coalesce_locals_run_module_pass` to return the entire original module. The obvious function-local isolation is not safe yet: protecting only 16+-local hazards produced an invalid local index in function 152; lowering protection to 12 exposed function 225; protecting every parameterized structured function validated and saved 8,611 bytes but failed Node/WASI with an out-of-bounds memory access. The experiment was reverted. Recover exact live-range/coloring correctness before replacing the module-wide boundary. The largest sampled Binaryen function drops from 8,249 body locals to 18.
- **Priority 2 — SimplifyLocals breadth:** Binaryen direct no-structure/full variants save 442,895 / 442,185 bytes. Starshine saves 17,941 / 0. Full `simplify-locals` skips modules with at least 2,048 definitions; no-structure reports more than ten thousand protection/fail-closed reasons, led by structured local-tee and typed-loop control families. Remove the whole-module cutoff and narrow guards one proven family at a time with runtime tests.
- **Priority 3 — optimizing inlining:** Starshine direct `inlining-optimizing` expands by 1,249,559 bytes while Binaryen shrinks by 1,119,242 bytes. Both reach roughly 5.9K defined functions, but 5,864 common named bodies are 2,039,427 bytes larger in Starshine. Repair typed-loop fallback, profitability, nested cleanup, and helper deletion before restoring inlining to wall-time-first presets.
- **Priority 4 — DAE optimizing:** Starshine direct DAE/DAEO exceed 150 seconds at default options; Binaryen DAEO takes 0.888 seconds and saves 102,216 bytes. Preserve result-removal correctness while replacing the typed-loop full-parameter fallback and repeated graph work.
- **Secondary direct gaps:** precompute-propagate 66,206 bytes, precompute 55,840, optimize-instructions 34,192, vacuum 24,295, code-folding 23,564, remove-unused-brs 21,805, simplify-globals-optimizing 7,885, reorder-locals 5,901, and RSE 4,196. Treat these as overlapping families, not additive totals.
- **Ordered evidence:** the locals-core sequence has an 849,691-byte savings gap; the broader function-cleanup sequence has a 1,092,117-byte gap. Inlining plus locals cleanup differs by 2,245,471 bytes of incremental savings. Preserve raw artifacts and the full protocol summary at `.tmp/production-smoke/size-attribution-accurate/summary.md`.
- **Exit criteria:** O1/O2/O3/O4/Os/Oz/O4z each validate, execute, and match or beat the corresponding verified-v131 raw size without reopening known semantic/runtime failures; every retained output-shape difference must be a measured Starshine win.

### [TOOL]001 - Self-opt compare normalization symmetry

- Canonicalize equivalent Binaryen/Starshine artifact paths symmetrically or ignore only proven transparent unused-label void wrappers.
- The freshly rerun exact 1,000-input ordered O4z corpus has `837` raw byte matches and `163` larger Starshine outputs totaling `+3,491` bytes; all pairs validate and become byte-identical after symmetric verified-v131 `-Oz --strip-debug` canonicalization. Keep the `163` raw differences classified as output-shape parity gaps, not Starshine wins.
- Preserve raw artifacts; do not hide semantic, size-losing, validation, level-scheduling, or fallback differences behind normalization.

### [STRIP-DEBUG]001 - Final artifact measurement

- Direct behavior and slot placement are complete.
- Re-measure debug custom-section size, validation, and runtime effects on the final large/generated artifacts.
- Keep `strip-debug` visibly separate from Binaryen's 56 O4z slots.

## v0.1.1 Optimizer Follow-ups

### [SSA-FULL]001 - Complete public full `ssa`

- **Priority:** not an O4z blocker; O4z uses `ssa-nomerge`.
- **Active work:** simple explicit-write merge locals; parameter/default entry inputs and prepend ordering; loop/branch/EH/typed-control classification; harness admission; dedicated profile; direct closeout.
- **Exit criteria:** the public pass is admitted, source/test-audited, covered by a dedicated profile, and green on the required four-lane matrix.

### [AUDIT]006 - Function `TypeIdx` / `RecIdx` invariant documentation

- Finish wiki, inline, and test documentation that function-section references are global `TypeIdx`, while `RecIdx` is rec-group-local and impossible in validated function-section positions.

### [SGO]003-[SGO]005 - Deferred SGO improvements

- The shared nested scheduler and former broad-filter removal are complete.
- Restore typed-loop optimizing breadth only after path-sensitive runtime-safe cleanup is proven.
- Add optional breadth only after a measured semantic or artifact need.
- Treat default-local compare normalization as tooling/cosmetic work, not a direct correctness blocker.

## v0.2.0 Or Later Work

### [V02-INL]001 - Ship the Binaryen-v131 inlining-family expansion

- **Status:** implementation is retained locally; publication is deferred to v0.2.0 or later.
- **Scope:** plain `inlining`, `inlining-optimizing`, active `inline-main`, `no-inline*` policy, toolchain hints, six configuration controls, represented trivial-instruction policy, Pattern A/B splitting, EH-safe tail handling, roots, metadata repair, and touched nested cleanup.
- **Release gate:** regenerate interfaces, run README/API sync, focused suites, the full repository suite, explicit-v131 direct lanes, and the repository-wide validation gate. Resolve or explicitly retain the large typed-loop fallback with source/runtime evidence.

### Shared-Everything Threads

Keep the dependency order; detailed proposal rules live in the Shared-Everything wiki pages.

1. Model proposal entities, heap/reference types, limits/flags, rec groups, shared descriptors, and annotations.
2. Decode/encode proposal bytes with contextual legality checks and round-trip tests.
3. Validate shared/unshared domains, type graphs, subtyping/LUB/GLB, rec groups, memory/table/global/tag rules, and proposal opcodes.
4. Link/import/export proposal entities and type graphs without index or ownership corruption.
5. Extend optimizer harness protocol, feature flags, semantic hashing, and compare/fuzz normalization.
6. Extend generators and shrinkers with high-yield proposal cases.
7. Preserve proposal structures through HOT lift/lower with provenance and correct failure boundaries.
8. Expose CLI flags, update docs, and run focused plus full proposal signoff.

### [INL]020-[INL]021 - Optional future inlining breadth

- Revisit tiny hot-path struct/array allocation inlining only with measured canonical-size and wall-time wins.
- Keep table/indirect-call callee recovery deferred; v131's direct-call planner and copied-body indirect/ref-call handling are complete.
- Keep expression-level code metadata, branch hints, source maps, and copied-callee debug-name synthesis under shared metadata-substrate work.

### [HOT]001-[HOT]004 - Deferred structural improvements

- Replace exact-expression span identity with stronger source provenance where needed.
- Preserve unknown/custom metadata through HOT round trips.
- Reduce opaque fallback lowering without sacrificing correctness.
- Keep startup-map local/tee/loop repair under `[O4Z-STARTUP]001` rather than opening unrelated HOT rewrites.

### [FUZZ]001 - Continuous parity triage

- Keep no permanent active bug entry while all maintained suites are green.
- On a new mismatch, save the seed/artifacts, minimize it, classify it, add the focused regression first, repair the owning pass/harness/codec, and archive the durable result in the relevant dossier.

## Backlog Hygiene

- Remove a slice when its exit criteria are met; do not retain completed checkbox diaries.
- Move durable closeout evidence to the pass dossier or `docs/wiki/log.md`.
- Add active slices only with a concrete owner, goal, reason, deliverables, dependencies, exit criteria, and suggested tests where implementation is expected.
- Keep release blockers and known failures visible until resolved.
- When live code and a planning page disagree, correct the planning page promptly; do not create duplicate implementation work for behavior already landed and signed off.
