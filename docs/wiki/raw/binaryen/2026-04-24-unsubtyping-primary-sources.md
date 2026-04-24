# Binaryen `unsubtyping` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/unsubtyping/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `unsubtyping` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/unsubtyping/index.md`
- `docs/wiki/binaryen/passes/unsubtyping/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/unsubtyping/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/unsubtyping/descriptor-squares-casts-and-js-boundaries.md`
- `docs/wiki/binaryen/passes/unsubtyping/wat-shapes.md`
- `docs/wiki/binaryen/passes/unsubtyping/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep the dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `Unsubtyping.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Unsubtyping.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Unsubtyping.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `subtype-exprs.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtype-exprs.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/subtype-exprs.h>
- `js-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/js-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/js-utils.h>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
- `type-updating.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.cpp>
- `localize.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/localize.h>
- `effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- `wasm-type.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type.h>

### Official test files consulted

- `unsubtyping.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/unsubtyping.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping.wast>
- `unsubtyping-casts.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/unsubtyping-casts.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-casts.wast>
- `unsubtyping-cmpxchg.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/unsubtyping-cmpxchg.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-cmpxchg.wast>
- `unsubtyping-desc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/unsubtyping-desc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-desc.wast>
- `unsubtyping-desc-tnh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/unsubtyping-desc-tnh.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-desc-tnh.wast>
- `unsubtyping-jsinterop.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/unsubtyping-jsinterop.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-jsinterop.wast>
- `unsubtyping-stack-switching.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/unsubtyping-stack-switching.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-stack-switching.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the existing living dossier's main teaching claims: hard GC and `--closed-world` gates, public-type freezing, JS-boundary analysis, module-wide validation-constraint discovery through `SubtypingDiscoverer`, ordinary-vs-exact cast handling, descriptor-square completion, descriptor-allocation fixups, private-type graph rewriting through shared type-updating machinery, and final refinalization.
- The reviewed lit roster remains intentionally broad: baseline validation constraints, cast success preservation, ref cmpxchg typing, descriptors and traps, traps-never-happen descriptor behavior, JS interop, and stack-switching / continuation constraints.
- The source remains stronger than any single lit file for the helper split. `Unsubtyping.cpp` owns the pass-specific relation fixed point, while `subtype-exprs.h`, `js-utils.h`, `type-updating.*`, `localize.h`, and `effects.h` own much of the real correctness surface.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper headers, and dedicated lit files did not surface a teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.
- The Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `unsubtyping` is a preserved **boundary-only** registry name, not an active HOT or module pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
