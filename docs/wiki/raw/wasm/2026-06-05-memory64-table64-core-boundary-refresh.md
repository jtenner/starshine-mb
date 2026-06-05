# Memory64/Table64 Core Boundary Refresh

- Capture date: 2026-06-05
- Source family: current WebAssembly Core 3.0 address-type, validation, finished-proposal, and Starshine local-code evidence
- Purpose: refresh the living [`../../validate/memory-table-address-widths.md`](../../validate/memory-table-address-widths.md) page and [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md) so memory64/table64 claims route as finished/Core-3.0 address-width behavior with local Starshine layer gaps, not as active proposal work and not as generic memory/table support.

## Primary sources checked

- WebAssembly Core Specification, `Syntax / Types — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/syntax/types.html>
  - Current Core types define address types as `i32` or `i64` and attach an address type to memory and table limits.
  - The `min(at1, at2)` helper still chooses the narrower address type for mixed-resource copy lengths.
- WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Memory and table instructions use selected-resource address types positionally: address/destination/source/size/count operands follow the selected memory/table where the operand indexes that resource.
  - Segment source offsets and segment lengths for `memory.init` and `table.init` remain `i32` because they index data/element segment payloads, not the selected destination resource.
  - `call_indirect` and `return_call_indirect` use the selected table address type for the dynamic table element index.
- WebAssembly Core Specification, `Text Format / Modules — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/text/modules.html>
  - Current text types carry memory/table type annotations, but local Starshine WAST declarations are narrower than Core/binary resource representation.
- WebAssembly finished-proposals table: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>
  - `memory64`, `typed function references`, `tail call`, and multi-value/SIMD/GC-adjacent features are listed as finished and routed into Core versions rather than active proposal buckets.
- WebAssembly proposal phases tracker: <https://github.com/WebAssembly/proposals/blob/main/proposals.json>
  - `memory64` is not a current active proposal row; active memory-related rows such as Memory Control and Custom Page Sizes remain separate from Core address width.

## Starshine evidence checked

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt)
  - `Limits` has `I32Limits` and `I64Limits`.
  - `MemType` and `TableType` carry those limits.
  - `Limits::addr_valtype(...)`, `Limits::min_addr(...)`, and `min_addr_valtype(...)` provide the local address-width helpers used by validation.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
  - `Decode for Limits` accepts i32 and i64 limit encodings.
  - `Decode for MemType` accepts ordinary, shared, memory64, and shared-memory64 flag shapes; validation still owns semantic legality such as shared-without-maximum rejection.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
  - Current aligned memory surfaces: `memory.size`, `memory.grow`, scalar memory `MemArg` address checks, `memory.copy`, and `memory.init` use selected-resource or mixed-width address rules.
  - Current aligned table surfaces: `table.copy` and `table.init` use selected-resource or mixed-width address rules.
  - Current local gaps remain: `memory.fill` length, `table.fill` length, ordinary `table.get` / `table.set` / `table.size` / `table.grow`, `call_indirect`, and `return_call_indirect` still contain `i32` assumptions where Core 3.0 expects the selected table/memory address type.
- [`../../../../src/validate/gen_invalid_tests.mbt`](../../../../src/validate/gen_invalid_tests.mbt) and [`../../../../src/validate/gen_valid_tests.mbt`](../../../../src/validate/gen_valid_tests.mbt)
  - Existing tests cover memory64 active-data offsets, memory64 invalid address/value/copy/init families, memory.fill/table.fill invalid strategies, and call-indirect/return-call-indirect index/type invalid strategies. These are evidence for current local coverage boundaries, not proof that every table64 positive validates.

## Durable conclusions

1. **memory64/table64 is a Core address-width boundary now.** Treat official memory/table address-width rules as WebAssembly Core 3.0 evidence and finished-proposal history, not active proposal evidence.
2. **Current Starshine support is layer-specific.** Core and binary representations know `I64Limits`; resource validation can admit i64 table/memory limits; some instruction validators are already address-width-aware; high-level WAST declaration syntax and several table/memory instruction validators are still narrower.
3. **Instruction operands are positional.** `memory.fill` length and `table.fill` length follow the selected resource's address type in Core; `memory.init` / `table.init` data/element segment source offsets and lengths remain `i32` even when the destination resource is memory64/table64.
4. **Do not conflate nearby memory proposals.** Memory Control, Custom Page Sizes, Threads/shared memory, and multi-memory/table selection have separate status and local-support boundaries. They can combine with memory64/table64 in future fixtures, but they are not the same feature claim.

## Supersession and follow-up

- This bridge supersedes the freshness of [`2026-06-04-memory-table-address-width-validation-refresh.md`](2026-06-04-memory-table-address-width-validation-refresh.md) only for the status-routing claim that memory64/table64 should be taught as Core/finished rather than proposal-active. The 2026-06-04 bridge remains the detailed source map for the exact validator matrix.
- If Starshine widens `memory.fill`, `table.fill`, ordinary table64 operations, or indirect-call index typing, update the living validator page, the local/spec divergence ledger, the relevant WAST instruction page, index, and log in the same change.
- If high-level WAST grows memory64/table64 declaration syntax, update WAST resource-declaration and text-surface-gap pages separately; a WAST text widening does not by itself change binary/core validation status.
