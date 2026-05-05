# Binaryen `strip-target-features` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable source manifest for `docs/wiki/binaryen/passes/strip-target-features/`

## Scope

This capture rechecks current `main` against the existing `strip-target-features` dossier. The goal is freshness, not a contract change.

## Official primary sources consulted

### Binaryen `src/passes/StripTargetFeatures.cpp`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
- raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/StripTargetFeatures.cpp>
- Reviewed symbols:
  - `struct StripTargetFeatures : public Pass`
  - `bool isStripped`
  - `StripTargetFeatures(bool isStripped)`
  - `requiresNonNullableLocalFixups() override { return false; }`
  - `void run(Module* module) override { module->hasFeaturesSection = !isStripped; }`
  - `createStripTargetFeaturesPass()`
  - `createEmitTargetFeaturesPass()`

### Binaryen `src/passes/pass.cpp`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Reviewed symbols:
  - `registerPass("emit-target-features", ...)`
  - `registerPass("strip-target-features", ...)`

### Binaryen `src/passes/passes.h`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Reviewed symbols:
  - `createEmitTargetFeaturesPass()`
  - `createStripTargetFeaturesPass()`

### Binaryen `src/pass.h`

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- Reviewed symbol:
  - base `Pass::modifiesBinaryenIR()` default behavior remains the source of the pass's mutation reporting.

### WebAssembly custom-section context

- Core spec custom sections: <https://webassembly.github.io/spec/core/binary/modules.html#custom-section>

## Durable observations

- Current `main` still matches `version_129` on the reviewed surfaces.
- `strip-target-features` and `emit-target-features` still share one tiny owner class.
- Stripping still means `module->hasFeaturesSection = false`; emitting still means `true`.
- The pass still does not walk function bodies or rewrite executable wasm.
- The pass still reports mutation through Binaryen's base `Pass` default, not through a local owner override.
- `requiresNonNullableLocalFixups()` is still false.
- The pass still differs from `strip-toolchain-annotations` and `remove-relaxed-simd`.

## Uncertainty and caveats

- This recheck did not chase the historical introduction commit for the shared owner shape.
- This recheck did not audit the target-feature payload format because the pass does not inspect individual entries.
- A future Starshine port still has the same architecture choice: first-class metadata, opaque custom-section deletion, or deliberate unknown/boundary-only status.
