# Binaryen `reorder-functions` current-main recheck

_Capture date:_ 2026-05-04  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/reorder-functions/` dossier

## Scope

This file records the fresh current-main spot check used to keep the `reorder-functions` dossier honest after the 2026-04-24 primary-source capture.

Use the living pages for interpretation:

- `docs/wiki/binaryen/passes/reorder-functions/index.md`
- `docs/wiki/binaryen/passes/reorder-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-functions/module-shapes.md`
- `docs/wiki/binaryen/passes/reorder-functions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions/starshine-port-readiness-and-validation.md`

## Provenance

### Official source files rechecked on current main

- `src/passes/ReorderFunctions.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
- `src/passes/pass.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `test/lit/passes/reorder-functions-by-name.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-functions-by-name.wast>

### Local Starshine surfaces rechecked against the repository

- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/duplicate_function_elimination.mbt`
- `agent-todo.md`

## Durable observations from the recheck

- Current main still treats `reorder-functions` as the tiny declaration-order pass taught in the existing dossier: the implementation is centered in `ReorderFunctions.cpp`, not in a broader optimizer framework.
- The reviewed `main` `ReorderFunctions.cpp` still shows the same public contract as `version_129` on the teaching surfaces: direct-call counting, start/export/element bumps, explicit `ref.func` and declaration-section TODOs, descending-count sort, and descending-name tie breaks.
- `pass.cpp` still registers both public names with the same split as before: `reorder-functions-by-name` is debugging-oriented, while `reorder-functions` is the access-frequency sorter.
- The reviewed current-main `test/lit/passes/reorder-functions-by-name.wast` still proves the sibling lexical-order contract directly.
- The current repository state still keeps both `reorder-functions` names boundary-only in `src/passes/optimize.mbt`, with no module-pass dispatcher case in `src/passes/pass_manager.mbt` and no dedicated active `agent-todo.md` slice.

## Consumability rule

Treat this as a freshness checkpoint, not as a replacement for the older `version_129` capture. If future wiki pages restate the contract, cite both the older primary-source manifest and this current-main recheck.
