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
- Direct passes remain available, and DAE, optimizing inlining, and SGO retain the full level/feature-aware nested function scheduler. DAE prepends `precompute-propagate`; SGO's touched-function nested roster does not. Separately, SGO owns a bounded transactional final suffix that starts with `precompute-propagate`.
- Nested cleanup remains touched-function-scoped. SGO's former 192-local / 1,000-instruction broad filter is removed. After SGO changes a module, the `<1000`-definition final transaction runs propagation, safe block merging, live-out-aware SimplifyLocals, branch cleanup, bounded coalescing, and final linear cleanup, then commits only a valid strictly smaller encoding.
- Large typed-loop modules currently use focused fail-closed owner fallbacks where production smoke exposed path-sensitive gaps: DAE optimizing uses plain DAE at lower levels and a results-only fallback at O3+/Oz; guarded call/bulk-memory optimizing inlining runs plain shrinking-trivial admission plus the default two-instruction always-inline ceiling and a four-instruction one-caller ceiling, while the flexible threshold stays zero; SGO no-ops; and flatten/merge-locals no-op in the affected large-module neighborhood. SimplifyLocals, TupleOptimization, DCE, Precompute, CodePushing, CoalesceLocals, CodeFolding, SSA, and OptimizeInstructions retain focused shape or guarded-writeback boundaries for reduced validation and runtime families.
- Optimizer registry/tracker/execution/release-horizon documentation has been reconciled with the live scheduler and registry.
- Current production O4z correctness evidence is green on native SHA-256 `443fa73acbe3789b0e1b330fdf28652fe5f567c4e6df53470e46217b65b92d47`: all `105/105` `json-as` outputs optimize and externally validate, and exact four-worker no-cache WIPC execution passes all `105/105` artifacts with zero failures/timeouts. The retained SGO-owned final transaction runs `precompute-propagate -> merge-blocks -> simplify-locals -> remove-unused-brs -> bounded coalesce-locals -> sgo_apply_final_cleanup` only after SGO changes a module, only below 1,000 defined functions, and only commits a valid strictly smaller encoded candidate. The historical late-SimplifyLocals rejection was reduced to defined function 43 / absolute function 47 in `bool.spec.wasm`: recursive adjacent-set/get cleanup erased a conditional call-result write because it ignored the parent continuation's later `local.get`, leaving a stale allocator pointer. `run_hot_pipeline_simplify_locals_lowered_collect_local_reads(...)`, `run_hot_pipeline_simplify_locals_lowered_reads_after(...)`, and the live-out-aware recursive cleanup now propagate later-sibling and inherited reads into blocks, `if` arms, loops, and `try_table`; loop bodies also contribute backedge reads. Aggregate output is `20,252,110` bytes, family totals naive `6,601,920`, SIMD `6,841,190`, and SWAR `6,809,000`; all 105 artifacts shrink from the signed MergeBlocks checkpoint by `24,387` bytes. Versus verified-v131 O4z `15,645,124`, the remaining gap is `4,606,986` bytes / `29.4468%`. Final-suffix acceptance, safe SimplifyLocals cleanup, and parent-live-out preservation are regression-covered.
- Current self-opt artifact-comparison evidence is green on the retained August 12 source checkpoint: debug artifact `13,770,560` bytes, release artifact `5,068,591` bytes, and self-optimized CLI `5,014,671` bytes. Native and rebuilt self-optimized-Wasm optimizers emit byte-identical output SHA-256 `4e17218bcb9bf42ac8f813333dd1dff395597363d39b3190bd8c7d0c9cc4bf00`; Node/WASI smoke passes, self-opt task tests are `16/16`, recursive full spec is `284` total / `64` passed / `220` intentionally skipped / `0` failed, and `bun validate full --profile ci --target wasm-gc` passes including `86,820` binary roundtrips. The August 14 review refresh is **not** green: native SHA-256 `165611733d7536f4b853c2642414e6ce213e0c0a39d164aed11326d910ebd78d` optimizes and externally validates `105/105` O4z corpus modules (`20,182,554` bytes), but exact WIPC reports `0` pass / `102` fail / `3` timeout. All corpus inputs have fewer than 2,000 defined functions (maximum `1,551`), and final native SHA-256 `da005c82e948716b16ec7ff90d07db41d2737ae56240ed85a88867858f6b5dc0` reproduces the retained naive `bool` output byte-for-byte at SHA-256 `0a927586f0f6c5936b0236b0b88c6e8c4632dceb240d915225daeebdb930efee`; the artifact-scale CFG performance guard therefore does not alter the corpus result. An isolated clean-HEAD build produces those same failing `bool` bytes, so the runtime blocker predates the three original August 14 review fixes. The self-opt build is now bounded and completes in `330` seconds end to end instead of running for hours: debug/release/self-optimized artifacts are `13,841,184` / `5,095,702` / `4,672,918` bytes, and self-optimized SHA-256 `fa002f6f3720d4622a6866ef27849e6e90237928fa790c2b33e9a5d9b3113dae` is produced from the release artifact through compact phase tracing. It still traps with an out-of-bounds memory access on `--help`, now through Wasm functions `28`, `32`, `34`, `56`, `617`, `597`, `596`, and `9788`; full spec and optimizer-capability execution remain blocked. Full Moon is `10,412/10,412`, and the final wasm-gc CI profile remains green. Dedicated direct SimplifyLocals evidence is `10000/10000` with `5000` normalized matches and `5000` inspected deterministic residuals: `3125` fourteen-byte canonical Starshine wins from `simplify-locals-family-coverage`, plus `1875` existing structure-result output-shape gaps where Starshine is `2..4` bytes larger because it retains one `nop` per generated function; aggregate canonical delta remains `-38,135`, with zero failures. The refreshed SGO aggregate is `5055` normalized plus `4945` inspected smaller-output residuals (`1427` nested-cleanup and `2127` read-only-to-write one-byte wins plus `1391` three-byte retained initializer aliases, `-7727` aggregate), with zero validation/property/generator/command failures.
- The remaining 303 corpus `call; drop` pairs are classified and no longer an unscoped DAE target: 105 call imported result functions, while 198 target 159 private defined callees that all have mixed direct observers. There are no private all-direct-dropped, exported, or `ref.func`-escaped residual callees. Further recovery must specialize dropped callsites or inline without changing the shared callee boundary. The refreshed dedicated DAEO lane is `10000/10000`, with `6954` normalized matches, `3046` inspected source-backed smaller-output residuals (`-37,910` raw/canonical aggregate), and zero validation/generator/property/command failures.

