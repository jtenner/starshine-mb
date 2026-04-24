# Binaryen `legalize-js-interface` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/legalize-js-interface/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `legalize-js-interface` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/legalize-js-interface/index.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/temp-ret-helpers-and-pruning-split.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/wat-shapes.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release date as **2026-04-01 14:31** when reviewed.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep the dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `LegalizeJSInterface.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/LegalizeJSInterface.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LegalizeJSInterface.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/LegalizeJSInterface.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `i64.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/i64.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/i64.h>
- `import-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/import-utils.h>
- `literal-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/literal-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/literal-utils.h>
- `shared-constants.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/shared-constants.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm/shared-constants.h>

### Official test files consulted

- `legalize-js-interface_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_all-features.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/legalize-js-interface_all-features.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface_all-features.wast>
- `legalize-js-interface-exported-helpers.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface-exported-helpers.wast>
- `legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast>
- `legalize-and-prune-js-interface.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-and-prune-js-interface.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing date **2026-04-01 14:31**.
- `pass.cpp` registers `legalize-js-interface` and its sibling `legalize-and-prune-js-interface` as separate public pass names, but both are implemented in the same `LegalizeJSInterface.cpp` owner file.
- The plain pass is a JS-boundary `i64` function-signature legalizer: export stubs rebuild wasm `i64` arguments, import wrappers split wasm `i64` arguments, `i64` results use temp-ret helpers for high halves, and direct `call` plus `ref.func` uses of legalized imports are retargeted.
- `i64.h` owns the low/high splitting and recreation helpers that keep the wrapper bodies from hand-rolling every bit operation in the main pass file.
- `import-utils.h`, `literal-utils.h`, and `shared-constants.h` provide supporting import lookup, default-value, and stable-name surfaces, but the pass-specific control flow remains in `LegalizeJSInterface.cpp`.
- The dedicated lit roster proves the ordinary import/export wrapper shapes, `ref.func` repair, exported-helper reuse, optional `orig$` exports, and the sibling prune behavior.
- The Starshine-specific follow-up in this run did not find a local registry entry or owner file. The durable local fact is that `legalize-js-interface` is **unknown/upstream-only** in current Starshine rather than boundary-only, removed, or active.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper headers, and dedicated lit files did not surface a teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
