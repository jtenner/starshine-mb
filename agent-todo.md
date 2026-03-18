# Agent Tasks

## Goal
Reach v0.1.0 "production-ready for MoonBit users" by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and a maintainable codebase.

## Scope
- Open work only.
- Keep tasks as simple bullet points.
- Move completed work to `CHANGELOG.md` instead of marking items done here.
- Order items highest priority first within each section.

## Publishing blockers
- Capture and commit optimize baseline measurements for `examples`, `spec-sanity`, `dist-optimized`, and the documented user-run `self-opt-debug` command.
- Finish `docs/pass-audit.md`: for each current pass, record what it does well, where it is inefficient, the best local fixes, expected size/runtime impact, and the nearest Binaryen comparison or adaptation.
- Refactor `SimplifyLocals` under strict TDD: use array-backed sinkable storage, compact invalidation buckets, dirty-index clearing, fused summaries with stronger early exits, and cheaper effect/validation handling without weakening correctness.
- Expand `SimplifyLocals` regressions for redundant set/get elimination, tee formation, block/if/loop result structuring, pathological invalidation, validation salvage/reject behavior, and prior broken-module cases.
- Add `SimplifyLocals` microbenchmarks for dense locals, deep nested control, high invalidation churn, and wide-local stress; record before/after deltas.
- Refactor `Vacuum` after `SimplifyLocals`: move to worklist-style parent reprocessing, avoid unchanged rebuilds, strengthen skip logic, and reuse side-effect metadata instead of repeated whole-function sweeps.
- Expand `Vacuum` coverage for nop removal, useless drop removal, trivial block cleanup, dead wrapper elimination, and cleanup chains that require parent reprocessing.
- Add `Vacuum` benchmarks for mostly-clean modules, cleanup-heavy synthetic inputs, and mixed modules after `SimplifyLocals`.
- Refactor `AlignmentLowering` after the scheduling audit: add cheap module/function exits, skip already-correct ops, and reduce cleanup debt introduced by lowering.
- Expand `AlignmentLowering` coverage for no-op modules, aligned-op passthrough, misaligned-op lowering, and post-lowering validation/cleanup behavior.
- Audit scheduler gating and pipeline ordering after the first `SimplifyLocals` and `Vacuum` measurements exist; prove any sequencing changes with size/runtime deltas instead of removing iterations blindly.
- Add deterministic scheduler and pass-order assertions so optimize traces remain stable and explainable.
- `SSANoMerge` performance blocker: optimize pass trace on `_build/wasm/debug/build/cmd/cmd.wasm` still takes `99.669s` at `pass[5/48]`.
- `SimplifyLocals` performance blocker: optimize pass trace on `_build/wasm/debug/build/cmd/cmd.wasm` still takes `70.579s` at `pass[25/48]`.
- `MergeBlocks` performance blocker: optimize pass trace on `_build/wasm/debug/build/cmd/cmd.wasm` still takes `47.924s` at `pass[32/48]` and `22.256s` at `pass[35/48]`.
- `MergeSimilarFunctions` correctness blocker: optimize pass trace still fails at `pass[44/48]` with `upstream-invalid direct call in preflight: arg count mismatch expected=3 actual=4 kind=call caller_abs_idx=924 callee_abs_idx=9038 node_id=15`.
- `Vacuum` correctness blocker: serial pass repro on `before.wasm` still fails at `pass=Vacuum` with `typed function stack underflow` in `Func 1360`; degraded local-retention hardening landed, but the root corruption is still unresolved.
- Improve validator end-of-body diagnostics so they distinguish underflow, wrong result types, and extra values; include expected vs actual stack shape and add regressions for each case.
- Add a dedicated validation benchmark/tracing harness around `validate_module_with_trace(...)`, plus fixed corpora for deep control nesting, wide locals, large code sections, and `ref.func`-heavy modules; record baseline `phase_totals`, `helper_totals`, and `hotspots`.
- Profile and reduce repeated `Env.with_label(...)`, `with_labels(...)`, and `tc_stack_from_types(...)` copying in structured control validation (`block`, `if`, `loop`, `try_table`); prove the change with before/after timings on large modules.
- Fold `collect_declared_funcs_bitmap(...)` and `validate_ref_func_declarations_in_module(...)` into the main validation/code walk, or another shared traversal, so large modules are not rescanned before function-body validation.
- Final verification/reporting: run `moon info && moon fmt`, run `moon test`, run all new benchmark commands before vs after, let the user run the self-optimization benchmark command and record its results, then write the final measured summary with size deltas, per-pass runtime deltas, justified regressions, implemented fixes, and remaining work.

## Post v0.1.0 blockers
- Complete the `src/passes` inventory and map each scheduler entry in `src/passes/optimize.mbt` to its implementation file, tests, and closest Binaryen equivalent.
- Add broader pass-level instrumentation in `src/passes/optimize.mbt` for wall time, changed/unchanged status, functions touched, and validation/salvage counters.
- Establish a pass benchmark suite covering microbenchmarks, pass-sequence benchmarks, and real-module end-to-end size/runtime measurements.
- Continue `simplify_locals` performance work: array-backed sinkable tracking, compact invalidation buckets, stronger early exits, fused analysis walks, cheaper cache keys, and more selective validation.
- Rework `vacuum` into a worklist-driven simplifier with parent tracking, and share side-effect analysis with `simplify_locals` so purity/no-op checks are consistent and cheaper.
- Add `alignment_lowering` fast-path guards for modules without relevant memory ops and reduce rewrite allocation churn where the IR allows it.
- Add scheduler change summaries so expensive passes rerun only when earlier passes created new opportunities.
- Build a regression corpus for pass interactions, especially `simplify_locals -> vacuum`, `vacuum -> simplify_locals`, and `alignment_lowering -> vacuum`.
- Add targeted tests for deep control nesting, high local-count functions, sinkable invalidation churn, and EH-heavy control flow.
- Add emitted Wasm byte-size reporting to optimization validation instead of relying only on IR node counts.
- Document the Starshine-to-Binaryen pass crosswalk and intentional semantic differences as the stable comparison baseline for future pass work.

## Post 0.1.0 Features
- Add `StackState` to traversal event callbacks to help debug validation issues.
- Continue `string.const` support and string optimization passes.
- Replace deep-recursive native decode with a recursion-free control-instruction path, and add regression or benchmark coverage for deep nested-control decode.
- Make `moduleToWast` output reliably parser-consumable in roundtrip tests.
- Reach `>=75%` line coverage on hot paths: decoder, IR lift, and top passes.
- Add a shared memarg-alignment helper (`byte width -> alignment exponent`), migrate remaining byte-count alignment emitters, and audit asyncify-generated `MemArg` alignments with validator-backed tests for both `i32` and `i64` memory.
- Add `re_reloop` end-to-end coverage for internal loop-target `br_table` cases carrying branch values.
- Improve fuzzing: tune or replace `gen_valid_module`, add corpus replay, add automatic testcase reduction for non-pass failures, add first-class differential-validation CI profiles, and add runtime-budgeted adaptive profiles.
- Replace conservative legacy-exception lowering with semantic-preserving lowering to `try_table` and `throw_ref`.
- Investigate `Poppify`, standalone `Outlining`, and broader Binaryen pass parity as medium/low-priority optimizer follow-up.
- Tackle larger maintainability refactors: file splits for `typecheck`, `env`, `transformer`, `optimize`, `remove_unused`, and `parser`, plus `decode_instruction` helper decomposition.
- Long-horizon platform/features: Component Model/WIT, streaming decoder API, custom sections/source maps, and a plugin system.
