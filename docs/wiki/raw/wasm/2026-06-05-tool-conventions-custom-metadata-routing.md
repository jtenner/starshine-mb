---
kind: raw-source
status: current
last_reviewed: 2026-06-05
sources:
  - https://webassembly.github.io/spec/core/appendix/custom.html
  - https://github.com/WebAssembly/tool-conventions/blob/main/ProducersSection.md
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/validate.mbt
related:
  - ../../binary/custom-and-name-sections.md
  - ../../wast/code-metadata-and-function-annotations.md
  - ../../binaryen/passes/strip-target-features/index.md
  - ../../binaryen/passes/strip-target-features/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/strip-toolchain-annotations/index.md
---

# Tool-Conventions Custom Metadata Routing (2026-06-05)

## Why this note exists

The living custom/name-section guide already covered Core 3.0 custom sections, the structured `name` section, official `@name` / `@custom` text annotations, and Starshine's local `custom_secs` / `name_sec` split. This focused refresh adds the neighboring tool-convention metadata that future pass, binary, and release work can easily overgeneralize:

- `producers` is a conventionally structured custom section for toolchain provenance, not execution semantics and not an optimizer hint source.
- `target_features` is metadata controlled by Binaryen's `strip-target-features` / `emit-target-features` mode bit, not a feature-lowering or validation repair pass.
- Starshine currently preserves non-`name` custom sections opaquely and validates only the special structured `name`-section model.

## Source refresh

Checked on 2026-06-05:

- WebAssembly Core 3.0 custom sections and text annotations remain non-semantic metadata: implementations may ignore them, and the appendix is the source for the standard `name` section and official `@name` / `@custom` text forms.
- The WebAssembly tool-conventions `ProducersSection.md` page defines a custom section named `producers`. It records language / processed-by / SDK name-version pairs, may appear only once, and is intended as toolchain provenance rather than an optimization contract. The page explicitly warns consumers not to derive optimization hints from `producers`.
- Binaryen current `main` still implements `strip-target-features` and `emit-target-features` in `src/passes/StripTargetFeatures.cpp` by toggling `module->hasFeaturesSection` and not by walking functions or rewriting feature-using instructions. `version_129` has the same owner-file shape according to the existing pass raw manifests.
- Starshine has no first-class producers or target-feature metadata model today. It stores arbitrary non-`name` custom sections as opaque `CustomSec` entries, emits those entries before standard sections, and treats raw `CustomSec("name", ...)` as invalid in favor of the structured `NameSec` field.

## Durable conclusions

1. **Do not make custom-section preservation generic policy for every named section.** Preserve unknown and `producers` sections by default, but keep `name` structured and keep future `target_features` stripping as a deliberately named policy.
2. **Do not use `producers` as an optimization signal.** It is provenance and telemetry metadata. Pass scheduling, feature assumptions, and Binaryen parity should use explicit config, feature models, or pass-specific evidence instead.
3. **Do not conflate `strip-target-features` with feature lowering.** A local opaque-section first slice may delete `CustomSec("target_features", ...)`, but that would only suppress metadata; it would not rewrite relaxed SIMD, GC, memory64, EH, strings, custom descriptors, or any other feature use.
4. **Do not promise exact custom-section placement preservation in Starshine.** Decode accepts custom-section gaps, but encode normalizes non-`name` `custom_secs` before standard sections and emits the structured name section separately.
5. **If Starshine adds first-class metadata later, route each section by purpose.** `NameSec` affects names and diagnostics, `FuncAnnotationSec` affects local function/import policy, `producers` should remain provenance, and `target_features` should be owned by a feature-metadata/output-policy design.

## Links checked

- Core 3.0 custom sections and annotations: <https://webassembly.github.io/spec/core/appendix/custom.html>
- WebAssembly tool-conventions producers section: <https://github.com/WebAssembly/tool-conventions/blob/main/ProducersSection.md>
- Binaryen `StripTargetFeatures.cpp` current main: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
- Binaryen `StripTargetFeatures.cpp` `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
