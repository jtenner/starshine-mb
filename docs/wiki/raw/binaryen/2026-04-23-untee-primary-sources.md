# Binaryen `untee` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/untee/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `untee` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/untee/index.md`
- `docs/wiki/binaryen/passes/untee/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/untee/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/untee/flattening-code-pushing-and-tee-boundaries.md`
- `docs/wiki/binaryen/passes/untee/wat-shapes.md`
- `docs/wiki/binaryen/passes/untee/starshine-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/index.md`
- `docs/wiki/binaryen/passes/simplify-locals/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/index.md`

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

- `Untee.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Untee.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Untee.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `SimplifyLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>

### Official test files consulted

- `untee.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/untee.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/untee.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still confirmed that `untee` is a tiny function-parallel postwalk in `Untee.cpp`: it only visits `LocalSet` nodes, rewrites reachable `local.tee` nodes into explicit set-plus-get sequences, and deletes tee wrappers outright when the tee value is already `unreachable`.
- The reviewed public registration still confirmed that the official pass name is exactly `untee`, that Binaryen still describes it as removing local tees by replacing them with sets and gets, and that the pass remains outside the reviewed default no-DWARF optimize-path surface used by this repo's canonical parity docs.
- The reviewed dedicated lit file still confirmed the core teaching surface already captured in the living dossier: dropped-tee expansion, non-integer type preservation, tee-feeding-set behavior, nested inside-out expansion, and the first-class unreachable fast path.
- The reviewed neighboring `SimplifyLocals.cpp` source still mattered for interpretation, not because it implements `untee`, but because it helps keep the split explicit between the tiny tee-desugaring pass and the much broader `simplify-locals` family variants.
- A narrow 2026-04-23 current-`main` spot check on `Untee.cpp`, `pass.cpp`, `passes.h`, `SimplifyLocals.cpp`, and `untee.wast` did not surface a new teaching-relevant contract drift beyond the updated living dossier's claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
