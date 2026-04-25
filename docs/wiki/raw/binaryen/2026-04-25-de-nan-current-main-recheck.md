# Binaryen `de-nan` / `denan` current-main recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable focused source recheck for the `docs/wiki/binaryen/passes/de-nan/` dossier

## Scope

This file captures a narrow primary-source recheck of Binaryen `denan` after the 2026-04-24 dossier refresh. It is intentionally a source manifest and drift note, not the main teaching document.

Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/de-nan/index.md`
- `docs/wiki/binaryen/passes/de-nan/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/de-nan/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/de-nan/helper-functions-fallthrough-and-boundaries.md`
- `docs/wiki/binaryen/passes/de-nan/wat-shapes.md`
- `docs/wiki/binaryen/passes/de-nan/starshine-strategy.md`

## Primary online sources rechecked

### Official Binaryen repository sources

- `DeNaN.cpp`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeNaN.cpp>
- `pass.cpp`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `properties.h`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/properties.h>
- `names.h`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/names.h>
- `wasm-builder.h`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-builder.h>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm-builder.h>
- `pass.h`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/pass.h>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/pass.h>

### Official Binaryen tests

- `denan.wast`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/denan.wast>

### Official release surface

- Binaryen GitHub release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen GitHub releases index: <https://github.com/WebAssembly/binaryen/releases>

## Recheck result

The 2026-04-25 recheck found **no teaching-relevant current-main drift** for `denan` beyond the 2026-04-24 dossier.

The durable contract remains:

- upstream public pass spelling is `denan`
- local Starshine compatibility spelling remains `de-nan`
- `DeNaN.cpp` owns the implementation
- the pass reports that it adds effects because it inserts helper calls
- constant `f32`, `f64`, and `v128` NaNs are rewritten to zero constants
- nonconstant `f32`, `f64`, and `v128` producers inside functions are wrapped in helper calls
- defined-function float/vector parameters are sanitized on entry
- imported functions are skipped for entry repair
- plain `local.get` and `Properties::isResultFallthrough(...)` shell nodes are intentionally skipped
- helper names are chosen with Binaryen's valid-name helper to avoid collisions
- helper functions are appended after the walk to avoid self-instrumentation
- the SIMD helper still uses scalar lane extraction rather than direct vector equality
- the dedicated `denan.wast` file remains the compact official behavior oracle for global constant repair, entry-param repair, producer wrapping, `local.get` skipping, fallthrough-shell preservation, and helper-name collision handling

## Refined local teaching consequence

This recheck does not change the Starshine status. It makes the current local guidance firmer:

- keep the pass unimplemented until Starshine grows a real module-owned instrumentation pass
- keep local `de-nan` request behavior documented as a removed-registry rejection, not as upstream `denan` support
- keep this pass out of no-DWARF preset-parity obligations unless a future source-backed scheduling decision says otherwise
- keep future validation centered on Binaryen's exact `denan` behavior, because current `main` still matches the reviewed `version_129` teaching contract closely enough for documentation and port-planning purposes

## Uncertainty

This was a focused source recheck, not a full commit-history archaeology pass. It did not attempt to prove when `denan` first entered Binaryen or whether any downstream distribution surfaces describe it differently. Use this file only for the current `version_129`-plus-`main` contract and Starshine port-planning consequences.
