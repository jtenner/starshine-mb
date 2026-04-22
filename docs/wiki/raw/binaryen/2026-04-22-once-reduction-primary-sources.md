# Binaryen `once-reduction` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/once-reduction/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `once-reduction` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/once-reduction/index.md`
- `docs/wiki/binaryen/passes/once-reduction/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/once-reduction/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/once-reduction/dominance-propagation-and-cycle-safety.md`
- `docs/wiki/binaryen/passes/once-reduction/wat-shapes.md`
- `docs/wiki/binaryen/passes/once-reduction/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/once-reduction/parity.md`

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

- `OnceReduction.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OnceReduction.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Supporting upstream helper surface reviewed for the annotation path
  - `intrinsics.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>

### Official test files consulted

- `once-reduction.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/once-reduction.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still lives in a compact but real four-owner structure inside `OnceReduction.cpp`: `Scanner`, `OnceReduction::run(...)`, `Optimizer`, and `optimizeOnceBodies(...)`.
- The reviewed source still exposes the easy-to-miss upstream-only `@binaryen.idempotent` path through `Intrinsics::getAnnotations(func.get()).idempotent` plus `Names::getValidGlobalName(...)`, while the dedicated lit file still does not foreground that path directly.
- The reviewed dedicated lit file still demonstrates the same teaching-relevant families already captured in the living dossier: classic repeated-call positives, loop and after-merge conservatism, nonconstant-initializer acceptance, nonconstant later-write rejection, and tiny wrapper cleanup.
- A narrow 2026-04-22 current-`main` spot check on `OnceReduction.cpp` and the dedicated `once-reduction.wast` file did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims; the reviewed `main` surfaces still exposed the same checked idempotent and nonconstant-initializer teaching points as `version_129`.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
