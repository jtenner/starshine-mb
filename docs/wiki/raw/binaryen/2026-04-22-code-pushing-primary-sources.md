# Binaryen `code-pushing` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/code-pushing/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `code-pushing` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/code-pushing/index.md`
- `docs/wiki/binaryen/passes/code-pushing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/segment-selection-and-barriers.md`
- `docs/wiki/binaryen/passes/code-pushing/wat-shapes.md`
- `docs/wiki/binaryen/passes/code-pushing/starshine-strategy.md`

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

- `CodePushing.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Supporting upstream helper surfaces reviewed for this dossier's effect, barrier, and rewrite story
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - `parents.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/parents.h>
  - `find_all.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>

### Official test files consulted

- `code-pushing.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing.wast>
- `code-pushing_into_if.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing_into_if.wast>
- `code-pushing_ignore-implicit-traps.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- `code-pushing_tnh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing_tnh.wast>
- `code-pushing-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing-gc.wast>
- `code-pushing-eh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing-eh.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the teaching-important contract already captured in the living dossier: block-local contiguous-suffix scanning, separate generic-segment versus direct-`if` sinking paths, strict two-arm `if` purity rules, a one-arm-unreachable special case, and local profitability gating before rewrite.
- The reviewed dedicated test files still exposed the same main positive and negative families already taught in the living pages: branchy segment sinking, one-arm and two-arm `if` motion, option-relaxed trap handling, GC-participating cases, and EH-sensitive bailout coverage.
- A narrow 2026-04-22 current-`main` spot check on `CodePushing.cpp`, `pass.cpp`, `opt-utils.h`, and the dedicated `code-pushing*` lit files did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
