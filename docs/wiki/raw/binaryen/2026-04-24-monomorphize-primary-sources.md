# Binaryen `monomorphize` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/monomorphize/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `monomorphize` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/monomorphize/index.md`
- `docs/wiki/binaryen/passes/monomorphize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/monomorphize/call-context-benefit-and-boundaries.md`
- `docs/wiki/binaryen/passes/monomorphize/clone-construction-signature-rebuild-and-dropped-call-rewrites.md`
- `docs/wiki/binaryen/passes/monomorphize/wat-shapes.md`
- `docs/wiki/binaryen/passes/monomorphize/starshine-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize-always/index.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish timestamp as **2026-04-01 14:31**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `Monomorphize.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Monomorphize.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `cost.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/cost.h>
- `effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- `find_all.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/find_all.h>
- `manipulation.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/manipulation.h>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- `names.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/names.h>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
- `return-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/return-utils.h>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
- `utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/utils.h>
- `wasm-limits.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-limits.h>

### Official test files consulted

- `monomorphize-benefit.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-benefit.wast>
- `monomorphize-consts.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-consts.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-consts.wast>
- `monomorphize-context.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-context.wast>
- `monomorphize-drop.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-drop.wast>
- `monomorphize-limits.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-limits.wast>
- `monomorphize-mvp.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-mvp.wast>
- `monomorphize-types.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-types.wast>
- `no-inline-monomorphize-inlining.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline-monomorphize-inlining.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish timestamp **2026-04-01 14:31**.
- The reviewed upstream implementation still confirmed the main contract already taught in the living dossier: scan original defined functions for direct-call candidates, build effect-safe executable `CallContext` operands, reject trivial contexts, clone and rebuild specialized functions, repair dropped-result calls, run nested optimization, and keep the clone only when the measured benefit satisfies the configured threshold.
- The reviewed test roster still confirmed the same main public families: threshold-sensitive benefit decisions, constant context, richer movable-context extraction, dropped-result specialization, `MaxParams = 20`-shaped limits, MVP-only usefulness, refined-reference specialization, and the interaction with copied `no-inline` state through monomorphization plus inlining.
- A narrow 2026-04-24 current-`main` spot check on `Monomorphize.cpp`, `pass.cpp`, the helper headers listed above, and the dedicated lit roster did not surface a new teaching-relevant contract drift beyond the updated living dossier's claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
