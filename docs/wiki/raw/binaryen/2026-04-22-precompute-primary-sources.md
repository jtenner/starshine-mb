# Binaryen `precompute` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/precompute/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `precompute` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/precompute/propagation-partial-precompute-and-gc-identity.md`
- `docs/wiki/binaryen/passes/precompute/wat-shapes.md`
- `docs/wiki/binaryen/passes/precompute/starshine-hot-ir-strategy.md`

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

- `Precompute.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `wasm-interpreter.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>

### Official test files consulted

- `precompute-effects.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-effects.wast>
- `precompute-partial.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-partial.wast>
- `precompute.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute.wast>
- `precompute-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc.wast>
- `precompute-gc-immutable.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-immutable.wast>
- `precompute-gc-atomics.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-atomics.wast>
- `precompute-ref-func.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-ref-func.wast>
- `precompute-strings.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-strings.wast>
- `precompute-relaxed.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-relaxed.wast>
- `precompute-propagate-partial.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
- Representative current-`main` spot checks
  - `Precompute.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
  - `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centered on the same teaching-relevant mechanics already described by the living dossier: bounded compile-time execution, effect-aware child retention for local and global writes, a block-specific quadratic-work bailout, upward partial-`select` precompute, `LazyLocalGraph` propagation in the sibling mode, GC identity / emitability boundaries, and final refinalization.
- The reviewed source layout still makes the owner split visible: `Precompute.cpp` is the core algorithm file, while `pass.cpp`, `passes.h`, and `opt-utils.h` explain the public plain-vs-propagate surface and scheduler role, and `local-graph.h`, `properties.h`, and `wasm-interpreter.h` own the main behavior-visible helper contracts.
- A narrow 2026-04-22 current-`main` spot check on `Precompute.cpp` and `pass.cpp` did not surface a new teaching-relevant contract drift beyond the already-recorded newer-than-`version_129` notes kept in the living dossier. Future wiki updates should still re-check `main` directly if they need stronger freshness claims than this spot check.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
