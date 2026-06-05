---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-memory-control-boundary-refresh.md
  - raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md
  - raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md
  - raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md
  - raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - ../../src/lib/types.mbt
  - ../../src/wast/keywords.mbt
  - ../../src/wast/lower_to_lib.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/typecheck.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-custom-page-sizes-boundary.md
  - wast/memory-instruction-authoring.md
  - wast/memory-argument-authoring.md
  - wast/atomic-memory-instruction-authoring.md
  - binary/instruction-and-expression-encoding.md
  - binary/type-table-memory-global-tag-sections.md
  - validate/memory-table-address-widths.md
  - validate/resource-sections-and-limits.md
---

# WebAssembly Memory Control Boundary

## Overview

Use this page when a fixture, pass, binary codec change, generator, external-validator disagreement, or proposal-status claim mentions **Memory Control**, `memory.discard`, memory decommit/commit, memory protection, mappable memory, virtual memory mode, or BYOB host memory. These are not the same as Starshine's current memory instruction support.

The current source bridge is [`raw/wasm/2026-06-05-memory-control-boundary-refresh.md`](raw/wasm/2026-06-05-memory-control-boundary-refresh.md). It rechecked the official WebAssembly proposals tracker, the Memory Control proposal repository, the proposal overview, the focused `memory.discard` sub-proposal, and current Starshine memory instruction sources.

The durable rule is:

> Memory Control is active **Phase 1** proposal evidence. Starshine currently has no `memory.discard`, `memory.commit`, memory-protection, mappable-memory, virtual-memory, or BYOB runtime surface. Do not infer support from `memory.grow`, `memory.fill`, `memory.copy`, `memory.init`, memory64, multi-memory, shared memory, or Custom Page Sizes.

## Beginner Model

Today, a normal WebAssembly linear memory is a growable byte array. Starshine's implemented memory operations are the familiar Core families:

```text
load/store       read or write bytes at an address
memory.size      report current page count
memory.grow      request more pages; never shrinks
memory.fill      write a repeated byte over a range
memory.copy      copy bytes between memories/ranges
memory.init      copy bytes from a passive data segment
data.drop        mark a passive data segment unavailable for later memory.init
atomics          synchronized reads/writes/waits/notifies on shared memories
```

Memory Control asks a different question: can the module or host control whether memory pages are physically backed, protected, mapped to host resources, or supplied by an already-owned buffer? A future `memory.discard`-style instruction might leave the range reading as zeroes while allowing the host to release backing resources. That is a memory-management operation, not a normal byte-copy or byte-fill convenience.

The easiest confusion to avoid:

```text
memory.fill 0       -> ordinary write of zero bytes; implemented locally
memory.discard      -> proposal memory-control operation; not implemented locally

data.drop           -> drops a passive data segment; implemented locally
memory.discard      -> would affect linear memory bytes/pages; not implemented locally
```

## Proposal Shape Snapshot

The Memory Control repository says the proposal is still early and decomposed into sub-proposals. Treat these rows as current proposal-routing vocabulary, not as a Starshine implementation checklist that already exists.

| Proposal idea | What it is trying to control | Current wiki routing |
| --- | --- | --- |
| BYOB for `WebAssembly.Memory` | Let a host create `WebAssembly.Memory` using a caller-supplied buffer-like backing object. | Host/JS API boundary; no current Starshine module, validator, or Node package support claim. |
| `memory.discard` | Allow a module to discard a linear-memory byte range so future reads observe zeroes and hosts with virtual memory can release backing resources. | Active proposal instruction family; no current Starshine `Instruction`, binary, WAST, validator, generator, or pass support. |
| Static memory protection | Add page-protection-style constraints so selected memory ranges cannot be read or written. | Runtime/protection proposal evidence; no current Starshine `MemType`, validation, or execution model. |
| Mappable memory | Let memory be backed by mapped storage or other host resources. | Host/runtime proposal evidence; no current Starshine binary/module representation. |
| Virtual mode | Make virtual-memory-style allocation and commitment behavior explicit. | Proposal-level memory-management mode; no current Starshine memory mode field. |
| Lazy commit / `memory.commit` | Discussed as a possible alternative or future companion to discard-oriented behavior. | Not a stable local or official instruction contract; route through this boundary until a focused proposal source and local implementation exist. |

## Current Starshine Non-Support Map

