# Binaryen `pick-load-signs` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/pick-load-signs/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `pick-load-signs` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/pick-load-signs/index.md`
- `docs/wiki/binaryen/passes/pick-load-signs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/pick-load-signs/wat-shapes.md`
- `docs/wiki/binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/parity.md`

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

- `PickLoadSigns.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PickLoadSigns.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/PickLoadSigns.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>

### Official test files consulted

- `pick-load-signs_sign-ext.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/pick-load-signs_sign-ext.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/pick-load-signs_sign-ext.wast>
- `optimize-instructions-sign_ext.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centers on the same small teaching-relevant contract already described by the living dossier: exact non-tee `local.set(load ...)` producer discovery, per-local usage counting, parent/grandparent helper-driven sign/zero-extension matching, all-uses-recognized gating, atomic exclusion, and the signed-weighted final choice.
- The checked current-`main` `PickLoadSigns.cpp` and dedicated `pick-load-signs_sign-ext.wast` surfaces still matched the tagged `version_129` behavior on the reviewed mechanics that matter most for this dossier.
- The reviewed neighboring `optimize-instructions-sign_ext.wast` file still matters as a boundary source because it proves that broader sign-extension cleanup exists elsewhere in Binaryen and should not be silently attributed to `pick-load-signs` itself.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
