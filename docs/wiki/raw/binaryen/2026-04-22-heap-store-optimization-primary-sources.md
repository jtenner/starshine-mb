# Binaryen `heap-store-optimization` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/heap-store-optimization/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `heap-store-optimization` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md`

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

- `HeapStoreOptimization.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/HeapStoreOptimization.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/HeapStoreOptimization.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `cfg-traversal.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/cfg-traversal.h>
- `effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>

### Official test files consulted

- `heap-store-optimization.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap-store-optimization.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap-store-optimization.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centered on the same teaching-relevant mechanics already described by the living dossier: CFG-local action collection for `struct.set` and `block`, immediate tee and later local-set folds, local motion across safe blockers, explicit default-constructor materialization, and `LazyLocalGraph` checks only when control flow can skip the moved `local.set`.
- The reviewed sources still make the narrow scope explicit: upstream `HeapStoreOptimization.cpp` continues to say the future work for generic dead-store elimination and load forwarding is still a TODO, so the public pass is still not a generic GC heap optimizer.
- The checked current-`main` `HeapStoreOptimization.cpp` and dedicated `heap-store-optimization.wast` file still matched the already-documented `version_129` teaching-relevant surfaces on this run; no new pass-contract drift was observed while preparing the provenance follow-up.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
