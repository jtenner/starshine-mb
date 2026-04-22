# Binaryen `optimize-instructions` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/optimize-instructions/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `optimize-instructions` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- `docs/wiki/binaryen/passes/optimize-instructions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/optimize-instructions/gc-casts-call_ref-and-trap-sensitive-rewrites.md`
- `docs/wiki/binaryen/passes/optimize-instructions/wat-shapes.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md`

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

- `OptimizeInstructions.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeInstructions.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `bits.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
- `branch-hints.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
- `call-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
- `drop.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>
- `effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `eh-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
- `gc-type-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
- `literal-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/literal-utils.h>
- `load-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/load-utils.h>
- `localize.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h>
- `manipulation.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- `properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>

### Official test files consulted

- `optimize-instructions-default.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-default.wast>
- `optimize-instructions-sign_ext.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast>
- `optimize-instructions-bulk-memory.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-bulk-memory.wast>
- `optimize-instructions-call_ref.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-call_ref.wast>
- `optimize-instructions-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-gc.wast>
- `optimize-instructions-gc-tnh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-gc-tnh.wast>
- `optimize-instructions-multivalue.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-multivalue.wast>
- `optimize-instructions_branch-hints-fold.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions_branch-hints-fold.wast>
- Representative current-`main` spot checks
  - `OptimizeInstructions.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeInstructions.cpp>
  - `optimize-instructions-default.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-default.wast>
  - `optimize-instructions-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-gc.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centered on the same teaching-relevant mechanics already described by the living dossier: local bit/sign-extension prescan, iterative local canonicalization, arithmetic and boolean peepholes, memory and bulk-memory cleanup, `call_ref` directization, GC cast/null-trap reasoning, and deferred `ReFinalize` plus EH-pop repair.
- The reviewed source layout still makes the owner split visible: `OptimizeInstructions.cpp` is the core algorithm file, but the pass contract depends on helper semantics from `bits.h`, `properties.h`, `effects.h`, `gc-type-utils.h`, `localize.h`, `type-updating.h`, `call-utils.h`, `branch-hints.h`, `drop.h`, `eh-utils.h`, `literal-utils.h`, `load-utils.h`, and `manipulation.h`.
- A narrow 2026-04-22 current-`main` spot check on the pass file, registration file, and representative default/GC test files did not surface a new teaching-relevant contract drift beyond what the living dossier already teaches. Future wiki updates should still re-check `main` directly if they need stronger freshness claims than this spot check.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
