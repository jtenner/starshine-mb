# Binaryen `string-gathering` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/string-gathering/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `string-gathering` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/string-gathering/index.md`
- `docs/wiki/binaryen/passes/string-gathering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/string-gathering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/string-gathering/reuse-naming-and-ordering.md`
- `docs/wiki/binaryen/passes/string-gathering/wat-shapes.md`
- `docs/wiki/binaryen/passes/string-gathering/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-23.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-23.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `StringLowering.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Supporting upstream helper surfaces reviewed for the dossier's exact-slot scan and module-code coverage story
  - `string-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
  - `string-utils.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.cpp>
  - `module-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `wasm-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>

### Official test files consulted

- `string-gathering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- Neighboring interaction test reviewed for the simplify-globals / late-tail relationship
  - `propagate-globals-globally.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the teaching-important contract already captured in the living dossier: `StringGathering` is a small standalone pass inside `StringLowering.cpp`, with `run()` calling `processModule(...)`, `addGlobals(...)`, and `replaceStrings(...)` in that order.
- The reviewed source still showed the same exact-slot scan rule already taught in the dossier: the pass records `Expression**` sites through `visitStringConst(...)` and rewrites those exact pointers later instead of re-searching the AST.
- The reviewed source still showed the same whole-module coverage boundary already taught in the dossier: defined functions are scanned through `ModuleUtils::ParallelFunctionAnalysis`, and module-level expression code is scanned separately so the pass is broader than a function-only optimization.
- The reviewed source still showed the same validity-first reorder rule already taught in the dossier: `std::stable_sort(...)` only moves defining string globals earlier, and the source comment explicitly leaves stronger layout work to `reorder-globals`.
- The reviewed dedicated lit file still demonstrated the same practical proof surface already captured in the living pages: repeated literal collection, reusable immutable direct string globals, nullable and mutable non-reuse, first-match canonicalization, and global-initializer reorder-for-validity behavior.
- A narrow 2026-04-23 current-`main` spot check on `StringLowering.cpp` did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
