# Binaryen `reorder-functions` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/reorder-functions/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `reorder-functions` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in [`docs/wiki/raw/binaryen/2026-04-24-reorder-functions-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-functions-primary-sources.md) and the 2026-05-04 freshness note in [`docs/wiki/raw/research/0439-2026-05-04-reorder-functions-current-main-recheck.md`](../../../raw/research/0439-2026-05-04-reorder-functions-current-main-recheck.md).
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/reorder-functions/index.md`
- `docs/wiki/binaryen/passes/reorder-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-functions/module-shapes.md`
- `docs/wiki/binaryen/passes/reorder-functions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `src/passes/ReorderFunctions.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderFunctions.cpp>
- `src/passes/pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `test/lit/passes/reorder-functions-by-name.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-functions-by-name.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/reorder-functions-by-name.wast>

### Comparison anchors

- `ReorderFunctions.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `test/lit/passes/reorder-functions-by-name.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast>

## Durable observations

- Current `main` still treats `reorder-functions` as the tiny declaration-order pass taught in the existing dossier: the implementation stays centered in `ReorderFunctions.cpp`, not in a broader optimizer framework.
- The reviewed `main` `ReorderFunctions.cpp` still shows the same public contract as `version_129` on the teaching surfaces: direct-call counting, start/export/element bumps, explicit `ref.func` and declaration-section TODOs, descending-count sort, and descending-name tie breaks.
- `pass.cpp` still registers both public names with the same split as before: `reorder-functions-by-name` is debugging-oriented, while `reorder-functions` is the access-frequency sorter.
- The reviewed current-main `test/lit/passes/reorder-functions-by-name.wast` still proves the sibling lexical-order contract directly.
- The current repository state still keeps both `reorder-functions` names boundary-only in `src/passes/optimize.mbt`, with no module-pass dispatcher case in `src/passes/pass_manager.mbt` and no dedicated active `agent-todo.md` slice.

## Consumability rule

Treat this as a freshness checkpoint, not as a replacement for the older `version_129` capture. If future wiki pages restate the contract, cite both the older primary-source manifest and this current-main recheck.
