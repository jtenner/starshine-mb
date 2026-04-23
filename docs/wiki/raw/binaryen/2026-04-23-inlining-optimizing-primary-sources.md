# Binaryen `inlining-optimizing` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/inlining-optimizing/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `inlining-optimizing` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/inlining-optimizing/index.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/planning-partial-inlining-and-reruns.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/inlining/index.md`
- `docs/wiki/binaryen/passes/inlining/binaryen-strategy.md`

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
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- `NoInline.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/NoInline.cpp>
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

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still confirmed the most important source correction already captured in the neighboring plain-`inlining` dossier: actual chosen inline actions in `version_129` are planned from reachable direct `call` / `return_call` sites, while `call_ref` / `call_indirect` logic remains part of repair and surrounding helper surfaces rather than the main chosen-action planner contract.
- The reviewed dedicated tests still exposed the same main public families the living pages now teach: tiny and one-use helpers, root-surviving inlines, tail-call and unreachable repairs, narrow Pattern A / Pattern B partial inlining, explicit no-inline controls, and the optimizing variant's nested rerun payoff.
- A narrow 2026-04-23 current-`main` spot check on `Inlining.cpp`, `pass.cpp`, `opt-utils.h`, `pass.h`, `NoInline.cpp`, `module-utils.cpp`, and the dedicated lit roster did not surface a new teaching-relevant contract drift beyond the updated living dossier's claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
