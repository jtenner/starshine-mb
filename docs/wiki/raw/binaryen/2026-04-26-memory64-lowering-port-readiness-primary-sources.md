---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/Memory64Lowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast
  - https://emscripten.org/docs/tools_reference/settings_reference.html#memory64
related:
  - ../../binaryen/passes/memory64-lowering/index.md
  - ../research/0411-2026-04-26-memory64-lowering-port-readiness.md
---

# `memory64-lowering` / `table64-lowering` port-readiness primary-source recheck

## Scope

This is an immutable 2026-04-26 manifest for the Starshine port-readiness bridge for Binaryen's public `memory64-lowering` and `table64-lowering` feature-lowering siblings.
It does not replace the earlier source-correction manifests; it adds first-slice and validation-order evidence for future Starshine work.

## Primary online sources checked

- Binaryen `version_129` `src/passes/Memory64Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
- Binaryen current `main` `src/passes/Memory64Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Memory64Lowering.cpp>
- Binaryen `version_129` `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen current `main` `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen `version_129` `test/lit/passes/memory64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
- Binaryen `version_129` `test/lit/passes/table64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast>
- Emscripten `MEMORY64` setting: <https://emscripten.org/docs/tools_reference/settings_reference.html#memory64>

## Durable observations

- Binaryen still concentrates both memory64 and table64 lowering in `Memory64Lowering.cpp`.
- The owner source still gates on the Memory64 feature, rewrites former 64-bit memory/table declarations after expression traversal, and disables the Memory64 feature at the end.
- Dynamic former 64-bit address-like operands are lowered with `i32.wrap_i64`; syntactic `i64.const` operands on the stack are not a special static-trap family.
- Former 64-bit `memory.size` / `table.size` results are repaired with unsigned extension.
- Former 64-bit grow results need sentinel-aware repair; a blind unsigned-extension of `i32 -1` would produce the wrong wasm64 failure value.
- Static `MemArg.offset` immediates at or above `2^32` remain the source-confirmed high-offset trap family.
- Active data and element offsets are module-shape inputs, not function-body details; a Starshine port must rewrite them in the same module pass that changes declarations.
- Emscripten documents `MEMORY64=2` as a mode that uses wasm64 internally and lowers to wasm32 in Binaryen, confirming the pass family is a compatibility lowering path rather than a size/profit pass.

## Current-main drift check

No teaching-relevant drift was found on 2026-04-26 from the 2026-04-25 static-offset correction or the tagged `version_129` contract.
The port-readiness delta is local to Starshine documentation: the existing dossier explained the source strategy but did not yet give a concrete registry-honesty, implementation-slice, and validation ladder for a future Starshine port.

## Uncertainties preserved

- Binaryen's source-level behavior for impossible lowered minimum limits is still not a polished diagnostic contract; the local Starshine page should continue to treat friendly error policy as an implementation decision.
- The existing Starshine table64 typechecking surface is partial. A future `table64-lowering` port should not be advertised before table instruction address/result typing is made coherent.
