# Binaryen `code-folding` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/code-folding/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `code-folding` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/code-folding/index.md`
- `docs/wiki/binaryen/passes/code-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-folding/terminating-tails.md`
- `docs/wiki/binaryen/passes/code-folding/wat-shapes.md`
- `docs/wiki/binaryen/passes/code-folding/starshine-strategy.md`

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

- `CodeFolding.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Supporting upstream helper surfaces reviewed for this dossier's movement-safety and helper-label story
  - `utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - `branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `eh-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
  - `label-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/label-utils.h>

### Official test files consulted

- `code-folding.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-folding.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation remained the same teaching-relevant split already captured in the living dossier: expression-exit folding over named block exits and foldable unnamed `if` arms, plus a separate recursive function-terminating suffix search for `return`, `return_call*`, and `unreachable` tails.
- The reviewed `CodeFolding.cpp` source still carried the same high-value negative contract already called out in the dossier: unsupported branch forms poison label-based folding, with `br_on_*` still explicitly left outside the handled branch family.
- The reviewed dedicated lit file still demonstrated the same teaching-relevant positive and negative families already captured in the living dossier: identical unnamed-arm folds, branch-value tail sharing, helper-label terminating-tail folds, and the scope-sensitive bailout families around outer break targets and `br_on_null`.
- A narrow 2026-04-22 current-`main` spot check on `CodeFolding.cpp`, `pass.cpp`, `opt-utils.h`, and the dedicated `code-folding.wast` file did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
