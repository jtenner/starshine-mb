# Binaryen `remove-unused-nonfunction-module-elements` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/remove-unused-non-function-elements/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 wiki-health pass on `remove-unused-non-function-elements`.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md` and the 2026-04-26 port-readiness bridge in `docs/wiki/raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/index.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/shared-engine-rooting-and-defined-vs-imported-functions.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/module-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `RemoveUnusedModuleElements.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedModuleElements.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `passes.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
- `module-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>
- dedicated fixture
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
- shared engine fixtures used for inherited behavior
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-module-elements-configureAll.wast>
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-module-elements-refs.wast>
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-module-elements-tables.wast>
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-module-elements_tnh.wast>

### Tagged comparison anchor

- `RemoveUnusedModuleElements.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `passes.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `module-utils.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- dedicated fixture at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
- shared fixtures at `version_129`:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-configureAll.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-tables.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_tnh.wast>

## Reviewed source surfaces

The recheck focused on the same teaching-relevant surfaces already documented in the living dossier:

- the shared `RemoveUnusedModuleElements.cpp` engine and its `rootAllFunctions` sibling mode
- the public registration split in `pass.cpp`
- the public factory declarations in `passes.h`
- the `ModuleUtils::iterDefinedFunctions(...)`-driven root-all step in `module-utils.h`
- the dedicated sibling all-features fixture
- the shared RUME fixtures that still prove inherited retention, segment, and TNH behavior

## Durable observations

- Current `main` still registers `remove-unused-nonfunction-module-elements` as a real public pass separate from `remove-unused-module-elements`.
- The implementation is still the same shared owner file plus one constructor-policy toggle; there is no separate sibling engine.
- The key source-level distinction remains the `rootAllFunctions` policy: sibling mode roots every **defined** function before the shared analyzer runs.
- The special root-all step still does not root imported functions, so dead imported functions can still be removed by the ordinary reachability engine.
- Ordinary RUME startup and export behavior still applies, including no-op start cleanup, imported-parent active segments, and TNH-governed startup-trap retention.
- No teaching-relevant drift was found on the reviewed current-main surfaces.
- The local Starshine story remains unchanged: `remove-unused-nonfunction-module-elements` is an active module pass that reuses the existing RUME machinery rather than forking a new sweep.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating the raw URLs as the explanatory destination.
