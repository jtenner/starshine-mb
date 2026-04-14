---
kind: concept
status: working
last_reviewed: 2026-04-14
sources:
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
related:
  - ./index.md
  - ./starshine-hot-ir-strategy.md
  - ./effect-ordering-and-barriers.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
---

# `simplify-locals` Implementation Map

## Why This Page Exists

- The other pages in this folder explain what the pass should do.
- This page explains where that behavior actually lives in tree.
- The maintenance goal is simple:
  - when a reducer fails, the next engineer should be able to jump from the observed shape to the owning helper cluster without re-reading the whole pass
  - when a new parity fix lands, the owning code path and the owning test lane should both be obvious

## Top-Level Ownership Split

- The implementation is split across three files with three different responsibilities:
  - [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt) owns the lifted HOT-IR pass
  - [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) owns the raw exact-instruction fast path, raw skip heuristics, and lowered exact cleanup glue
  - the pass-specific test surface is split across [`src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt), [`src/passes/pass_manager_wbtest.mbt`](../../../../../src/passes/pass_manager_wbtest.mbt), [`src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt), and the separate long perf lane [`src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`](../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt)
- If a change is semantic parity in lifted HOT IR, it usually belongs in `simplify_locals.mbt`.
- If a change is an artifact-specific exact rewrite or a skip-without-lift policy, it usually belongs in `pass_manager.mbt`.
- If a change only exists to erase lowered dead temp debris after writeback, it still belongs in the pass-manager cleanup side, not in the lifted pass proper.

## HOT Pass Entry Points

### Public Surface

- `simplify_locals_descriptor`
  - declares `simplify-locals` as a HOT pass
  - invalidates CFG, dominance, liveness, use-def, effects, loop info, and SSA
  - this is the first maintenance hint that the pass is not a narrow peephole; it rewrites enough structure and value flow to invalidate almost every local-flow analysis
- `simplify_locals_summary`
  - gives the public one-line intent
  - use this as the short truth when CLI or registry surfaces need a summary sentence

### Internal Driver

- `simplify_locals_run`
  - top-level lifted pass entry
  - calls the major phases in order
- `simplify_locals_run_main_cycle`
  - main sink-and-tee loop
  - owns the repeated linear scan behavior
- `simplify_locals_run_structure_rewrites`
  - structured return lifting and one-armed control cleanup
- `simplify_locals_run_equivalent_cleanup`
  - copied-local canonicalization after the main sink cycle
- `simplify_locals_run_dead_cleanup`
  - final local-dead cleanup inside the lifted pass

## Sinkable State And Effect Accounting

### Core Data Structures

- `SimplifyLocalsEffects`
  - effect mask plus sparse local-read and local-write footprints
- `SimplifyLocalsSinkableInfo`
  - one pending candidate per tracked local
- `SimplifyLocalsSinkables`
  - aggregate state for all currently-pending sink candidates
  - includes:
    - active entries
    - active local set
    - aggregate effect counters
    - sparse scratch-stamp arrays for local effect collection

### Aggregate Effect Helpers

- `simplify_locals_new_sinkables`
  - allocates pass-local state sized to the function's local count
- `simplify_locals_accumulate_effect_mask_counts`
- `simplify_locals_accumulate_local_effect_counts`
- `simplify_locals_sinkables_add_effects`
- `simplify_locals_sinkables_remove_effects`
- `simplify_locals_sinkables_have_effect`
- `simplify_locals_sinkables_may_conflict`
  - these helpers answer the central question for a pending local set:
    - can this candidate still move past the code we just scanned, or did some effect make the move illegal

### Entry Lifecycle Helpers

- `simplify_locals_sinkables_get`
- `simplify_locals_sinkables_set`
- `simplify_locals_sinkables_clear_local`
- `simplify_locals_sinkables_should_bulk_clear`
- `simplify_locals_sinkables_zero_aggregate_counts`
- `simplify_locals_clear_sinkables`
  - these helpers matter disproportionately on artifact-scale functions because naive whole-array clears showed up directly in runtime cost

## Exact Local-Effect Collection

### Sparse Local Tracking

- `simplify_locals_empty_effects`
- `simplify_locals_next_scratch_stamp`
- `simplify_locals_record_sparse_local_effect`
- `simplify_locals_record_exact_local_effects`
- `simplify_locals_collect_region_local_effects`
- `simplify_locals_collect_subtree_local_effects`

### Why This Cluster Matters

- This is the cluster that fixed the earlier sibling-argument and copied-local wrong-code families.
- The important design decision is that local effects are not approximated only from root flags.
- The pass explicitly walks through nested `if`, `try`, and `try_table` bodies to see local traffic that would otherwise be invisible to a shallow scan.

## Effect Mask Derivation And Ordering Logic

### Effect Classification

- `simplify_locals_effects_mask_for_flags`
- `simplify_locals_effects_mask_for_atomic_exact`
- `simplify_locals_effects_mask_for_heap_exact`
- `simplify_locals_effects_mask_for_exact_node`
- `simplify_locals_exact_local_read_id`
- `simplify_locals_exact_local_write_id`
- `simplify_locals_effects_for_pending_local_set`

