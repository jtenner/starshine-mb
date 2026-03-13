# Agent Tasks

## Goal
Reach v0.1.0 "production-ready for MoonBit users" by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Scope
- This file tracks open work split into publishing blockers and post-0.1.0 follow-up.
- Items are ordered highest priority first within each section.
- Recent completed items are retained at the bottom until the next audit pass.

## Publishing blockers
- [ ] Optimize + Binaryen feature parity comparison: `SimplifyLocals`
- [ ] Optimize + Binaryen feature parity comparison: `RemoveUnusedBrs`
- [ ] Optimize + Binaryen feature parity comparison: `PrecomputePropagate`
- [ ] Optimize + Binaryen feature parity comparison: `CodePushing`
- [ ] Optimize + Binaryen feature parity comparison: `CodeFolding`
- [ ] Optimize + Binaryen feature parity comparison: `MergeBlocks`
- [ ] Replace the module-wide optimize pass loop with a Binaryen-style stacked function-parallel runner for the default optimization path.
- [ ] Replace the default-pipeline `DataflowOptimization` fallback with Binaryen-style `ssa-nomerge` parity behavior, or prove the substitution is runtime-safe on pathological functions.
- [ ] Implement `StringGathering` in the global post pipeline under the appropriate feature/optimization gates.
- [ ] Publish the first release and MoonBit registry package (`moon publish` plus GitHub Release binaries).

## Post 0.1.0 Features
- [ ] Add "StackState" to node traversal to event callbacks help with validation issues
- [ ] Replace deep-recursive native decode with a recursion-free control-instruction path for robust cross-platform behavior when `setrlimit` is unavailable.
- [ ] Add a native regression test for deep nested-control decode (or an equivalent non-recursive decoder benchmark fixture) to prevent stack-overflow regressions.
- [ ] Make `moduleToWast` output reliably parser-consumable in roundtrip tests.
- [ ] Reach `>=75%` line coverage on hot paths (decoder, IR lift, top passes).
- [ ] Add a shared memarg-alignment helper (`byte width -> alignment exponent`) and migrate pass code that still emits byte-count alignments directly.
- [ ] Audit asyncify-generated `MemArg` alignments across all rewritten instruction paths (including non-tail-call entrypoints) and add validator-backed tests per pointer width (`i32`/`i64` memory).
- [ ] Add `re_reloop` end-to-end coverage for internal loop-target `br_table` cases carrying branch values (non-empty `values`) to lock in typed value-flow behavior.
- [ ] Tune or replace `gen_valid_module` candidate generation for harness throughput so fewer candidates are discarded before the 100k valid target.
- [ ] Add persistent corpus replay workflow (`src/fuzz --replay-corpus <dir>`) and baseline corpus curation for deterministic regression locking.
- [ ] Add automatic testcase reduction for non-pass failures (module minimization + structured repro bundle beyond pass-list minimization).
- [ ] Add first-class differential-validation fuzz profiles in CI (toolchain install, adapters enabled, and mismatch triage artifacts).
- [ ] Introduce runtime-budgeted/adaptive fuzz profiles (target wall-clock budgets per suite instead of fixed iteration counts only).
- [ ] Replace conservative legacy-exception lowering with semantic-preserving lowering to `try_table`/`throw_ref` (the current path is static-validation oriented).
- [ ] `Poppify`.
- [ ] `Outlining` as a standalone pass (beyond current inlining partial-splitting behavior).
- [ ] Broad Binaryen pass parity backlog (medium/low priority pass list).
- [ ] Large refactors: file splits (`typecheck`/`env`/`transformer`/`optimize`/`remove_unused`/`parser`) and `decode_instruction` helper decomposition.
- [ ] Long-horizon platform/features: Component Model/WIT, streaming decoder API, custom sections/source maps, plugin system.

