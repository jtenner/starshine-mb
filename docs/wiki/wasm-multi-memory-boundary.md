---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-multi-memory-core-boundary-refresh.md
  - raw/wasm/2026-06-05-memory64-table64-core-boundary-refresh.md
  - raw/wasm/2026-05-19-wast-memory-argument-sources.md
  - raw/wasm/2026-05-19-wast-memory-instruction-sources.md
  - ../src/lib/types.mbt
  - ../src/lib/eq.mbt
  - ../src/binary/decode.mbt
  - ../src/binary/encode.mbt
  - ../src/validate/typecheck.mbt
  - ../src/validate/gen_valid.mbt
  - ../src/wast/parser.mbt
  - ../src/wast/lower_to_lib.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - validate/memory-table-address-widths.md
  - wast/memory-argument-authoring.md
  - wast/memory-instruction-authoring.md
  - wast/resource-declaration-authoring.md
  - wast/text-surface-gap-ledger.md
  - binary/instruction-and-expression-encoding.md
  - binary/type-table-memory-global-tag-sections.md
  - binaryen/passes/multi-memory-lowering/index.md
  - wasm-memory-control-boundary.md
  - wasm-custom-page-sizes-boundary.md
  - wasm-linear-memory-threads-boundary.md
---

# Multi-Memory Core Boundary

## Overview

Use this page when a fixture, validator change, generator, binary codec change, or optimizer pass touches **which linear memory** an instruction or data segment uses.

For beginners: a WebAssembly module can define or import more than one linear memory. Without multi-memory, examples often pretend there is only memory `0`. With multi-memory, an instruction such as `memory.copy` can say “copy from memory `1` into memory `0`,” and a load/store memarg can select a nonzero memory. That selected memory is an ordinary part of the Core module model, not a Binaryen-only pass trick.

The current source bridge is [`raw/wasm/2026-06-05-multi-memory-core-boundary-refresh.md`](raw/wasm/2026-06-05-multi-memory-core-boundary-refresh.md). It rechecked current WebAssembly Core 3.0 text, binary, validation, and module pages; historical multi-memory proposal context; and current Starshine core, binary, WAST, validator, generator, and pass evidence.

## Status Rule

Treat multi-memory as **Core selected-memory/index behavior** for Core modules. Use the official Core 3.0 pages for standards claims, and use historical proposal pages only for origin/context.

Do not confuse multi-memory with nearby memory features:

| Feature | What it changes | Starshine routing |
| --- | --- | --- |
| Multi-memory | Which memory an instruction, `MemArg`, or active data segment selects. | This page; [`wast/memory-argument-authoring.md`](wast/memory-argument-authoring.md); [`wast/memory-instruction-authoring.md`](wast/memory-instruction-authoring.md). |
| memory64 | Whether memory addresses/page counts are `i32` or `i64`. | [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md). |
| Custom Page Sizes | Whether a memory's page size is not the ordinary 64KiB. | [`wasm-custom-page-sizes-boundary.md`](wasm-custom-page-sizes-boundary.md). |
| Threads/shared memory | Whether a memory is shared and whether atomics/synchronization rules apply. | [`wasm-linear-memory-threads-boundary.md`](wasm-linear-memory-threads-boundary.md). |
| Memory Control | Future discard/commit/protection/mapping/BYOB memory-management operations. | [`wasm-memory-control-boundary.md`](wasm-memory-control-boundary.md). |
| Binaryen `multi-memory-lowering` | A compatibility transform that rewrites many memories into one combined memory. | [`binaryen/passes/multi-memory-lowering/index.md`](binaryen/passes/multi-memory-lowering/index.md). |

The local `GenValidProposalFeature::MultiMemoryFeature` name in [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt) is fuzzing vocabulary, not standards-status evidence. It says which toggles are needed for Starshine's generator to emit selected-memory surfaces; it does not make multi-memory an active proposal row.

## Concrete Shapes

### Scalar/SIMD memargs

A load/store memory argument has alignment, optional selected memory, and static offset:

