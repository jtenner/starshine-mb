# Agent Tasks

## Scope
- Keep only unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Keep each slice actionable enough to implement directly without re-deriving the architecture.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice

### IR2 - 210 - Liveness
- Goal:
  Compute block `live_in` and `live_out` sets for locals.
- Why this slice exists:
  SSA placement and dead local cleanup depend on local liveness.
- Concrete deliverables:
  - `src/ir/liveness.mbt`.
  - `src/ir/liveness_test.mbt`.
- Detailed implementation tasks:
  - Implement backward local-liveness dataflow using block defs/uses and CFG successors.
  - Keep the policy explicit that liveness is locals-only.
  - Add `local_live_in` and `local_live_out` queries.
  - Document whether exceptional edges are included and keep it consistent with SSA.
- Required utilities / APIs:
  - `liveness_build(cfg, use_def)`.
  - `live_in(liveness, block_id)`.
  - `live_out(liveness, block_id)`.
  - `local_live_in(liveness, block_id, local_id)`.
  - `local_live_out(liveness, block_id, local_id)`.
- Invariants / correctness rules:
  - `live_in = uses ∪ (live_out - defs)`.
  - Overlay invalidates on CFG/local mutation.
- Dependencies:
  - IR2 - 150 - CFG Construction.
  - IR2 - 165 - Dataflow Bitset Utilities.
  - IR2 - 200 - Use-Def.
- Exit criteria:
  - Liveness works on joins and loops.
- Suggested tests:
  - Diamond join liveness.
  - Loop-carried local liveness.
  - Exceptional-edge inclusion policy coverage.

### IR2 - 220 - Effect Summaries
- Goal:
  Compute derived effect summaries for nodes, blocks, and regions.
- Why this slice exists:
  Passes need more than raw node flags to decide purity, motion safety, and exceptional behavior.
- Concrete deliverables:
  - `src/ir/effects.mbt`.
  - `src/ir/effects_test.mbt`.
- Detailed implementation tasks:
  - Define `EffectMask` categories for memory, table, global/local state, calls, throws, traps, and control effects.
  - Build per-node summaries from raw flags and typed payload knowledge.
  - Build per-block and per-region summaries.
  - Add convenience purity and may-throw predicates.
  - Keep raw flags and derived summaries as separate layers.
- Required utilities / APIs:
  - `effects_for_node(func, node_id)`.
  - `effects_for_block(func, cfg, block_id)`.
  - `effects_for_region(func, region_ref)`.
  - `effects_is_pure(mask)`.
  - `effects_may_throw(mask)`.
  - `effects_reads_memory(mask)`.
  - `effects_writes_memory(mask)`.
- Invariants / correctness rules:
  - Summaries conservatively over-approximate behavior.
  - Overlay is invalid on revision change.
  - Exceptional-edge semantics stay consistent with CFG policy.
- Dependencies:
  - IR2 - 020 - Hot IR Flags Model.
  - IR2 - 090 - Hot IR Traversal Utilities.
  - IR2 - 150 - CFG Construction.
- Exit criteria:
  - Passes can ask node/block/region purity and memory/throw properties through shared APIs.
- Suggested tests:
  - Pure arithmetic vs stateful memory ops.
  - Call/throw/trap effect categories.
  - Region/block summary aggregation.

### IR2 - 230 - SSA Design Policy
- Goal:
  Lock the local-SSA-only overlay policy so construction and destruction are unambiguous.
- Why this slice exists:
  Without a policy slice, future agents could accidentally introduce a second owned IR.
- Concrete deliverables:
  - SSA policy ADR under `docs/`.
  - `src/ir/ssa_policy.mbt`.
  - `src/ir/ssa_policy_test.mbt`.
- Detailed implementation tasks:
  - Define scope: locals-only SSA overlay, not a new owned body representation.
  - Define `SsaValueId`, `PhiId`, `HotLocalSsa`, and def/use categories.
  - Define phi placement at block entries using dominance frontiers pruned by liveness.
  - Define parameter and default-local-init entry definitions.
  - Define rename and destruction policies.
  - State what SSA v1 excludes.
