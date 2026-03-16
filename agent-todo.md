# Agent Tasks

## Goal
Reach v0.1.0 "production-ready for MoonBit users" by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Scope
- This file tracks open work split into publishing blockers and post-0.1.0 follow-up.
- Items are ordered highest priority first within each section.
- Recent completed items are retained at the bottom until the next audit pass.

## Publishing blockers
### `SimplifyLocals` work plan
- [ ] `SL-01` / `ID-C1`: preserve prior sinkables when an intermediate `local.get` reads the destination local.
- [ ] `SL-02` / `ID-C2`: keep `local.get` counts exact after structure rewrites that add or remove gets.
- [ ] `SL-03` / `ID-P1`: support `if` result structuring when one arm is unreachable.
- [ ] `SL-04` / `ID-P2`: preserve fixpoint-cycle behavior that unlocks later sinks without oscillation.
- [ ] `SL-05` / `ID-P3`: keep loop-result structuring parity for eligible loops and reject `br 0` loops.
- [ ] `SL-06` / `ID-P4`: allow subtype-safe single-use sinking without widening or invalidating local types.
- [ ] `SL-07` / `ID-P5`: keep subtype-aware late canonicalization correct for both small and large local arrays.
- [ ] `SL-08`: keep conditional `br_if` value/block-return structuring legal, typed, and effect-order-safe.
- [ ] `SL-09`: keep supported single-target `br_table` block-exit coalescing and reject unsupported shapes.
- [ ] `SL-10`: preserve typed rewrite validation, repair, and rejection accounting for rewritten functions.
- [ ] `SL-11` / `ID-F1`: bound main-phase effect recomputation with shared cached effect analysis.
- [ ] `SL-12`: keep pathological/wide-local guards fast, explicit, and non-destructive on safe inputs.
- [ ] `SL-13` / `ID-F2`: reduce invalidation-scan overhead below naive active-sinkables-per-instruction behavior.
- [ ] `SL-14` / `ID-F3`: reuse get-count state across fixpoint cycles without stale-count regressions.
- [ ] `SL-15` / `ID-F4`: avoid unnecessary late-phase state cloning on nested branch-heavy bodies.
- [ ] `SL-16`: sign off `SimplifyLocals` pipeline placement and five-variant scheduler parity in `optimize.mbt`.
- [ ] `SL-17`: close the `SimplifyLocals` parity/performance matrix with explicit tests, divergences, and rerun commands.
- [ ] Optimize + Binaryen feature parity comparison: `RemoveUnusedBrs`
- [ ] Optimize + Binaryen feature parity comparison: `PrecomputePropagate`
- [ ] Optimize + Binaryen feature parity comparison: `CodePushing`
- [ ] Optimize + Binaryen feature parity comparison: `CodeFolding`
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
- [x] `MergeBlocks` parity signoff: reran the in-tree parity matrix, classified every row as `Match` or documented `Intentional divergence` (with explicit divergence rationale rows for non-validating `try_table` fixtures), recorded signoff metrics in the plan completion notes, ran final gates (`moon info && moon fmt`, `moon test`), and moved the parity plan from `docs/plans/active` to `docs/plans/done`.
- [x] `MergeBlocks` parity test matrix: added an explicit parity-matrix harness in `merge_blocks_parity_wbtest.mbt` with per-row expected outcomes and assertions covering named block merge boundaries, loop-tail extraction, dropped-block value removal, `try_table` catch permutations, restructure dependency/effect collisions, type/stack-signature invariants, and idempotence (`run_merge_blocks` once vs twice), using strict red/green TDD.
- [x] `MergeBlocks` performance P-005: replaced `optimize_block(...)` round commit replay (`curr_items.clear()` + push-all copy) with staged mutable buffers and swap-based round assembly, added per-function round-assembly stats (`optimize_block_round_buffer_swaps`, `optimize_block_round_rebuild_copies`), and locked stress coverage requiring representative positive swap counts with zero rebuild-copy replays.
- [x] `MergeBlocks` performance P-004: removed non-control restructure `eval_children(...).to_array()` materialization from `mb_restructure_non_control(...)` in favor of direct child iteration, added per-function non-control child-iteration stats (`non_control_child_iteration_steps`, `non_control_child_array_materializations`), and locked stress coverage that requires representative zero materializations while still exercising non-control child traversal.
- [x] `MergeBlocks` performance P-003: replaced structural-hash branch query cache keys with identity-backed instruction ids plus generation-scoped query keys, added explicit rewrite-round cache invalidation boundaries, and locked branch-cache regressions for clone-key non-aliasing, invalidation miss behavior, and representative stress hit-rate targets (`>=80%`).
- [x] `MergeBlocks` performance P-002: added per-function `compute_effects` memoization in `MBContext` keyed by stable instruction key (`MBStableInstrKey` over `TInstr` identity/equality), routed MergeBlocks hot-path effect queries through the cache (`mb_compute_effects_cached`), exposed cache hit/miss stats in `MBFunctionRunStats`, and locked a stress fixture that verifies cached execution improves wall time by at least 15% versus uncached execution.
- [x] `MergeBlocks` runtime gap: documented and justified an intentional sequential-execution divergence for `MergeBlocks` by locking a runtime policy note (`mb_runtime_execution_policy_note()`) to current transformer constraints (`walk_opt_codesec_default` -> `walk_opt_array` state threading), adding regression coverage so the rationale remains explicit until function-parallel dispatch is available in the local pass runner.
- [x] `MergeBlocks` correctness gap C-004: replaced the fixed 20-round `optimize_block` loop with convergence-driven iteration plus safety-cap instrumentation (`optimize_block_rounds`, `optimize_block_round_cap_hits`) and added deep-nesting + forced-cap regression coverage, including a cap-override stats runner to verify non-silent truncation signaling.
- [x] `MergeBlocks` correctness gap C-003: ported Binaryen-compatible loop partial-merge gating to extracted-tail concreteness (`keepEnd < childSize && childList.back()->type.isConcrete()` parity) and added typed loop fixtures that separate unsound concrete-tail extraction (blocked) from valid non-concrete-tail extraction (allowed) while preserving post-pass validation.
- [x] `MergeBlocks` effect-model hardening: filled missing `mb_collect_shallow_effects` tags for trap/atomic families (`memory.copy/fill/init` trap flags, `ref.cast_desc_eq`, `array.len`, `array.new*` trap flags, `array.set/fill` read+write memory, atomic memory ops, integer `div/rem` trap ops, float->int trunc trap ops) and added a table-driven movement matrix regression (`MBMovementCase`) that locks representative blocked/allowed movement behavior for side-effect, trap, branch, and control-transfer opcode families.
- [x] `MergeBlocks` correctness gap C-002: added an explicit motion-barrier opcode-effect checklist (`mb_effect_checklist_entries()`) for `mb_collect_shallow_effects`, added checklist-stability and checklist-vs-collector regression tests, and locked the expected effect signature surface for all currently tagged MergeBlocks barrier opcode families.
- [x] `MergeBlocks` dropped-block parity: added exhaustive dropped-path `try_table` fixtures across catch forms (`catch_ref` without params allowed+rewritten, `catch`/`catch_all` targeting origin blocked, paramful `catch_ref` blocked including nested dropped context), added a nested-drop `br_if` legality regression to ensure outer-label value branches are preserved, and fixed `problem_finder` to traverse non-direct `drop(...)` values so nested dropped-path blockers are honored before rewriting.
- [x] `MergeBlocks` parity baseline: added a dedicated parity fixture corpus in `src/passes/merge_blocks_parity_wbtest.mbt`, added a fixed-corpus timing harness (`mbp_time_fixed_corpus_us(iterations)`), and locked baseline correctness/performance snapshot checks (`fixtures=8`, `changed=5`, `valid_after=8`, `idempotent=8`, `value_branch_after=0`, timing harness elapsed `> 0` on fixed iterations).
- [x] `MergeBlocks` correctness gap C-001: switched dropped-block `problem_finder` analysis from per-top-level-child traversal to whole-body traversal and aligned `br_if` accounting with Binaryen-style dropped-vs-non-dropped balancing (`non_dropped_br_if_values > dropped_br_if_values` blocks); added regression coverage for globally balanced sibling `drop(br_if ...)` + non-dropped `br_if` cases and verified break values are stripped when optimization proceeds.
- [x] `MergeBlocks` performance P-001: collapse refinalization to a single per-function gate (`needs_refinalize || changed`) by routing function execution through a stats-backed helper and running one refinalization pass per changed/needs-refinalize function; added failing-first regression coverage proving refinalize invocation count stays at `1` for a function that triggers both `changed` and `needs_refinalize`.
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