```text
MemArg(U32(2), None, U64(8))              ;; default memory, equivalent to memory 0
MemArg(U32(2), Some(MemIdx(0)), U64(8))   ;; explicit memory 0
MemArg(U32(2), Some(MemIdx(1)), U64(8))   ;; explicit memory 1
```

Starshine equality intentionally treats `None` and `Some(MemIdx(0))` as equal in [`src/lib/eq.mbt`](../src/lib/eq.mbt), but keeps `Some(MemIdx(1))` distinct. Binary decode/encode preserves explicit memory indices through the local `align + 64` memarg convention in [`src/binary/decode.mbt`](../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../src/binary/encode.mbt). Validation then checks the selected memory exists and that the stack address type matches that memory's address width in [`memarg_check(...)`](../src/validate/typecheck.mbt).

### `memory.size`, `memory.grow`, and `memory.fill`

Core IR carries an explicit memory index on each of these forms:

```moonbit
Instruction::memory_size(MemIdx::new(1))
Instruction::memory_grow(MemIdx::new(1))
Instruction::memory_fill(MemIdx::new(1))
```

`memory.size` and `memory.grow` use the selected memory's address type for page-count values. `memory.fill` uses the selected memory for destination typing, but Starshine currently still types the length as `i32` even for memory64; keep that memory64 gap routed through [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md). The multi-memory part is only the `MemIdx` selection.

### `memory.copy`

`memory.copy` has two memory indices:

```text
MemoryCopy(dst_mem, src_mem)
```

Validation in [`typecheck_memory_copy(...)`](../src/validate/typecheck.mbt) checks both memories. If memory64 combines with multi-memory, the destination address uses the destination memory's width, the source address uses the source memory's width, and the length uses the narrower width. This is why a correct test names operand roles as **destination**, **source**, and **length** instead of saying “the memory operand.”

### `memory.init` and active data segments

`memory.init` has a data index and a memory index:

```text
MemoryInit(data_idx, mem_idx)
```

An active data segment also has a parent memory index:

```text
DataMode::Active(mem_idx, offset_expr)
```

Those are separate carriers. A pass that remaps memories must update both `MemoryInit(..., mem_idx)` and active `DataMode::Active(mem_idx, ...)`; a pass that remaps data segments must update `MemoryInit(data_idx, ...)` and `DataDrop(data_idx)`. The active data offset expression is a constant-expression initializer, not a function-body `MemArg.offset` immediate.

## Starshine Layer Map

| Layer | Current behavior | Evidence |
| --- | --- | --- |
| Core IR | Represents `MemIdx`, optional selected-memory memargs, explicit memory operands on size/grow/fill/copy/init, and active data-segment memory parents. | [`src/lib/types.mbt`](../src/lib/types.mbt). |
| Core equality | Treats omitted memidx and explicit memory `0` as equivalent, while preserving nonzero memory identity. | [`src/lib/eq.mbt`](../src/lib/eq.mbt). |
| Binary decode/encode | Preserves explicit memargs, `memory.size` / `memory.grow` indices, and `0xFC` bulk-memory memory operands. | [`src/binary/decode.mbt`](../src/binary/decode.mbt), [`src/binary/encode.mbt`](../src/binary/encode.mbt), [`src/binary/tests.mbt`](../src/binary/tests.mbt). |
| Validation | Checks selected memories exist and stack-types selected-memory operands; `memory.copy` keeps destination/source memories distinct. | [`src/validate/typecheck.mbt`](../src/validate/typecheck.mbt), [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md). |
| WAST text | Currently narrower: WAST-local memargs carry `align`/`offset` only, and high-level memory instructions lower/print as memory `0`. | [`src/wast/parser.mbt`](../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../src/wast/module_wast.mbt), [`wast/memory-argument-authoring.md`](wast/memory-argument-authoring.md). |
| Generator/fuzzing | Has local feature-gate vocabulary and valid/invalid coverage for memory variants; this is local generation evidence, not proposal-status evidence. | [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md). |
| Passes | Existing passes must preserve/remap memory carriers they touch. Binaryen `multi-memory-lowering` is a future compatibility-lowering dossier, not active Starshine support. | [`binaryen/passes/multi-memory-lowering/index.md`](binaryen/passes/multi-memory-lowering/index.md), [`src/passes/memory_packing.mbt`](../src/passes/memory_packing.mbt). |