- Required utilities / APIs:
  - `SsaValueId`, `PhiId`, `HotLocalSsa`.
  - `ssa_value_type(ssa, value_id)`.
  - `ssa_value_origin(ssa, value_id)`.
  - `ssa_phi_block(ssa, phi_id)`.
  - `ssa_phi_local(ssa, phi_id)`.
  - `ssa_default_init_def(local_id)`.
- Invariants / correctness rules:
  - Hot IR remains ordinary local ops plus other hot nodes.
  - Phi nodes exist only in the overlay, not as persistent hot nodes.
  - Every SSA value has one defining origin.
- Dependencies:
  - IR2 - 170 - Dominators.
  - IR2 - 200 - Use-Def.
  - IR2 - 210 - Liveness.
- Exit criteria:
  - SSA construction/destruction slices can execute without re-deciding scope or policy.
- Suggested tests:
  - Parameter/default-init entry-def classification.
  - Phi-placement policy on a diamond.
  - Policy rejection of permanent phi nodes in `HotFunc`.

### IR2 - 240 - Local SSA Construction
- Goal:
  Build the local SSA overlay from hot IR + CFG + dominance + liveness.
- Why this slice exists:
  SSA-assisted passes need precise reaching definitions for locals.
- Concrete deliverables:
  - `src/ir/ssa_local.mbt`.
  - `src/ir/ssa_local_test.mbt`.
- Detailed implementation tasks:
  - Place local phis using dominance frontiers pruned by liveness.
  - Create synthetic entry defs for parameters and default local initialization.
  - Run dominator-tree rename for `LocalGet`, `LocalSet`, and `LocalTee`.
  - Record phi incoming values per predecessor.
  - Record mappings from hot local nodes to SSA defs/uses.
  - Add query helpers for reaching def, phi lists, phi inputs, and uses of SSA values.
- Required utilities / APIs:
  - `ssa_build_local(func, cfg, dom, liveness, use_def)`.
  - `ssa_value_for_local_get(ssa, node_id)`.
  - `ssa_def_for_local_set(ssa, node_id)`.
  - `ssa_phis_for_block(ssa, block_id)`.
  - `ssa_phi_inputs(ssa, phi_id)`.
  - `ssa_uses_of_value(ssa, value_id)`.
- Invariants / correctness rules:
  - Every `LocalGet` maps to exactly one SSA value.
  - Every SSA value has one defining origin.
  - Phi input counts match predecessor counts under the chosen edge policy.
- Dependencies:
  - IR2 - 170 - Dominators.
  - IR2 - 200 - Use-Def.
  - IR2 - 210 - Liveness.
  - IR2 - 230 - SSA Design Policy.
- Exit criteria:
  - Local SSA overlay works for joins, loops, parameters, default-init locals, and `LocalTee`.
- Suggested tests:
  - Diamond local merge phi.
  - Loop-carried local phi.
  - Uninitialized-local use resolves to default-init entry def.

### IR2 - 250 - SSA Destruction
- Goal:
  Lower SSA-driven rewrites back into ordinary local ops inside hot IR.
- Why this slice exists:
  The architecture requires plain hot IR as the optimizer body after SSA-assisted work.
- Concrete deliverables:
  - `src/ir/ssa_destroy.mbt`.
  - `src/ir/ssa_destroy_test.mbt`.
- Detailed implementation tasks:
  - Lower block-entry phis to predecessor copies or structured edge-local copies.
  - Define critical-edge handling policy consistent with structured region editing.
  - Allocate fresh locals when required for safe materialization.
  - Rewrite `LocalGet` uses and insert `LocalSet` nodes as needed.
  - Remove dead local defs created during destruction.
  - Invalidate/rebuild analyses after destruction.
- Required utilities / APIs:
  - `ssa_destroy_into_hot(func, cfg, ssa, policy?)`.
  - `ssa_assign_concrete_locals(ssa, func.locals)`.
  - `ssa_insert_predecessor_copies(func, region_ref, predecessor_block, copies)`.
  - `ssa_rewrite_local_use(func, node_id, local_id)`.
  - `ssa_remove_dead_local_defs(func, dead_nodes)`.