## v0.1.1 Execution Order

1. Complete `[WALL]001` pass-local attribution so every slow-pass item separates optimizer work from the 0.615-second Starshine command floor.
2. Execute `[SIZE]001` together with the overlapping performance items: CoalesceLocals correctness first; SimplifyLocals with `[PERF-SLNS]001`; optimizing inlining with `[PERF-INL-OPT]001`; then DAE with `[PERF-DAE]001` and `[PERF-DAEO]001`.
3. Repair the remaining direct slow passes in descending measured cost: `[PERF-DCE]001`, `[PERF-OPTINST]001`, `[PERF-VACUUM]001`, `[PERF-CODEFOLD]001`, `[PERF-PRECOMPUTE]001`, `[PERF-RUB]001`, and `[PERF-PRECOMPUTE-PROP]001`.
4. Run `[JSON-AS]001`, `[TOOL]001`, and `[STRIP-DEBUG]001` final release evidence.
5. Revisit focused startup fallbacks only with smaller regressions and runtime proof.

## v0.1.1 Pipeline Supporting Work

### [REVIEW-ARTIFACT]001 - Recover the August 14 O4z runtime gate and large-input self-hosting

- **Evidence:** native SHA-256 `165611733d7536f4b853c2642414e6ce213e0c0a39d164aed11326d910ebd78d` optimized and externally validated all `105/105` retained `json-as` modules at `20,182,554` bytes, but exact four-worker no-cache WIPC is `0/105` with `102` exit-1 failures and `3` timeouts. All 105 inputs remain below the artifact-scale boundaries (maximum `1,551` defined functions), and native SHA-256 `da005c82e948716b16ec7ff90d07db41d2737ae56240ed85a88867858f6b5dc0` reproduced the retained naive `bool` artifact byte-for-byte at SHA-256 `0a927586f0f6c5936b0236b0b88c6e8c4632dceb240d915225daeebdb930efee`. The same bytes and failure reproduce from an isolated clean `HEAD` build, proving the WIPC issue predates the August 14 CFG, metadata, WAST harness, and timeout/performance fixes.
- **Recovered self-opt evidence:** startup/runtime bisection added focused SSA and SimplifyLocals lifetime regressions, then excluded artifact-scale O4z `remove-unused-brs`, `precompute-propagate`, CFG coalescing, and the second/later SSA waves at `>=2000` definitions while preserving direct invocation and the initial SSA wave. The final bounded production build emits debug/release/self-optimized sizes `13,855,200` / `5,101,032` / `4,687,144`, native SHA-256 `33082d11b18c08fe58d46cde984b6611793dda2982b3ce577f8992e9655948cf`, and self-optimized SHA-256 `ea931f9c4aa01f3ba06736687b1cf51b73323ad4c51eff843fec93e1cfa4323f`. `bun validate self-opt-smoke` passes, recursive full spec is `284` files / `87` passed / `197` skipped / `0` failed, and the default bounded native-vs-self-hosted optimizer comparison is byte-identical on `tests/repros/merge-blocks-v131-main.wasm`. Full Moon is `10,418/10,418`, self-opt scripts are `21/21`, and the wasm-gc CI profile is green.
- **Remaining work:** rerun and repair exact WIPC without weakening the current self-opt guards. Larger explicit self-hosted optimizer inputs remain outside signed capability: the release Wasm CLI exceeds Node's stack budget on generated CLI artifacts, and the 192 KB startup-map repro was not bounded to a successful exact comparison. Reduce that capacity limit separately before restoring an artifact-scale self-hosting claim.
- **Exit criteria:** fresh current-source O4z optimize/validate and exact WIPC are `105/105`; the bounded self-opt smoke/full/default optimizer gates stay green; any larger self-hosted optimizer capability claim has an explicit input, deadline, valid output, and native byte comparison.

