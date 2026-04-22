# Binaryen `tuple-optimization` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/tuple-optimization/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `tuple-optimization` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/tuple-optimization/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/tuple-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-map.md`
- `docs/wiki/binaryen/passes/tuple-optimization/scheduler-and-gates.md`
- `docs/wiki/binaryen/passes/tuple-optimization/parity.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01** and marked this tag as the latest reviewed official release surface on that day.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that `version_129` was still the reviewed official release surface for this dossier on this run.

### Official source files consulted

- `TupleOptimization.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `OptimizeInstructions.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeInstructions.cpp>
- `wasm.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
- `wasm-validator.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp>

### Official test files consulted

- `tuple-optimization.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still matched the living dossier's central teaching rule: `tuple-optimization` is a narrow tuple-local scratch-storage splitter, not a generic multivalue optimizer.
- The reviewed source layout still showed the same ownership split already described in the dossier: `TupleOptimization.cpp` owns the full pass logic, `pass.cpp` owns the multivalue gate plus scheduler placement, `OptimizeInstructions.cpp` owns the earlier direct `tuple.extract(tuple.make(...))` peephole boundary, and `wasm.cpp` plus `wasm-validator.cpp` own the tuple typing and validation neighbors that make the scalarization rules meaningful.
- A narrow 2026-04-22 current-`main` spot check on `TupleOptimization.cpp`, the relevant `pass.cpp` scheduler lines, the tuple-specific `OptimizeInstructions.cpp` peephole, and the dedicated `tuple-optimization.wast` file did not surface a new teaching-relevant contract drift beyond the living dossier's current claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
