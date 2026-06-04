# Tail-Call Current Source Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core 3.0 instruction syntax/text/binary/validation/execution pages plus Starshine WAST/core/binary/validator/CFG source surfaces

## Primary Sources Checked

- WebAssembly Core Specification, `Syntax / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- WebAssembly Core Specification, `Text Format / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/text/instructions.html>
- WebAssembly Core Specification, `Binary Format / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/binary/instructions.html>
- WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly Core Specification, `Execution / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/exec/instructions.html>
- Historical tail-call proposal repository: <https://github.com/WebAssembly/tail-call>

## Durable Takeaways

- Current Core 3.0 still exposes the three tail-call forms `return_call`, `return_call_indirect`, and `return_call_ref`; no replacement spelling was found in the 2026-06-03 official pages.
- Validation keeps the same call-plus-return model captured in the May notes: the target consumes ordinary callee parameters, validates against the current function return type, and leaves the local continuation unreachable rather than pushing ordinary results for later instructions.
- `return_call_indirect` remains the tail-call sibling of `call_indirect`: it carries a type index and table index at the binary/core layer, consumes the dynamic table element index, and requires a function-reference-compatible table.
- The current official validation model is address-type-aware for selected tables. Starshine's current `typecheck_return_call_indirect(...)` still pops an `i32` table element index, matching ordinary table32 fixtures but not a complete table64 validation story.
- `return_call_ref` still shares the same target-reference shape as `call_ref` while terminating the current function. It is not a `ref.func` declaration source by itself.

## Starshine Evidence Checked

- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) registers `return_call`, `return_call_indirect`, and `return_call_ref`.
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses direct tail calls with a required function index, indirect tail calls with an optional table index plus type use, and reference tail calls with a type use.
- [`../../../../src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints all three forms and currently prints the resolved/default table index for `return_call_indirect`.
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) resolves WAST ids/type uses into `FuncIdx`, `TableIdx`, and `TypeIdx` carriers.
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) keeps separate `Instruction::ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef` variants.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) decode/encode opcodes `0x12`, `0x13`, and `0x15`, with `return_call_indirect` encoded as type index before table index.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) checks target result compatibility with `require_return_results(...)`, then calls `set_unreachable()` for all three tail-call forms; the indirect path still uses an `i32` table element index.
- [`../../../../src/ir/cfg.mbt`](../../../../src/ir/cfg.mbt) and [`../../../../src/ir/hot_flags.mbt`](../../../../src/ir/hot_flags.mbt) are the local CFG/effect surfaces that treat tail calls as call-family terminators.

## Caveats And Supersession

- This refresh supersedes only the source-date portion of [`2026-05-19-wast-tail-call-sources.md`](2026-05-19-wast-tail-call-sources.md) and narrows the local caveat wording. The May manifest remains useful for the original Starshine source map and authoring-page split.
- The historical tail-call proposal remains useful rationale, not the live validation contract. Prefer the current Core 3.0 pages for syntax, binary, validation, and execution facts.
- Do not use Starshine's current `i32` indirect-tail-call table index behavior as evidence for full table64 compliance. The table64 validation caveat is shared with ordinary `call_indirect` and the table-instruction page.
