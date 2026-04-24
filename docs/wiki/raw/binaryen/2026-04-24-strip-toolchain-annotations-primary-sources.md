# Binaryen `strip-toolchain-annotations` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/strip-toolchain-annotations/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `strip-toolchain-annotations` dossier.
Use the living pages for explanation:

- `docs/wiki/binaryen/passes/strip-toolchain-annotations/index.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/wat-shapes.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/starshine-strategy.md`

## Provenance

### Official release and changelog pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.
- Binaryen `CHANGELOG.md`
  - `version_129` tag: <https://github.com/WebAssembly/binaryen/blob/version_129/CHANGELOG.md>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/CHANGELOG.md>
  - Key reviewed surface: `version_126` adds `@binaryen.removable.if.unused`, `@binaryen.js.called`, and the public `--strip-toolchain-annotations` pass for those intrinsics and future toolchain annotations.

### Official Binaryen source files consulted

- `StripToolchainAnnotations.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripToolchainAnnotations.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/StripToolchainAnnotations.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripToolchainAnnotations.cpp>
  - Key reviewed locations:
    - file header explaining that VMs do not need these toolchain annotations and that the pass should run after toolchain optimizations no longer need them.
    - `WalkerPass<PostWalker<StripToolchainAnnotations>>`, `isFunctionParallel() == true`, and `requiresNonNullableLocalFixups() == false`.
    - `doWalkFunction(...)`, which strips function-level annotations and walks `codeAnnotations`.
    - `remove(CodeAnnotation&)`, which clears `removableIfUnused`, `jsCalled`, and `idempotent`.
    - the empty-annotation cleanup path that erases a per-expression annotation entry once no bits remain.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key reviewed location: public registration for `strip-toolchain-annotations`, described as stripping all toolchain-specific code annotations.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: `createStripToolchainAnnotationsPass()` declaration in the ordinary public pass-constructor roster.

### Official Binaryen tests consulted

- `strip-toolchain-annotations.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/strip-toolchain-annotations.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/strip-toolchain-annotations.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/strip-toolchain-annotations.wast>
  - Key reviewed surface: direct before/after proof that `@binaryen.removable.if.unused` and `@binaryen.idempotent` code annotations disappear, while `@metadata.code.inline` remains even when paired with a removed toolchain annotation.

## Durable observations from the captured sources

- `strip-toolchain-annotations` is a real public Binaryen pass in `version_129`; the changelog records it as a `version_126` addition.
- The pass is a metadata/code-annotation cleanup pass, not an expression optimizer.
- The pass is function-parallel and does not require non-nullable local fixups.
- Source review proves three removed annotation bits today: `removableIfUnused`, `jsCalled`, and `idempotent`.
- The lit file directly proves removal for `@binaryen.removable.if.unused` and `@binaryen.idempotent`, plus preservation of `@metadata.code.inline`.
- The lit file does not directly isolate `@binaryen.js.called`; that removal is source-backed by `remove(CodeAnnotation&)` and release-note provenance.
- The reviewed current-`main` source and lit file still present the same teaching-level contract as `version_129`.
- No local Starshine registry entry for `strip-toolchain-annotations` was found in this repo on 2026-04-24, although Starshine already has WAT parser/lowering and in-memory `FuncAnnotationSec` surfaces for Binaryen-style annotations.

## Uncertainty and caveats

- This capture records Binaryen IR annotation cleanup. It does not prove a generic custom-section stripping contract; do not conflate this pass with `strip-debug`, `strip-producers`, or `strip-target-features`.
- Starshine's current annotation storage is not a one-to-one model of Binaryen's `Function::funcAnnotations` plus per-expression `codeAnnotations`, so a future port must decide whether it is matching Binaryen's printed WAT behavior, Binaryen's binary custom annotation sections, or only Starshine's in-memory `FuncAnnotationSec` subset.
- The source clears `jsCalled`, but the dedicated lit file reviewed here does not have an isolated `@binaryen.js.called` check. Treat that as source-backed behavior with less direct test proof than the two lit-covered annotation families.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