### [O4Z-STARTUP]001 - Preserve and reduce the startup-map regression guards

- Keep `tests/repros/o4z-debug-startup-map-init-repro.wasm` until smaller generated fixtures cover every production family.
- Preserve the focused regressions for startup initializer SimplifyLocals convergence, giant post-inline call builders, oversized lowered preflight, dynamic nonzero-offset stores, typed and untyped loop-carried locals, and typed-loop optimizing fallbacks.
- Recover precision one owner at a time only with source-backed tests plus validation and runtime evidence. Current recovery targets are path-sensitive SimplifyLocals loop reasoning, CoalesceLocals parameter interference, CodePushing local-carrier placement, and typed-loop nested cleanup.
- Do not remove a fail-closed owner fallback merely because a candidate output validates or is smaller.

### [JSON-AS]001 - Repeatable artifact correctness and size signoff

- **Current correctness gate:** complete for O4z on the pinned `json-as` corpus. The current native binary optimizes and validates `105/105` modules, and exact no-cache `as-test` execution passes all artifacts in all three modes. Preserve evidence under `.tmp/o4z-signoff-20260808/` until durable Bun tooling replaces the temporary runners.
- Add a documented opt-in clone/build/replay task under existing Bun tooling; do not add shell scripts under `scripts/`.
- Re-measure final `strip-debug` custom-section wins.
- Measure each public level/preset on medium-naive, medium-simd, and large-swar artifacts.
- Keep validation, process-level runtime, and exact report-protocol execution as separate gates; prefer `d8` when available, otherwise use the checked Node/WASI path.

### [WALL]001 - Cross-pass wall-time attribution

