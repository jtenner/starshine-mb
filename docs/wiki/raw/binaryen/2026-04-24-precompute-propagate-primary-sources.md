# Binaryen `precompute-propagate` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/precompute-propagate/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `precompute-propagate` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/precompute-propagate/index.md`
- `docs/wiki/binaryen/passes/precompute-propagate/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute-propagate/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/precompute-propagate/local-worklist-fallthrough-and-merge-boundaries.md`
- `docs/wiki/binaryen/passes/precompute-propagate/wat-shapes.md`
- `docs/wiki/binaryen/passes/precompute-propagate/starshine-strategy.md`
- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/starshine-hot-ir-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to confirm that `version_129` was still present on the official reviewed release surface during this run.

### Official source files consulted

- `Precompute.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
- `wasm-interpreter.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-interpreter.h>

### Official test files consulted

- `precompute-propagate-partial.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-propagate-partial.wast>
- `precompute-propagate_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-propagate_all-features.wast>
- Neighboring shared-family `precompute*` tests remained relevant because the selected pass shares the `Precompute.cpp` semantic evaluator with plain `precompute`; the focused follow-up relied on the sibling-specific files above for the propagate contract and on the existing plain `precompute` raw manifest for the larger shared-family roster.

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `Precompute.cpp` still owns both public pass names: plain `precompute` and sibling `precompute-propagate`.
- `pass.cpp` still exposes `precompute-propagate` as a public pass name rather than only an internal mode flag.
- `opt-utils.h` still owns the important nested-runner fact: optimizing boundary rewrites use the useful-post-inlining cleanup path that prepends `precompute-propagate` before the default function pipeline.
- The dedicated lit files still expose the sibling-specific proof surface: local get/set consensus through `LazyLocalGraph`, fallthrough-value reasoning for set values, branch-join consensus, zero/default entry values, tee/fallthrough carriers, tuple-local propagation, and the partial-select temporary heap-cache boundary.
- A narrow 2026-04-24 current-`main` spot check on `Precompute.cpp`, `pass.cpp`, `opt-utils.h`, `local-graph.h`, `properties.h`, `wasm-interpreter.h`, and the two dedicated propagate lit files did not surface a new teaching-relevant contract drift beyond the refreshed living dossier's claims. The existing plain-`precompute` dossier still records separate newer-than-`version_129` trunk drift for the shared evaluator family; do not silently apply those drift notes to the tagged sibling contract.
- Local Starshine status intentionally remains a repository fact separate from upstream provenance: current Starshine keeps `precompute-propagate` only as a removed registry name in `src/passes/optimize.mbt`; the active local implementation is plain `precompute` in `src/passes/precompute.mbt` and has no `LazyLocalGraph` propagation mode or nested optimizing-rerun scheduler today.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
