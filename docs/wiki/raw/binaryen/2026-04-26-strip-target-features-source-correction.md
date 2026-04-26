# Binaryen `strip-target-features` source-correction capture

_Capture date:_ 2026-04-26  
_Status:_ immutable source-correction manifest for `docs/wiki/binaryen/passes/strip-target-features/`

## Scope

This capture corrects the earlier 2026-04-25 dossier for Binaryen's `strip-target-features` pass. The older dossier described the pass as an output-option toggle of `PassOptions::emitTargetFeatures`. Official `version_129` and current-`main` sources instead show a direct `Module` metadata flag mutation:

- `StripTargetFeatures::modifiesBinaryenIR() == true`
- `StripTargetFeatures::run(...)` sets `module->hasFeaturesSection = false`

The practical user-visible result is still target-feature custom-section omission in output, but the internal pass contract is not “IR unchanged.”

## Official primary sources consulted

### `src/passes/StripTargetFeatures.cpp`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
- raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/StripTargetFeatures.cpp>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
- raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/StripTargetFeatures.cpp>
- Reviewed locations:
  - file header: frames the pass as stripping target features from output for size;
  - `modifiesBinaryenIR()`: returns `true`;
  - `run(PassRunner*, Module*)`: assigns `module->hasFeaturesSection = false`.

### `src/passes/pass.cpp`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Reviewed location: public pass registration for `strip-target-features`, described as stripping the target-features section from output.

### `src/passes/passes.h`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Reviewed location: declaration of `createStripTargetFeaturesPass()`.

### Module metadata context

- Binaryen `src/wasm/wasm.h` in `version_129` and current `main` was checked for `hasFeaturesSection`; the module-level flag is the state the pass mutates.
- WebAssembly core custom-section context: <https://webassembly.github.io/spec/core/binary/modules.html#custom-section>

## Durable corrected observations

- `strip-target-features` is a real public Binaryen pass in `version_129` and current `main`.
- The pass is intentionally tiny, but it **does modify Binaryen module state** by clearing `Module::hasFeaturesSection`.
- The pass does not walk or rewrite functions, expressions, types, imports, exports, memories, tables, globals, data, or element segments.
- The output effect is still whole target-features section omission.
- The pass does not filter individual features, lower feature-using opcodes, repair validation, or strip arbitrary custom sections.
- The earlier local dossier's output-shape conclusions remain mostly useful, but every “option-only,” “emitTargetFeatures,” and “modifiesBinaryenIR false / IR unchanged” claim is superseded.

## Starshine relevance

Starshine currently has no `strip-target-features` registry entry. The closest local surfaces are opaque custom-section storage and binary round-trip code:

- `src/lib/types.mbt:350-424`: `Module.custom_secs` and `CustomSec`
- `src/binary/decode.mbt:1153-1195`: custom-section decoding preserves non-`name` custom sections opaquely
- `src/binary/encode.mbt:1134-1143`: `CustomSec` encoding
- `src/binary/encode.mbt:1653-1743`: module-level custom-section emission
- `src/validate/validate.mbt:2284-2291`: raw `name` custom-section guard, no target-features semantics

A faithful Starshine port cannot be described as toggling a Binaryen-like `emitTargetFeatures` option unless such an option is added. The closest current implementation shape would be a module pass deleting only `CustomSec(Name::new("target_features"), ...)` records, but that is an opaque-section mutation rather than Binaryen's typed `hasFeaturesSection` flag.

## Uncertainty and caveats

- The reviewed source makes the current contract clear, but the exact upstream commit that changed or introduced the `hasFeaturesSection` model was not chased in this run.
- Binaryen's `hasFeaturesSection` is more semantic than Starshine's current opaque custom-section list. Future local implementation work should decide whether to add first-class target-feature metadata or implement a narrower decoded-custom-section deletion pass.
- Custom sections are non-executing from the WebAssembly core execution perspective, but downstream tools may rely on `target_features` metadata. Stripping it should remain an explicit user/product choice.

## Supersedes

This capture supersedes the incorrect source-mechanics portions of:

- `docs/wiki/raw/binaryen/2026-04-25-strip-target-features-primary-sources.md`
- `docs/wiki/raw/research/0334-2026-04-25-strip-target-features-primary-sources-and-starshine-followup.md`

The older files remain useful for provenance and broad neighboring-pass distinctions, but not for the owner-file mechanics.
