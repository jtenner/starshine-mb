# IR2 Test Matrix Repository Refresh

_Status:_ immutable repository-evidence bridge for [`docs/wiki/ir2/test-matrix.md`](../../ir2/test-matrix.md) and [`docs/wiki/raw/research/0064-2026-03-24-ir2-test-matrix.md`](../../raw/research/0064-2026-03-24-ir2-test-matrix.md)
_Captured:_ 2026-05-20

## Why this refresh exists

The living IR2 test matrix was last reconciled on 2026-05-13. Since then the `src/ir` package has accumulated broader HOT-body, builder, module-context, query, region-edit, walk, lowering-repro, SSA-policy, and white-box invariant coverage. This bridge records the in-tree proof surface so future wiki edits can cite one dated audit instead of treating the older March handoff as current by itself.

No new external source was needed for this refresh. The target is Starshine-local test placement and helper ownership, so the repository tests and helper modules are the primary source of truth. Existing algorithmic external context for local SSA remains in [`2026-05-20-local-ssa-source-bridge.md`](2026-05-20-local-ssa-source-bridge.md).

## Repository evidence checked

### Shared helper and golden layer

- [`src/ir/test_helpers.mbt`](../../../../src/ir/test_helpers.mbt) owns WAT-to-HOT fixture construction, verify/lower/validate checkpoints, and deterministic CFG/dominance/liveness/SSA dumps.
- [`src/ir/test_helpers_test.mbt`](../../../../src/ir/test_helpers_test.mbt) keeps the shared local-phi golden fixture plus lower/validate regression shapes.
- [`src/passes/pass_test_helpers.mbt`](../../../../src/passes/pass_test_helpers.mbt) owns pass-side WAT fixtures, public pass execution, first-function lifting, and trace capture helpers.
- [`src/passes/trace_golden_test.mbt`](../../../../src/passes/trace_golden_test.mbt) keeps the public optimizer trace golden.

### HOT ownership, construction, mutation, and traversal

- [`src/ir/architecture_test.mbt`](../../../../src/ir/architecture_test.mbt) checks revision increments and `HotPassDescriptor` analysis requirements/invalidations.
- [`src/ir/hot_builders_test.mbt`](../../../../src/ir/hot_builders_test.mbt) and [`src/ir/hot_builders_wbtest.mbt`](../../../../src/ir/hot_builders_wbtest.mbt) check typed builders for control, calls, memory, branch tables, select payloads, and lowering compatibility.
- [`src/ir/hot_core_wbtest.mbt`](../../../../src/ir/hot_core_wbtest.mbt), [`src/ir/hot_types_test.mbt`](../../../../src/ir/hot_types_test.mbt), [`src/ir/hot_labels_test.mbt`](../../../../src/ir/hot_labels_test.mbt), and [`src/ir/hot_labels_wbtest.mbt`](../../../../src/ir/hot_labels_wbtest.mbt) cover core ids, type interning, local metadata, label ownership, and branch arity.
- [`src/ir/hot_flags_test.mbt`](../../../../src/ir/hot_flags_test.mbt) and [`src/ir/hot_flags_wbtest.mbt`](../../../../src/ir/hot_flags_wbtest.mbt) check canonical flag helpers and conservative trap/side-effect flags.
- [`src/ir/hot_side_tables_test.mbt`](../../../../src/ir/hot_side_tables_test.mbt) and [`src/ir/hot_side_tables_wbtest.mbt`](../../../../src/ir/hot_side_tables_wbtest.mbt) check typed payload side tables for memargs, exact instructions, branch tables, catches, and opcode identity.
- [`src/ir/hot_module_context_test.mbt`](../../../../src/ir/hot_module_context_test.mbt) checks imported/defined index resolution, declared function-type slots, type-index block result expansion, aggregate field resolution, and immutable global constant initializers.
- [`src/ir/hot_mutate_test.mbt`](../../../../src/ir/hot_mutate_test.mbt) checks root/child mutation, batched replacement, tombstones, local appends, detached deletes, label rehoming, and lowering of appended locals.
- [`src/ir/hot_region_edit_test.mbt`](../../../../src/ir/hot_region_edit_test.mbt) checks root/body/then/else/catch region insert/remove/splice/set helpers.
- [`src/ir/hot_walk_test.mbt`](../../../../src/ir/hot_walk_test.mbt) checks deterministic root/child/subtree/worklist walks, skip/stop semantics, control-region walks, and child rewrite walkers.
- [`src/ir/hot_query_test.mbt`](../../../../src/ir/hot_query_test.mbt) checks family classification, branch metadata, read-only root/local/tombstone queries, simple-value keys, wrapper peeling, single-exit/branch-arm queries, payload splits, and repeated-shape detection.

