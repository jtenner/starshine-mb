# Binaryen `const-hoisting` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/const-hoisting/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `const-hoisting` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/const-hoisting/index.md`
- `docs/wiki/binaryen/passes/const-hoisting/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/const-hoisting/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/const-hoisting/size-model-and-boundaries.md`
- `docs/wiki/binaryen/passes/const-hoisting/literal-bit-identity-zero-signs-and-nan-payloads.md`
- `docs/wiki/binaryen/passes/const-hoisting/wat-shapes.md`
- `docs/wiki/binaryen/passes/const-hoisting/starshine-strategy.md`
- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/index.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/index.md`

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

- `ConstHoisting.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstHoisting.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ConstHoisting.cpp>
- `literal.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/literal.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/literal.h>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `insert_ordered.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/insert_ordered.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/insert_ordered.h>
- `wasm-binary.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-binary.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-binary.h>
- `wasm-builder.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-builder.h>

### Official test files consulted

- `const-hoisting.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/const-hoisting.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/const-hoisting.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still confirmed that `const-hoisting` is a tiny function-parallel pass centered in `ConstHoisting.cpp`, with public registration in `pass.cpp`, exact float-bucket semantics inherited from `Literal` equality and hashing, deterministic bucket order coming from `InsertOrderedMap`, real integer byte-size costing delegated to `wasm-binary.h`, and builder-driven fresh-local prelude insertion through `wasm-builder.h`.
- The reviewed dedicated lit file still confirmed the main teaching surface already captured in the living dossier: exact signed-LEB and float profitability thresholds, stable prelude ordering, the tested wrapper-block output shape, unsupported `v128`, and the tiny stale inline source comment that still describes the final `f64` example as if it were a 4-byte threshold case even though the checked output and implementation both prove the real `f64` rule is 8 bytes and 2 uses.
- A narrow 2026-04-23 current-`main` spot check on `ConstHoisting.cpp`, `literal.h`, `pass.cpp`, `insert_ordered.h`, `wasm-binary.h`, `wasm-builder.h`, and `const-hoisting.wast` did not surface a new teaching-relevant contract drift beyond the updated living dossier's claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
