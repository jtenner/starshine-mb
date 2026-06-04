# WebAssembly Data Segment And Data-Count Current Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core Specification 3.0 pages plus Starshine repository evidence
- Primary sources checked on 2026-06-04; opened spec pages identify themselves as WebAssembly 3.0 (2026-06-03):
  - WebAssembly Core Specification, `Text Format / Modules`: <https://webassembly.github.io/spec/core/text/modules.html>
  - WebAssembly Core Specification, `Syntax / Modules`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Validation / Modules`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions`: <https://webassembly.github.io/spec/core/valid/instructions.html>

## Durable takeaways

- The current official text data segment surface is unchanged from the May snapshot: passive `(data $id? "...")`, active `(data $id? (memory x)? (offset expr) "...")`, omitted memory use defaulting to memory `0`, and data strings formed by concatenating zero or more string literals.
- The current official binary data section remains section id `11` with data headers `0` active memory `0`, `1` passive, and `2` active explicit memory. The binary data-count section remains section id `12`, represents the number of data segments, and is malformed when present with a count that differs from the data-section length.
- The current official binary module rule is broader than the explanatory note under the data-count section: the data-count section must be present if **any data index** occurs in the code section. The same page's note explains the original single-pass validation motivation using `memory.init` and `data.drop` because those are the bulk-memory data-index users.
- The current official instruction validation surface includes data-index uses beyond bulk memory: `array.new_data` and `array.init_data` both check that the selected data segment exists and is valid, alongside their array-type and storage-type constraints.
- `memory.init` still consumes destination address typed by the target memory and `i32` source-offset and length operands; `data.drop` consumes no stack operands and validates only the data index.

## Starshine implications

- `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, and `src/wast/module_wast.mbt` still match the ordinary active/passive data text layer recorded in the May snapshot: omitted data offset means passive, active memory names/indices resolve only for active data, and WAST lowering emits `DataCntSec` whenever it emits any data segments.
- `src/lib/types.mbt`, `src/binary/decode.mbt`, and `src/binary/encode.mbt` preserve `DataIdx`, `DataSec`, `DataCntSec`, all three data headers, `MemoryInit`, `DataDrop`, `ArrayNewData`, and `ArrayInitData` core carriers.
- `src/validate/typecheck.mbt` checks data-index existence for `memory.init`, `data.drop`, `array.new_data`, and `array.init_data`.
- `src/validate/validate.mbt` currently splits data-count checks into `validate_datacnt(...)` for count equality and `validate_bulk_memory_data_count_requirement(...)` for missing count in code bodies. The latter currently scans only `MemoryInit` and `DataDrop`. That matches the bulk-memory note but is narrower than the current official binary module rule if a binary/core fixture reaches `array.new_data` or `array.init_data` without `DataCntSec`.
- High-level WAST text cannot currently author `array.new_data` / `array.init_data`, so the practical missing-data-count gap is most relevant to direct core, binary, and generator fixtures rather than ordinary WAST data-segment authoring.

## Follow-up questions

- If Starshine widens the data-count requirement scanner, add focused core or binary validation tests proving `ArrayNewData` and `ArrayInitData` without `DataCntSec` reject with the intended diagnostic family, then update invalid-fuzzer and trace expectations if the user-visible phase or family changes.
- If WAST aggregate array text support lands later, make the data-count rule visible in both the aggregate-instruction and data-segment pages so `(data ...)` fixtures using `array.new_data` or `array.init_data` are not mistaken for ordinary passive-data-only modules.
- If a printer/pass starts eliding data-count from data modules, keep the elision proof tied to **all** surviving code-section data-index users, not only `memory.init` / `data.drop`.