### Ordering Rules

- `simplify_locals_effects_has`
- `simplify_locals_effects_has_local`
- `simplify_locals_effects_conflict_exact_local`
- `simplify_locals_effects_readonly_trap_commutable`
- `simplify_locals_effects_local_state_only`
- `simplify_locals_effects_ordered_before`

### Maintenance Rule

- If a new parity bug is about "this effectful thing should still commute" or "this pure-looking thing actually blocks motion," this is the first helper family to inspect.
- Do not patch around these bugs only in one rewrite caller if the real issue is classification or ordering itself.

## Node Construction And Region Navigation

### Tiny Constructors

- `simplify_locals_make_nop`
- `simplify_locals_make_drop`
- `simplify_locals_make_local_get`
- `simplify_locals_make_local_tee`
- `simplify_locals_make_local_set`

### Type And Liveness Helpers

- `simplify_locals_local_type_id`
- `simplify_locals_local_type_is_defaultable`
- `simplify_locals_region_last_live_non_nop_root_idx`
- `simplify_locals_region_prev_live_non_nop_root_idx`
- `simplify_locals_region_next_live_non_nop_root_idx`
- `simplify_locals_region_tail_local_set`
- `simplify_locals_build_one_armed_if_then_body`
- `simplify_locals_subtree_mentions_local`
- `simplify_locals_root_allows_moving_local_set_value_after`

### Why These Helpers Are Separate

- They encode the "shape surgery" part of the pass.
- Most parity diffs around `nop` sentinels, live prefix roots, and one-armed `if` tails end up flowing through these helpers before they reach the larger rewrite drivers.

## Structured Return-Rewrite Cluster

### Candidate Discovery

- `simplify_locals_collect_block_return_candidates`
- `simplify_locals_following_root_local_get_order`
- `simplify_locals_find_branch_exit_set_for_local`
- `simplify_locals_node_is_nonfallthrough_exit`
- `simplify_locals_region_is_unreachableish`
- `simplify_locals_control_has_typed_branch_payload`
- `simplify_locals_branch_payload_count`

### Forwarder And Wrapper Helpers

- `simplify_locals_build_i32_eqz`
- `simplify_locals_try_extract_stacked_forwarder_tail`
- `simplify_locals_try_rewrite_split_local_set_wrapper_forwarder`

### Concrete Rewriters

- `simplify_locals_collect_block_branch_exits`
- `simplify_locals_try_apply_block_return_candidate`
- `simplify_locals_region_has_branch_to_label`
- `simplify_locals_subtree_has_branch_to_label`
- `simplify_locals_subtree_has_typed_control`
- `simplify_locals_try_rewrite_block_return`
- `simplify_locals_try_rewrite_if_return`
- `simplify_locals_try_rewrite_loop_return`
- `simplify_locals_try_rewrite_nested_one_armed_if_child`
- `simplify_locals_try_rewrite_nested_one_armed_if_children`
- `simplify_locals_try_structure_rewrite_region`
- `simplify_locals_run_structure_rewrites`

### What To Look For

- Block-return parity bugs usually start in the candidate and branch-exit helpers.
- One-armed `if` parity bugs usually involve the `nop` and live-prefix root helpers.
- Loop-return bugs often trace back to branch-payload or nonfallthrough classification rather than to the final rewrite function itself.

## Main Sink-And-Tee Scan Cluster

### Eligibility Helpers

- `simplify_locals_node_targets_label`
- `simplify_locals_value_can_clone_node`
- `simplify_locals_value_can_move_one_use`
- `simplify_locals_value_can_tee`
- `simplify_locals_value_is_pure`
- `simplify_locals_value_is_child_inline_safe`

### Direct Consumers

- `simplify_locals_try_consume_following_local_get`
- `simplify_locals_try_inline_local_get_child`
- `simplify_locals_try_inline_leading_local_get_child`
- `simplify_locals_try_inline_following_local_get`

### Linear Scan And Mutation

- `simplify_locals_count_local_gets`
- `simplify_locals_mark_reachable`
- `simplify_locals_build_reachable_nodes`
- `simplify_locals_build_label_owner_nodes`
- `simplify_locals_delete_detached_nodes`
- `simplify_locals_record_local_set`
- `simplify_locals_scan_region`
- `simplify_locals_scan_node`

### Typical Debugging Interpretation

- If the bug is "a temp should have sunk but did not," inspect:
  - use counting
  - pending-candidate invalidation
  - child-inline safety
- If the bug is "we incorrectly created a tee" or "we moved an effectful producer too far," inspect:
  - `simplify_locals_value_can_tee`
  - `simplify_locals_value_can_move_one_use`
  - the exact ordering helpers

## Equivalent-Copy Cleanup Cluster

### State And Bookkeeping

- `simplify_locals_new_equivalences`
- `simplify_locals_clone_equivalences`
- `simplify_locals_clear_equivalences`
- `simplify_locals_reset_equivalent_local`
- `simplify_locals_equivalent_check`
- `simplify_locals_add_equivalence`
- `simplify_locals_equivalent_local_get_value`

