---
kind: entity
status: supported
last_reviewed: 2026-06-05
sources:
  - ../../../raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md
  - ../../../raw/binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md
  - ../../../raw/research/0393-2026-04-26-multi-memory-lowering-port-readiness.md
  - ../../../raw/research/0370-2026-04-25-multi-memory-lowering-source-dossier.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./memory-layout-bounds-and-growth.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../memory64-lowering/index.md
  - ../memory-packing/index.md
  - ../../../wasm-custom-page-sizes-boundary.md
  - ../remove-unused-module-elements/index.md
  - ../tracker.md
---

# Binaryen pass: `multi-memory-lowering`

## Purpose

`multi-memory-lowering` is Binaryen's compatibility lowering pass for modules that use more than one linear memory. It rewrites a multi-memory module into a single-memory module by laying the original memories out inside one combined memory, then repairing every memory-indexed operation to access the right byte range.

Binaryen also exposes `multi-memory-lowering-with-bounds-checks`, a sibling that uses the same owner file but adds explicit traps when a lowered access would exceed the original memory's virtual data length.

The beginner version:

- input: one module with several memories and memory instructions that name which memory they use;
- output: one real memory, helper globals holding each original memory's byte offset, and rewritten instructions that add the right offset before accessing the combined memory.

The advanced version:

- memory declarations, active data segments, memory exports, `memory.size`, `memory.grow`, bulk-memory operations, ordinary loads/stores, SIMD memory ops, and atomics all participate;
- non-last `memory.grow` must move later original memories upward inside the combined memory;
- the pass only accepts a constrained memory family: same address type, same sharedness, same page size, no imported memories after the first, and no exported memories after the first. In Starshine, the page-size part is currently a Binaryen/future-port constraint only because local `MemType` has no page-size field; route that proposal boundary through [`../../../wasm-custom-page-sizes-boundary.md`](../../../wasm-custom-page-sizes-boundary.md).

## Inputs and outputs

### Input shape

The useful input has:

- two or more memories;
- memory operations that target memory index `0`, `1`, `2`, ...;
- active data segments attached to specific memories;
- optional memory imports/exports, within Binaryen's restrictions;
- optional `memory.size` / `memory.grow` uses for nonzero memories.

### Output shape

The output has:

- one combined memory;
- mutable byte-offset globals for original memories after memory `0`;
- active data segments retargeted to the combined memory with shifted offsets;
- ordinary memory instructions retargeted to memory `0`, with their address child shifted by the original memory's byte-offset global;
- helper functions for virtual `memory.size` and `memory.grow`;
- repaired memory exports that preserve the first-memory export identity when legal;
- MultiMemory feature metadata disabled in Binaryen's module feature set.

## Correctness constraints

- **No address-space aliasing:** every original memory must map to a distinct byte range in the combined memory.
- **Address repair:** every operation that used a nonzero memory index must add that memory's base byte offset before touching the combined memory.
- **Segment repair:** active data segments are part of the observable initialization behavior and must move with their memory.
- **Size/grow illusion:** callers of `memory.size` and `memory.grow` must still see per-original-memory sizes and growth behavior even though only one real memory remains.
- **Non-last grow movement:** growing an earlier original memory must preserve the bytes of later original memories by copying them upward and updating offset globals.
- **Module-shape restrictions:** imported/exported memory restrictions, address-type equality, sharedness equality, and page-size equality are part of Binaryen's contract rather than accidental implementation detail. Current Starshine can represent address type and sharedness, but not custom page size.
- **Bounds-check variant caveat:** the checked sibling adds explicit traps, but Binaryen's source comments still record an imprecision around spec-style offset overflow in one shifted-address family.

## Notable edge cases

- zero or one memory: Binaryen skips the lowering;
- imported first memory: legal and preserved as the combined memory;
- imported second or later memory: unsupported by the reviewed source;
- exported first memory: legal and repaired;
- exported second or later memory: unsupported by the reviewed source;
- non-constant active data offset: still behind a source TODO/assertion;
- `memory.copy` where source and destination memories differ;
- `memory.grow` on any memory except the last original memory;
- memory64 input: all memories must share the same address type, and this pass is not a substitute for [`memory64-lowering`](../memory64-lowering/index.md);
- custom-page-size input: not locally representable in Starshine today, even though Binaryen's accepted family compares page size upstream.

## Validation strategy

For Binaryen research, start with the official lit files:

- `test/lit/passes/multi-memory-lowering.wast`
- `test/lit/passes/multi-memory-lowering-with-bounds-checks.wast`

For a future Starshine port, add tests in this order:

1. no-op behavior for zero or one memory;
2. two-memory declaration merge plus offset global creation;
3. active data segment retargeting and constant offset shifting;
4. scalar load/store retargeting;
5. `memory.init`, `memory.copy`, and `memory.fill` retargeting;
6. `memory.size` helper behavior;
7. last-memory `memory.grow` helper behavior;
8. non-last `memory.grow` movement plus offset-global update;
9. import/export restriction diagnostics or explicit unsupported-pass errors;
10. bounds-checking sibling traps;
11. feature/custom-section cleanup for the lowered output.

The 2026-04-26 port-readiness bridge keeps that test order explicit for Starshine: begin with unchecked two-memory structural lowering, then helpers, then non-last grow movement, and only then the checked sibling. See [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - source-backed Binaryen strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and official test surface.
- [`memory-layout-bounds-and-growth.md`](memory-layout-bounds-and-growth.md) - focused guide to layout, optional traps, and `memory.grow` movement.
- [`wat-shapes.md`](wat-shapes.md) - before/after shape catalog.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.
- [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) - staged future implementation and validation ladder.

## Sources

- [`../../../raw/binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md)
- [`../../../raw/research/0393-2026-04-26-multi-memory-lowering-port-readiness.md`](../../../raw/research/0393-2026-04-26-multi-memory-lowering-port-readiness.md)
- [`../../../raw/research/0370-2026-04-25-multi-memory-lowering-source-dossier.md`](../../../raw/research/0370-2026-04-25-multi-memory-lowering-source-dossier.md)
- Binaryen `MultiMemoryLowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MultiMemoryLowering.cpp>
- Binaryen pass registration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- WebAssembly multi-memory proposal overview: <https://github.com/WebAssembly/multi-memory/blob/main/proposals/multi-memory/Overview.md>
