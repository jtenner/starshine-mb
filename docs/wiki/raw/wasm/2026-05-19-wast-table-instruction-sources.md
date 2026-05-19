---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-19
sources:
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - https://webassembly.github.io/spec/core/syntax/instructions.html
  - ../../../../src/wast/types.mbt
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/module_wast.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/wast/arbitrary.mbt
  - ../../../../src/validate/invalid_fuzzer.mbt
  - ../../../../src/validate/gen_invalid.mbt
related:
  - ../../wast/table-instruction-authoring.md
  - ../../wast/element-segment-authoring.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../validate/module-validation-phases.md
---

# WAST Table Instruction Sources (2026-05-19)

Purpose: primary-source and local-code manifest for `call_indirect`, `return_call_indirect`, `table.get`, `table.set`, `table.size`, `table.grow`, `table.fill`, `table.copy`, `table.init`, and `elem.drop` authoring in Starshine WAST fixtures.

## Primary sources checked

1. WebAssembly Core Specification 3.0, text instructions: <https://webassembly.github.io/spec/core/text/instructions.html> (opened 2026-05-19; page header shows WebAssembly 3.0 dated 2026-05-14). Relevant rules:
   - `call_indirect` and `return_call_indirect` may omit the table index for backward compatibility; omitted means table `0`.
   - Table instructions accept table indices; table-index abbreviations may omit the table index for `table.get`, `table.set`, `table.size`, `table.grow`, `table.fill`, and `table.copy`; omitted `table.copy` means destination `0` and source `0`.
   - `table.init` has a special text abbreviation where `table.init elemidx` means table `0` and that element segment.
2. WebAssembly Core Specification 3.0, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html> (opened 2026-05-19; page header shows WebAssembly 3.0 dated 2026-05-14). Relevant rules:
   - `table.get`, `table.set`, `table.size`, and `table.grow` use the selected table address type (`at`) and reference type (`rt`).
   - `table.fill` consumes destination index, reference value, and length using the table address type.
   - `table.copy` requires source reference type to match destination reference type, consumes destination index, source index, and a length with `min(at1, at2)`.
   - `table.init` validates the destination table and element segment reference types, consumes destination index with the table address type plus i32 source and length operands.
   - `elem.drop` validates only the element-segment index and has no operand-stack effect.
3. WebAssembly Core Specification 3.0, binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html> (opened 2026-05-19; page header shows WebAssembly 3.0 dated 2026-05-14). Relevant rules:
   - `call_indirect` / `return_call_indirect` encode type index first and table index second, even though text syntax is table then type use.
   - One-byte table ops are `0x25 table.get` and `0x26 table.set`.
   - Prefixed table ops use `0xFC` subcodes `12` through `17`: `table.init`, `elem.drop`, `table.copy`, `table.grow`, `table.size`, and `table.fill`; binary `table.init` carries element index before table index.
4. WebAssembly Core Specification 3.0, syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html> (opened 2026-05-19; page header shows WebAssembly 3.0 dated 2026-05-14). Relevant rules:
   - The core instruction model names table instructions with explicit table and element indices after text abbreviations are expanded.

## Starshine local evidence checked

- [`src/wast/types.mbt`](../../../../src/wast/types.mbt) and [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) define `CallIndirect`, `ReturnCallIndirect`, `TableGet`, `TableSet`, `TableSize`, `TableGrow`, `TableFill`, `TableCopy`, `TableInit`, and `ElemDrop`.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses default table indices for indirect calls and table operations; `table.init` resolves either `elemidx` or `tableidx elemidx`; parser tests cover representative table instruction text.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints explicit table and element indices for the table instruction family.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) resolves `$`/numeric table and element indices, lowers `call_indirect` / `return_call_indirect` with `(TypeIdx, TableIdx)`, and lowers `table_init` to the core order `(ElemIdx, TableIdx)`.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt), [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt), and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) keep core/table immediate order distinct from text abbreviations and binary immediate order.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) validates table existence, funcref-compatible indirect-call tables, element/table reference-type matching, table-copy reference subtyping, and element-drop index existence. It already uses table address widths for `table.copy`, `table.init` destination, and `table.fill`, but currently fixes `table.get`, `table.set`, `table.size`, `table.grow`, and indirect-call table indices/results to `i32` in their local implementations.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt), [`src/wast/arbitrary.mbt`](../../../../src/wast/arbitrary.mbt), [`src/validate/invalid_fuzzer.mbt`](../../../../src/validate/invalid_fuzzer.mbt), and [`src/validate/gen_invalid.mbt`](../../../../src/validate/gen_invalid.mbt) already exercise some table initializers, table instructions, indirect/tail-indirect calls, and invalid table-initializer constant-expression cases.

## Current Starshine caveats to keep visible

- Text parsing for omitted table indices intentionally matches the official backward-compatible default-table abbreviations.
- Starshine prints explicit indices after parsing/lowering, so roundtrip text may be more explicit than the source.
- Core `Instruction::TableInit(ElemIdx, TableIdx)` follows Binaryen/core local storage order, while WAST text spells `table.init tableidx elemidx` and binary bytes encode `elemidx` before `tableidx`; docs must not collapse these three orderings.
- Table64 support is not uniformly validated across the local instruction family yet. `table.copy`, `table.init` destination, and `table.fill` consult table address width, but `table.get`, `table.set`, `table.size`, `table.grow`, `call_indirect`, and `return_call_indirect` currently use `i32` index/result assumptions in the typechecker. Treat table64 table-instruction fixtures as a future validation-widening area rather than a fully green WAST authoring surface.