- Separate pass-local time from decode, validation, HOT lift/lower, parse/emit, buffering, caching, and process startup.
- The wall-time-first public presets clear the production blocker on the 13,118,096-byte / 11,999-function debug-WASI artifact: O1 1.944 seconds, O2 1.962, O3 5.578, O4 5.729, Os 5.611, and Oz 5.597. Every output validates externally and passes Node/WASI runtime.
- O1/O2 emit 4,889,183 bytes; O3/O4/Os/Oz emit 4,753,316 bytes. The speed-focused rosters intentionally trade some Binaryen size parity for practical wall time; direct passes remain available for targeted use.
- O4z remains the full 57-slot compatibility lane and is still the active aggregate wall-time owner. The SimplifyLocals scan-cache, full-module breadth, owner-priority, and parameter-lifetime work improves the lane from 142.144 seconds / 5,997,701 bytes to the original August 3 result of 115.435 seconds / 5,912,452 bytes; the August 4 reconstruction emits byte-identical output and remains external-validation/runtime green. Verified-v131 combined `-O4 -Oz` remains 17.795 seconds / 4,514,743 bytes. Preserve the exact order while attributing and repairing pass-local costs.
- The August 17 WAGO audit checkpoint covers all 1,330 tracked fixtures at or below 2 MiB, including 842 externally valid inputs. The runtime-safe residual-pass7 sweep retains 807/807 valid successful Starshine outputs, zero valid-input timeouts/corruptions, and the same 35 compatibility failures. Level-correct pass-prefix bisection repaired or bounded the remaining ifs/primes wrong-code owners: HOT binary-spill lowering preserves multi-use local payloads, full SimplifyLocals/MergeBlocks/CFG CoalesceLocals fail closed on the measured 44/50-function family, and Vacuum preserves root global snapshots through tee-return and set/get-return carriers. Normal O4z plus the separately verified late-cleanup/SSA candidate now emit runtime-exact ifs/primes at 24,127/23,570 bytes. Export-scoped `stackAlloc` snapshot repair keeps fannkuch/fasta compact and runtime-exact at 23,397/23,795. On the unchanged 766-file cohort Starshine is 416,519 bytes versus Binaryen's 415,485, a +1,034-byte / +0.249% gap, with smaller/equal/larger distribution 105/563/98 and 6,000 positive residual bytes. The original 460,130-byte checkpoint is reduced by 43,611 bytes and 97.68% of the original gap is closed. Additional pass7 closures are no-mixup-stack-maps 71, Winch issue 424666628 142, and fuzzcase 2084 46; all match Binaryen and focused runtime probes. Unsigned `i16x8.narrow_i32x4_u` now saturates negative signed lanes to zero, restoring repeated-call fuzzcase 1820 state. A new 1797a probe rejected the prior 161-byte trapping candidate; the accepted bounded DFE/RUME cleanup is 171 bytes and returns zero like input/Binaryen. Exact native SHA-256 is `4ad5b78d84a6a16d8cf622e8e719e5983a50d906d0b031c2e50fe594218cf67b`; 10,536 tests, 1,394 ISA/SIMD calls, 29 non-tree probes, eight bounded binary-tree probes, all four stateful embenchen hashes, 1820 repeated state, and focused small-fixture execution are green. Next: reduce the remaining ifs +2,014, primes +1,880, JSON SIMD +412, fannkuch +235, fasta +203, scalar JSON +96, fuzzcase 1797a +86, `urem_regalloc` +85, startup JSON +73, and scalar ISA residuals without relaxing runtime gates.

## v0.1.1 Pass Performance Work

The measurements below are whole-command medians on the 4,977,401-byte canonical production artifact, with one warmup and three serial measured runs. Starshine's no-op floor is 0.615 seconds and verified Binaryen v131's is 0.515 seconds. Each item must first separate pass-local work from decode, encode, validation, HOT lift/lower, and process startup under `[WALL]001`; size improvements do not excuse wall-time regressions, and timing improvements do not excuse validation or runtime failures.

### [PERF-DAE]001 - Bound plain DAE convergence

- **Evidence:** direct `dae` exceeds the 150-second limit; verified-v131 completes in 0.621 seconds in the diagnostic screen.
- **Work:** attribute graph reconstruction, repeated worklist scans, dropped-result transaction convergence, parameter-removal retries, and validation/writeback cost. Reuse stable call-graph and signature facts across iterations and prove every progress signal corresponds to a committed change.
- **Exit criteria:** the direct production lane completes in a practical bounded time, validates externally, passes Node/WASI runtime, preserves direct DAE behavior tests, and has a documented pass-local profile and explicit-v131 comparison.

