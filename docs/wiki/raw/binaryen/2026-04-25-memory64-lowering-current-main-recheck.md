# Binaryen `memory64-lowering` current-main recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable source recheck for the `docs/wiki/binaryen/passes/memory64-lowering/` dossier

## Scope

This file records a focused primary-source recheck of Binaryen `memory64-lowering` / `table64-lowering` after the 2026-04-24 dossier left out-of-range behavior as an explicit uncertainty.
Use the living pages for teaching material:

- `docs/wiki/binaryen/passes/memory64-lowering/index.md`
- `docs/wiki/binaryen/passes/memory64-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/memory64-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/memory64-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/memory64-lowering/starshine-strategy.md`

## Primary sources rechecked

- Binaryen `Memory64Lowering.cpp`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Memory64Lowering.cpp>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Memory64Lowering.cpp>
  - Key source locations reviewed: pass option helpers, limit-lowering helper, `lowerAddress(...)`, `makeGrow(...)`, memory/table declaration visitors, active data/element offset visitors, memory/table operation visitors, and bulk memory/table visitors.
- Binaryen `memory64-lowering.wast`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/memory64-lowering.wast>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/memory64-lowering.wast>
  - Key source locations reviewed: active offset and high-constant tests, `memory.size`, `memory.grow`, memory init/fill/copy, SIMD, and atomic cases.
- Binaryen `table64-lowering.wast`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/table64-lowering.wast>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/table64-lowering.wast>
  - Key source locations reviewed: table declaration, element offsets, `table.get` / `table.set`, `table.size` / `table.grow`, `table.fill`, `table.init`, and `table.copy` cases.
- Emscripten `MEMORY64` setting for external motivation only: <https://emscripten.org/docs/tools_reference/settings_reference.html#memory64>

## Durable observations

- The current-main owner source still has the same teaching-level pass contract as `version_129`: two public siblings lower memory or table index width from 64 bits to 32 bits, rewrite declarations, repair use sites, and refinalize touched code.
- The 2026-04-24 dossier was too vague about out-of-range behavior. The source-backed refinement is:
  - Dynamic memory/table address operands are repaired with `i32.wrap_i64(...)` after declaration lowering.
  - Constant address or active offset expressions that are at least `2^32` are replaced with `unreachable` rather than wrapped. This preserves the fact that the original memory64/table64 operation or segment offset is definitely outside a lowered 32-bit address space.
  - In-range constant addresses/offsets become `i32.const` values.
  - Maximum limits above the 32-bit limit are clamped to the 32-bit maximum during limit lowering.
  - Minimum limits are asserted to fit the lowered output after max clamping; the reviewed source does not present a user-facing diagnostic contract for impossible minimums.
- `memory.grow` / `table.grow` need more than plain result zero-extension:
  - Constant grow deltas above `2^32 - 1` become the 64-bit failure sentinel immediately.
  - Dynamic grow deltas are wrapped for the lowered operation.
  - The lowered operation's `i32` result is repaired so a failure result maps back to the 64-bit failure sentinel, while successful results are zero-extended to `i64`.
- `memory.size` / `table.size` remain the simple `i32` result plus unsigned `i64` extension case.
- Bulk copy/init/fill shape coverage remains as recorded before: destination, source, and length positions must be reasoned about independently; for copies, the length uses the smaller/common 32-bit type unless both sides are still 64-bit before lowering.
- The reviewed current-main source and tests did not show a teaching-relevant drift from the tagged `version_129` contract above.

## Uncertainty and caveats

- This recheck resolves the earlier active-offset / high-constant uncertainty, but it still does not prove a polished command-line error policy for impossible minimum limits. The source-level observation is an internal assertion around the lowered minimum after max clamping.
- The source distinguishes known-constant out-of-range operands from dynamic operands. Future Starshine docs or implementations must not collapse both cases into a single “always wrap” rule.
- Emscripten's `MEMORY64=2` setting explains why lowering exists in real pipelines, but all mechanics in this capture are sourced from Binaryen.

## Filed-back target

This capture should support updates to the living `memory64-lowering` pages so readers learn the exact high-constant, grow-failure, limit-clamp, and Starshine-port boundaries without reopening chat history.
