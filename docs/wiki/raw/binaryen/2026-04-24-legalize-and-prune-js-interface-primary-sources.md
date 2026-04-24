# Binaryen `legalize-and-prune-js-interface` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `legalize-and-prune-js-interface` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/index.md`
- `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/prune-boundary-matrix.md`
- `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/wat-shapes.md`
- `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/starshine-strategy.md`

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
- Shared plain-pass helper surfaces already captured by the sibling manifest in `docs/wiki/raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`:
  - `src/passes/i64.h`
  - `src/ir/import-utils.h`
  - `src/ir/literal-utils.h`
  - `src/wasm/shared-constants.h`

### Official test files consulted

- `legalize-and-prune-js-interface.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-and-prune-js-interface.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/legalize-and-prune-js-interface.wast>
- Plain-family fixture used to verify the inherited first phase:
  - `legalize-js-interface-exported-helpers.wast` `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast>
  - `legalize-js-interface_all-features.wast` `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_all-features.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing date **2026-04-01 14:31**.
- `pass.cpp` registers `legalize-js-interface` and `legalize-and-prune-js-interface` as separate public pass names even though both are implemented in `LegalizeJSInterface.cpp`.
- `LegalizeAndPruneJSInterface` is a subclass of `LegalizeJSInterface`; its run path calls the plain pass first, then calls `prune(module)`.
- The prune sibling's legality predicate is feature-based, not merely an `i64` test: boundary-visible SIMD, multivalue results, exception-handling types, and stack-switching types are illegal after the inherited plain legalization phase.
- The function-prune branch is asymmetric by boundary direction: illegal imports are converted into defined functions with `nop`, zero/default literals, or `unreachable` bodies, while illegal exports are removed without deleting function bodies.
- Function pruning is followed by `ReFinalize()` / module-code refinalization before the global-export prune pass, matching the source comment about `ref.func` type facts.
- Illegal global exports are removed, but the globals themselves are not rewritten or deleted by this pass.
- The dedicated prune lit file is the strongest public proof surface for the import-stub, function-export-removal, imported-and-exported combined, result-defaultability, and global-export-removal matrix.
- The Starshine-specific follow-up in this run did not find a local registry entry or owner file for `legalize-and-prune-js-interface`. The durable local fact is that it is **unknown/upstream-only** in current Starshine rather than boundary-only, removed, or active.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, and dedicated prune lit file did not surface a teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
