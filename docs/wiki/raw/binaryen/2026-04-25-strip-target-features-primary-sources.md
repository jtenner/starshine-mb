# Binaryen `strip-target-features` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/strip-target-features/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `strip-target-features` dossier.
Use the living pages for explanation:

- `docs/wiki/binaryen/passes/strip-target-features/index.md`
- `docs/wiki/binaryen/passes/strip-target-features/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/strip-target-features/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/strip-target-features/wat-shapes.md`
- `docs/wiki/binaryen/passes/strip-target-features/starshine-strategy.md`

## Provenance

### Official release and changelog pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - This is the tagged source baseline used by the surrounding pass wiki.
- Binaryen `CHANGELOG.md`
  - `version_129` tag: <https://github.com/WebAssembly/binaryen/blob/version_129/CHANGELOG.md>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/CHANGELOG.md>
  - Current `main`: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
  - Key caveat: the reviewed changelog text did not provide a clear human-readable `strip-target-features` addition note. Treat the source files below, not the changelog, as the primary proof of the pass contract.

### Official Binaryen source files consulted

- `StripTargetFeatures.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/StripTargetFeatures.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
  - Key reviewed locations:
    - file header framing the pass as an output-size pass for tools that know their target and do not need feature metadata;
    - `modifiesBinaryenIR() == false`, which is the central contract: the pass changes output options, not the module IR;
    - `run(PassRunner*, Module*)`, which sets `runner->options.emitTargetFeatures = false`.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key reviewed location: public registration for `strip-target-features`, described as stripping the target-features section from the output.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: `createStripTargetFeaturesPass()` declaration in the ordinary public pass-constructor roster.

### Specification context consulted

- WebAssembly Core specification, custom sections
  - URL: <https://webassembly.github.io/spec/core/binary/modules.html#custom-section>
  - Key context: custom sections are metadata from the core execution perspective. This supports teaching `strip-target-features` as metadata-output cleanup rather than an instruction or validation rewrite.

## Durable observations from the captured sources

- `strip-target-features` is a real public Binaryen pass in `version_129`.
- The pass does not rewrite functions, expressions, types, imports, exports, memories, tables, globals, data, or element segments.
- Its entire reviewed source-level behavior is to set `PassOptions::emitTargetFeatures` to `false`.
- `modifiesBinaryenIR() == false` is important: callers should not expect the in-memory `Module` to differ after the pass.
- The user-visible output change is the absence of Binaryen's emitted `target_features` custom section when output is written after the pass.
- This pass is different from `strip-toolchain-annotations`, which removes Binaryen IR annotations, and from `remove-relaxed-simd`, which rewrites relaxed-SIMD instructions to traps.
- Starshine currently has no registry entry for `strip-target-features`, and local binary encode/decode support treats arbitrary custom sections opaquely through `Module.custom_secs` rather than modeling a first-class target-features option.

## Uncertainty and caveats

- The reviewed `CHANGELOG.md` pages do not give the same clear provenance story that many other pass dossiers have. Older wiki text had called out `strip-target-features` in a pass-addition chronology; this capture narrows the claim to source-level presence in `version_129` and current `main` unless a future run finds a more precise release note or commit.
- Binaryen's behavior is output-option state, not IR mutation. A Starshine port that only removes `CustomSec("target_features", ...)` entries from an already-decoded module would mimic one possible binary-shape result but would not be the same architecture as Binaryen's pass.
- The WebAssembly core spec says custom sections are metadata, but producers and downstream tools may still rely on target-feature metadata for feature discovery. Stripping it should be an explicit user-requested or product-policy choice, not an optimizer's default side effect.
- The exact Binaryen test filenames for `strip-target-features` should be source-confirmed in the target upstream revision before future implementation signoff; this dossier intentionally relies on the small owner file and pass registration as the primary contract.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
