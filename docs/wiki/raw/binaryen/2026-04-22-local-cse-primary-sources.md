# Binaryen `local-cse` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/local-cse/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `local-cse` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/local-cse/index.md`
- `docs/wiki/binaryen/passes/local-cse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-cse/basic-block-windows-and-barriers.md`
- `docs/wiki/binaryen/passes/local-cse/wat-shapes.md`
- `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`

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

- `LocalCSE.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalCSE.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Supporting upstream helper surfaces reviewed for the reuse-window, effects, and profitability story
  - `linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `properties.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.cpp>
  - `intrinsics.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
  - `cost.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>

### Official test files consulted

- `local-cse.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-cse.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the current living dossier's core teaching claim: `local-cse` in `version_129` is a **scan/check/apply** temp-local reuse pass for repeated whole expression trees in limited linear execution windows, not a CFG-wide or subtree-extracting CSE engine.
- The reviewed `LocalCSE.cpp` source still carried the same teaching-critical conservative boundaries already described in the living pages: first-occurrence originals, parent-over-child request cancellation, shallow side-effect and generativity filtering, trap-insensitive invalidation for repeated loads, and the narrow idempotent-direct-call carveout.
- The reviewed scheduler and helper surfaces still matched the current dossier's scheduler story: an extra aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` slot, a late ordinary `coalesce-locals -> local-cse -> simplify-locals` slot, and additional nested reruns via `optimizeAfterInlining` callers.
- The reviewed dedicated lit surface still demonstrated the same high-value positive and negative families already captured in the living dossier: same-block arithmetic and load reuse, before-`if` / `then` positives, after-`if` and local-write barriers, nested-call negatives, switch-child ordering, and the small-root profitability no-op cases.
- A narrow 2026-04-22 current-`main` spot check on `LocalCSE.cpp`, `pass.cpp`, `opt-utils.h`, and `local-cse.wast` did not surface a new teaching-relevant contract drift beyond the dossier's current Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