### [PERF-DAEO]001 - Bound DAEOptimizing and nested cleanup

- **Evidence:** direct `dae-optimizing` exceeds the 150-second limit on the production artifact; verified-v131 completes in 0.888 seconds and saves 102,216 bytes. On the 27,780-byte WAGO fannkuch fixture, isolated DAEO takes about 175 ms wall time: core is about 85 ms (56 ms fixed worklist), nested cleanup is about 48 ms across 35 passes on 12 touched functions, and the final effect frontier analyzes 224 items with zero candidates or commits.
- **Work:** separate plain DAE cost from touched-function optimizing cleanup; reuse stable dependency/call graphs across the ten committed core waves; preflight or narrow zero-yield effect-frontier families without losing forwarding-cycle convergence; remove guaranteed no-progress nested setup while preserving measured size gains; replace the large typed-loop full-parameter fallback with path-sensitive admission where required.
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

- **Evidence:** one shared raw shape inventory replaces the former duplicate generic/shape scans and caches local-write, local-tee, global-state, memory-size, and stack-effect facts. Folding the small-local preflight into that scan reduced the original August 3 median from 3.792 seconds to 1.710 seconds versus verified-v131 0.618 seconds; August 4 reconstruction rechecks are 1.823/1.867/1.878 seconds and byte-identical to the preserved binary. The direct artifact still saves 21,162 bytes.
- **Work:** profile the remaining HOT-pass total, especially lifted unchanged functions and control-embedded-tee root-only functions. Add a candidate preflight only when it is cheaper than the work it avoids; the attempted post-lift local-get inventory reuse and an extra no-root-candidate scan produced no measured win and were reverted.
- **Dependencies:** coordinate with `[SIZE]001` because reducing guard cost must not entrench the remaining 421,733-byte no-structure transformation gap.
- **Regression status:** the 12 bounded default perf expectations reach their specific multivalue, adjacent-local, structured-tail, stringview, and decision-ladder owners before generic convergence guards. Four multivalue stress tests plus the synthetic 2,048-function breadth test are explicit `#skip` manual lanes in `passes_perf_long`, and all five pass when selected directly. Full `moon test` is green at `10230/10230`; fresh regular GenValid lanes are `10000/10000` normalized matches for both full and no-structure variants with zero failures.
- **Exit criteria:** direct no-structure production time is below 1.5 seconds while increasing or preserving safe transformation breadth and keeping all initialized-loop, local-tee, call-result, parameter-alias, multivalue, and owner-priority regressions green.

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

### [SIZE]001 - Match or beat Binaryen output size

