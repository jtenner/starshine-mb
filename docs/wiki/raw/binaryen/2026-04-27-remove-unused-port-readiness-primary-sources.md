# Binaryen `remove-unused` / historical `remove-unused-functions` port-readiness source recheck

_Capture date:_ 2026-04-27  
_Status:_ immutable primary-source recheck for the `docs/wiki/binaryen/passes/remove-unused/` lineage and Starshine registry-hygiene dossier

## Scope

This source capture rechecks the 2026-04-25 `remove-unused` lineage dossier before adding a port-readiness / validation bridge. It does **not** replace the earlier raw manifest; it narrows the question to what a future Starshine change should do with the ambiguous local `remove-unused` boundary-only name.

The durable conclusion remains unchanged:

- current Binaryen `main` registers the modern removal-family names `remove-unused-brs`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `remove-unused-names`, and `remove-unused-types`, but no public `remove-unused` / `remove-unused-functions` pass spelling;
- historical Binaryen commit `5881b541a4b276dcd5576aa065e4fb860531fc7b` contains the old function-only implementation that rooted start/export/table-segment functions, followed direct-call reachability, and erased unreachable functions;
- Starshine still keeps `remove-unused` as a boundary-only local alias, while modern RUME and RUNE are separate implemented module passes.

## Official online sources rechecked

### Current Binaryen `main` registry and scheduling

- GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Reviewed on 2026-04-27.
- Key source locations from the GitHub view:
  - lines around `3003`-`3029` register the current removal-family pass names: `remove-unused-brs`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `remove-unused-names`, and `remove-unused-types`;
  - lines around `3616`-`3619`, `3655`-`3657`, and `3745`-`3746` schedule `remove-unused-module-elements` in the default global optimization paths;
  - no public registration for `remove-unused` or `remove-unused-functions` was found in the current-main registry view.

### Current Binaryen `main` modern replacement owner

- GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp>
- Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedModuleElements.cpp>
- Reviewed on 2026-04-27.
- Key role: confirms that the current implementation surface is the broader RUME family, not a resurrected old function-only pass.

### Historical Binaryen old function-only owner

- GitHub: <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
- Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
- Reviewed on 2026-04-27.
- Key source locations from the GitHub view:
  - lines around `438`-`448` root functions named in table segments, after start/export roots in the same function;
  - lines around `450`-`452` run `DirectCallGraphAnalyzer` from the root set;
  - lines around `454`-`458` begin erasing unreachable functions from the module function vector.

## Local Starshine source locations rechecked

- `src/passes/optimize.mbt:127`-`139` keeps `remove-unused` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt:243`-`249` registers the implemented modern module siblings `remove-unused-module-elements` and `remove-unused-nonfunction-module-elements` as active module passes.
- `src/passes/pass_manager.mbt:8655`-`8685` dispatches active module passes and contains cases for RUME/RUNE but no `remove-unused` case.
- `src/passes/remove_unused_module_elements.mbt:1`-`8` defines the summaries for the implemented modern RUME/RUNE module passes.
- `src/passes/registry_test.mbt:78`-`82` asserts that `remove-unused-module-elements` is a module pass; there is no corresponding active-category test for `remove-unused` because it is boundary-only.

## Durable port-readiness observations

- The safest near-term Starshine action is **registry honesty**, not an implementation: keep rejecting `remove-unused` unless a maintainer chooses a precise migration.
- If preserving the local alias, document it as a historical function-only alias and validate only a literal old-function-DCE behavior.
- If aligning to modern Binaryen, prefer removing or renaming the alias and pointing users to `remove-unused-module-elements`, because modern Binaryen no longer exposes the short spelling.
- If a literal historical port is requested, first build an analyzer-only module pass that reports old-style roots and direct-call closure without mutating the module; then add deletion/remap only after function-index, export, start, element, name, and validation repair tests are in place.

## Uncertainty preserved

No primary source directly proves that Starshine's short local spelling was intentionally coined as an alias for historical `remove-unused-functions`. That remains an evidence-backed inference from the old upstream pass, the local boundary-cleanup grouping, and the absence of any modern upstream `remove-unused` spelling.
