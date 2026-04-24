# Binaryen `avoid-reinterprets` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/avoid-reinterprets/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `avoid-reinterprets` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/avoid-reinterprets/index.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/single-load-chains-and-bailouts.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/wat-shapes.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-strategy.md`

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

- `AvoidReinterprets.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AvoidReinterprets.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
- `wasm.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm/wasm.h>

### Official test files consulted

- `avoid-reinterprets.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/avoid-reinterprets.wast>
- `avoid-reinterprets64.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/avoid-reinterprets64.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the existing living dossier's main teaching claims: public registration as `avoid-reinterprets`, a small function-parallel postwalker centered in `AvoidReinterprets.cpp`, direct `reinterpret(load)` load-type flips, indirect `reinterpret(local.get)` helper-local rewrites, and conservative `LocalGraph` single-source provenance checks.
- The reviewed lit tests still prove the same important contract boundaries: memory32 positives, mixed-use helper-local duplication, copy-chain eligibility, partial-load no-ops, non-fallthrough wrapper bailouts, and the memory64 pointer-temp rule in the dedicated `avoid-reinterprets64.wast` file.
- A narrow 2026-04-24 current-`main` spot check on `AvoidReinterprets.cpp`, `pass.cpp`, `local-graph.h`, `properties.h`, `avoid-reinterprets.wast`, and `avoid-reinterprets64.wast` did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.
- The Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is still that `avoid-reinterprets` is a preserved **removed** registry name, not an active HOT or module pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
