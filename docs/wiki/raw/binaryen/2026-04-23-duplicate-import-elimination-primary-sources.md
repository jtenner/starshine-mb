# Binaryen `duplicate-import-elimination` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/duplicate-import-elimination/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `duplicate-import-elimination` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/duplicate-import-elimination/index.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/identity-and-rewrite-surface.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/wat-shapes.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/starshine-strategy.md`

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

- `DuplicateImportElimination.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateImportElimination.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateImportElimination.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `import-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/import-utils.h>

### Official test files consulted

- `duplicate-import-elimination.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/duplicate-import-elimination.wast>
- `duplicate-import-elimination.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.txt>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/duplicate-import-elimination.txt>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the teaching-important corrected contract already captured in the living dossier: a tiny late module pass over imported **functions** only, `(module, base)` bucketing plus exact function-type equality, first-import-wins canonicalization, `OptUtils::replaceFunctions(...)` rewrites, and direct duplicate imported-function removal.
- The reviewed dedicated test pair still exposed the same main positive and negative families already taught in the living pages: duplicate imported-function collapse, preserved different-signature imports, retargeted element payloads, `start` rewrite, and direct-call rewrite.
- A narrow 2026-04-23 current-`main` spot check on `DuplicateImportElimination.cpp`, `pass.cpp`, `passes.h`, `opt-utils.h`, `import-utils.h`, and the dedicated test pair did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
