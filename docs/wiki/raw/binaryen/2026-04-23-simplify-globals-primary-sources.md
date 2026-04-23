# Binaryen `simplify-globals` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/simplify-globals/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 plain-`simplify-globals` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/simplify-globals/index.md`
- `docs/wiki/binaryen/passes/simplify-globals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-globals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-globals/plain-vs-optimizing-and-safety.md`
- `docs/wiki/binaryen/passes/simplify-globals/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-globals/starshine-strategy.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/index.md`
- `docs/wiki/binaryen/passes/propagate-globals-globally/index.md`

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

- `SimplifyGlobals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- `effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- `find_all.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/find_all.h>
- `linear-execution.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/linear-execution.h>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
- `utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/utils.h>

### Official test files consulted

- `simplify-globals-dominance.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-dominance.wast>
- `simplify-globals-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-gc.wast>
- `simplify-globals-nested.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-nested.wast>
- `simplify-globals-non-init.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-non-init.wast>
- `simplify-globals-offsets.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-offsets.wast>
- `simplify-globals-prefer_earlier.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-prefer_earlier.wast>
- `simplify-globals-read_only_to_write.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-read_only_to_write.wast>
- `simplify-globals-single_use.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-single_use.wast>
- `simplify-globals_func-effects.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals_func-effects.wast>
- `propagate-globals-globally.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/propagate-globals-globally.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still confirmed that plain `simplify-globals`, `simplify-globals-optimizing`, and `propagate-globals-globally` are one shared `SimplifyGlobals.cpp` family exposed as separate public pass names through `pass.cpp`.
- The reviewed source and dedicated tests still confirmed the main plain-pass contract already taught in the living dossier: startup-only single-use folding into later global initializers, dead and same-as-init `global.set` replacement with preserved operand evaluation via `drop(value)`, the exact `read-only-to-write` legality story, startup-vs-runtime propagation as distinct algorithms, and the plain-pass stop point before the optimizing sibling's nested default-function rerun.
- A narrow 2026-04-23 current-`main` spot check on `SimplifyGlobals.cpp`, `pass.cpp`, and the key `simplify-globals-read_only_to_write` plus `propagate-globals-globally` tests did not surface a new teaching-relevant contract drift beyond the updated living dossier's claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
