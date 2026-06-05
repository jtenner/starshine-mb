# Typed Function References / `call_ref` Boundary Refresh

- Capture date: 2026-06-05
- Source family: current WebAssembly Core 3.0 pages, official finished/proposal-status routing, historical function-references proposal pages used as teaching aids, and current Starshine WAST/core/binary/validator/generator evidence.
- Purpose: add a focused durable router for typed function references so future docs do not treat ordinary `call_ref` as either an active proposal gap or as Starshine WAST text support.

## Primary sources checked

- WebAssembly Core Specification, `Syntax / Instructions — WebAssembly 3.0 (Release 3.0, 2026-06-04)`: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- WebAssembly Core Specification, `Text Format / Instructions — WebAssembly 3.0 (Release 3.0, 2026-06-04)`: <https://webassembly.github.io/spec/core/text/instructions.html>
- WebAssembly Core Specification, `Binary Format / Instructions — WebAssembly 3.0 (Release 3.0, 2026-06-04)`: <https://webassembly.github.io/spec/core/binary/instructions.html>
- WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (Release 3.0, 2026-06-04)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly blog, `Wasm 3.0 Completed`: <https://webassembly.org/news/2025-09-17-wasm-3.0/>
- Historical function-references proposal validation page, retained as a teaching aid for explicit validation rules: <https://webassembly.github.io/function-references/core/valid/instructions.html>
- Existing Starshine raw notes: [`2026-06-04-reference-call-and-cast-current-refresh.md`](2026-06-04-reference-call-and-cast-current-refresh.md), [`2026-05-20-call-ref-source-refresh.md`](2026-05-20-call-ref-source-refresh.md), and [`2026-06-04-ref-func-start-refs-current-refresh.md`](2026-06-04-ref-func-start-refs-current-refresh.md).

## Local Starshine sources checked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt): `CallRef(TypeIdx)`, `ReturnCallRef(TypeIdx)`, `RefFunc(FuncIdx)`, `CallIndirect(TypeIdx, TableIdx)`, and tail-call variants.
- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt): registers `call`, `call_indirect`, `return_call`, `return_call_indirect`, and `return_call_ref`, but not ordinary `call_ref`.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), and [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt): parse/lower/print `return_call_ref` and `ref.func`; ordinary `call_ref` is not a current high-level text surface.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt): decodes opcode `0x14` as `Instruction::call_ref(tidx)` and opcode `0x15` as `Instruction::return_call_ref(tidx)`.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt): emits opcode `0x14` for `CallRef` and `0x15` for `ReturnCallRef`.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt): `typecheck_call_ref(...)` and `typecheck_return_call_ref(...)` require a function type index, pop a nullable reference to that function heap type after callee parameters, and either push results (`call_ref`) or mark the continuation unreachable after return-result compatibility (`return_call_ref`).
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) and [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt): whole-module `ref.func` declaration validation and natural/coverage-forced reference-call generation.
- [`src/validate/gen_valid_tests.mbt`](../../../../src/validate/gen_valid_tests.mbt): coverage-forced call-reference sources through locals, block results, globals, and tables.

## Durable takeaways

1. Treat typed function references and ordinary `call_ref` as **Core 3.0 / finished** WebAssembly for standards-status claims. Do not route them as an active proposal solely because the historical function-references proposal pages remain useful for explicit validation examples.
2. Current Core syntax/binary pages list `call_ref` and `return_call_ref` as call-family instructions with a function-type immediate; binary opcodes are `0x14` and `0x15` respectively.
3. `call_ref` consumes ordinary callee operands and then a first-class function reference whose heap type matches the immediate function type, producing the function type's results. `return_call_ref` uses the same target/reference shape but is a tail call and leaves the current continuation unreachable after result-list compatibility is checked.
4. `ref.func` is a common way to materialize the function reference, but it remains governed by the separate module-level declaration-source rule. `call_ref` and `return_call_ref` consume a reference; they do not themselves declare a function index as referenceable.
5. Starshine's **core/binary/validator/generator** support is broader than its WAST text support: ordinary `call_ref` is modeled, encoded, decoded, typechecked, and generated, while high-level WAST `call_ref` keyword/parser/lowerer/printer support is still absent. `return_call_ref` text is supported because it lives on the local tail-call WAST surface.
6. The official text page routes many control instructions through the generic verbatim-control rule rather than per-instruction subsections. Lack of a standalone `call_ref` text subsection is not evidence that Core WAT lacks the instruction; local Starshine WAST evidence still must come from `src/wast` sources.

## Starshine implications

- Add or update docs with the layer name first: standards Core, WAST text, binary codec, validator, generator, pass, or Binaryen oracle. A correct one-line summary is: “`call_ref` is Core 3.0, but Starshine WAST text does not yet expose ordinary `call_ref`; use core/binary/generator fixtures.”
- WAST pages should link a focused typed-function-reference boundary instead of scattering this explanation across call, reference, tail-call, and text-gap pages.
- Pass docs that rewrite functions, signatures, tables, or references should include `CallRef`, `ReturnCallRef`, `RefFunc`, function exports, table/global/element declaration sources, and function/type remaps in the same checklist.
- If Starshine adds ordinary WAST `call_ref`, update the focused boundary page, WAST function/call guide, reference guide, text-surface gap ledger, WAST arbitrary parity plan, parser/lowerer/printer tests, and generator ledger together.

## Caveats and supersession

- This note narrows and refreshes source routing. It does not supersede the detailed 2026-05-20 `call_ref` stack-shape note or the 2026-06-04 reference-call/cast refresh; it crystallizes their durable claims into a focused living page.
- The historical function-references proposal pages are cited only as stable teaching aids for explicit validation shape. The current standards-status source is the Core 3.0 specification plus official finished/Core routing.
- If Core 3.0 generated HTML changes how it surfaces `call_ref` validation details, keep the focused boundary page grounded in the current Core syntax/binary pages plus Starshine's local typechecker until the current validation page is easier to cite directly.
