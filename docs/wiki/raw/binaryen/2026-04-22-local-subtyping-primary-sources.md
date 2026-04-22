# Binaryen `local-subtyping` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/local-subtyping/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `local-subtyping` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/local-subtyping/index.md`
- `docs/wiki/binaryen/passes/local-subtyping/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-subtyping/lubs-and-dominance.md`
- `docs/wiki/binaryen/passes/local-subtyping/wat-shapes.md`
- `docs/wiki/binaryen/passes/local-subtyping/starshine-strategy.md`

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

- `LocalSubtyping.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Supporting upstream helper surfaces reviewed for the LUB and dominance story
  - `lubs.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - `type-updating.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `local-structural-dominance.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>

### Official test files consulted

- `local-subtyping.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation corrected an earlier over-broad local reading in this repo's dossier: `local-subtyping` in `version_129` is a **small definition-driven local-type retagging pass**, not a generic local-flow collector over `local.get`, `ref.as_non_null`, or `LocalUpdater`-driven copy-local insertion.
- The reviewed `LocalSubtyping.cpp` source showed the teaching-critical mechanics that now anchor the living pages:
  - one `LUBFinder` per original local, seeded from the declared local type for non-parameter vars only
  - fact collection from **`local.set` / `local.tee` definitions only**
  - candidate narrowing restricted to reference-typed locals
  - a `LocalStructuralDominance::dominatesAll(...)` gate for non-nullability tightening
  - direct declaration and `local.get` / `local.tee` type retagging instead of `LocalUpdater(...).changeType(...)`
- The reviewed helper surfaces still supported the narrower source-backed story now captured in the living dossier: LUB computation in `lubs.h`, helper-support gating through `TypeUpdating::canHandleAsLocal(...)`, and structured-control dominance used as a guard rather than as a general rewrite engine.
- The reviewed dedicated lit surface still demonstrated the same high-value positive and negative families now captured in the living dossier: set-driven narrowing, common-parent LUBs, tee retagging, dominance-gated non-nullability, and preserved param / tuple / undominated-get cases.
- The reviewed pass source did **not** support several claims that had previously drifted into the older local summary: there is no `visitRefAs` collector here, no `visitLocalGet` evidence collection, no `LocalUpdater` call, no helper-added copy-local path, and no trailing `ReFinalize()` step in the reviewed `version_129` pass body.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
