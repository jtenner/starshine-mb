# Binaryen `type-generalizing` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the corrected `docs/wiki/binaryen/passes/type-generalizing/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `type-generalizing` source-correction follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/type-generalizing/index.md`
- `docs/wiki/binaryen/passes/type-generalizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-generalizing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-generalizing/local-flow-type-floor-and-boundaries.md`
- `docs/wiki/binaryen/passes/type-generalizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-generalizing/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - Used as the tagged release anchor for this correction.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep this dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `TypeGeneralizing.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeGeneralizing.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeGeneralizing.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeGeneralizing.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `wasm-type.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-type.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm/wasm-type.h>
  - Reviewed as the owner of the `Type::isSubType(...)` and `Type::getLeastUpperBound(...)` type-lattice calls used by the pass.

### Official test files consulted

- `type-generalizing.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-generalizing.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-generalizing.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-generalizing.wast>

### Negative source check

The previous living dossier described an upstream `experimental-type-generalizing-with-optimizing-casts` sibling and a `type-generalizing-with-optimizing-casts.wast` lit file. A fresh 2026-04-24 source check did **not** find either surface in the reviewed `version_129` sources. The checked `pass.cpp` registration surface instead shows one hidden/test pass name, `experimental-type-generalizing`, and `TypeGeneralizing.cpp` exports one `createTypeGeneralizingPass()` constructor.

## Durable observations from the captured sources

- The earlier 0191 research-note interpretation is stale for the reviewed `version_129` source. It attributed this pass to a `ContentOracle`-driven `struct.get` / `struct.set` / `call_ref` / `ref.cast` family that the actual `TypeGeneralizing.cpp` file does not implement.
- `pass.cpp` registers `experimental-type-generalizing` with `registerTestPass(...)`, not a normal public pass registration and not a two-sibling family.
- `TypeGeneralizing.cpp` is a small function pass. It is not a module-wide closed-world GC oracle pass.
- The owner file keeps a map from local index to observed value type, uses `Type::isSubType(...)` and `Type::getLeastUpperBound(...)`, and performs a walk that can retag defaultable expressions to a better local-flow type.
- The special local-get case replaces a retagged `local.get` with a sequence that drops the original get and materializes a zero/default value of the chosen type; this preserves side effects of evaluating the local-get operand shape while avoiding an invalid direct type mutation of the get.
- The pass does not define visitors for `struct.get`, `struct.set`, `call_ref`, `ref.cast`, `ContentOracle`, or `ReFinalize`.
- The dedicated lit file proves the intended local-flow/generalization behavior and nearby no-op or safety cases; it does not prove a GC oracle or cast-optimizing sibling.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `type-generalizing` is a preserved **boundary-only** registry name, not an active HOT or module pass; it is absent from the active `optimize` / `shrink` presets and has no dedicated backlog slice today.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, and dedicated lit file did not surface teaching-relevant contract drift from the corrected `version_129` story beyond a comment spelling cleanup.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
