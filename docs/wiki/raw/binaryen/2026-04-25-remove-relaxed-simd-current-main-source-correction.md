# Binaryen `remove-relaxed-simd` current-main source correction

_Capture date:_ 2026-04-25  
_Status:_ immutable focused source-correction manifest for `docs/wiki/binaryen/passes/remove-relaxed-simd/`

## Scope

This manifest extends the 2026-04-24 `remove-relaxed-simd` source capture after a fresh primary-source recheck found one teaching-relevant correction: the reviewed `version_129` / current-`main` owner file does **not** contain the previously documented per-function relaxed-SIMD feature gate or `changed` flag. The pass still traps relaxed SIMD expressions, preserves child effects with `ChildLocalizer`, and refinalizes visited functions.

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/remove-relaxed-simd/index.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/starshine-strategy.md`

## Primary sources rechecked

### Official Binaryen owner file

- `RemoveRelaxedSIMD.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveRelaxedSIMD.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveRelaxedSIMD.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveRelaxedSIMD.cpp>
  - Reviewed surfaces:
    - `RemoveRelaxedSIMD` is a `WalkerPass<PostWalker<RemoveRelaxedSIMD>>`.
    - `doWalkFunction(...)` calls `PostWalker::doWalkFunction(func)` and then `ReFinalize().walkFunctionInModule(func, getModule())`.
    - No `getModule()->features.hasRelaxedSIMD()` or equivalent feature check was found in the reviewed owner file.
    - No `changed` field or conditional refinalization was found in the reviewed owner file.
    - `rewrite(...)` still uses `ChildLocalizer` and returns a block ending in `makeUnreachable()`.
    - `visitUnary`, `visitBinary`, and `visitSIMDTernary` still enumerate the relaxed-SIMD families directly.

### Official Binaryen registration and declarations

- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed surface: the public pass remains registered as `remove-relaxed-simd` with help text describing replacement of relaxed SIMD instructions by `unreachable`.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Reviewed surface: `createRemoveRelaxedSIMDPass()` remains declared.

### Official Binaryen tests

- `remove-relaxed-simd.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-relaxed-simd.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-relaxed-simd.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-relaxed-simd.wast>
  - Reviewed surface: the dedicated lit file still proves relaxed operations become traps and ordinary SIMD neighbors survive.
  - Naming caveat: the Binaryen lit/source names for the dot-product relaxed family omit the textual `relaxed_` prefix (`i16x8.dot_i8x16_i7x16_s`, `i32x4.dot_i8x16_i7x16_add_s`), while Starshine's WAT keyword table currently uses `i16x8.relaxed_dot_i8x16_i7x16_s` and `i32x4.relaxed_dot_i8x16_i7x16_add_s`.

### Proposal context

- WebAssembly relaxed SIMD proposal overview: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>
- Proposal repository: <https://github.com/WebAssembly/relaxed-simd>

The proposal context remains supporting background for why the family is implementation-defined; the Binaryen owner file remains the source of truth for this pass's trap-replacement behavior.

## Corrections to carry forward

- Replace the older claim “skip each function if the module feature set does not include relaxed SIMD” with: the reviewed owner file walks each function and always calls `ReFinalize` after the walk; if no relaxed expressions are present, the visitor has no matching rewrite.
- Replace “refinalizes changed functions” with: the reviewed owner file refinalizes each visited function after the postwalk.
- Keep the feature-metadata caveat narrow: the reviewed source does not show a feature-section cleanup step, but this is different from proving an explicit feature-gated no-op path.
- Keep the text-name caveat visible for dot-product examples when mapping Binaryen WAT to Starshine's current keyword spelling.

## Relation to the older 2026-04-24 capture

The previous raw manifest remains useful for the broad dossier. This file supersedes it only for the feature-gate / changed-function details and the clarified dot-product spelling caveat. It does not change the core strategy: relaxed SIMD operations trap, child effects are preserved, ordinary SIMD remains out of scope, and Starshine has no local pass implementation today.