- Invariants / correctness rules:
  - No phi artifacts remain in `HotFunc`.
  - Fresh locals have correct types and metadata.
  - Structured region semantics are preserved during copy insertion.
- Dependencies:
  - IR2 - 100 - Hot IR Region Editing Utilities.
  - IR2 - 150 - CFG Construction.
  - IR2 - 230 - SSA Design Policy.
  - IR2 - 240 - Local SSA Construction.
- Exit criteria:
  - SSA-assisted passes can reliably return to plain hot IR.
- Suggested tests:
  - Diamond phi destruction to predecessor copies.
  - Loop-header phi destruction.
  - Fresh temporary local allocation coverage.

### IR2 - 260 - Analysis Invalidation / Caching
- Goal:
  Provide one shared cache for derived analyses keyed to `HotFunc.revision`.
- Why this slice exists:
  CFG, dominance, liveness, effects, and SSA need safe reuse without stale overlay bugs.
- Concrete deliverables:
  - `src/ir/analysis_cache.mbt`.
  - `src/ir/analysis_cache_test.mbt`.
- Detailed implementation tasks:
  - Define cache entries for CFG, orders, dominators, post-dominators, loop info, use-def, liveness, effects, and SSA.
  - Store `built_at_revision` for each entry.
  - Add typed `get_or_build_*` helpers.
  - Use conservative invalidation on any semantic mutation for v1.
  - Add explicit cache drop/reset helpers.
- Required utilities / APIs:
  - `HotAnalysisCache`.
  - `cache_get_or_build_cfg(cache, func)`.
  - `cache_get_or_build_dom(cache, func)`.
  - `cache_get_or_build_postdom(cache, func)`.
  - `cache_get_or_build_loop_info(cache, func)`.
  - `cache_get_or_build_use_def(cache, func)`.
  - `cache_get_or_build_liveness(cache, func)`.
  - `cache_get_or_build_effects(cache, func)`.
  - `cache_get_or_build_ssa(cache, func)`.
  - `cache_invalidate_all(cache)`.
- Invariants / correctness rules:
  - Cached overlays are never reused across revision changes.
  - Mutation primitives are the only source of revision change.
  - Cache getters build dependencies internally rather than pushing that burden to passes.
- Dependencies:
  - IR2 - 150 - CFG Construction.
  - IR2 - 170 - Dominators.
  - IR2 - 180 - Post-Dominators.
  - IR2 - 190 - Loop Info.
  - IR2 - 200 - Use-Def.
  - IR2 - 210 - Liveness.
  - IR2 - 220 - Effect Summaries.
  - IR2 - 240 - Local SSA Construction.
- Exit criteria:
  - Passes can request derived analyses safely from one cache object.
- Suggested tests:
  - Reuse without mutation.
  - Rebuild after child/root mutation.
  - Reject or rebuild stale overlay use.

### IR2 - 270 - Pipeline Orchestration
- Goal:
  Replace compatibility-only pass execution with the real hot-IR pass manager and optimization pipeline.
- Why this slice exists:
  `src/cmd/cmd.mbt` still routes many pass names through compatibility expansion and no-op execution.
- Concrete deliverables:
  - `src/passes/optimize.mbt`.
  - `src/passes/pass_manager.mbt`.
  - `src/passes/optimize_test.mbt`.
  - `src/cmd/cmd.mbt` rewired to the real pipeline.
- Detailed implementation tasks:
  - Define pass descriptor, pass context, pass result, and analysis requirement metadata.
  - Implement the pipeline sequence `lift -> verify -> run passes -> verify checkpoints -> lower -> optional module validation`.
  - Support optimize/shrink presets and explicit pass lists through one registry.
  - Integrate tracing/timing hooks aligned with `docs/0001-2026-03-10-tracing.md`.
  - Remove the fiction that deleted pass layers execute real work.
- Required utilities / APIs:
  - `run_hot_pipeline(module, options, requested_passes)`.
  - `HotPassDescriptor`.
  - `hot_pass_requires(descriptor)`.
  - `hot_pass_invalidates(descriptor)`.
  - `hot_pass_run(ctx, func)`.
  - `pipeline_verify_checkpoint(policy, func/module)`.
  - `pipeline_trace_hook(pass_name, event, payload)`.