### Type-Aware Selection

- `simplify_locals_type_env`
- `simplify_locals_local_type_is_subtype`
- `simplify_locals_get_count_ignoring_current`
- `simplify_locals_pick_best_equivalent_local`

### Walkers

- `simplify_locals_scan_equivalent_region`
- `simplify_locals_scan_equivalent_current`
- `simplify_locals_scan_equivalent_node`
- `simplify_locals_collect_equivalent_tee_defined_locals`
- `simplify_locals_equivalent_candidate_count`
- `simplify_locals_run_equivalent_cleanup`

### What This Cluster Owns

- copied-local canonicalization
- later best-source selection when multiple equivalent locals exist
- the tee-backed alias preservation versus collapse boundary

## Late Dead Cleanup Inside The HOT Pass

- `simplify_locals_run_dead_cleanup`
  - final lifted cleanup for dead locals that remain after the earlier transforms
- This phase is intentionally late because the earlier sink, structure, and equivalence steps can create new dead writes.
- Do not use the late dead cleanup as a place to hide ordering bugs from the main cycle. If an earlier transform is wrong, fix the earlier transform.

## Raw Lane And Exact Cleanup Ownership

### Raw Gating And Classification In `pass_manager.mbt`

- Shape and stat helpers:
  - `run_hot_pipeline_raw_simplify_locals_match_tail_local_get`
  - `run_hot_pipeline_raw_simplify_locals_has_local_write`
  - `run_hot_pipeline_raw_simplify_locals_scan_shape`
  - `run_hot_pipeline_raw_simplify_locals_gate_stats`
  - `run_hot_pipeline_raw_simplify_locals_take_statement_prefix_allow_escape`
    - now also owns the boundary that exposes a full escaping value tail to the pure-suffix dupable-copy reducer
- Skip heuristics:
  - `run_hot_pipeline_raw_simplify_locals_should_skip_*`
  - these own the artifact-family gates such as validator-heavy, dense structured helpers, parser-shaped churn, decode-shaped churn, and large straight-line builders
- Raw rewrites:
  - `run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_nested`
  - `run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_nested`
  - `run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails`
  - `run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested_fixpoint`
  - `run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets`
  - `run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets`
  - `run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees`
  - `run_hot_pipeline_raw_simplify_locals_rewrite_straight_line_lane_builder`
  - `run_hot_pipeline_raw_simplify_locals_try_rewrite_tail`
  - `run_hot_pipeline_raw_simplify_locals_rewrite_instrs`

### Post-Lower Exact Cleanup In `pass_manager.mbt`

- `run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_instr`
- `run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_instr`
- `run_hot_pipeline_simplify_locals_lowered_body_is_nonfallthrough`
- `run_hot_pipeline_simplify_locals_lowered_cleanup_instr`
- `run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs`
- `run_hot_pipeline_simplify_locals_lowered_cleanup_body`
- `run_hot_pipeline_simplify_locals_cleanup_exact_func`
- `run_hot_pipeline_simplify_locals_cleanup_lowered_func`

### Boundary Rule

- If the desired change only exists on lowered exact Wasm and should not alter lifted HOT semantics, keep it here.
- If the desired change changes when a value may move in semantic program order, it belongs in the lifted pass instead.

## Test Ownership Map

### `src/passes/simplify_locals_test.mbt`

- Owns reduced semantic families.
- Use this file for:
  - sink and tee reducers
  - structure-rewrite reducers
  - copied-local reducers
  - exact writeback reducers that are specific to simplify-locals behavior

### `src/passes/pass_manager_wbtest.mbt`

- Owns pass-manager gates and raw-lane whitebox behavior.
- Use this when the change is about:
  - raw skip reason selection
  - exact raw-lane tracing
  - artifact-shape gate acceptance or rejection

### `src/passes/perf_test.mbt`

- Owns the lean default performance-oriented synthetic families.
- Use this when the point is:
  - the pass should skip hot lift entirely
  - a no-op family should stay on a raw path
  - a named artifact-shaped churn family needs a stable synthetic guardian
  - the test should stay cheap enough for the normal `moon test src/passes` loop

### `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`

- Owns the intentionally slower multivalue stress families that were split out of `src/passes/perf_test.mbt`.
- Use this when the point is:
  - the raw multivalue ladder or flat-dense ladder shape still needs explicit synthetic coverage
  - the shape is useful for performance guardrails but too expensive for the default package test loop
  - the test should run only under the explicit `moon test src/passes_perf_long` command

## Maintenance Checklist

- When a new reducer lands, update the most specific page in this folder, not only the parity page.
- When a change touches raw gates, add or update a whitebox or perf test beside it.
- When a change touches lifted semantics, prefer a reduced `simplify_locals_test.mbt` case first, then fuzz.
- If you cannot name the owning helper cluster for a fix, the fix is probably too broad.
- If the fix only works because an escaping value tail became visible to an existing reducer, document that helper boundary here so later work does not misclassify it as a brand-new rewrite family.
