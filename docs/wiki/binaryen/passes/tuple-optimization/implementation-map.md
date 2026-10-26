---
kind: concept
status: supported
last_reviewed: 2026-09-01
sources:
  - ../reorder-locals/index.md
  - ../simplify-locals-nostructure/index.md
  - ./index.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ./parity.md
---

# `tuple-optimization` implementation map

## Why this page exists

- The other pages in this folder explain what `tuple-optimization` means.
- This page explains where that behavior actually lives in Starshine.
- The maintenance goal is simple:
  - when a reduced repro fails, the next engineer should be able to jump from the observed shape to the owning helper cluster quickly
  - when a new parity fix lands, the owning code path and the owning local test lane should both be obvious

## Top-level ownership split

- [`src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt) owns the HOT pass itself.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) owns pass-manager dispatch, the fail-closed raw multivalue-producer classifier, tuple-specific safety skips, and the debug trace hook that dumps tuple groups and the rewrite mask for a targeted function.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) owns registry exposure and the current public tuple/no-structure preset lane.
- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) proves the pass is still exposed as an active hot pass.
- [`src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt) is the main focused analysis-and-rewrite test file.
- [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) proves the public CLI path and lowered-module validity on committed reduced repros.
- [`src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt) is the direct Binaryen-oracle lane for committed reduced repros.

## Registry, dispatch, and preset locations

- `run_hot_pipeline_raw_tuple_block_may_produce_multivalue(...)`, `run_hot_pipeline_raw_tuple_instr_may_produce_multivalue(...)`, and `run_hot_pipeline_raw_tuple_has_multivalue_producer(...)` in `src/passes/pass_manager.mbt`
  - conservatively classify direct/indirect/reference calls and structured type-indexed results before HOT lifting
  - recurse through every structured body and treat unresolved type information as a possible candidate
- `run_hot_pipeline_raw_tuple_optimization_skip(...)` in `src/passes/pass_manager.mbt`
  - applies the candidate-free one-scan skip before the effect-bracketed-call and load/call/set safety fallbacks
- `src/passes/tuple_optimization.mbt:292`
  - `tuple_optimization_descriptor()`
  - declares the active hot-pass surface and invalidated analyses
- `src/passes/tuple_optimization.mbt:309`
  - `tuple_optimization_summary()`
  - one-line registry / help-text summary
- `src/passes/pass_manager.mbt:96322`
  - active hot-pass dispatch entry for `tuple-optimization`
- `src/passes/pass_manager.mbt`
  - targeted debug-trace hook that reruns tuple analysis and prints the rewrite mask for the traced function
- `src/passes/optimize.mbt:245`
  - registry entry in `pass_registry_entries()`
- `src/passes/optimize.mbt:622`
  - `tuple_optimization_exact_slot_prereqs_ready()`
  - current exact-slot gate now resolves against the active `code-pushing` and `simplify-locals-nostructure` neighbors
- `src/passes/optimize.mbt`
  - public preset lane: `code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs`
- `src/passes/optimize_test.mbt`
  - pipeline tests include active-pass admission and scalar-only behavior
- `src/passes/registry_test.mbt`
  - focused registry acceptance test

## Main HOT analysis clusters

### Seed-group discovery

- `src/passes/tuple_optimization.mbt:329`
  - `tuple_optimization_collect_seed_group(...)`
  - exact multivalue spill-bridge matcher
- `src/passes/tuple_optimization.mbt:398`
  - `tuple_optimization_collect_seed_groups(...)`
  - whole-function seed scan
- `src/passes/tuple_optimization.mbt:748`
  - `tuple_optimization_build_local_group_ids(...)`
  - local-to-group ownership map

### Copy-payload recovery and copy-group linking

- `src/passes/tuple_optimization.mbt:765`
  - `tuple_optimization_try_payload_source_read(...)`
- `src/passes/tuple_optimization.mbt:778`
  - `tuple_optimization_resolve_copy_payload_local(...)`
- `src/passes/tuple_optimization.mbt:828`
  - `tuple_optimization_collect_copy_payload_lane_nodes(...)`
- `src/passes/tuple_optimization.mbt:869`
  - `tuple_optimization_pick_copy_lane_source_node(...)`
- `src/passes/tuple_optimization.mbt:915`
  - `tuple_optimization_link_copy_groups(...)`
- `src/passes/tuple_optimization.mbt:1036`
  - `tuple_optimization_collect_result_block_copy_group(...)`
- `src/passes/tuple_optimization.mbt:1409`
  - `tuple_optimization_link_result_block_copy_groups(...)`
- `src/passes/tuple_optimization.mbt:1474`
  - `tuple_optimization_collect_scalar_forward_copy_group(...)`
- `src/passes/tuple_optimization.mbt:1620`
  - `tuple_optimization_link_scalar_forward_copy_groups(...)`

### Query-summary and forwarded-use analysis

- `src/passes/tuple_optimization.mbt:1699`
  - `tuple_optimization_build_query_summary(...)`
- `src/passes/tuple_optimization.mbt:1851`
  - `tuple_optimization_empty_query_summary()`
- `src/passes/tuple_optimization.mbt`
  - direct-use and forwarded-use predicates
  - this is the main local answer to “is this scalar traffic still behaving like one safe tuple bundle?”
- `src/passes/tuple_optimization.mbt:2317`
  - `tuple_optimization_finalize_host_lanes(...)`
- `src/passes/tuple_optimization.mbt:2364`
  - `tuple_optimization_find_overlap_lane_between_groups(...)`
- `src/passes/tuple_optimization.mbt:2391`
  - `tuple_optimization_count_lane_traffic(...)`
- `src/passes/tuple_optimization.mbt:2584`
  - `tuple_optimization_propagate_badness(...)`
- `src/passes/tuple_optimization.mbt`
  - `tuple_optimization_analyze_with_groups(...)` and `tuple_optimization_analyze(...)`
  - end-to-end analysis entry points

## Rewrite-planning clusters

- `src/passes/tuple_optimization.mbt:2775`
  - `tuple_optimization_group_should_rewrite(...)`
- `src/passes/tuple_optimization.mbt:2819`
  - `tuple_optimization_copy_group_redundant_with_source_host_chain(...)`
- `src/passes/tuple_optimization.mbt:2863`
  - `tuple_optimization_group_has_nested_rootslot_host_copy_wrapper(...)`
- `src/passes/tuple_optimization.mbt:3057`
  - `tuple_optimization_group_should_rewrite_in_func(...)`
- `src/passes/tuple_optimization.mbt:3144`
  - `tuple_optimization_build_group_rewrite_mask(...)`
- `src/passes/tuple_optimization.mbt:3232`
  - `tuple_optimization_ensure_split_locals(...)`
- `src/passes/tuple_optimization.mbt`
  - rewrite-order collection helpers
- `src/passes/tuple_optimization.mbt`
  - split-local allocation vs lane-local reuse policy

## Root-slot and carrier-placement clusters

- `src/passes/tuple_optimization.mbt:4010`
  - `tuple_optimization_find_root_slot_in_region(...)`
- `src/passes/tuple_optimization.mbt:4102`
  - `tuple_optimization_find_root_slot(...)`
- `src/passes/tuple_optimization.mbt:4208`
  - `tuple_optimization_pick_root_anchor_slot(...)`
- `src/passes/tuple_optimization.mbt`
  - passthrough-root-chain discovery and wrapper helpers
- `src/passes/tuple_optimization.mbt:4352`
  - `tuple_optimization_build_source_host_replacement(...)`
- `src/passes/tuple_optimization.mbt:4464`
  - `tuple_optimization_build_source_passthrough_init_root(...)`
- `src/passes/tuple_optimization.mbt:4520`
  - `tuple_optimization_build_source_root_anchor_replacement(...)`
- `src/passes/tuple_optimization.mbt:4552`
  - `tuple_optimization_build_tuple_make_from_locals(...)`
- `src/passes/tuple_optimization.mbt`
  - host-result and host-carrier builders
- `src/passes/tuple_optimization.mbt:4708`
  - `tuple_optimization_build_copy_host_replacement(...)`
- `src/passes/tuple_optimization.mbt`
  - copy-root-anchor and root-carrier builders

## Concrete rewrite and cleanup entry points

- `src/passes/tuple_optimization.mbt:5046`
  - `tuple_optimization_try_rewrite_root_host_copy_group_defs(...)`
- `src/passes/tuple_optimization.mbt:5147`
  - `tuple_optimization_try_rewrite_root_no_host_copy_group_defs(...)`
- `src/passes/tuple_optimization.mbt:5852`
  - `tuple_optimization_try_rewrite_root_source_group_defs(...)`
- `src/passes/tuple_optimization.mbt:6085`
  - `tuple_optimization_try_rewrite_anchor_host_copy_group_defs(...)`
- `src/passes/tuple_optimization.mbt:6369`
  - `tuple_optimization_try_rewrite_direct_scalar_copy_group_defs(...)`
- `src/passes/tuple_optimization.mbt:6413`
  - `tuple_optimization_rewrite_group_defs(...)`
- `src/passes/tuple_optimization.mbt:7131`
  - `tuple_optimization_rewrite_good_components(...)`
- `src/passes/tuple_optimization.mbt:7465`
  - `tuple_optimization_cleanup_drop_local_tees(...)`
- `src/passes/tuple_optimization.mbt:7577`
  - `tuple_optimization_cleanup_scalarized_tuple_locals(...)`
- `src/passes/tuple_optimization.mbt:7733`
  - `tuple_optimization_cleanup_unused_body_locals(...)`
- `src/passes/tuple_optimization.mbt:7877`
  - `tuple_optimization_prune_nops_in_region(...)`
- `src/passes/tuple_optimization.mbt:8207`
  - `tuple_optimization_cleanup_post_rewrite(...)`
- `src/passes/tuple_optimization.mbt:8336`
  - `tuple_optimization_run(...)`
  - top-level pass entry

## Test ownership map

### Focused pass tests

- `src/passes/tuple_optimization_wbtest.mbt`
  - seed-group, copy-group, badness, and host-tee basics
- `src/passes/tuple_optimization_wbtest.mbt`
  - scalar-forward, nested exact-copy, branch-exit, and scalar-result-carrier families
- `src/passes/tuple_optimization_wbtest.mbt`
  - one-hop forwarders, terminal host-lane families, and chained host-copy `tail-live0`
- `src/passes/tuple_optimization_wbtest.mbt`
  - via-binary suppression coverage plus mixed direct-producer scalar-forward families

### CLI / lowered-module validity lane

- `src/cmd/cmd_wbtest.mbt`
  - explicit CLI acceptance plus committed reduced repros on the lowered-module surface

### Native Binaryen-oracle lane

- `src/cmd/cmd_native_wbtest.mbt`
  - direct Binaryen compare lane for the same main reduced repro families plus debug-artifact spot checks

## Practical maintenance rule

- If a failure is about group formation, start in the seed-group and copy-payload clusters.
- If a failure is about whether a safe group should still stay scalar, start in the rewrite-mask helpers.
- If a failure is about wrong host-lane value flow, start in the root-slot and host-carrier builders.
- If a failure appears only after lowering or only in CLI/native compare lanes, jump straight from this page to the matching test block and then confirm whether the bug is in the HOT pass proper or in later materialization.