- Invariants / correctness rules:
  - Every hot pass runs on verified hot IR.
  - Analysis invalidation flows through revision/cache semantics.
  - CLI/pass reporting only describes real execution.
- Dependencies:
  - IR2 - 110 - Hot IR Verification Utilities.
  - IR2 - 120 - Boundary -> Hot Lifting.
  - IR2 - 130 - Hot -> Boundary Lowering.
  - IR2 - 260 - Analysis Invalidation / Caching.
- Exit criteria:
  - CLI optimize paths call the real hot-IR pass manager.
- Suggested tests:
  - Real pass execution order on a small pipeline.
  - Verification checkpoint policy coverage.
  - Trace markers for hot passes.

### IR2 - 280 - Pass Migration Support
- Goal:
  Provide shared scaffolding and migration rules for porting optimizer passes onto IR2.
- Why this slice exists:
  Future agents need reusable pass helpers and a strict checklist instead of per-pass reinvention.
- Concrete deliverables:
  - `src/passes/pass_common.mbt`.
  - `src/passes/pass_test_helpers.mbt`.
  - Pass-porting checklist doc under `docs/`.
  - `src/passes/pass_common_test.mbt`.
- Detailed implementation tasks:
  - Add helpers for subtree peephole replacement, worklist rewrites, CFG-local rewrites, and SSA-assisted rewrites.
  - Add pass-author helpers for requesting analyses, marking mutation, and verify-before/after flow.
  - Add common dead-node cleanup and use-count predicates.
  - Centralize pass registry/dispatch instead of scattering it across CLI code.
  - Add shared fixture helpers for pass tests.
- Required utilities / APIs:
  - `pass_require_cfg(ctx)`.
  - `pass_require_dom(ctx)`.
  - `pass_require_liveness(ctx)`.
  - `pass_require_ssa(ctx)`.
  - `pass_mark_mutated(ctx, func)`.
  - `pass_replace_node(ctx, func, node_id, new_node)`.
  - `pass_splice_region(ctx, func, region_ref, idx, remove_count, nodes)`.
  - `pass_verify_before_after(ctx, func)`.
- Invariants / correctness rules:
  - Shared helpers only use public mutation/query APIs.
  - Pass descriptors truthfully declare requirements and invalidations.
  - CLI-visible pass ids come from one registry.
- Dependencies:
  - IR2 - 090 - Hot IR Traversal Utilities.
  - IR2 - 100 - Hot IR Region Editing Utilities.
  - IR2 - 200 - Use-Def.
  - IR2 - 220 - Effect Summaries.
  - IR2 - 260 - Analysis Invalidation / Caching.
  - IR2 - 270 - Pipeline Orchestration.
- Exit criteria:
  - Future pass ports can start from shared helpers instead of rebuilding boilerplate.
- Suggested tests:
  - Peephole helper mutation/invalidation behavior.
  - Missing-analysis failure behavior.
  - Shared pass harness running through public pipeline code.

### IR2 - 285 - Initial Pass Port Batches
- Goal:
  Define the concrete pass-port batches that will replace the current compatibility/no-op surface.
- Why this slice exists:
  The CLI already exposes pass names and presets; future agents need an explicit port order.
- Concrete deliverables:
  - Pass-batch mapping doc under `docs/`.
  - Pass registry coverage tests.
  - Placeholder or initial pass files under `src/passes/` for batch 1.
- Detailed implementation tasks:
  - Batch 1: hot-query/traversal/effects passes such as `vacuum`, trivial DCE, constant folding, drop/nop cleanup.
  - Batch 2: CFG/use-def/effects passes such as CFG simplification, stronger DCE, unreachable cleanup, branch cleanup.
  - Batch 3: local SSA passes such as copy propagation, local forwarding, dead local cleanup.
  - Batch 4: loop/effect-heavy passes if still desired.
  - Map every currently CLI-visible pass name to one of: real hot pass, boundary-only pass, or remove from CLI/help.
  - Define optimize/shrink preset composition against the new registry.
