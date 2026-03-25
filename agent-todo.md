# Agent Tasks

## Scope
- Keep only unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Keep each slice actionable enough to implement directly without re-deriving the architecture.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice

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
