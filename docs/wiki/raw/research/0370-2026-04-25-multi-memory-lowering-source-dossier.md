# `multi-memory-lowering` source dossier

_Date:_ 2026-04-25  
_Status:_ filed back into living wiki pages  
_Sources:_ `docs/wiki/raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md`, `docs/wiki/binaryen/passes/multi-memory-lowering/`, `src/passes/optimize.mbt`, `src/lib/types.mbt`, `src/wast/lower_to_lib.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/validate/typecheck.mbt`

## Question

The pass tracker had no obvious remaining `none` target, but the memory/table feature-lowering area still had a real gap: Binaryen exposes public `multi-memory-lowering` and `multi-memory-lowering-with-bounds-checks` passes, while Starshine already has multi-memory representation, binary, validation, and memory-optimization surfaces. The wiki had only one stray fuzz-plan mention of multi-memory and no pass dossier explaining how Binaryen lowers multiple memories to one.

## Source-backed findings

- Binaryen `version_129` has one owner file, `src/passes/MultiMemoryLowering.cpp`, for both public pass names.
- `pass.cpp` registers:
  - `multi-memory-lowering`, described as combining multiple memories into one memory;
  - `multi-memory-lowering-with-bounds-checks`, which additionally traps on reads or writes outside the original memory's data length.
- The pass disables Binaryen's MultiMemory feature and skips modules with zero or one memory.
- The lowered output is one combined memory plus mutable byte-offset globals for every original memory after the first.
- Function-body memory operations are retargeted to the combined memory after adding the selected original memory's byte offset to the address operand.
- The pass covers scalar loads/stores, SIMD memory ops, atomics, `memory.init`, `memory.copy`, `memory.fill`, `memory.size`, and `memory.grow`.
- `memory.size` and `memory.grow` use generated helper functions rather than simple operand rewrites.
- Growing a non-last original memory requires moving later original-memory ranges upward inside the combined memory and updating their offset globals.
- Active data segments are also lowered: they are moved to the combined memory and have constant offsets shifted by their original memory's base offset.
- Important limits are source-confirmed rather than inferred: all memories must share address type, sharedness, and page size; only the first memory may be imported; only the first memory may be exported; non-constant active data offsets still sit behind an owner-file TODO/assertion.
- The bounds-checking sibling inserts explicit trap checks before retargeted memory accesses, but the source comment records an overflow-imprecision caveat.
- A 2026-04-25 current-main spot check found no teaching-relevant drift in `MultiMemoryLowering.cpp` or the paired lit filenames.

## Starshine local findings

- `src/passes/optimize.mbt:126-153` has no boundary-only or removed entry for `multi-memory-lowering` or `multi-memory-lowering-with-bounds-checks`.
- `src/passes/optimize.mbt:156-267` has no active registry entry for either pass.
- Current explicit requests would therefore be unknown-pass failures, not boundary-only rejections.
- `src/lib/types.mbt:174` carries `MemType`, `src/lib/types.mbt:475` carries `MemArg` with an optional `MemIdx`, and `src/lib/types.mbt:1263-1270` maps memory limits to address value types.
- `src/wast/lower_to_lib.mbt:2298-2310` still lowers WAT memory bulk instructions to memory index `0`, so the WAT named/indexed multi-memory surface is incomplete.
- `src/binary/decode.mbt:3238-3242` and `src/binary/encode.mbt:3034-3074` preserve memory indexes for bulk memory operations at the binary/lib layer.
- `src/validate/typecheck.mbt:371-376` derives memory address width from the selected memory; `src/validate/typecheck.mbt:2408-2509` threads selected memory indexes through size/grow/init/copy/fill typing.
- No local module pass rewrites memory declarations, data segment offsets, memory exports, or memory-indexed instructions into a single-memory output.

## Filed-back pages

- `docs/wiki/binaryen/passes/multi-memory-lowering/index.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/memory-layout-bounds-and-growth.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-ups

- If Starshine implements the pass, add tests for declaration merging, offset globals, active data offset shifting, imported/exported-memory restrictions, `memory.size` helpers, last and non-last `memory.grow`, bulk-memory retargeting, optional bounds traps, and feature/custom-section cleanup.
- Decide whether the local WAT frontend should support named/indexed multi-memory operands before or with any lowering port.