## Recently completed
- [x] Finish `Vacuum` Stage 3 fallback metadata specialization by replacing remaining unindexed `vq_type_of_cached(...)` / `vq_has_unremovable_effects_cached(...)` generic helper fallbacks with structural formulas (`vq_type_of_fallback_structural(...)`, `vq_instr_has_unremovable_effects_structural(...)`), removing unindexed `vq_collect_effects_timed(...)` fallback usage, and adding regression coverage for wrapped `local.tee` / typed-block type inference and wrapped `local.set` effect metadata without generic helper-call increments.
- [x] Continue `Vacuum` Stage 3 fallback cleanup/value-break reduction by replacing unindexed cached depth-0 break and value-break fallback collectors with structural local summaries (`vq_texpr_may_target_break_to_depth0(...)` and `vq_has_value_break_lub_depth0_fallback(...)`), including `try_table` catch-label depth targeting coverage, so targeted unindexed fallback checks avoid generic break/value-break scan helpers.
- [x] Continue `Vacuum` Stage 3 fallback metadata specialization by replacing unindexed `vq_instr_effect_transfers_control_flow_cached(...)` generic effect-collector fallback with a structural branch/throw detector (`vq_instr_effect_transfers_control_flow_structural(...)`) and regression coverage that verifies wrapped branch-transfer trees skip `collect_effects` fallback calls.
- [x] Continue `Vacuum` Stage 3 fallback metadata specialization by replacing unindexed fallback `vq_instr_has_calls_cached(...)` generic effect-collector use with an exact structural call detector (`vq_instr_has_calls_structural(...)`) and adding regression coverage that verifies wrapped non-call leaves avoid `collect_effects` fallback calls.
- [x] Continue `Vacuum` Stage 3 fallback-scan/value-break reduction by adding bounded unindexed target summaries (`may target depth-0 break` / `may target depth-0 value break`) so fallback helpers skip expensive generic scans when labels exist but cannot hit the queried depth/value shape.
- [x] Continue `Vacuum` Stage 3 fallback metadata specialization by adding unindexed pure-leaf fast paths in `vq_type_of_cached(...)`, `vq_has_unremovable_effects_cached(...)`, `vq_has_unremovable_shallow_effects_cached(...)`, `vq_instr_has_calls_cached(...)`, and `vq_instr_effect_transfers_control_flow_cached(...)` to avoid generic helper calls on trivial rewritten leaves.
- [x] Continue `Vacuum` Stage 3 rewrite-guard optimization by replacing hot-path drop-rewrite uses of `vq_rewrite_preserves_stack_sig_cached(...)` with a child-signature local formula guard and using generic rewrite-stack checks only as uncommon fallback when the local guard rejects.
- [x] Continue `Vacuum` Stage 3 fallback-scan reduction by adding expression-level unindexed fast paths in `vq_has_break_to_depth0_cached(...)` and `vq_has_value_break_lub_depth0_cached(...)`, so multi-item label-free rewritten trees skip generic fallback collectors.
- [x] Continue pathological `Vacuum` fallback cleanup by adding an unindexed single-item fast path in `vq_has_value_break_lub_depth0_cached` so label-free trees skip expensive value-break LUB collection, with regression coverage on helper-call counters.
- [x] Continue pathological `Vacuum` fallback cleanup by deduplicating unindexed wrapper-collapse rebase-score analysis across break-check and rebase-gate paths, and by adding explicit helper-level rebase-score timing/call metrics.
- [x] Continue pathological `Vacuum` hot-path cleanup by restructuring `vq_simplify_block_to_contents` to run depth-0 break scans only for single-item collapse candidates and by adding unindexed no-scan guards for label-free/depth-local cases.
- [x] Continue pathological `Vacuum` wrapper-collapse hardening by replacing generic label-rebase transformer walks with a custom recursive rebase walker and by skipping rebasing for unindexed rewritten single-item bodies when their local rebase-label score proves no label adjustment is needed.
- [x] Harden pathological `Vacuum` cleanup handling beyond the no-op rerun skip heuristic by adding bounded shape-aware seed/optimize/degraded tiers and removing value-keyed fallback caches (`TExpr` and `TInstr`) from hot metadata queries.
- [x] Complete fuzz runner usability blockers: add `src/fuzz` control commands (`--help`/`--list-suites`/`--list-profiles`) so users can discover suites/profiles directly from the binary.
- [x] Complete fuzz output blocker: add `jsonl` output mode in `src/fuzz` (`--output jsonl` / `--jsonl`) with machine-readable per-suite summary lines.
- [x] Complete fuzz script-seed blocker: make `scripts/run-fuzz.sh` and `scripts/run-full-test.sh` treat seed as optional and only pass `--seed` when explicitly provided.
- [x] Split the local `ConstantFieldPropagation` / `cfp-reftest` behavior so plain CFP now only handles constant field reads and the narrower known-null `ref.test` cleanup lives in `ConstantFieldNullTestFolding` with explicit scheduler/docs coverage.
