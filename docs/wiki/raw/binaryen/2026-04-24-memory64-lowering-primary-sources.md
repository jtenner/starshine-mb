# Binaryen `memory64-lowering` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/memory64-lowering/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `memory64-lowering` dossier.
It is provenance-heavy by design. Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/memory64-lowering/index.md`
- `docs/wiki/binaryen/passes/memory64-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/memory64-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/memory64-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/memory64-lowering/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.

### Official Binaryen source files consulted

- `Memory64Lowering.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Memory64Lowering.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Memory64Lowering.cpp>
  - Key reviewed locations in the tagged file:
    - pass-level comment and `Memory64Lowering` visitor declaration near the top of the file.
    - helpers that lower 64-bit memory/table limits to 32-bit forms.
    - address-child wrapping helpers that insert `i32.wrap_i64` around former memory64/table64 operands.
    - result repair helpers that insert `i64.extend_i32_u` around `memory.size`, `memory.grow`, `table.size`, and `table.grow` when source-level code still expects an `i64` result.
    - visitors for scalar/SIMD/atomic memory ops, bulk-memory ops, active data offsets, table ops, active element offsets, and module memory/table declarations.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - Key reviewed location: public registration for `memory64-lowering` and sibling `table64-lowering`, both described as lowering 64-bit indexes to 32-bit indexes.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: pass constructor declarations for memory64/table64 lowering.

### Official Binaryen test files consulted

- `memory64-lowering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/memory64-lowering.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory64-lowering.wast>
  - Key reviewed surface: memory64-to-memory32 lowering for memory declarations, active data offsets, scalar loads/stores, SIMD loads/stores, atomic operations, `memory.size` / `memory.grow`, and bulk-memory families.
- `table64-lowering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/table64-lowering.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/table64-lowering.wast>
  - Key reviewed surface: table64-to-table32 lowering for table declarations, active element offsets, `table.get` / `table.set`, `table.size` / `table.grow`, `table.fill`, `table.init`, and `table.copy` mixed-width index rules.

### Related primary-source context

- Emscripten settings reference for `MEMORY64`
  - URL: <https://emscripten.org/docs/tools_reference/settings_reference.html#memory64>
  - Key reviewed surface: Emscripten documents the `MEMORY64=2` mode as producing wasm64 internally and lowering to wasm32 before final output; this explains why a lowering pass exists, but the pass mechanics above are sourced from Binaryen.

## Durable observations from the captured sources

- `memory64-lowering` is a real public Binaryen pass in `version_129`; `table64-lowering` is a real sibling using the same owner file and the same lowering idea for table indexes.
- The pass is a whole-module index-width conversion pass, not an optimizer in the usual profitability sense.
- Source-level memory64/table64 operands that had type `i64` are repaired by wrapping them with `i32.wrap_i64` after the corresponding memory/table declaration has been lowered to 32-bit limits.
- Source-level `memory.size`, `memory.grow`, `table.size`, and `table.grow` results that were `i64` before lowering are repaired with unsigned `i64.extend_i32_u` around the now-32-bit operation result.
- Bulk-memory/table operations have mixed-width cases: destination, source, and length operands must be lowered according to the destination/source memory or table width, and `table.copy` / `memory.copy` length is 64-bit only when both sides are 64-bit in the reviewed code.
- Active data and element offsets are part of the pass surface, not just instructions inside function bodies.
- The reviewed current-`main` source and lit filenames still present the same teaching-level contract as `version_129`; no local Starshine registry entry for `memory64-lowering` or `table64-lowering` was found in this repo on 2026-04-24.

## Uncertainty and caveats

- This capture records source-level mechanics. It does not prove every possible out-of-range 64-bit limit or offset policy from the tests. Future implementation work should source-confirm the exact failure/truncation behavior for memory/table limits and active offsets that cannot be represented in 32-bit output.
- Starshine already parses, encodes, decodes, and validates several `I64Limits` memory/table surfaces, but this dossier found no active local pass that rewrites a wasm64 module into a wasm32 module.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
