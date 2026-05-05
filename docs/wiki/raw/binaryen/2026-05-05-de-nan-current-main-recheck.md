# 2026-05-05 `de-nan` current-main recheck

Primary-source freshness check for Binaryen `denan` / local `de-nan`.

## Scope

Reviewed the official Binaryen current-main sources and compared them against the existing `version_129` oracle surface for the pass:

- `src/passes/DeNaN.cpp`
- `src/passes/pass.cpp`
- `src/ir/properties.h`
- `src/ir/names.h`
- `src/wasm-builder.h`
- `src/pass.h`
- `test/lit/passes/denan.wast`

## Finding

No teaching-relevant drift was found.

The current-main source still matches the durable `version_129` contract already captured in the wiki:

- runtime NaN-to-zero instrumentation
- helper-call insertion for nonconstant `f32` / `f64` / `v128` producers
- constant NaN-to-zero rewrites
- entry-parameter sanitization for defined functions
- `local.get` and result-fallthrough skip rules
- module-context legality boundary for helper calls
- helper-name collision avoidance
- nested `merge-blocks` cleanup after entry fixups
- SIMD lane-wise helper strategy

## Source URLs

- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeNaN.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/properties.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/names.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm-builder.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/pass.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/denan.wast>

## Notes

- This recheck is freshness-only; it does not supersede the older primary-source manifest, it just confirms it remains current enough for teaching use.
- The local removed-registry spelling `de-nan` still maps to upstream `denan`.
