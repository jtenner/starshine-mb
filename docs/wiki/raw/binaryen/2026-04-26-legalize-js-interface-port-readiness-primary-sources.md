# Binaryen `legalize-js-interface` current-main / port-readiness primary-source capture

_Capture date:_ 2026-04-26  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/legalize-js-interface/` port-readiness bridge

## Scope

This file records the primary online sources rechecked while deepening the `legalize-js-interface` dossier from a source-correct overview into an implementation-readiness guide for a possible future Starshine module pass.

Use the living pages for interpretation:

- `docs/wiki/binaryen/passes/legalize-js-interface/index.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/temp-ret-helpers-and-pruning-split.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/wat-shapes.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/starshine-strategy.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/starshine-port-readiness-and-validation.md`

## Official sources rechecked

### Binaryen current `main`

- `LegalizeJSInterface.cpp`
  - Browser URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LegalizeJSInterface.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/LegalizeJSInterface.cpp>
  - Rechecked on 2026-04-26 as the current upstream owner file for both public pass names.
- `pass.cpp`
  - Browser URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Rechecked for the public registration split between `legalize-js-interface` and `legalize-and-prune-js-interface`.
- `i64.h`
  - Browser URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/i64.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/i64.h>
  - Rechecked because low/high `i64` split/recreate helpers are part of the wrapper-body contract.
- `shared-constants.h`
  - Browser URL: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm/shared-constants.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm/shared-constants.h>
  - Rechecked for stable temp-ret helper names used by the pass.

### Binaryen `version_129`

- `LegalizeJSInterface.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `i64.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/i64.h>
- `shared-constants.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/shared-constants.h>

These tagged links remain the stable release anchors already captured by `docs/wiki/raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`.

### Official lit fixtures rechecked

- `legalize-js-interface_all-features.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface_all-features.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_all-features.wast>
- `legalize-js-interface-exported-helpers.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface-exported-helpers.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast>
- `legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast>
- `legalize-and-prune-js-interface.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-and-prune-js-interface.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>

## Durable observations

- The 2026-04-26 current-main recheck did not find a teaching-relevant drift from the earlier `version_129` contract for the plain pass: `legalize-js-interface` is still a JS-boundary `i64` wrapper pass, not whole-module `i64` lowering.
- The same owner file still implements both public names. A Starshine port should therefore keep the sibling relation explicit even if it lands the plain pass before prune mode.
- The plain-pass shape remains wrapper-first and deletion-last: synthesize export stubs, synthesize legalized imports plus wasm-facing wrappers, repair `call` / `ref.func` users, then remove original illegal imports.
- The official fixtures remain the best beginner-to-advanced oracle set: ordinary all-feature coverage, exported-helper reuse, `export-originals`, and prune-mode removal/stubbing are separate validation lanes.
- Starshine still has no local registry entry, owner file, module dispatcher case, or active backlog slice for this pass family as of the local code reviewed on 2026-04-26.

## Uncertainties and caveats

- This capture is a focused pass-family recheck, not a whole Binaryen drift audit.
- The current Starshine code has useful module/import/export/type/ref.func substrates, but no tested pass-level abstraction for inserting wrapper functions and remapping all function indices. The living port-readiness page keeps that as a design risk rather than implying implementation is near-complete.
- `legalize-and-prune-js-interface` remains a sibling with additional unsupported-feature pruning; this file only deepens the plain `legalize-js-interface` port-readiness path and cross-links the prune page where relevant.
