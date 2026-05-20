# WebAssembly WAST Data Segment Source Refresh

- Capture date: 2026-05-19
- Source family: WebAssembly Core Specification 3.0 draft and current Starshine repository evidence
- Primary sources checked on 2026-05-19; opened spec pages identify themselves as WebAssembly 3.0 (2026-05-14):
  - WebAssembly Core Specification, `Text Format / Modules`: <https://webassembly.github.io/spec/core/text/modules.html>
  - WebAssembly Core Specification, `Syntax / Modules`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Validation / Modules`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions`: <https://webassembly.github.io/spec/core/valid/instructions.html>

## Durable takeaways

- Official text data segments have two top-level shapes: passive `(data $id? "...")` and active `(data $id? (memory x)? (offset expr) "...")`. The memory use can be omitted and then defaults to memory `0`.
- Official text data payloads are a data string: a possibly empty sequence of string literals whose decoded bytes concatenate into one payload.
- Official memory declarations have an inline `(data ...)` abbreviation that expands to a memory definition plus an active data segment at offset `0`; Starshine's current WAST parser handles ordinary data fields but not this inline memory-data abbreviation.
- Official binary data segments use data-section id `11` with data headers `0` for active memory `0`, `1` for passive, and `2` for active with an explicit memory index.
- Official binary data-count section id `12` represents the data-section segment count before code, allowing single-pass validation of data-index instructions such as `memory.init` and `data.drop`.
- Official validation accepts passive data directly. Active data additionally requires the selected memory to exist, the offset expression to have the selected memory address type, and that offset expression to be constant.
- Official instruction validation for `memory.init` and `data.drop` checks the data index against the validation context's data list. `memory.init` consumes destination address typed by the target memory and `i32` source-offset and length operands.

## Starshine implications

- `src/wast/parser.mbt` stores `DataSegment { id, memory_index, offset, data }`, decodes one or more text string literals into bytes, defaults omitted memory use to `Index::Num(0)`, and treats the absence of an offset expression as the passive text shape.
- `src/wast/lower_to_lib.mbt` lowers empty-offset data to `DataMode::passive()` and non-empty-offset data to `DataMode::active(MemIdx, Expr)`. It resolves named or numeric memory indices only for active data.
- `src/wast/lower_to_lib.mbt` currently emits `DataCntSec` whenever WAST lowering emits any data segments. That is conservative for passive-only modules, but it keeps text-to-binary output ready for later `memory.init` / `data.drop` users.
- `src/wast/module_wast.mbt` prints every data field with an explicit memory index token before the offset/data payload. That is accepted by the current parser, but differs from the most concise official text examples where passive data omits a memory use entirely.
- Starshine core/binary support is broader than the high-level text path: `src/lib/types.mbt`, `src/binary/decode.mbt`, and `src/binary/encode.mbt` preserve active explicit-memory data headers, passive data, data-count, and data-index instruction carriers.
- Starshine validation keeps data-section validation, data-count equality, and missing-data-count-for-code-use as separate diagnostics: `DataSection`, `DataCountSection`, and function-body `data count section required`.

## Follow-up questions

- If exact official text compatibility for passive data becomes user-visible, decide whether the WAST printer should omit the default memory token when `offset` is empty instead of printing `(data 0 "...")`.
- If inline memory-data abbreviations are needed for spec fixture parity, add parser/lowerer/printer tests that prove `(memory (data "..."))` expands to a memory plus active data at offset `0`, then update the resource declaration and data segment pages together.
- If a pass or printer starts eliding data-count from passive-only modules, keep `validate_datacnt(...)`, `validate_bulk_memory_data_count_requirement(...)`, binary encode/decode tests, and invalid repro expectations aligned.
