---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0239-2026-04-21-tuple-optimization-starshine-code-map-followup.md
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
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) owns pass-manager dispatch plus one debug trace hook that dumps tuple groups and the rewrite mask for a targeted function.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) owns registry exposure and the current preset exclusion rule.
- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) proves the pass is still exposed as an active hot pass.
- [`src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt) is the main focused analysis-and-rewrite test file.
- [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) proves the public CLI path and lowered-module validity on committed reduced repros.
- [`src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt) is the direct Binaryen-oracle lane for committed reduced repros.

## Registry, dispatch, and preset locations

- `src/passes/tuple_optimization.mbt:97`
  - `tuple_optimization_descriptor()`
  - declares the active hot-pass surface and invalidated analyses
- `src/passes/tuple_optimization.mbt:114`
  - `tuple_optimization_summary()`
  - one-line registry / help-text summary
- `src/passes/pass_manager.mbt:8699`
  - active hot-pass dispatch entry for `tuple-optimization`
- `src/passes/pass_manager.mbt:7938-7946`
  - targeted debug-trace hook that reruns tuple analysis and prints the rewrite mask for the traced function
- `src/passes/optimize.mbt:212`
  - registry entry in `pass_registry_entries()`
- `src/passes/optimize.mbt:374-379`
  - `tuple_optimization_exact_slot_prereqs_ready()`
  - current exact-slot gate now resolves against the active `code-pushing` and `simplify-locals-nostructure` neighbors
- `src/passes/optimize.mbt:380-392`
  - explicit comment and code keeping `tuple-optimization` out of public presets for now, pending ordered-neighborhood replay proof
- `src/passes/registry_test.mbt:172-185`
  - focused registry acceptance test

## Main HOT analysis clusters

### Seed-group discovery

- `src/passes/tuple_optimization.mbt:134`
  - `tuple_optimization_collect_seed_group(...)`
  - exact multivalue spill-bridge matcher
- `src/passes/tuple_optimization.mbt:200`
  - `tuple_optimization_collect_seed_groups(...)`
  - whole-function seed scan
- `src/passes/tuple_optimization.mbt:228`
  - `tuple_optimization_build_local_group_ids(...)`
  - local-to-group ownership map

### Copy-payload recovery and copy-group linking

- `src/passes/tuple_optimization.mbt:245`
  - `tuple_optimization_try_payload_source_read(...)`
- `src/passes/tuple_optimization.mbt:268`
  - `tuple_optimization_resolve_copy_payload_local(...)`
- `src/passes/tuple_optimization.mbt:319`
  - `tuple_optimization_collect_copy_payload_lane_nodes(...)`
- `src/passes/tuple_optimization.mbt:360`
  - `tuple_optimization_pick_copy_lane_source_node(...)`
- `src/passes/tuple_optimization.mbt:396`
  - `tuple_optimization_link_copy_groups(...)`
- `src/passes/tuple_optimization.mbt:515`
  - `tuple_optimization_collect_result_block_copy_group(...)`
- `src/passes/tuple_optimization.mbt:844`
  - `tuple_optimization_link_result_block_copy_groups(...)`
- `src/passes/tuple_optimization.mbt:894`
  - `tuple_optimization_collect_scalar_forward_copy_group(...)`
- `src/passes/tuple_optimization.mbt:1039`
  - `tuple_optimization_link_scalar_forward_copy_groups(...)`

### Query-summary and forwarded-use analysis

- `src/passes/tuple_optimization.mbt:1118`
  - `tuple_optimization_build_query_summary(...)`
- `src/passes/tuple_optimization.mbt:1240`
  - `tuple_optimization_empty_query_summary()`
- `src/passes/tuple_optimization.mbt:1264-1680`
  - direct-use and forwarded-use predicates
  - this is the main local answer to “is this scalar traffic still behaving like one safe tuple bundle?”
- `src/passes/tuple_optimization.mbt:1702`
  - `tuple_optimization_finalize_host_lanes(...)`
- `src/passes/tuple_optimization.mbt:1749`
  - `tuple_optimization_find_overlap_lane_between_groups(...)`
- `src/passes/tuple_optimization.mbt:1776`
  - `tuple_optimization_count_lane_traffic(...)`
- `src/passes/tuple_optimization.mbt:1864`
  - `tuple_optimization_propagate_badness(...)`
- `src/passes/tuple_optimization.mbt:1901-1935`
  - `tuple_optimization_analyze_with_groups(...)` and `tuple_optimization_analyze(...)`
  - end-to-end analysis entry points

## Rewrite-planning clusters

- `src/passes/tuple_optimization.mbt:1955`
  - `tuple_optimization_group_should_rewrite(...)`
- `src/passes/tuple_optimization.mbt:1999`
  - `tuple_optimization_copy_group_redundant_with_source_host_chain(...)`
- `src/passes/tuple_optimization.mbt:2044`
  - `tuple_optimization_group_has_nested_rootslot_host_copy_wrapper(...)`
- `src/passes/tuple_optimization.mbt:2132`
  - `tuple_optimization_group_should_rewrite_in_func(...)`
