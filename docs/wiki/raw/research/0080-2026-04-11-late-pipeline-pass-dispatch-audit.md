# `0080` Late `-O4z` Pipeline Pass Dispatch Audit

## Scope

- Re-validate the wiki coverage for late-function optimization passes that appear toward the tail of Starshine’s `-O4z` pipeline and `optimize`/`shrink` presets.
- Confirm in-tree dispatch/categorization for:
  - `dead-code-elimination`
  - `global-refining`
  - `heap-store-optimization`
  - `memory-packing`
  - `once-reduction`
  - `optimize-instructions`
  - `precompute`
  - `simplify-locals`
  - `vacuum`

## Sources

- [`src/cmd/cli.mbt`](../../../../src/cli/cli.mbt) (`-O4z` parser and optimize-level lowering)
- [`src/cmd/cmd.mbt`](../../../../src/cmd/cmd.mbt) (`resolve_optimize_levels` + `resolve_effective_pass_flags`)
- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt) (pass registry + `optimize` / `shrink` preset vectors)
- [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt) (module-vs-hot dispatch)
- Per-pass executable coverage in `src/passes/*_test.mbt` (`*.mbt` test files per pass).
- [`src/passes/dead_code_elimination.mbt`](../../../../src/passes/dead_code_elimination.mbt)
- [`src/passes/global_refining.mbt`](../../../../src/passes/global_refining.mbt)
- [`src/passes/heap_store_optimization.mbt`](../../../../src/passes/heap_store_optimization.mbt)
- [`src/passes/memory_packing.mbt`](../../../../src/passes/memory_packing.mbt)
- [`src/passes/once_reduction.mbt`](../../../../src/passes/once_reduction.mbt)
- [`src/passes/optimize_instructions.mbt`](../../../../src/passes/optimize_instructions.mbt)
- [`src/passes/precompute.mbt`](../../../../src/passes/precompute.mbt)
- [`src/passes/simplify_locals.mbt`](../../../../src/passes/simplify_locals.mbt)
- [`src/passes/optimize_test.mbt`](../../../../src/passes/optimize_test.mbt)
- [`src/passes/trace_golden_test.mbt`](../../../../src/passes/trace_golden_test.mbt)
- [`src/cmd/cmd_test.mbt`](../../../../src/cmd/cmd_test.mbt)
- [`docs/wiki/binaryen/passes/index.md`](../../binaryen/passes/index.md)
- Wiki landing pages for the listed late-pass names

## Findings

### 1) `-O4z` still maps to shrink preset expansion

- `-O4z` is parsed as `CliOptimizationFlag::olevel(4, true)`.
- `resolve_optimize_levels` turns that into `optimize_level=4`, `shrink_level=4`.
- `resolve_effective_pass_flags` therefore schedules `shrink` when no explicit passes are requested.
- `shrink` expands to `shrink_preset_passes()` in `src/passes/optimize.mbt`.

### 2) Late passes are implemented and registered (not merely placeholders)

For each inspected pass, implementation and/or registry hooks exist in current source:

- **Hot pass entries in registry:**
  - `dead-code-elimination`, `optimize-instructions`, `heap-store-optimization`, `precompute`, `simplify-locals`
  - `pass descriptors` exist in each corresponding `src/passes/*` module and are wired through `run_hot_pipeline_apply_hot_pass`.
- **Module pass entries in registry:**
  - `global-refining`, `memory-packing`, `once-reduction`
  - each dispatches through `run_hot_pipeline_apply_module_pass`.
- **`vacuum`:**
  - no dedicated `src/passes/vacuum.mbt`, but descriptor and behavior live in `src/passes/optimize.mbt` (`pass_registry_entry_hot("vacuum", ...)`) and are executed in `run_hot_pipeline_apply_hot_pass` via `hot_pass_remove_region_nops`.

### 3) Wiki coverage is now more accurately aligned with live implementation state

- `docs/wiki/binaryen/passes/index.md` already listed all of these passes in active module/hot sections, and their landing pages existed before this sweep.
- Some landing pages still carried “future-oriented” wording; these were normalized to avoid implying these passes are unimplemented.
- `docs/wiki/binaryen/passes/index.md` wording was updated to make it explicit that all listed late passes are currently dispatchable/implemented in-tree while still stubbed at the strategy-documentation level.

### 4) Remaining gap

- Many late-pass folders are still structurally stubbed (`status: stub`) and intentionally lacking full parity strategy/shape pages.
- This is a documentation depth gap, not a dispatcher gap.

### 5) Practical Wiki Maintenance Outcome

- Treat these pages as **active / implemented / documented-minimally** instead of “future-only”.
- Keep source-of-truth ordering and dispatch details anchored to:
  - `src/passes/optimize.mbt`
  - `src/passes/pass_manager.mbt`
  - `src/cmd/cmd.mbt`

## Recommendation

Keep parity/research deepening focused on this slice with a dedicated follow-up pass, but do not classify these passes as inactive just because their wiki folders are sparse.