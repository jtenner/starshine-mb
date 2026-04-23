# Binaryen `directize` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/directize/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `directize` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/directize/index.md`
- `docs/wiki/binaryen/passes/directize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/directize/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/directize/table-info-and-immutability.md`
- `docs/wiki/binaryen/passes/directize/wat-shapes.md`
- `docs/wiki/binaryen/passes/directize/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `Directize.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Directize.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `call-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/call-utils.h>
- `table-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/table-utils.h>
- `table-utils.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/table-utils.cpp>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>

### Official test files consulted

- `directize_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize_all-features.wast>
- `directize-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize-gc.wast>
- `directize-wasm64.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize-wasm64.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the teaching-important contract already captured in the living dossier: module-wide `TableUtils` precomputation, a fast “no table can optimize by entry” bail-out, three-way `Known` / `Trap` / `Unknown` target classification, narrow `select` lowering via `CallUtils`, subtype-based compatibility checks, and post-rewrite `ReFinalize()` repair.
- The reviewed dedicated test files still exposed the same main positive and negative families already taught in the living pages: direct-call positives, trap-to-`unreachable` rewrites, immutable-initial-contents mode, mutable/imported-table bailouts, wasm64 full-width index handling, and GC subtype compatibility.
- A narrow 2026-04-22 current-`main` spot check on `Directize.cpp`, `pass.cpp`, `call-utils.h`, `table-utils.{h,cpp}`, and the dedicated `directize*` lit files did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