- `src/passes/tuple_optimization.mbt:2282`
  - `tuple_optimization_build_group_rewrite_mask(...)`
- `src/passes/tuple_optimization.mbt:2322`
  - `tuple_optimization_ensure_split_locals(...)`
- `src/passes/tuple_optimization.mbt:2405-2429`
  - rewrite-order collection helpers
- `src/passes/tuple_optimization.mbt:2610-2676`
  - split-local allocation vs lane-local reuse policy

## Root-slot and carrier-placement clusters

- `src/passes/tuple_optimization.mbt:2684`
  - `tuple_optimization_find_root_slot_in_region(...)`
- `src/passes/tuple_optimization.mbt:2776`
  - `tuple_optimization_find_root_slot(...)`
- `src/passes/tuple_optimization.mbt:2793`
  - `tuple_optimization_pick_root_anchor_slot(...)`
- `src/passes/tuple_optimization.mbt:2830-2902`
  - passthrough-root-chain discovery and wrapper helpers
- `src/passes/tuple_optimization.mbt:2941`
  - `tuple_optimization_build_source_host_replacement(...)`
- `src/passes/tuple_optimization.mbt:3053`
  - `tuple_optimization_build_source_passthrough_init_root(...)`
- `src/passes/tuple_optimization.mbt:3109`
  - `tuple_optimization_build_source_root_anchor_replacement(...)`
- `src/passes/tuple_optimization.mbt:3141`
  - `tuple_optimization_build_tuple_make_from_locals(...)`
- `src/passes/tuple_optimization.mbt:3155-3250`
  - host-result and host-carrier builders
- `src/passes/tuple_optimization.mbt:3297`
  - `tuple_optimization_build_copy_host_replacement(...)`
- `src/passes/tuple_optimization.mbt:3394-3564`
  - copy-root-anchor and root-carrier builders

## Concrete rewrite and cleanup entry points

- `src/passes/tuple_optimization.mbt:3628`
  - `tuple_optimization_try_rewrite_root_host_copy_group_defs(...)`
- `src/passes/tuple_optimization.mbt:3727`
  - `tuple_optimization_try_rewrite_root_no_host_copy_group_defs(...)`
- `src/passes/tuple_optimization.mbt:3838`
  - `tuple_optimization_try_rewrite_root_no_host_source_group_defs(...)`
- `src/passes/tuple_optimization.mbt:3930`
  - `tuple_optimization_try_rewrite_anchor_host_copy_group_defs(...)`
- `src/passes/tuple_optimization.mbt:4199`
  - `tuple_optimization_try_rewrite_direct_scalar_copy_group_defs(...)`
- `src/passes/tuple_optimization.mbt:4242`
  - `tuple_optimization_rewrite_group_defs(...)`
- `src/passes/tuple_optimization.mbt:4750`
  - `tuple_optimization_rewrite_good_components(...)`
- `src/passes/tuple_optimization.mbt:4866`
  - `tuple_optimization_cleanup_drop_local_tees(...)`
- `src/passes/tuple_optimization.mbt:4948`
  - `tuple_optimization_cleanup_scalarized_tuple_locals(...)`
- `src/passes/tuple_optimization.mbt:5080`
  - `tuple_optimization_cleanup_unused_body_locals(...)`
- `src/passes/tuple_optimization.mbt:5184`
  - `tuple_optimization_prune_nops_in_region(...)`
- `src/passes/tuple_optimization.mbt:5256`
  - `tuple_optimization_cleanup_post_rewrite(...)`
- `src/passes/tuple_optimization.mbt:5268`
  - `tuple_optimization_run(...)`
  - top-level pass entry

## Test ownership map

### Focused pass tests

- `src/passes/tuple_optimization_wbtest.mbt:120-318`
  - seed-group, copy-group, badness, and host-tee basics
- `src/passes/tuple_optimization_wbtest.mbt:345-622`
  - scalar-forward, nested exact-copy, branch-exit, and scalar-result-carrier families
- `src/passes/tuple_optimization_wbtest.mbt:640-918`
  - one-hop forwarders, terminal host-lane families, and chained host-copy `tail-live0`
- `src/passes/tuple_optimization_wbtest.mbt:957-1109`
  - via-binary suppression coverage plus mixed direct-producer scalar-forward families

### CLI / lowered-module validity lane

- `src/cmd/cmd_wbtest.mbt:1998-2369`
  - explicit CLI acceptance plus committed reduced repros on the lowered-module surface

### Native Binaryen-oracle lane

- `src/cmd/cmd_native_wbtest.mbt:404-1281`
  - direct Binaryen compare lane for the same main reduced repro families plus debug-artifact spot checks

## Practical maintenance rule

- If a failure is about group formation, start in the seed-group and copy-payload clusters.
- If a failure is about whether a safe group should still stay scalar, start in the rewrite-mask helpers.
- If a failure is about wrong host-lane value flow, start in the root-slot and host-carrier builders.
- If a failure appears only after lowering or only in CLI/native compare lanes, jump straight from this page to the matching test block and then confirm whether the bug is in the HOT pass proper or in later materialization.