- **Measurement protocol:** use `.tmp/production-smoke/size-attribution-accurate/common-star-canonical.wasm` as the shared debug-free input. Compare every direct pass against its own tool's no-op `--strip-debug` roundtrip: Starshine 4,977,401 bytes, verified Binaryen v131 5,300,041 bytes. This removes the 322,640-byte codec/roundtrip bias before attributing pass savings. Validate every output externally; use one warmup plus three measured serial runs for timing claims.
- **Debug conclusion:** the 13,118,096-byte source contains only one custom section, `name`, occupying 7,841,984 bytes including framing. It is fully removed in the compared outputs. Remaining gaps are code transformations, not hidden DWARF or custom-section debris.
- **Priority 1 — local coalescing:** Binaryen direct `coalesce-locals` saves 517,553 bytes across 9,264 functions. Starshine now admits a bounded O4z subset for ordinary modules below 2,000 definitions and defaultable functions with at most 512 body locals; changed candidates are batch-validated with individual rollback. Dense-tee structured functions use a conservative lexical interval compactor that reuses only nonoverlapping locals whose first write dominates the remaining sequence, preserving branch-skipped implicit-default reads and every tee. Deep-copying nested instruction arrays and preserving later-read tees closed earlier report-protocol corruption. This retained slice saves 251,866 aggregate `json-as` bytes with all exact tests green. The refreshed `coalesce-locals-all` 10k lane has 8,125 exact normalized matches plus 1,875 inspected three-byte Starshine cleanup wins (`-5,625` aggregate), all converging under common verified-v131 `-Oz --strip-debug --all-features`, with zero validation/property/generator/command failures. A 2026-08-13 experiment widened O4z selection and dense intervals through the existing 4,096-local ceiling, but recovered only 28 bytes on the BLAKE3 SIMD artifact; the widening was reverted because prior exact WIPC evidence already showed wrong-code above 512 locals. Large structured coloring therefore remains fail-closed pending sparse path-sensitive interference. A 2026-08-14 CFG-backed loop path now handles defaultable functions within the 512-local boundary: conservative block liveness, raw/HOT action-count agreement, and ineffective-write/live-value interference reduce BLAKE3 SIMD function 8 from 339 to 52 body locals. Two late-only `simplify-locals-nostructure -> coalesce-locals-cfg -> reorder-locals -> vacuum` O4z waves plus CFG per-definition ineffective set/tee cleanup reduce validated SIMD output from 44,017 to 42,032 bytes. Bounded preflight stackification for oversized small-local functions reaches 41,796 bytes, two late SSA-normalization plus local-cleanup waves reach 41,621 bytes, dropped pure SIMD shuffle cleanup reaches 41,109 bytes, and O4z-only bounded small-function stackification reaches 40,903 bytes. Scheduling the CFG shape in earlier compatibility slots was size-losing and remains rejected.
- **Priority 2 — SimplifyLocals breadth:** Binaryen direct no-structure/full variants save 442,895 / 442,185 bytes. Starshine now saves 21,162 / 54,211 bytes on the canonical production artifact. The full-pass 2,048-definition cutoff is removed; production recovery required extending local-alias, call-result, and call-local-tee lifetime protection to full SimplifyLocals, then deferring those broad guards behind specific bounded owners. The O4z prefix exposed an early parameter read being replaced by a later result-if alias; the focused correctness guard preserves that lifetime. The retained SGO-owned late wave additionally uses parent/later-sibling live-out propagation so structured-child local writes survive when the continuation reads them. On 2026-08-13, a guarded raw rewrite eliminated split `i32x4.shr_u` / `i32x4.shl` rotate scratch locals only when every read of both scratch indices belongs to a recognized complementary-shift `v128.or` pattern. On 2026-08-14, an exact commutative SIMD carrier rewrite converted `producer; local.set X; local.get Y; local.get X; op` to `producer; local.tee X; local.get Y; op` for `v128.xor` and `i32x4.add`, preserving later reads and leaving noncommutative operations unchanged. The two slices preserve the historical large-local tee/memory-write guard and TLSF map-update regression. After the intervening inlining recovery, the carrier slice reduces validated BLAKE3 SIMD O4z from 45,654 to 44,062 bytes; running the same exact rewrite before the generic loop-carried fallback reaches 44,017 bytes. Two late no-structure simplification plus CFG local-coalescing waves with per-definition dead-write cleanup reach 42,032 bytes. Exact bounded stackification across independently typechecked unstructured spans reaches 41,796 bytes; two late SSA-normalization plus local-cleanup waves reach 41,621 bytes, and exact dropped pure `i8x16.shuffle` cleanup reaches 41,109 bytes, and O4z-only small-function stackification reaches 40,903 bytes. The remaining gap is 1,419 bytes / 3.6% versus Binaryen's 39,484-byte result. Remaining broad gaps include structured local-tee, typed-loop control, local coalescing, and the existing generated structure-result `nop` shape family.
- **Priority 3 — optimizing inlining:** Starshine direct `inlining-optimizing` expands by 1,249,559 bytes while Binaryen shrinks by 1,119,242 bytes. Both reach roughly 5.9K defined functions, but 5,864 common named bodies are 2,039,427 bytes larger in Starshine. A 2026-08-13 conservative appended-local entry-liveness repair now omits copied default initialization unless a reachable read can observe the incoming zero/null value; focused tests cover root writes, conditional paths, structured-control boundaries, and legacy EH, and both plain and optimizing dedicated 10k lanes remain exact. This reduced the validated BLAKE3 SIMD O4z artifact from 63,927 to 45,654 bytes; the subsequent commutative SIMD carrier cleanup plus its pre-loop-guard source-kernel follow-up reaches 44,017 bytes, and two late no-structure simplification plus CFG local-coalescing waves with per-definition dead-write cleanup plus bounded stackification and two late SSA-normalization cleanup waves plus dropped pure SIMD shuffle cleanup and O4z-only small-function stackification reach 40,903 bytes, leaving a 1,419-byte / 3.6% gap versus verified-v131. Continue with profitability, typed-loop fallback, nested cleanup, helper deletion, and the remaining local simplification/coalescing gap before restoring inlining to wall-time-first presets.
- **Priority 4 — DAE optimizing:** Starshine direct DAE/DAEO exceed 150 seconds at default options; Binaryen DAEO takes 0.888 seconds and saves 102,216 bytes. Preserve result-removal correctness while replacing the typed-loop full-parameter fallback and repeated graph work.
- **Late SGO cleanup:** SGO's bounded cheap cleanup deletes adjacent pure `local.get; drop` pairs only when the local has no prior write in that sequence, preserving local-tee payoff shapes used by side-effecting select cleanup. After nested cleanup completes, the `<1000`-definition transaction runs propagation, safe block merging, live-out-aware SimplifyLocals, branch cleanup, bounded coalescing, and the module-wide final sweep. The sweep removes `nop` roots, adjacent stack-neutral local/global reads and numeric/vector/reference constants followed by `drop`, immediate pure unary or binary numeric expression trees whose result is dropped, safe trivial result blocks, pure result-`if`s, and stack-neutral effectful result blocks ending in a pure value plus `br 0`; uncertain instructions, owner-targeting branches, and EH fail closed. The whole candidate is validated, encoded, and committed only when strictly smaller. The repaired late SimplifyLocals wave advances the corpus from the signed MergeBlocks checkpoint `20,276,497` to `20,252,110` bytes (`-24,387`) with exact WIPC `105/105`. Multi-instruction immutable initializer aliases are not duplicated when the source global remains. The refreshed SGO aggregate is `5055` normalized plus `4945` inspected smaller residuals (`-7,727` aggregate) with zero failures. SGO rollback deep-copies only touched function bodies instead of encoding and decoding the whole module; the representative snapshot phase remains reduced from 39.023 ms to 1.773 ms.
- **Secondary direct gaps:** precompute-propagate 66,206 bytes, precompute 55,840, optimize-instructions 34,192, vacuum 24,295, code-folding 23,564, remove-unused-brs 21,805, remaining simplify-globals-optimizing shape gaps, reorder-locals 5,901, and RSE 4,196. Treat these as overlapping families, not additive totals.
- **Ordered evidence:** the locals-core sequence has an 849,691-byte savings gap; the broader function-cleanup sequence has a 1,092,117-byte gap. Inlining plus locals cleanup differs by 2,245,471 bytes of incremental savings. Preserve raw artifacts and the full protocol summary at `.tmp/production-smoke/size-attribution-accurate/summary.md`.
- **Exit criteria:** O1/O2/O3/O4/Os/Oz/O4z each validate, execute, and match or beat the corresponding verified-v131 raw size without reopening known semantic/runtime failures; every retained output-shape difference must be a measured Starshine win.

### [TOOL]001 - Self-opt compare normalization symmetry

- Canonicalize equivalent Binaryen/Starshine artifact paths symmetrically or ignore only proven transparent unused-label void wrappers.
- The freshly rerun exact 1,000-input ordered O4z corpus has `837` raw byte matches and `163` larger Starshine outputs totaling `+3,491` bytes; all pairs validate and become byte-identical after symmetric verified-v131 `-Oz --strip-debug` canonicalization. Keep the `163` raw differences classified as output-shape parity gaps, not Starshine wins.
- Preserve raw artifacts; do not hide semantic, size-losing, validation, level-scheduling, or fallback differences behind normalization.
- The full-debug-artifact optimizer capability is now closed independently of corpus normalization: all 57 explicit O4z slots and the exact direct `--optimize -O4z` invocation are byte-identical between native and self-optimized Wasm. Final evidence is under `.tmp/o4z-signoff-20260808/native-wasm-slot-diff-after-ssa-production-guards/` and `.tmp/o4z-signoff-20260808/self-opt-artifact-optimizer-final-ssa-production-guards-20260810/`.

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