- Required utilities / APIs:
  - `pass_registry_all()`.
  - `pass_registry_lookup(name)`.
  - `optimize_preset_passes(options)`.
  - `shrink_preset_passes(options)`.
  - `pass_registry_category(name)`.
- Invariants / correctness rules:
  - No pass name remains silently accepted as a no-op once migrated.
  - Presets only expand to implemented or explicitly documented boundary-only behavior.
- Dependencies:
  - IR2 - 270 - Pipeline Orchestration.
  - IR2 - 280 - Pass Migration Support.
- Exit criteria:
  - There is an explicit registry and batch plan for every user-visible pass name/preset.
- Suggested tests:
  - Registry lookup for implemented vs removed names.
  - Optimize/shrink preset expansion coverage.
  - No-op placeholder rejection for names marked real.

## v0.2.0 Backlog

### IR2 - 290 - Tests / Fixtures / Golden Coverage
- Goal:
  Build the shared test harness and golden coverage for hot IR, analyses, and pass execution.
- Why this slice exists:
  The IR2 rebuild spans lift/lower, CFG, dataflow, SSA, and passes; coverage needs a dedicated shared layer.
- Concrete deliverables:
  - `src/ir/test_helpers.mbt`.
  - Adjacent tests for every new `src/ir` and `src/passes` module.
  - Golden dump fixtures for CFG, dominance, liveness, SSA, and pass traces.
  - IR2 test matrix doc under `docs/`.
- Detailed implementation tasks:
  - Add fixture builders from boundary WAT/WASM or direct hot builders.
  - Add dump comparators for CFG, dominance tree, loop info, use-def, liveness, and SSA overlays.
  - Add roundtrip coverage for untouched and mutated hot functions.
  - Add negative verification corruption tests for every structural invariant family.
  - Add pass harness tests through the real registry and pipeline.
- Required utilities / APIs:
  - `ir_test_build_hot_from_wat` or equivalent.
  - `ir_test_assert_verify_and_lower`.
  - `ir_test_dump_cfg`.
  - `ir_test_dump_dom`.
  - `ir_test_dump_ssa`.
  - `ir_test_run_pass`.
- Invariants / correctness rules:
  - Golden outputs are deterministic.
  - Tests use public APIs, not deleted compatibility paths.
- Dependencies:
  - IR2 - 110 - Hot IR Verification Utilities.
  - IR2 - 120 - Boundary -> Hot Lifting.
  - IR2 - 130 - Hot -> Boundary Lowering.
  - IR2 - 150 - CFG Construction.
  - IR2 - 170 - Dominators.
  - IR2 - 240 - Local SSA Construction.
  - IR2 - 270 - Pipeline Orchestration.
- Exit criteria:
  - Shared fixture helpers and golden dump coverage exist across the new architecture.
- Suggested tests:
  - CFG/dominance golden dump.
  - Mutated hot roundtrip through lower + validation.
  - Real pipeline regression on representative example modules.

### IR2 - 300 - Performance Instrumentation and Profiling Support
- Goal:
  Add timers, allocation counters, traversal counters, debug dumps, and validation checkpoints for IR2 work.
- Why this slice exists:
  The rebuilt optimizer will add many overlays and rebuild opportunities; performance needs visibility early.
- Concrete deliverables:
  - `src/ir/perf.mbt` or `src/passes/perf.mbt`.
  - Instrumentation tests.
  - Pipeline trace/timing integration.
- Detailed implementation tasks:
  - Add per-pass timing hooks around lift, analysis build, pass run, verify checkpoints, lower, and final validation.
  - Add counters for node allocs, child-span allocs, side-table allocs, region splices, CFG builds, dataflow builds, and traversal visits.
  - Add optional before/after debug dumps gated by options.
  - Add validation checkpoint reporting.
  - Keep instrumentation overhead low when disabled.
- Required utilities / APIs:
  - `perf_start_timer(name)`.
  - `perf_stop_timer(name)`.
  - `perf_count_node_alloc()`.
  - `perf_count_child_span_alloc()`.
  - `perf_count_cfg_build()`.
  - `perf_count_dataflow_build(name)`.
  - `perf_dump_hot_func(func, options)`.
  - `perf_dump_cfg(cfg, options)`.
  - `perf_validation_checkpoint(name)`.
