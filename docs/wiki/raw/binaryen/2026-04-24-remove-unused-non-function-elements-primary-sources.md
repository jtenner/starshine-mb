# Binaryen `remove-unused-nonfunction-module-elements` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/remove-unused-non-function-elements/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `remove-unused-non-function-elements` provenance and Starshine-status refresh.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/index.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/shared-engine-rooting-and-defined-vs-imported-functions.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/module-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published on **2026-04-01** in neighboring 2026-04-24 pass ingests; this dossier uses `version_129` as the stable release oracle for the source reading.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24 in the pass-ingest campaign.

### Official source files consulted

- `RemoveUnusedModuleElements.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedModuleElements.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedModuleElements.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>

### Official test files consulted

- Dedicated sibling test:
  - `test/passes/remove-unused-nonfunction-module-elements_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
- Shared full-RUME lit files used for inherited engine semantics:
  - `remove-unused-module-elements-configureAll.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-configureAll.wast>
  - `remove-unused-module-elements-refs.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast>
  - `remove-unused-module-elements-tables.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-tables.wast>
  - `remove-unused-module-elements_tnh.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_tnh.wast>

## Durable observations from the captured sources

- `version_129` registers a real public pass named `remove-unused-nonfunction-module-elements`, separate from full `remove-unused-module-elements`.
- The implementation is not a separate owner file. `RemoveUnusedModuleElements.cpp` owns both public pass names through the same `RemoveUnusedModuleElements` class and a `rootAllFunctions` constructor policy.
- The public factory split is the core contract: full RUME constructs the shared pass with `rootAllFunctions = false`, while `remove-unused-nonfunction-module-elements` constructs it with `rootAllFunctions = true`.
- In sibling mode, Binaryen calls the module utility that iterates **defined** functions and inserts those function names into the root set before the shared analyzer runs.
- The defined-function wording is important: imported functions are not automatically rooted by the sibling policy, so dead imported functions may still be removed by the shared engine.
- The sibling still inherits ordinary RUME startup/export roots, imported-parent active segment retention, startup-trap retention unless TNH applies, reference/table/segment/data traversal, index remapping, and function-type cleanup.
- A no-op start declaration can still be removed while the start function body itself survives, because start metadata cleanup and defined-function body preservation are different surfaces.
- The dedicated all-features test proves the most visible sibling shapes: dead defined functions and cycles remain, dead memories/tables/tags/imports can still disappear, imported-parent segments stay when observable, and unused function types can still shrink.
- A narrow 2026-04-24 current-`main` spot check confirmed the pass name, sibling factory, and dedicated test path remain present. The owner file has drifted in helper/container details since `version_129`; this capture does **not** claim whole-file semantic equivalence between `version_129` and current `main`.
- Starshine-specific follow-up in this run found no local sibling implementation. The durable local fact is that `remove-unused-non-function-elements` is a boundary-only registry name, not an active HOT or module pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and `0328` research note instead of relying only on the older `0194` research note or direct online links.
