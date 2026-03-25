# Agent Tasks

## Scope
- Keep only unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Keep each slice actionable enough to implement directly without re-deriving the architecture.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice

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