| Layer | Current evidence | Memory Control status |
| --- | --- | --- |
| Core model | [`Instruction`](../../src/lib/types.mbt) has `MemorySize`, `MemoryGrow`, atomics, `MemoryInit`, `DataDrop`, `MemoryCopy`, and `MemoryFill`, but no discard/commit/protect/map variants. | No core representation. |
| WAST text | [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt) registers `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, `memory.init`, and `data.drop`; [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt) lowers only those runtime memory opcodes. | No parser/lowerer/printer text support. |
| Binary codec | [`src/binary/decode.mbt`](../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../src/binary/encode.mbt) cover current `0xFC` saturating conversions plus Core bulk-memory/table subcodes `8..17`; they do not decode or encode proposal `memory.discard`. | Current proposal bytes are decode errors, not known local instructions. |
| Validation | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) stack-types the current memory families, including address-width-aware `memory.size`, `memory.grow`, `memory.copy`, and `memory.init`, with the documented memory64 `memory.fill` length caveat. | No validation rule, effect rule, trap rule, or memory-management policy. |
| Generator/fuzz | Existing generator feature gates cover bulk memory, multi-memory, memory64, ordinary atomics, and shared memories where implemented. | No Memory Control proposal gate or coverage row. |
| Passes/effects | Memory operations are treated through ordinary read/write/grow/trap/effect boundaries. | A future discard/protect/map operation needs explicit effect/barrier modeling before any optimizer can move or delete it. |

## How To Avoid Misrouting

### `memory.discard` is not `memory.fill`

Both can make a range read back as zeroes, but only `memory.fill` is a current Starshine/Core instruction. `memory.fill` writes a byte value and has ordinary memory-write effects. The `memory.discard` sub-proposal adds memory-control semantics: page-aligned discard, zero-observation after discard, and possible host backing-resource release. A pass must not replace one with the other unless a future proposal implementation and semantic proof make that legal.

### `memory.discard` is not `data.drop`

`data.drop` consumes a **data segment** index and prevents a passive segment from being reused by future `memory.init`. It does not touch the bytes already in linear memory. A proposal `memory.discard` consumes memory range operands and would affect the contents/backing of linear memory.

### Memory Control is not memory64, multi-memory, shared memory, or Custom Page Sizes

- **memory64** changes address and page-count value widths; see [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md).
- **multi-memory** changes which memory an instruction selects; see [`wasm-multi-memory-boundary.md`](wasm-multi-memory-boundary.md), [`wast/memory-argument-authoring.md`](wast/memory-argument-authoring.md), and [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md).
- **shared memory / atomics** changes synchronization and sharedness requirements; see [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) and [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md).
- **Custom Page Sizes** changes the declared page-size dimension; see [`wasm-custom-page-sizes-boundary.md`](wasm-custom-page-sizes-boundary.md).
- **Memory Control** changes runtime memory-management capabilities and currently has no Starshine carrier.

## Future Implementation Checklist

If Memory Control work becomes in scope, land it as a focused implementation slice rather than mixing it into ordinary memory instruction cleanup:

1. Recheck the proposals tracker and the focused Memory Control sub-proposal source; record whether the target is still Phase 1, has advanced, or has changed names/stack shapes.
2. Add core `Instruction` variants and decide how selected memory indices and address-width operands are represented.
3. Add binary decode/encode only for a source-confirmed opcode assignment; keep prototype opcode values labeled as provisional until the proposal says otherwise.
4. Add WAST keywords, parser/lowerer/printer tests only if text syntax is in scope.
5. Add typechecker rules for memory existence, address-width operands, size operands, out-of-bounds traps, page alignment, and interaction with memory64/multi-memory.
6. Add effect-model and pass-barrier rules before optimizers can reorder around discard/protect/map operations.
7. Add generator, invalid-fuzzer, and external-validator classification so proposal unsupported-feature failures are distinguishable from malformed binary and ordinary validation bugs.
8. Refresh this page, [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md), memory/binary authoring pages, and [`docs/wiki/log.md`](log.md).

## Sources

- Focused bridge: [`raw/wasm/2026-06-05-memory-control-boundary-refresh.md`](raw/wasm/2026-06-05-memory-control-boundary-refresh.md)
- Active proposal routing snapshot: [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md)
- Current memory instruction docs: [`wast/memory-instruction-authoring.md`](wast/memory-instruction-authoring.md), [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md), [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md)
- Related memory-type boundaries: [`wasm-custom-page-sizes-boundary.md`](wasm-custom-page-sizes-boundary.md), [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md), [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md)
- Starshine code: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`../../src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt)
