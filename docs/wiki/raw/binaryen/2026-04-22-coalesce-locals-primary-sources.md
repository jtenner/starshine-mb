# Binaryen `coalesce-locals` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/coalesce-locals/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `coalesce-locals` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/coalesce-locals/index.md`
- `docs/wiki/binaryen/passes/coalesce-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/coalesce-locals/interference-and-ordering.md`
- `docs/wiki/binaryen/passes/coalesce-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md`

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

- `CoalesceLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CoalesceLocals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Supporting upstream helper surfaces reviewed for the liveness, value-numbering, and rewrite-cleanup story
  - `liveness-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
  - `numbering.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
  - `utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>

### Official test files consulted

- `coalesce-locals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/coalesce-locals.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the current living dossier's core teaching claim: `coalesce-locals` in `version_129` is a late nonlinear local-slot coalescer built from `LivenessWalker`, value-aware interference, greedy exact-type coloring, and rewrite cleanup, not a generic type-widening or whole-function register-allocation engine.
- The reviewed `CoalesceLocals.cpp` source still carried the same teaching-critical conservative boundaries already described in the living pages: exact-type-only merges, parameter freezing, zero-init entry reasoning, extra backedge-copy weighting, and dead-set / dead-tee cleanup that can require `ReFinalize()`.
- The reviewed scheduler and helper surfaces still matched the current dossier's scheduler story: an ordinary late `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` cluster plus a second later `reorder-locals -> coalesce-locals -> reorder-locals` cleanup pair, with additional nested reruns via `optimizeAfterInlining` callers.
- The reviewed dedicated lit surface still demonstrated the same high-value positive and negative families already captured in the living dossier: exact-type positives, equal-value overlap positives, differing-value overlap negatives, zero-init cases, copy-removal wins, loop-backedge priorities, and greedy-order sensitivity.
- A narrow 2026-04-22 current-`main` spot check on `CoalesceLocals.cpp`, `pass.cpp`, `opt-utils.h`, and `coalesce-locals.wast` did not surface a new teaching-relevant contract drift beyond the dossier's current Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
