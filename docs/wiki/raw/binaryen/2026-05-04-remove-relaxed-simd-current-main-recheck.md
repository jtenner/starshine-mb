# Binaryen `remove-relaxed-simd` current-main recheck

_Capture date:_ 2026-05-04  
_Status:_ immutable focused source recheck for the `docs/wiki/binaryen/passes/remove-relaxed-simd/` dossier

## Scope

This file captures a narrow primary-source recheck of Binaryen `remove-relaxed-simd` after the 2026-04-26 dossier refresh. It is intentionally a source manifest and drift note, not the main teaching document.

Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/remove-relaxed-simd/index.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/starshine-port-readiness-and-validation.md`

## Primary online sources rechecked

### Official Binaryen repository sources

- `RemoveRelaxedSIMD.cpp`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveRelaxedSIMD.cpp>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveRelaxedSIMD.cpp>
- `pass.cpp`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `child-localizer.h`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/child-localizer.h>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/child-localizer.h>

### Official Binaryen tests

- `remove-relaxed-simd.wast`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-relaxed-simd.wast>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-relaxed-simd.wast>

### Proposal background

- WebAssembly relaxed SIMD overview: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>

## Recheck result

The 2026-05-04 recheck found **no teaching-relevant current-main drift** for `remove-relaxed-simd` beyond the 2026-04-25 correction and 2026-04-26 port-readiness note.

The durable contract remains:

- upstream public pass spelling is `remove-relaxed-simd`
- `RemoveRelaxedSIMD.cpp` still owns the implementation
- the pass still replaces relaxed SIMD expressions with traps rather than deterministic SIMD substitutions
- `ChildLocalizer` is still the child-effect preservation mechanism
- the pass still postwalks functions and refinalizes them
- relaxed unary, binary, and ternary opcode families remain the covered rewrite surface
- ordinary deterministic SIMD stays unchanged
- Binaryen's source/test spelling split for relaxed dot-product forms still differs from Starshine's current keyword spelling
- the dedicated `remove-relaxed-simd.wast` file still remains the compact behavior oracle

## Refined local teaching consequence

This recheck does not change the Starshine status. It makes the current local guidance firmer:

- keep the pass unimplemented in Starshine until a real rewrite pass lands
- keep local request rejection documented as registry truth, not as an upstream support gap
- keep child-effect preservation and dot-product spelling separation explicit in the future port plan
- keep feature-metadata cleanup separate unless a future source proves Binaryen does it here

## Uncertainty

This was a focused source recheck, not a full commit-history archaeology pass. It did not attempt to prove when `remove-relaxed-simd` first entered Binaryen or whether any downstream distribution surfaces describe it differently. Use this file only for the current `version_129`-plus-`main` contract and Starshine port-planning consequences.