- Invariants / correctness rules:
  - Instrumentation is semantically inert.
  - Trace keys and pass names are stable.
- Dependencies:
  - IR2 - 070 - Hot IR Direct Mutation Primitives.
  - IR2 - 150 - CFG Construction.
  - IR2 - 260 - Analysis Invalidation / Caching.
  - IR2 - 270 - Pipeline Orchestration.
- Exit criteria:
  - Optimize runs can report pass and analysis timing plus key allocation counters.
- Suggested tests:
  - Counter increments on node allocation and CFG build.
  - Timing/checkpoint trace lines present in a small run.
  - Debug dumps remain opt-in.

### IR2 - 310 - Dead Code / Old Abstraction Cleanup
- Goal:
  Remove stale compatibility shims, dead public claims, and obsolete optimizer naming once IR2 replaces them.
- Why this slice exists:
  Current docs and command comments still carry compatibility/no-op language tied to deleted layers.
- Concrete deliverables:
  - `src/cmd/cmd.mbt` cleaned of obsolete no-op optimizer paths.
  - README/package map/help text aligned with the real IR2 surface.
  - Cleanup regression tests.
- Detailed implementation tasks:
  - Remove or rewrite compatibility expansion and no-op execution shims once real pass paths exist.
  - Remove stale docs/help text implying old explicit pass flags still do work when they do not.
  - Remove dead exports/imports tied to deleted recursive optimizer bodies.
  - Review `.mbti` diffs and public package descriptions.
  - Update `agent-todo.md` as slices land.
- Required utilities / APIs:
  - Registry-backed CLI/help generation.
  - README/API sync checks.
  - Repository grep/assert tests for forbidden stale names.
- Invariants / correctness rules:
  - Public docs and CLI help only describe real current behavior.
  - Cleanup never hides failures by deleting tests.
- Dependencies:
  - IR2 - 270 - Pipeline Orchestration.
  - IR2 - 285 - Initial Pass Port Batches.
- Exit criteria:
  - No-op compatibility execution paths are gone or narrowed to explicit boundary-only behavior.
- Suggested tests:
  - CLI pass resolution uses the real registry.
  - README/API sync alignment.
  - Forbidden stale-name repository assertions.

### IR2 - 320 - Documentation / ADR / Handoff Notes
- Goal:
  Leave the repository with canonical IR2 planning, ADRs, and backlog references so future agents can continue slice by slice.
- Why this slice exists:
  This migration is explicitly a planning and handoff task and needs stable in-repo execution notes.
- Concrete deliverables:
  - Main IR2 plan doc under `docs/`.
  - CFG contract ADR.
  - SSA policy ADR.
  - Updated `agent-todo.md` and `src/ir/README.md` as implementation lands.
- Detailed implementation tasks:
  - Save the canonical IR2 execution plan in `docs/` using the next serial.
  - Cross-link the main plan doc to CFG and SSA ADRs.
  - Keep `agent-todo.md` active-only and slice-id driven.
  - Add a short “next slice order” and “minimum validation per slice” section to the docs plan.
  - Keep `agent-lost-and-found.md` local-only and uncommitted.
- Required utilities / APIs:
  - `bun validate readme-api-sync`.
  - Docs serial naming convention helpers/process.
- Invariants / correctness rules:
  - The `docs/` plan becomes canonical handoff material.
  - `agent-todo.md` stays active-only backlog, not historical log.
  - Public docs do not overclaim optimizer behavior.
- Dependencies:
  - IR2 - 000 - Architecture Rules.
  - IR2 - 140 - CFG Contract and Block Boundary Rules.
  - IR2 - 230 - SSA Design Policy.
  - IR2 - 270 - Pipeline Orchestration.
  - IR2 - 310 - Dead Code / Old Abstraction Cleanup.
- Exit criteria:
  - Repo contains canonical IR2 handoff docs and active backlog references.
- Suggested tests:
  - `bun validate readme-api-sync`.
  - Docs naming-convention check.
  - Manual or scripted backlog-format check referencing active slice ids only.
