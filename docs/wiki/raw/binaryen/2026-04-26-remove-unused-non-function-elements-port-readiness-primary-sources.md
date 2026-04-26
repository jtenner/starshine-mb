# Binaryen `remove-unused-nonfunction-module-elements` port-readiness primary-source recheck

_Capture date:_ 2026-04-26  
_Status:_ immutable source manifest for the `remove-unused-non-function-elements` Starshine port-readiness bridge

## Scope

This manifest rechecks the official Binaryen sources needed to turn the existing `remove-unused-non-function-elements` dossier into an implementation-readiness guide for a future Starshine port. It does not replace the 2026-04-24 source capture; it records that the safe local implementation sequence remains anchored in the same shared-RUME sibling contract.

Use with:

- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/index.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/shared-engine-rooting-and-defined-vs-imported-functions.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/module-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-non-function-elements/starshine-port-readiness-and-validation.md`

## Official primary sources rechecked

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
- official dedicated fixture
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
- sibling/shared fixtures that still matter for inherited RUME behavior
  - `version_129` configure-all fixture: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-configureAll.wast>
  - `version_129` refs fixture: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast>
  - `version_129` tables fixture: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-tables.wast>
  - `version_129` TNH fixture: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_tnh.wast>

## Durable recheck observations

- No teaching-relevant drift was found from the 2026-04-24 dossier contract.
- The public pass remains a registration/factory sibling of full `remove-unused-module-elements`; the upstream public spelling is still `remove-unused-nonfunction-module-elements`.
- The key source-level distinction remains the `RemoveUnusedModuleElements(bool rootAllFunctions)` mode. In the sibling mode Binaryen roots every defined function through `ModuleUtils::iterDefinedFunctions(...)` before adding ordinary RUME roots.
- The special root-all step still does not root imported functions. This is the main reason the pass can preserve dead defined helpers while still pruning unused imported functions and function types through the shared engine.
- Ordinary RUME startup and export behavior still applies: non-`nop` starts and exports root their targets, no-op starts can drop the start declaration, imported-parent active segments stay observable, and startup-trap retention remains governed by the shared analyzer and TNH policy.
- The dedicated all-features fixture remains the compact oracle for the sibling's public behavior, but the sibling's inherited correctness surface is broader than that one file. A Starshine port should keep full-RUME fixtures and tests in the validation ladder.
- Starshine-specific recheck again found no local owner file or dispatcher case. The current in-tree state is a boundary-only registry spelling plus reusable full-RUME liveness/rewrite machinery in `src/passes/remove_unused_module_elements.mbt`.

## Uncertainties to preserve

- This recheck is a source-surface and port-planning check, not a complete proof that every helper reached from Binaryen current `main` is byte-for-byte unchanged.
- The local name remains different from upstream. A future Starshine implementation must decide whether to expose only the existing local spelling or add an upstream alias as a separate CLI compatibility decision.
- The right local API shape is probably a RUME policy parameter, but the exact owner function names should be chosen during implementation after tests lock the sibling contract.
