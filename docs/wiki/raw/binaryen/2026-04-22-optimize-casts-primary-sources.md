# Binaryen `optimize-casts` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/optimize-casts/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `optimize-casts` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/optimize-casts/index.md`
- `docs/wiki/binaryen/passes/optimize-casts/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-casts/two-phase-dataflow.md`
- `docs/wiki/binaryen/passes/optimize-casts/wat-shapes.md`
- `docs/wiki/binaryen/passes/optimize-casts/starshine-strategy.md`

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

- `OptimizeCasts.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeCasts.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Supporting upstream helper surfaces reviewed for the linear-window, fallthrough, and effect-barrier story
  - `linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>

### Official test files consulted

- `optimize-casts.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-casts.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the current living dossier's core teaching claim: `optimize-casts` in `version_129` is a **two-phase local GC cast cleanup** pass, not a generic optimizer for every cast-like instruction.
- The reviewed `OptimizeCasts.cpp` source still carried the same teaching-critical scope boundary already described in the living pages: only `ref.cast` and `ref.as_non_null` are handled here, with strict earlier-motion rules and looser later-reuse rules.
- The reviewed helper surfaces still supported the same source-backed mechanics already captured in the living dossier: `LinearExecutionWalker` windows, `Properties::getFallthrough(...)`-based local tracking, shallow effect barriers for the earlier-motion phase, fresh refined-local materialization, and mandatory `ReFinalize` after each rewrite half.
- The reviewed dedicated lit surface still demonstrated the same high-value positive and negative families already captured in the living dossier: earlier cast duplication, later refined-local reuse, same-index local-write barriers, side-effect and call barriers, `ref.as_non_null` positives, and ignored unsupported cast families.
- A narrow 2026-04-22 current-`main` spot check on `OptimizeCasts.cpp`, `pass.cpp`, `opt-utils.h`, and `optimize-casts.wast` did not surface a new teaching-relevant contract drift beyond the dossier's current Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
