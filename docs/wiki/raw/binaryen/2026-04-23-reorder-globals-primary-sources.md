# Binaryen `reorder-globals` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/reorder-globals/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `reorder-globals` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/reorder-globals/index.md`
- `docs/wiki/binaryen/passes/reorder-globals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-globals/size-model-and-dependency-order.md`
- `docs/wiki/binaryen/passes/reorder-globals/wat-shapes.md`
- `docs/wiki/binaryen/passes/reorder-globals/starshine-strategy.md`
- `docs/wiki/binaryen/passes/reorder-globals-always/index.md`

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

- `ReorderGlobals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderGlobals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- `wasm-traversal.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-traversal.h>
- `topological_sort.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/topological_sort.h>
- `wasm.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>
- `GlobalStructInference.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>

### Official test files consulted

- `reorder-globals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-globals.wast>
- `reorder-globals-real.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-globals-real.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the existing living dossier's main teaching claims: parallel `global.get` / `global.set` use counting, module-code scanning, initializer-`global.get` dependency edges, four candidate-search families, true-count final scoring, the public `< 128` early return, and the separate smooth-scoring `reorder-globals-always` sibling mode.
- The reviewed dedicated tests still exposed the same main positive and negative families already taught in the living pages: hotter independent globals, dependency-preserving chains, `global.set` heat, import-first ordering, the public `< 128` no-op, and the larger-than-`127` production-positive families.
- A narrow 2026-04-23 current-`main` spot check on `ReorderGlobals.cpp`, `pass.cpp`, `passes.h`, `pass.h`, `wasm-traversal.h`, `topological_sort.h`, `wasm.h`, `GlobalStructInference.cpp`, and the dedicated `reorder-globals{,-real}.wast` test pair did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
