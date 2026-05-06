# Binaryen `strip-toolchain-annotations` current-main recheck

_Capture date:_ 2026-05-06  
_Status:_ immutable current-main freshness manifest for the `strip-toolchain-annotations` pass

## Scope

This capture rechecks the official Binaryen sources that matter to the existing `strip-toolchain-annotations` contract.
It asks one question: does current `main` still match the version_129 teaching story?

The answer on the reviewed surfaces is yes.

## Official sources reviewed

- Binaryen `src/passes/StripToolchainAnnotations.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripToolchainAnnotations.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripToolchainAnnotations.cpp>
  - Reviewed surfaces: the late-run header note, `WalkerPass<PostWalker<...>>`, function-parallel execution, no non-nullable local fixups, `doWalkFunction(...)`, `funcAnnotations` stripping, per-expression `codeAnnotations` cleanup, and the `removableIfUnused` / `jsCalled` / `idempotent` allowlist.
- Binaryen `src/passes/pass.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Reviewed surfaces: public `strip-toolchain-annotations` registration and the `strip all toolchain-specific code annotations` summary.
- Binaryen `test/lit/passes/strip-toolchain-annotations.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/strip-toolchain-annotations.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/strip-toolchain-annotations.wast>
  - Reviewed surfaces: direct proof that `@binaryen.removable.if.unused` and `@binaryen.idempotent` disappear while `@metadata.code.inline` remains.
- Binaryen `CHANGELOG.md`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/CHANGELOG.md>
  - Reviewed surfaces: `v126` introduction of `@binaryen.removable.if.unused`, `@binaryen.js.called`, and `--strip-toolchain-annotations`.

## Durable observations

- Current `main` still matches the earlier source contract on the reviewed surfaces.
- The pass remains a narrow metadata/code-annotation cleanup pass, not an expression optimizer.
- The implementation is still function-parallel and still does not require non-nullable local fixups.
- The source-backed removed annotation bits remain `removableIfUnused`, `jsCalled`, and `idempotent`.
- The official lit file still directly proves removal for `@binaryen.removable.if.unused` and `@binaryen.idempotent`, plus preservation of `@metadata.code.inline`.
- `@binaryen.js.called` remains source-backed but less directly lit-backed than the other two removed families.

## Uncertainty and caveats

- This is a narrow freshness check, not a proof that every neighboring helper file is unchanged.
- The current Starshine annotation model is still narrower than Binaryen's function-level plus per-expression annotation surface, so local parity remains a separate implementation question.
- The capture does not prove a generic custom-section stripping contract.
