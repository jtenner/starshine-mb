# Binaryen `remove-unused-module-elements` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/remove-unused-module-elements/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `remove-unused-module-elements` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/remove-unused-module-elements/index.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/roots-reference-only-and-nullification.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/retention-and-index-rewrites.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/parity.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that the `version_129` release page was still the reviewed official release surface for this dossier on this run.

### Official source files consulted

- `RemoveUnusedModuleElements.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- `element-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/element-utils.h>
- `gc-type-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
- `table-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- `FunctionTypeUtils.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/FunctionTypeUtils.cpp>

### Official test files consulted

- `remove-unused-module-elements_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_all-features.wast>
- `remove-unused-module-elements-eh-old.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-eh-old.wast>
- `remove-unused-module-elements-refs.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast>
- `remove-unused-nonfunction-module-elements_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-nonfunction-module-elements_all-features.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centers on the same teaching-relevant contract already described by the living dossier: build strong-vs-reference-aware roots, run the `Analyzer` fixed point over expression and module queues, remove unused function types before final module cleanup, and either delete or weaken surviving declarations depending on kind and usage mode.
- The checked current-`main` `RemoveUnusedModuleElements.cpp` surface still matched the tagged `version_129` behavior on the reviewed mechanics that matter most for this dossier: the same `rootAllFunctions` sibling split for `remove-unused-nonfunction-module-elements`, the same start-root no-op handling, the same `Analyzer::prepare()` flat-table prepass, and the same disabled top-level `prepare(module)` fast path guarded by the longstanding FIXME.
- The reviewed upstream tests still prove the same high-value teaching surfaces that matter most for this dossier: all-features whole-module pruning and rewrite coverage, reference-heavy families, legacy-EH coverage, and the separate sibling-mode proof for `remove-unused-nonfunction-module-elements`.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
