# WebAssembly Data, Element, And Data-Count Section Source Snapshot

- Capture date: 2026-05-13
- Source family: WebAssembly Core Specification 3.0 draft
- Primary sources:
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Text Format / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/text/modules.html>

## Durable takeaways

- Data segments have two semantic modes: `active memidx expr`, which initializes memory during instantiation, and `passive`, whose bytes can be copied later with `memory.init`. Data segments are referenced by data indices.
- Element segments have three semantic modes: `active tableidx expr`, `passive`, and `declare`. Element payloads are typed reference expressions; legacy function-index encodings are abbreviations for `ref.func` expressions.
- Binary element section id is `9`; its segment headers `0` through `7` cover legacy active/passive/active-explicit-table/declarative function-index forms plus active/passive/declarative expression forms.
- Binary data section id is `11`; data segment headers are `0` for active memory `0`, `1` for passive, and `2` for active with an explicit memory index.
- Binary data-count section id is `12`; when present, it must equal the number of data segments. The module-level binary rule also requires data count presence when any data index appears in the code section, so `memory.init` and `data.drop` can be validated before the later data section is decoded.
- Text data segments support optional memory-use and offset syntax, with omitted memory use defaulting to memory `0`; multiple string literals concatenate into one byte payload.
- Text element segments support optional table-use and offset syntax, explicit `declare`, typed `item` expressions, and inline table abbreviations.

## Starshine implications

- Starshine's core `@lib.Module` keeps separate `elem_sec`, `data_cnt_sec`, and `data_sec` fields. `ElemMode`, `ElemKind`, and `DataMode` mirror the official active/passive/declarative split in the core library representation.
- Starshine's binary encode/decode surface implements the official element header family `0` through `7`, data header family `0` through `2`, and section ids `9`, `11`, and `12`.
- Starshine validation requires active data and element offsets to be constant expressions of the parent memory/table address type, checks element type compatibility with active-table element type, validates data-count equality when present, and separately requires a data-count section before code that uses `memory.init` or `data.drop`.
- Starshine's WAST parser/lowering accepts passive and active data/element forms, typed element item expressions, table element abbreviations, passive typed empty element declarations, and ordinary `elem declare func` syntax. Current text-to-lib lowering does not carry an explicit declarative-mode bit in the WAST `ElemSegment` AST; direct binary/lib/generator paths preserve `ElemMode::declarative()`, but text-declared function-only element segments lower through the empty-offset path unless this AST gap is fixed.

## Follow-up questions

- If WAST round-trip fidelity for declarative element segments becomes user-visible, add an explicit mode to `src/wast/parser.mbt`'s `ElemSegment` and update `src/wast/lower_to_lib.mbt` / `src/wast/module_wast.mbt` tests so `(elem declare ...)` lowers to `ElemMode::declarative()` instead of relying on empty-offset inference.
- If Starshine adds stronger single-pass binary validation, keep `DataCntSec` present whenever encoded code contains data-index instructions and maintain the existing full-validator diagnostic split for missing data count versus mismatched count.