### Lift, verify, lower, and CFG/analysis overlays

- [`src/ir/hot_lift_test.mbt`](../../../../src/ir/hot_lift_test.mbt) and [`src/ir/hot_lift_perf_test.mbt`](../../../../src/ir/hot_lift_perf_test.mbt) check exact-payload preservation, module-context lift, `try_table`, deep labels, stack-polymorphic/unreachable cases, multi-result bridges, and duplicated-control-entry stack behavior.
- [`src/ir/hot_lower_test.mbt`](../../../../src/ir/hot_lower_test.mbt) and [`src/ir/hot_lower_live_repro_test.mbt`](../../../../src/ir/hot_lower_live_repro_test.mbt) check broad lowering roundtrips plus saved live-repro carrier, payload, compare, call-spill, and wrapper families.
- [`src/ir/hot_verify_test.mbt`](../../../../src/ir/hot_verify_test.mbt) and [`src/ir/hot_verify_wbtest.mbt`](../../../../src/ir/hot_verify_wbtest.mbt) check valid HOT bodies plus core/control failure reporting.
- [`src/ir/cfg_test.mbt`](../../../../src/ir/cfg_test.mbt), [`src/ir/cfg_contract_test.mbt`](../../../../src/ir/cfg_contract_test.mbt), and [`src/ir/cfg_order_test.mbt`](../../../../src/ir/cfg_order_test.mbt) check concrete CFG shape, policy helpers, boundary classification, edge kinds, and deterministic traversal order.
- [`src/ir/dominators_test.mbt`](../../../../src/ir/dominators_test.mbt), [`src/ir/postdominators_test.mbt`](../../../../src/ir/postdominators_test.mbt), [`src/ir/loop_info_test.mbt`](../../../../src/ir/loop_info_test.mbt), [`src/ir/use_def_test.mbt`](../../../../src/ir/use_def_test.mbt), [`src/ir/liveness_test.mbt`](../../../../src/ir/liveness_test.mbt), and [`src/ir/liveness_wbtest.mbt`](../../../../src/ir/liveness_wbtest.mbt) check the main analysis overlays.
- [`src/ir/effects_test.mbt`](../../../../src/ir/effects_test.mbt) checks pure/memory/call/throw/trap/local-state summaries, region aggregation, and shared-DAG cache behavior.
- [`src/ir/analysis_cache_test.mbt`](../../../../src/ir/analysis_cache_test.mbt) checks cache reuse, dependency rebuild, and full invalidation by HOT revision.

### SSA overlays

- [`src/ir/ssa_policy_test.mbt`](../../../../src/ir/ssa_policy_test.mbt) checks entry/default/local-set origins, overlay-only phi metadata, liveness-pruned dominance-frontier placement, rename/destruction policy labels, v1 exclusions, and loop-header no-write skips.
- [`src/ir/ssa_local_test.mbt`](../../../../src/ir/ssa_local_test.mbt) checks local SSA construction over diamonds, loops, uninitialized locals, local tees, and unreachable predecessors.
- [`src/ir/ssa_destroy_test.mbt`](../../../../src/ir/ssa_destroy_test.mbt) checks predecessor-copy lowering, loop copies, synthetic continuations, cycle temps, dead-local cleanup, Binaryen temp-retention choices, unreachable carriers, and `br_table` result regions.

## Durable wiki implications

- The March numbered handoff remains useful historical/normative guidance, but the living matrix should cite this repository refresh and current test files as fresher coverage evidence.
- The matrix should split HOT-body mechanics from derived analyses. A future test author should be able to choose between builder/mutation/query/walk coverage, concrete CFG policy, analysis overlays, SSA policy/build/destroy, shared golden helpers, and public pass helpers.
- Whole-repo pass or validation signoff still belongs in the pass/tooling pages. The IR2 matrix is a placement and evidence map, not a replacement for Binaryen oracle comparison or `bun validate`.
