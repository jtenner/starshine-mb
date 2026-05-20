# GC Aggregate Instruction And Constant-Expression Source Refresh

- Source family: WebAssembly Core 3.0 aggregate instruction validation/text/syntax plus Starshine local WAST/core/validator source.
- Capture date: 2026-05-20.
- Reason for capture: the living GC aggregate instruction page already separates Starshine core/binary/validator support from the narrower WAST text path. This refresh records one extra boundary that is easy to miss: current official WebAssembly treats some aggregate constructors as constant-expression instructions, while Starshine's local constant-instruction gate still accepts struct constructors but not array constructors in initializer contexts.

## Primary external sources checked

1. WebAssembly Core Specification, `Instructions — Validation — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
2. WebAssembly Core Specification, `Instructions — Text Format — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/text/instructions.html>
3. WebAssembly Core Specification, `Instructions — Structure — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/syntax/instructions.html>
4. WebAssembly Core Specification, `Instructions — Binary Format — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/binary/instructions.html>

## Source-backed takeaways

- Current WebAssembly 3.0 text and abstract syntax list the full aggregate instruction family: struct constructors/gets/sets, array constructors including data/element-backed constructors, array gets/sets/length/fill/copy/init, i31 operators, and `any`/`extern` conversions.
- The validation rules keep important array constraints visible: `array.new_elem` depends on an existing element segment whose reference type matches the array element reference type; `array.new_data` depends on an existing data segment and a numeric or vector array element type; packed array reads require the signedness suffix, while unpacked array reads must not use it; struct and array writes require mutable storage.
- The official constant-expression predicate includes `struct.new`, `struct.new_default`, `array.new`, `array.new_default`, `array.new_fixed`, `ref.i31`, `any.convert_extern`, and `extern.convert_any` along with the usual scalar/reference/global-get families.
- That official constant-expression list is not the same as Starshine's current local allow-list. Starshine accepts struct constructors plus local descriptor constructors in constant expressions, but the reviewed `validate_const_instr(...)` path still rejects `ArrayNew`, `ArrayNewDefault`, and `ArrayNewFixed` even though the instruction typechecker supports them in ordinary expression contexts.
- Therefore there are two independent Starshine boundaries to preserve in docs and tests:
  1. **WAST text boundary:** `struct.set` and official `array.*` aggregate instruction text are not accepted by the current high-level WAST parser/printer/lowerer, even though core/binary/validator surfaces exist.
  2. **Initializer boundary:** direct core/binary fixtures for `array.new*` can validate in ordinary bodies, but they are not currently valid Starshine constant expressions until `validate_const_instr(...)` and focused tests are widened.

## Starshine local source map

- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) registers `struct.new`, `struct.new_default`, `struct.get*`, local descriptor constructors, `ref.i31`, `i31.get_*`, and `any`/`extern` conversion keywords, but does not register official `struct.set` or `array.*` instruction keywords.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses WAST struct constructors/gets, descriptor constructors, i31, and conversion forms, and has array type-definition support, but no official array instruction parser cases.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines core `StructSet`, all `Array*` instruction variants, i31 forms, and `any`/`extern` conversions.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) typechecks `StructSet`, `ArrayNew`, `ArrayNewDefault`, `ArrayNewFixed`, `ArrayNewData`, `ArrayNewElem`, `ArrayGet*`, `ArraySet`, `ArrayLen`, `ArrayFill`, `ArrayCopy`, `ArrayInitData`, and `ArrayInitElem` in ordinary instruction contexts.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) has the reviewed `validate_const_instr(...)` gate: it admits struct constructors and local descriptor constructors as constant instructions, but not the array constructor variants currently listed by official WebAssembly 3.0.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) and the generator coverage ledger provide core valid-generation evidence for aggregate instructions; that evidence should not be cited as WAST text or initializer support unless the corresponding layer has tests.

## Documentation guidance

- Keep [`../../wast/gc-aggregate-instruction-authoring.md`](../../wast/gc-aggregate-instruction-authoring.md) responsible for choosing WAST versus core/binary/generated fixture format for aggregate instructions.
- Keep [`../../validate/constant-expressions.md`](../../validate/constant-expressions.md) responsible for official-versus-local initializer eligibility.
- Pages that mention data- or element-backed arrays should link both the segment page and the aggregate-instruction page, because segment-index validity and aggregate typechecking are separate proofs.
