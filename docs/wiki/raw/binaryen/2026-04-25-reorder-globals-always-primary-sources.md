# Binaryen `reorder-globals-always` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/reorder-globals-always/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-25 `reorder-globals-always` source bridge.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/reorder-globals-always/index.md`
- `docs/wiki/binaryen/passes/reorder-globals-always/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-globals-always/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-globals-always/small-module-threshold-scoring-and-proof.md`
- `docs/wiki/binaryen/passes/reorder-globals-always/wat-shapes.md`
- `docs/wiki/binaryen/passes/reorder-globals-always/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - GitHub showed release **version_129** as published by `kripken` on **2026-04-01 14:31**.

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
- `GlobalStructInference.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
- `topological_sort.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/topological_sort.h>
- `wasm-traversal.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-traversal.h>
- `wasm.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>

### Official test files consulted

- `reorder-globals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-globals.wast>
- `reorder-globals-real.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-globals-real.wast>

## Durable observations from the captured sources

- The reviewed official release surface anchors this dossier on Binaryen `version_129`, with the tagged release page showing publish time **2026-04-01 14:31**.
- `pass.cpp` registers ordinary `reorder-globals` as an optimization pass and `reorder-globals-always` as a test pass with the user-facing summary that it sorts globals by access frequency even when there are few globals.
- `ReorderGlobals.cpp` implements both public names through one shared `ReorderGlobals` class: `createReorderGlobalsPass()` passes `false`, while `createReorderGlobalsAlwaysPass()` passes `true`.
- The sibling-specific policy is exactly the shared engine continuing past the `globals.size() < 128 && !always` early return plus `computeSize(...)` using the smooth synthetic per-slot multiplier `1.0 + (i / 128.0)` when `always` is true.
- The shared engine still collects `global.get` / `global.set` traffic, scans module code, builds dependency edges from non-imported global initializers, tries zero-count / greedy / sum / exponential candidate orders, preserves imports-first legality, breaks ties by original index, rebuilds `module->globals`, and calls `module->updateMaps()`.
- `GlobalStructInference.cpp` still proves a practical internal caller: after adding helper globals, it runs a nested `PassRunner` with `reorder-globals-always` so added globals appear before their uses.
- `reorder-globals.wast` remains the direct small-module sibling proof surface; `reorder-globals-real.wast` remains the production contrast for ordinary `reorder-globals` and the real stepped-size model.
- A narrow 2026-04-25 current-`main` spot check on the listed source and test files did not reveal teaching-relevant drift from the `version_129` contract above. The refreshed living pages still treat this as a spot check, not a formal guarantee that every unrelated Binaryen global-layout helper is unchanged.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
