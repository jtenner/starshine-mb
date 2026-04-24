# Binaryen `dae-optimizing` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/dae-optimizing/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `dae-optimizing` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/dae-optimizing/index.md`
- `docs/wiki/binaryen/passes/dae-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae-optimizing/signature-updates-and-nested-reruns.md`
- `docs/wiki/binaryen/passes/dae-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dead-argument-elimination/index.md`
- `docs/wiki/binaryen/passes/dead-argument-elimination/implementation-structure-and-tests.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `DeadArgumentElimination.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `param-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.h>
- `return-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/return-utils.h>
- `lubs.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/lubs.h>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>

### Official test files consulted

- `dae-optimizing.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-optimizing.wast>
- `dae-refine-params-and-optimize.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-refine-params-and-optimize.wast>
- `dae-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc.wast>
- `dae-gc-refine-params.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-params.wast>
- `dae-gc-refine-return.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-return.wast>
- `dae_tnh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae_tnh.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01**.
- `DeadArgumentElimination.cpp` still owns the shared direct-call boundary rewrite engine for both public pass names; `pass.cpp` distinguishes `dae` from `dae-optimizing`; and `opt-utils.h` owns the optimizing-only nested cleanup helper.
- The reviewed dedicated tests still expose the same main public families the living pages teach: visible cleanup after parameter removal, GC parameter and result refinement, constant actual materialization, dropped-return cleanup, TNH/unreachable repair, and the extra optimizing replay.
- A narrow 2026-04-24 current-`main` spot check on `DeadArgumentElimination.cpp`, `pass.cpp`, `opt-utils.h`, the helper headers, and the dedicated lit roster did not surface a new teaching-relevant contract drift beyond the refreshed living dossier's claims.
- Local Starshine naming intentionally remains a separate repository fact: the upstream public pass is `dae-optimizing`, while current Starshine's boundary-only registry entry is the descriptive name `dead-argument-elimination-optimizing` in `src/passes/optimize.mbt`.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
