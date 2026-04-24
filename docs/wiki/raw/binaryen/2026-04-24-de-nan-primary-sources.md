# Binaryen `de-nan` / `denan` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/de-nan/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `de-nan` / `denan` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/de-nan/index.md`
- `docs/wiki/binaryen/passes/de-nan/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/de-nan/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/de-nan/helper-functions-fallthrough-and-boundaries.md`
- `docs/wiki/binaryen/passes/de-nan/wat-shapes.md`
- `docs/wiki/binaryen/passes/de-nan/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep the dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `DeNaN.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeNaN.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeNaN.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
- `names.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/names.h>
- `wasm-builder.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-builder.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>

### Official test files consulted

- `denan.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/denan.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/denan.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the existing living dossier's main teaching claims: public registration as `denan`, implementation in `DeNaN.cpp`, helper-name collision avoidance, `addsEffects()` truthfulness, constant NaN-to-zero rewrites, entry-param sanitization, helper-call wrapping for nonconstant float/SIMD producers, and nested `merge-blocks` cleanup after entry fixups.
- The reviewed lit test still proves the most important beginner-facing contract boundaries: global NaN constants become zero, defined-function params are sanitized, `local.get` and fallthrough shells are preserved, call/unary producers are wrapped, function-body NaN constants are replaced directly, and helper names are generated collision-safely.
- The reviewed source remains stronger than the lit file for a few edge surfaces: imported functions are skipped by implementation, nonconstant nonfunction contexts cannot receive helper calls, and the `v128` helper uses scalar lane extraction rather than direct vector equality to avoid self-interference.
- A narrow 2026-04-24 current-`main` spot check on `DeNaN.cpp`, `pass.cpp`, `properties.h`, `names.h`, and `denan.wast` did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims; the previously recorded comment typo cleanup remains non-semantic.
- The Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is still that `de-nan` is a preserved **removed** registry name, not an active HOT or module pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
