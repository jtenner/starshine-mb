# WebAssembly Data-Count And Code Data-Index Recheck

- Capture date: 2026-06-04
- Source family: current WebAssembly Core Specification 3.0 pages plus Starshine repository evidence
- Primary sources checked on 2026-06-04; opened spec pages identify themselves as WebAssembly 3.0 (2026-06-04):
  - WebAssembly Core Specification, `Binary Format / Modules`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions`: <https://webassembly.github.io/spec/core/valid/instructions.html>

## Durable takeaways

- The binary modules page still makes data-count section id `12` distinct from data section id `11`, and still places data-count before code and data in the binary module order.
- The focused data-count section note still explains the single-pass motivation using `memory.init` and `data.drop`, because those were the original bulk-memory data-index users and they need a segment count before the data section is decoded.
- The enclosing binary module rule is broader than that note: a data-count section must be present when any data index occurs in the code section.
- The current instruction-validation page has four ordinary code-section instruction families that carry a `DataIdx` in Starshine terminology: `memory.init`, `data.drop`, `array.new_data`, and `array.init_data`.
- `memory.init` validates both a memory and a data segment; its destination address follows the selected memory address type, while its data-segment source offset and length remain `i32`.
- `data.drop` validates only that the selected data segment exists.
- `array.new_data` and `array.init_data` validate that the selected data segment exists and additionally require an array type whose unpacked storage is numeric or vector; `array.init_data` also requires mutable array storage and a nullable destination reference stack operand.

## Starshine reconciliation

- `src/lib/types.mbt` has explicit core instruction carriers for `MemoryInit(DataIdx, MemIdx)`, `DataDrop(DataIdx)`, `ArrayNewData(TypeIdx, DataIdx)`, and `ArrayInitData(TypeIdx, DataIdx)`, plus `DataCntSec` and `DataIdx` wrappers.
- `src/validate/typecheck.mbt` validates data-index existence for all four instruction families during ordinary body typechecking.
- `src/validate/validate.mbt` splits data-count validation into count equality (`validate_datacnt`) and a pre-code requirement scan (`validate_bulk_memory_data_count_requirement`). The pre-code scan currently recurses through structured control bodies but returns true only for `MemoryInit` and `DataDrop` leaves.
- That local scan is intentionally narrower than the current official module rule. Direct core or binary fixtures containing `ArrayNewData` or `ArrayInitData` without `DataCntSec` should remain documented as validator-gap evidence until the scanner widens.
- `src/validate/invalid_fuzzer.mbt` has invalid-AST coverage for missing data-count through both `memory.init` and `data.drop`, but no sibling missing-data-count strategy for the two GC array data-index carriers as of this recheck.

## Follow-up questions

- If Starshine widens `instr_uses_bulk_memory_data_count(...)`, add focused validation tests and invalid-AST strategies for `array.new_data` and `array.init_data` without `DataCntSec`, then update diagnostic-family docs if the public issue classification changes.
- If the WAST text layer starts accepting `array.new_data` or `array.init_data`, route those fixtures through the same data-count requirement guide rather than treating them as ordinary passive-data examples.
- If a pass or printer elides `DataCntSec`, it must prove absence of every surviving code-section data-index carrier, not just absence of `memory.init` / `data.drop`.
