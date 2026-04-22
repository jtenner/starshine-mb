# Binaryen `simplify-locals-nostructure` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/simplify-locals-nostructure/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `simplify-locals-nostructure` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/simplify-locals-nostructure/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/variant-surface.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that `version_129` was still the latest official reviewed release surface for this dossier during this run.

### Official source files consulted

- `SimplifyLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Supporting upstream helper surfaces reviewed for the locals-family analysis and safety story
  - `local-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `equivalent_sets.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - `linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>

### Official test files consulted

- `simplify-locals-nostructure.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nostructure.wast>
- `simplify-locals-nostructure.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nostructure.txt>
- Nearby variant tests rechecked for contrast
  - `simplify-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - `simplify-locals.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
  - `simplify-locals-notee-nostructure.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - `simplify-locals-notee-nostructure.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - `simplify-locals-nonesting.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - `simplify-locals-nonesting.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the current living dossier's core teaching claim: `simplify-locals-nostructure` in `version_129` is the shared locals-family engine instantiated as **`SimplifyLocals<true, false, true>`**, not a separate algorithm and not a no-tee or no-nesting variant.
- The reviewed `pass.cpp` source still matched the current dossier's scheduler story: in the canonical no-DWARF pipeline Binaryen runs `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals`, while the more aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude remains a different slot.
- The reviewed implementation still carried the same teaching-critical mechanics already described in the living pages: a first cycle limited to easy single-use sinks, later tee-enabled multi-use sinking, directional effect invalidation, explicit `try` / `try_table` throwing-value barriers, late equivalent-get canonicalization, and final dead-set cleanup.
- The reviewed dedicated lit surface still demonstrated the same high-value positive and negative families already captured in the living dossier: tee-enabled contrast cases, sink-into-existing-consumer positives, overwrite cleanup, trap-sensitive barriers, and preserved block / `if` structure in this no-structure variant.
- A narrow 2026-04-22 current-`main` spot check on `SimplifyLocals.cpp`, `pass.cpp`, `passes.h`, `opt-utils.h`, and the dedicated no-structure test files did not surface a new teaching-relevant contract drift beyond the dossier's current Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
