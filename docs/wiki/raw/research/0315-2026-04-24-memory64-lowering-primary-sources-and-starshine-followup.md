# `memory64-lowering` primary sources and Starshine follow-up

_Date:_ 2026-04-24  
_Status:_ filed back into living wiki pages; superseded for out-of-range constants, grow-failure repair, and max/min limit policy by `docs/wiki/raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`  
_Sources:_ `docs/wiki/raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`, `docs/wiki/binaryen/passes/memory64-lowering/`, `src/lib/types.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/validate/validate.mbt`, `src/validate/typecheck.mbt`, `src/passes/optimize.mbt`

## Question

The pass tracker had no obvious remaining `none` target after the 2026-04-24 GUFA/type-finality wave.
A useful next target still needed to satisfy two constraints:

1. it should be a real upstream Binaryen optimization or transformation pass with primary sources; and
2. it should clarify a Starshine-relevant surface rather than adding a random upstream pass with no local teaching value.

`memory64-lowering` qualified because Starshine already has durable memory64/table64 parsing, binary, validation, and optimization-adjacent references, but the wiki had no canonical page explaining Binaryen's dedicated lowering pass or Starshine's current lack of such a transform.

## Source-backed findings

- Binaryen `version_129` exposes public `memory64-lowering` and `table64-lowering` pass names in `pass.cpp`.
- Both siblings are owned by `src/passes/Memory64Lowering.cpp`.
- The core transform lowers 64-bit memory/table declarations to 32-bit declarations and repairs typed uses:
  - former `i64` memory/table addresses become `i32.wrap_i64(...)` operands,
  - former `i64` size/grow results become `i64.extend_i32_u(...)` around the now-`i32` operation result,
  - active data/element offsets are also rewritten,
  - mixed-width bulk copy/fill/init forms must account for destination, source, and length operand widths independently.
- Official lit coverage exists in `memory64-lowering.wast` and `table64-lowering.wast`.
- Emscripten's official settings reference documents `MEMORY64=2` as wasm64 internally lowered to wasm32, which explains why this pass matters even though the Binaryen source remains the source of mechanics.

## Starshine local status

- `src/passes/optimize.mbt` has no registry entry for `memory64-lowering` or `table64-lowering`; request status is therefore unknown-pass rather than boundary-only or removed.
- `src/lib/types.mbt` already models memory/table limits with `I32Limits` and `I64Limits`, and exposes `Limits::addr_valtype(...)` / `min_addr_valtype(...)` helpers that future lowering would rely on.
- `src/binary/decode.mbt` and `src/binary/encode.mbt` already round-trip memory/table limit encodings, including memory64 bytes for `MemType`.
- `src/validate/validate.mbt` validates memory64 page bounds and active data offsets through each memory's address type.
- `src/validate/typecheck.mbt` already derives memory address/result types from memory limits for many memory operations, and derives mixed-width `memory.copy` / `table.copy` lengths with local helper logic.
- Table64 support is uneven: some table operations already consult table limits for copy/fill/init, while `table.get`, `table.set`, `table.size`, and `table.grow` still use hard-coded `i32` stack shapes in the reviewed local file. A future Binaryen-parity lowering or table64 feature pass should resolve this before advertising full table64 support.

## Filed-back pages

- `docs/wiki/binaryen/passes/memory64-lowering/index.md`
- `docs/wiki/binaryen/passes/memory64-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/memory64-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/memory64-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/memory64-lowering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

`CHANGELOG.md` was intentionally not edited for this follow-up because unrelated local changes to that file appeared before changelog writeback, and this run must not mix unrelated changes into a wiki commit.

## Follow-ups

- If Starshine adds a wasm64-to-wasm32 lowering pass, decide whether to register both upstream public names or one shared local implementation with aliases.
- Superseded on 2026-04-25 for out-of-range constants and active offsets: see `docs/wiki/raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`. The remaining open piece is a future Starshine policy decision around impossible min limits, because the reviewed Binaryen source uses an internal assertion rather than a clear user-facing diagnostic.
- Audit table64 validation separately. The local table type model can represent `I64Limits`, but several table instruction typecheckers still use `i32` directly.
