# Binaryen `reorder-locals` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/reorder-locals/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `reorder-locals` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/reorder-locals/index.md`
- `docs/wiki/binaryen/passes/reorder-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-locals/names-roundtrip-and-porting.md`
- `docs/wiki/binaryen/passes/reorder-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/parity.md`
- `docs/wiki/binaryen/passes/reorder-locals/multivalue-call-scope.md`

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

- `ReorderLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderLocals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Supporting upstream boundary files reviewed for the remaining non-pass-local parity caveat
  - `wasm-ir-builder.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-ir-builder.cpp>
  - `wasm-stack.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-stack.cpp>

### Official test files consulted

- `reorder-locals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.wast>
- `reorder-locals.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.txt>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.txt>
- `reorder-locals_print_roundtrip.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.wast>
- `reorder-locals_print_roundtrip.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.txt>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.txt>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass remained a very small function-parallel implementation concentrated in `ReorderLocals.cpp`: one local-user `ReIndexer`, one access-count plus first-use sorter, one zero-count body-local truncation step, and one local-name-map repair step.
- The reviewed dedicated tests still split into two important proof families:
  - `reorder-locals.wast` / `.txt` for count ordering, zero-count trimming, and parameter stability
  - `reorder-locals_print_roundtrip.wast` / `.txt` for declaration-order and printed-name roundtrip visibility
- The reviewed supporting boundary files still explain the remaining non-pass-local multivalue-call drift discussed in the dossier: `wasm-ir-builder.cpp` and `wasm-stack.cpp` own tuple scratch-local packaging and emitted-local expansion, not `ReorderLocals.cpp` itself.
- A narrow 2026-04-22 current-`main` spot check on `ReorderLocals.cpp`, `pass.cpp`, and the dedicated pass tests did not surface a new teaching-relevant contract drift beyond the dossier's existing claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
