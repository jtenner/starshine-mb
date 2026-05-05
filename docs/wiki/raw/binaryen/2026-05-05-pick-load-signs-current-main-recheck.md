# Binaryen `pick-load-signs` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/pick-load-signs/` dossier

## Scope

This file captures the current-`main` recheck that refreshed the existing `pick-load-signs` dossier.
Use the living pages for interpretation:

- `docs/wiki/binaryen/passes/pick-load-signs/index.md`
- `docs/wiki/binaryen/passes/pick-load-signs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/pick-load-signs/wat-shapes.md`
- `docs/wiki/binaryen/passes/pick-load-signs/parity.md`
- `docs/wiki/binaryen/passes/pick-load-signs/starshine-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md`

## Provenance

### Official upstream sources rechecked

- `PickLoadSigns.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PickLoadSigns.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/PickLoadSigns.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>

### Official upstream tests rechecked

- `pick-load-signs_sign-ext.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/pick-load-signs_sign-ext.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/pick-load-signs_sign-ext.wast>
- `optimize-instructions-sign_ext.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast>

## Durable observations from the recheck

- The current-`main` source and dedicated test surface still matched the tagged `version_129` mechanics that matter for this dossier.
- The upstream pass remains the small local-written-load selector documented in the living pages: exact non-tee `local.set(load ...)` producers, helper-driven sign/zero-extension use classification, all-uses-recognized gating, atomic exclusion, and a signed-weighted final choice.
- The neighboring `optimize-instructions-sign_ext.wast` file still belongs to the broader sign-extension cleanup story and should not be folded into `pick-load-signs` semantics.

## Consumability rule

Future wiki updates should cite this manifest together with the living dossier pages when they restate the freshness bridge.
