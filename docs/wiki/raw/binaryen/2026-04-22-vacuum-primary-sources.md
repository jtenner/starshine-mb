# Binaryen `vacuum` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/vacuum/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `vacuum` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/vacuum/index.md`
- `docs/wiki/binaryen/passes/vacuum/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/vacuum/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/vacuum/effect-pruning-and-traps-never-happen.md`
- `docs/wiki/binaryen/passes/vacuum/wat-shapes.md`
- `docs/wiki/binaryen/passes/vacuum/starshine-hot-ir-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that the `version_129` release page was still the reviewed official release surface for this dossier on this run.

### Official source files consulted

- `Vacuum.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Vacuum.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `branch-hints.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
- `drop.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>

### Official test files consulted

- `vacuum-func.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-func.wast>
- `vacuum-removable-if-unused.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-removable-if-unused.wast>
- `vacuum-removable-if-unused-func.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-removable-if-unused-func.wast>
- `vacuum-branch-hints.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-branch-hints.wast>
- `vacuum-global-effects.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
- `vacuum-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc.wast>
- `vacuum-gc-atomics.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc-atomics.wast>
- `vacuum-strings.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-strings.wast>
- `vacuum-desc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-desc.wast>
- `vacuum-eh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh.wast>
- `vacuum-eh-pop.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh-pop.wast>
- `vacuum-eh-legacy.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh-legacy.wast>
- `vacuum-intrinsics.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-intrinsics.wast>
- `vacuum-tnh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh.wast>
- `vacuum-tnh-mvp.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh-mvp.wast>
- `vacuum_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum_all-features.wast>
- Representative current-`main` spot checks
  - `Vacuum.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Vacuum.cpp>
  - `vacuum-func.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-func.wast>
  - `vacuum-tnh.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-tnh.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centered on the same teaching-relevant mechanics already described by the living dossier: effect-aware unused-result pruning, dedicated `block` / `if` / `loop` / `drop` / `try` / `try_table` cleanup, TNH trap-path pruning, whole-function cleanup, explicit-`unreachable` preservation, and mandatory post-edit refinalization.
- The reviewed source layout still makes the owner split visible: `Vacuum.cpp` is the core algorithm file, while `branch-hints.h` and `drop.h` own the main behavior-visible helper contracts and `pass.cpp` plus `opt-utils.h` explain why the pass appears repeatedly in optimize pipelines.
- A narrow 2026-04-22 current-`main` spot check on the pass file, registration file, and representative function/TNH tests did not surface a new teaching-relevant contract drift beyond what the living dossier already teaches. Future wiki updates should still re-check `main` directly if they need stronger freshness claims than this spot check.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
