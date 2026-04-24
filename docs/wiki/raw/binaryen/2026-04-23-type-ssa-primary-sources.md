# Binaryen `type-ssa` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/type-ssa/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `type-ssa` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/type-ssa/index.md`
- `docs/wiki/binaryen/passes/type-ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-ssa/created-exact-types-control-values-and-signature-rewrites.md`
- `docs/wiki/binaryen/passes/type-ssa/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/index.md`
- `docs/wiki/binaryen/passes/ssa/index.md`

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

- `TypeSSA.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeSSA.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `ReFinalize.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp>

### Official test files consulted

- `type-ssa.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-ssa.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page and releases index both showing the release on **2026-04-01**.
- The reviewed upstream implementation still matched the existing living dossier's main teaching claims: public registration as `type-ssa`, a tiny function-pass implementation centered on the `createdTypes` map, a narrow constructor/cast seed surface, conservative `block` / `if` / `try` carried-value forwarding, explicit `loop` exclusion, and GC-only `ReFinalize` after successful retagging.
- The reviewed dedicated test still exposed the same main positive and preserved families already taught in the living pages: local/global forwarding from freshly created exact values, control-value agreement through `if` and `try`, direct call-operand sharpening, return-value sharpening, and preserved broad types when the proof is too weak.
- A narrow 2026-04-23 current-`main` spot check on `TypeSSA.cpp`, `pass.cpp`, `ReFinalize.cpp`, and `type-ssa.wast` did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
