---
kind: raw-source
status: current
last_reviewed: 2026-07-10
sources:
  - https://webassembly.github.io/spec/core/appendix/custom.html
  - https://raw.githubusercontent.com/WebAssembly/tool-conventions/main/Linking.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/StripTargetFeatures.cpp
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/passes/optimize.mbt
related:
  - ../../binary/custom-and-name-sections.md
  - ../../binaryen/passes/strip-target-features/index.md
  - ../../binaryen/passes/strip-target-features/binaryen-strategy.md
  - ../../wasm-feature-status-and-proposal-boundaries.md
---

# Target-Features Custom Metadata Recheck (2026-07-10)

## Scope

This immutable source note refreshes the boundary between three similarly named but different things:

1. Core WebAssembly custom sections, which are non-semantic binary metadata;
2. the WebAssembly linking-convention `target_features` custom-section payload, which communicates feature constraints to link-time tooling; and
3. Binaryen's `strip-target-features` / `emit-target-features` passes, which toggle whether Binaryen emits that metadata.

It does **not** claim that the linking convention is part of Core WebAssembly validation, that a `target_features` payload makes a feature usable, or that Starshine currently parses the payload.

## Sources checked

- The current Core 3.0 custom-section appendix is dated **2026-07-10**. It retains the core rule that a custom section is section id `0`, has a UTF-8 name plus arbitrary payload bytes, and does not affect module semantics. The standardized `name` section remains a special metadata convention; this check found no Core semantic change relevant to `target_features`.
- The current `WebAssembly/tool-conventions` linking document describes a custom section named `target_features`. Its payload is a vector of prefixed feature names. The convention uses `+` for a used feature, `-` for a disallowed feature, and `=` for a required feature; it also distinguishes a compact executable form from a richer standalone-object form that can carry more than one feature vector. This is linker/tool metadata, not a Core instruction/type/validation feature declaration.
- Current Binaryen `src/passes/StripTargetFeatures.cpp` still gives `strip-target-features` and `emit-target-features` one module-metadata owner. The owner sets `module->hasFeaturesSection` from its mode; it does not walk expressions or lower feature-using code.
- Starshine still has no first-class target-feature carrier or pass. [`Module.custom_secs`](../../../../src/lib/types.mbt) keeps non-`name` custom sections as opaque [`CustomSec`](../../../../src/lib/types.mbt) values, [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) preserves those values during module decode, [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) emits them before standard sections, and [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt) has neither target-feature pass name in its boundary-only, removed, or active registry lists.

## Durable conclusions

1. **Treat `target_features` as purpose-specific metadata.** It is not interchangeable with arbitrary unknown custom sections when a linker or output-policy decision owns it, but it is also not a semantic feature gate.
2. **Do not confuse stripping with lowering.** Removing `target_features` can change downstream compatibility information while leaving feature-using instructions, types, and sections intact. It cannot make a GC, SIMD, memory64, exception-handling, or other feature-using module acceptable to an engine that lacks that feature.
3. **Keep the two layers of “valid” separate.** Core validation may ignore custom metadata; a linker may nevertheless use the linking-convention payload to reject incompatible object inputs. Starshine's current validator neither parses nor relies on this opaque payload.
4. **A narrow Starshine port would intentionally diverge in representation from Binaryen.** Deleting `CustomSec("target_features", payload)` entries is a useful opaque-metadata policy, but Binaryen toggles a first-class `hasFeaturesSection` flag. Do not call the former transform a byte-for-byte implementation of the latter without an explicit output-policy decision and tests.
5. **The payload format remains an implementation boundary.** A future Starshine `emit-target-features` pass cannot faithfully synthesize the section until the project decides how to derive, represent, validate, and preserve feature facts. The current opaque model is sufficient only for preservation or whole-section suppression.

## Source links

- Core custom sections and annotations: <https://webassembly.github.io/spec/core/appendix/custom.html>
- WebAssembly tool-conventions linking document: <https://github.com/WebAssembly/tool-conventions/blob/main/Linking.md>
- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
