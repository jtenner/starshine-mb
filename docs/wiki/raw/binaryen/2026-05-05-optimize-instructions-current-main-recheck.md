# Binaryen `optimize-instructions` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable source manifest for the 2026-05-05 current-main freshness check in the `docs/wiki/binaryen/passes/optimize-instructions/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-05-05 `optimize-instructions` recheck.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- `docs/wiki/binaryen/passes/optimize-instructions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/optimize-instructions/gc-casts-call_ref-and-trap-sensitive-rewrites.md`
- `docs/wiki/binaryen/passes/optimize-instructions/wat-shapes.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md`

## Provenance

### Official source files consulted

- `OptimizeInstructions.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeInstructions.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
- `pass.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>

### Official test files consulted

- `optimize-instructions-default.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-default.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-default.wast>
- `optimize-instructions-sign_ext.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-sign_ext.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast>
- `optimize-instructions-bulk-memory.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-bulk-memory.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-bulk-memory.wast>
- `optimize-instructions-call_ref.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-call_ref.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-call_ref.wast>
- `optimize-instructions-gc.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-gc.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-gc.wast>
- `optimize-instructions-gc-tnh.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-gc-tnh.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-gc-tnh.wast>
- `optimize-instructions-multivalue.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions-multivalue.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-multivalue.wast>
- `optimize-instructions_branch-hints-fold.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-instructions_branch-hints-fold.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions_branch-hints-fold.wast>

## Durable observations from the captured sources

- The reviewed current-main pass and representative tests stayed aligned with the existing `version_129` dossier on the reviewed surfaces.
- The pass still teaches best as a local canonicalization and rewrite engine with a broad helper surface, not as a tiny arithmetic-only peephole.
- The 2026-05-05 wiki update is therefore a freshness and navigation refresh, not a contract rewrite.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
