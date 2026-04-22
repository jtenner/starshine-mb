# Binaryen `dead-code-elimination` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/dead-code-elimination/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `dead-code-elimination` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/dead-code-elimination/index.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/typed-control-voidification-and-eh.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/wat-shapes.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/starshine-hot-ir-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that the `version_129` release page was still the reviewed official release surface for this dossier on this run.

### Official source files consulted

- `DeadCodeElimination.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

### Official test files consulted

- `dce_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast>
- `dce_vacuum_remove-unused-names.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast>
- `dce-eh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast>
- `dce-eh-legacy.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh-legacy.wast>
- `dce-stack-switching.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast>
- Representative current-`main` spot checks
  - `DeadCodeElimination.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp>
  - `dce_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce_all-features.wast>
  - `dce-eh.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce-eh.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still matched the living dossier's main correction: Binaryen `dce` is a small `TypeUpdater`-centered unreachable-shape postwalk, not a broad `EffectAnalyzer`-driven dead-result simplifier.
- The reviewed source layout stayed small and easy to teach: `DeadCodeElimination.cpp` owns the pass logic, while `pass.cpp` owns the public registration and pipeline placement. The visible proof surface is concentrated in the dedicated `dce_all-features`, combo-neighbor, EH, legacy-EH, and stack-switching lit files rather than in a scattered helper forest.
- A narrow 2026-04-22 current-`main` spot check on the pass file, registration file, and representative ordinary/EH tests did not surface a new teaching-relevant contract drift beyond what the living dossier already teaches. Future wiki updates should still re-check `main` directly if they need stronger freshness claims than this spot check.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
