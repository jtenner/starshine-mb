# Binaryen `rse` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/rse/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `rse` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/rse/index.md`
- `docs/wiki/binaryen/passes/rse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/rse/cfg-and-value-tracking.md`
- `docs/wiki/binaryen/passes/rse/wat-shapes.md`
- `docs/wiki/binaryen/passes/rse/starshine-strategy.md`

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

- `RedundantSetElimination.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Supporting upstream helper surfaces reviewed for the local-value, CFG, and replacement story
  - `local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - `liveness.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/liveness.h>
  - `numbering.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
  - `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>

### Official test files consulted

- `rse_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/rse_all-features.wast>
- `rse_all-features.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/rse_all-features.txt>
- `rse-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/rse-gc.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the current living dossier's core teaching claim: `rse` in `version_129` is a **locals-only** late cleanup pass built around `LocalSet` / `LocalGet`, `LocalGraph`, liveness, and value numbering rather than generic global, memory, or GC field-store elimination.
- The reviewed `RedundantSetElimination.cpp` source still carried the same teaching-critical conservative boundary already described in the living pages: exact straight-line local-value reasoning, predecessor merge tracking, same-block read rewriting, and an explicit refusal to claim stronger loop precision than the current block-input model can justify.
- The reviewed dedicated test surfaces still demonstrated the same high-value positive and negative families already captured in the living dossier: overwritten-set removal, copied-local inheritance, exact-vs-merged predecessor behavior, same-block read rewriting, GC refined-expression substitution, and negative type-compatibility cases.
- A narrow 2026-04-22 current-`main` spot check on `RedundantSetElimination.cpp`, `pass.cpp`, `opt-utils.h`, `rse_all-features.wast`, `rse_all-features.txt`, and `rse-gc.wast` did not surface a new teaching-relevant contract drift beyond the dossier's current Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
