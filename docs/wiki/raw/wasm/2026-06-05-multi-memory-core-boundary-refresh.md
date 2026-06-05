# Multi-Memory Core Boundary Refresh

- Capture date: 2026-06-05
- Source family: current WebAssembly Core 3.0 selected-memory/index behavior, historical multi-memory proposal context, and Starshine local-code evidence
- Purpose: add a focused living boundary for multi-memory so selected-memory claims route as current Core-module memory-index behavior with Starshine layer gaps, not as Memory Control, Custom Page Sizes, memory64, shared-memory/Threads, or Binaryen `multi-memory-lowering` evidence.

## Primary sources checked

- WebAssembly Core Specification, `Text Format / Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/text/instructions.html>
  - Current text instructions include memory immediates/defaults for memory operations; the selected memory is part of the instruction surface rather than a pass-only convention.
- WebAssembly Core Specification, `Binary Format / Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/binary/instructions.html>
  - Current binary instructions encode memory indices or memory arguments for memory operations. Bulk-memory instructions carry memory/data index immediates separately from scalar/SIMD load/store memargs.
- WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Validation checks the selected memory exists, uses its address type for memory-indexing operands, and keeps `memory.copy` destination/source memories distinct.
- WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - Modules can have memory index spaces; instructions and data segments refer to memories by index.
- Historical WebAssembly multi-memory proposal pages: <https://webassembly.github.io/multi-memory/core/text/modules.html>
  - Useful for origin/context around explicit memory indices and symbolic memory names in text, but current status claims should cite Core 3.0 pages first.
- WebAssembly proposals repository: <https://github.com/WebAssembly/proposals>
  - The active proposal tracker is still useful for neighboring active memory proposals, but multi-memory should not be routed through active Memory Control or Custom Page Sizes rows.

## Starshine evidence checked

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt)
  - `MemIdx` is the memory index carrier.
  - `MemArg(U32, MemIdx?, U64)` stores load/store selected-memory metadata when present.
  - `Instruction::MemorySize`, `MemoryGrow`, `MemoryFill`, `MemoryCopy`, `MemoryInit`, and `DataMode::Active` carry explicit memory indices in core IR.
- [`../../../../src/lib/eq.mbt`](../../../../src/lib/eq.mbt)
  - `MemArg(..., None, ...)` and `MemArg(..., Some(MemIdx(0)), ...)` compare equal, while nonzero `Some(MemIdx(n))` remains distinct.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
  - Binary memargs use the local `align + 64` convention to carry explicit memory indices.
  - `memory.size`, `memory.grow`, `memory.init`, `memory.copy`, and `memory.fill` encode/decode `MemIdx` operands.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
  - `memarg_check(...)`, `typecheck_memory_size(...)`, `typecheck_memory_grow(...)`, `typecheck_memory_init(...)`, `typecheck_memory_copy(...)`, and `typecheck_memory_fill(...)` validate selected-memory existence and stack typing.
  - `memory.copy` keeps destination and source memories separate and uses mixed-width length typing through `min_addr_valtype(...)` when memory64 combines with multi-memory.
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt), [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), and [`../../../../src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt)
  - Current high-level WAST memargs carry `align` and `offset` only.
  - Current WAST lowering defaults load/store memargs and `memory.size` / `memory.grow` / `memory.fill` / `memory.copy` / `memory.init` memory operands to memory `0`.
  - Current WAST printing does not expose explicit nonzero memory indices for these instruction forms.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)
  - `GenValidProposalFeature::MultiMemoryFeature` is local fuzzer vocabulary gated by `allow_mems && allow_memory_limit_variants`. It helps generate selected-memory surfaces, but it is not a standards-status authority.
- [`../../../../src/passes/memory_packing.mbt`](../../../../src/passes/memory_packing.mbt)
  - The current local memory-packing transform is intentionally active-memory-segment scoped and skips nonzero active memory indices in its fast path; pass pages must not use it as a general multi-memory lowering proof.

## Durable conclusions

1. **Multi-memory is current Core selected-memory/index behavior for Core modules.** Use Core 3.0 text, binary, validation, and module pages as status evidence. Use the historical proposal site for context only.
2. **Current Starshine support is layer-specific.** Core IR, binary codec, validator, and generator surfaces can represent and check nonzero memories; WAST text authoring/printing remains narrower and defaults most memory instruction forms to memory `0`.
3. **Memory selection is not address width, page size, sharing, or runtime memory control.** Multi-memory chooses *which* memory an instruction or active segment uses. memory64/table64 changes address-width typing, Custom Page Sizes changes page-size declarations, Threads/shared memory changes synchronization/sharedness, and Memory Control changes future runtime memory-management operations.
4. **Bulk-memory has two index axes.** `memory.copy(dst, src)` has two memory indices; `memory.init(data, mem)` has a data index and a memory index; active data segments have a parent memory index plus a constant offset expression. Passes must update all of those separately.
5. **`GenValidProposalFeature::MultiMemoryFeature` is local fuzzing vocabulary.** It remains useful for generator profiles and feature-fact rows, but wiki status claims should not imply multi-memory is an active proposal because the local enum says `ProposalFeature`.
6. **Binaryen `multi-memory-lowering` is a compatibility transform, not Starshine multi-memory support.** That pass lowers multiple memories into one memory. It is relevant when implementing or comparing a lowering pass, but it is not evidence that Starshine WAST text can author every selected-memory shape.

## Follow-ups

- If WAST grows explicit memory-index syntax for scalar/SIMD memargs, `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, or `memory.init`, update the living boundary, `wast/memory-argument-authoring.md`, `wast/memory-instruction-authoring.md`, `wast/text-surface-gap-ledger.md`, WAST parser/lowerer/printer tests, index, and log together.
- If a pass rewrites or deletes memories, audit `MemArg`, `MemorySize`, `MemoryGrow`, `MemoryFill`, both `MemoryCopy` operands, `MemoryInit`, active `DataMode`, memory imports/exports, and structured name maps in one validation-backed change.
- If generator or external-validator reporting changes the multi-memory feature vocabulary, keep `fuzzing/generator-coverage-ledger.md` and `wasm-feature-status-and-proposal-boundaries.md` clear that local feature gates are not standards-status evidence.
