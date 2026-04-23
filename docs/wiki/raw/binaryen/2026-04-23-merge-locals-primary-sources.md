# Binaryen `merge-locals` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/merge-locals/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `merge-locals` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/merge-locals/index.md`
- `docs/wiki/binaryen/passes/merge-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-locals/local-graph-and-copy-influences.md`
- `docs/wiki/binaryen/passes/merge-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-locals/starshine-strategy.md`

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

- `MergeLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- Supporting upstream helper surfaces reviewed for the dossier's real dominance and copy-equivalence story
  - `local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - `LocalStructuralDominance.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalStructuralDominance.h>
  - `pass-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass-utils.h>

### Official test files consulted

- `merge-locals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-locals.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation corrected the dossier's older overread in two important ways: current Binaryen `merge-locals` is **not** gated by a local-name early bailout, and it **does** report `invalidatesDWARF() == true` in the pass source.
- The reviewed upstream implementation also corrected the older simplification that the pass normalizes any local with exactly one set into either one old slot or one fresh temp. The real `version_129` engine works from simple `local.set` roots, computes ordinary and set influences, consults `LocalStructuralDominance`, groups copy-equivalent alias locals, chooses one existing target local, and rewrites redundant copy sets plus dominated gets around that chosen existing slot.
- The reviewed source still keeps the same scheduler fact already taught in the dossier: `pass.cpp` inserts `merge-locals` only when `optimizeLevel >= 3 || shrinkLevel >= 2`, so the pass stays outside this repo's canonical no-DWARF `-O` / `-Os` path.
- The reviewed dedicated lit file still demonstrates the core user-visible families the refreshed dossier now centers: simple-set roots, direct and transitive copy-equivalence merges, loop/ordering cases, and negative cases such as extra sets or non-simple values.
- A narrow 2026-04-23 current-`main` spot check on `MergeLocals.cpp`, `pass.cpp`, `pass.h`, `local-graph.h`, `LocalStructuralDominance.h`, and `merge-locals.wast` did not surface a new teaching-relevant contract drift beyond the refreshed dossier claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
