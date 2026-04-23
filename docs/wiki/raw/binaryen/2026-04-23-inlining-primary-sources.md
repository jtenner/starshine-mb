# Binaryen `inlining` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/inlining/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 plain-`inlining` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/inlining/index.md`
- `docs/wiki/binaryen/passes/inlining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inlining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/inlining/heuristics-splitting-and-plain-vs-optimizing.md`
- `docs/wiki/binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md`
- `docs/wiki/binaryen/passes/inlining/wat-shapes.md`
- `docs/wiki/binaryen/passes/inlining/starshine-strategy.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/index.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-23.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-23.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `Inlining.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Inlining.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `NoInline.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/NoInline.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- `wasm.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>
- `wasm.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm/wasm.cpp>
- `wasm-binary.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-binary.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm/wasm-binary.cpp>
- `contexts.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/parser/contexts.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/parser/contexts.h>
- `module-utils.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>

### Official test files consulted

- `inlining.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining.wast>
- `inlining_optimize-level=3.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_optimize-level=3.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_optimize-level=3.wast>
- `inlining_enable-tail-call.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_enable-tail-call.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_enable-tail-call.wast>
- `inlining_splitting.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_splitting.wast>
- `inlining_splitting_basics.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting_basics.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_splitting_basics.wast>
- `inlining-trivial-instructions.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-instructions.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-trivial-instructions.wast>
- `inlining-trivial-calls-1.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-calls-1.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-trivial-calls-1.wast>
- `inlining-unreachable.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-unreachable.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-unreachable.wast>
- `inlining-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-gc.wast>
- `no-inline.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline.wast>
- `no-inline-monomorphize-inlining.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline-monomorphize-inlining.wast>
- `inline-main.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inline-main.wast>
- `inline-hints.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/inline-hints.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/inline-hints.wast>
- `inline-hints-func.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/inline-hints-func.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/inline-hints-func.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still confirmed the main plain-`inlining` contract already taught in the living dossier: actual chosen inline actions in `version_129` are planned from reachable direct `call` / `return_call` sites, while `call_ref` / `call_indirect` logic remains part of repair and surrounding helper surfaces rather than the main chosen-action planner contract.
- The reviewed source and dedicated tests still confirmed the same main public families the living pages now teach: layered tiny / one-caller / trivial wrapper heuristics, root-surviving inlines, tail-call and unreachable repairs, narrow Pattern A / Pattern B partial inlining, explicit `no-inline*` controls, and the real split between preserved `@metadata.code.inline` bytes and practical function-level no-inline booleans.
- A narrow 2026-04-23 current-`main` spot check on `Inlining.cpp`, `pass.cpp`, `NoInline.cpp`, `opt-utils.h`, `pass.h`, `wasm.h`, `wasm.cpp`, `wasm-binary.cpp`, `contexts.h`, `module-utils.cpp`, and the dedicated lit roster did not surface a new teaching-relevant contract drift beyond the updated living dossier's claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