## Current Gaps And Caveats

- **WAST text cannot author the whole selected-memory surface today.** Current parser/lowerer/printer paths do not preserve explicit nonzero memories on ordinary scalar/SIMD memargs or on high-level `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init` text forms. Use direct core or binary fixtures when nonzero memory behavior is the point of the test.
- **Core/binary/generator support is broader than WAST support.** Do not infer lack of Starshine core support from a missing WAST spelling; do not infer WAST support from a core or binary round trip.
- **Mixed memory32/memory64 cases are two-dimensional.** Multi-memory selects the destination/source memory; memory64 decides address widths. `memory.copy` is the best stress case because its destination, source, and length can each exercise different address-width roles.
- **Memory-packing is not general multi-memory lowering.** The current local pass has active-segment and nonzero-memory skip/guard behavior. Binaryen's `multi-memory-lowering` dossier is the correct route for many-memories-to-one compatibility transforms.
- **Name and metadata maps matter.** A memory-remapping pass must update memory names, exports/imports, active data modes, all memory instruction carriers, and any pass-local memory summaries together.

## Implementation And Signoff Checklist

When changing selected-memory behavior:

1. **Pick the owning layer first.** WAST syntax belongs in `src/wast`; binary memarg/index preservation belongs in `src/binary`; semantic stack typing belongs in `src/validate/typecheck.mbt`; pass rewrites belong in the relevant `src/passes` file plus validation tests.
2. **Test memory `0` and nonzero memories separately.** Include omitted/default memory `0`, explicit memory `0`, and explicit memory `1` where the layer can represent them.
3. **For copy/init/data changes, name every carrier.** Audit `MemArg`, `MemorySize`, `MemoryGrow`, `MemoryFill`, both `MemoryCopy` operands, `MemoryInit`, active `DataMode`, memory imports/exports, and name-section memory maps.
4. **Use direct core/binary fixtures until WAST widens.** A WAST-only positive does not currently prove nonzero memory instruction behavior.
5. **Keep neighboring proposals separate.** If a test also needs memory64, shared memory, Custom Page Sizes, or Memory Control, cite the focused page for that second dimension.
6. **Run validation after any rewrite.** A well-formed memory index can become invalid if a pass deletes, reorders, narrows, or merges memories without updating all carriers.

## Sources

- Current multi-memory source bridge: [`raw/wasm/2026-06-05-multi-memory-core-boundary-refresh.md`](raw/wasm/2026-06-05-multi-memory-core-boundary-refresh.md)
- Memory64/table64 Core boundary: [`raw/wasm/2026-06-05-memory64-table64-core-boundary-refresh.md`](raw/wasm/2026-06-05-memory64-table64-core-boundary-refresh.md), [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md)
- WAST memory argument and instruction manifests: [`raw/wasm/2026-05-19-wast-memory-argument-sources.md`](raw/wasm/2026-05-19-wast-memory-argument-sources.md), [`raw/wasm/2026-05-19-wast-memory-instruction-sources.md`](raw/wasm/2026-05-19-wast-memory-instruction-sources.md)
- Official WebAssembly sources: <https://webassembly.github.io/spec/core/text/instructions.html>, <https://webassembly.github.io/spec/core/binary/instructions.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>, <https://webassembly.github.io/spec/core/syntax/modules.html>
- Historical proposal context: <https://webassembly.github.io/multi-memory/core/text/modules.html>
- Starshine implementation: [`../src/lib/types.mbt`](../src/lib/types.mbt), [`../src/lib/eq.mbt`](../src/lib/eq.mbt), [`../src/binary/decode.mbt`](../src/binary/decode.mbt), [`../src/binary/encode.mbt`](../src/binary/encode.mbt), [`../src/validate/typecheck.mbt`](../src/validate/typecheck.mbt), [`../src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt), [`../src/wast/parser.mbt`](../src/wast/parser.mbt), [`../src/wast/lower_to_lib.mbt`](../src/wast/lower_to_lib.mbt), [`../src/wast/module_wast.mbt`](../src/wast/module_wast.mbt)
