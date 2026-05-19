# WAST Call And Function Authoring Source Snapshot

- Capture date: 2026-05-19
- Source family: WebAssembly Core Specification 3.0 draft plus Starshine WAST/core/validator/generator code
- Primary sources checked:
  - WebAssembly Core Specification, `Text Format / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/text/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - Existing broader Starshine snapshot: [`2026-05-13-function-import-export-section-sources.md`](2026-05-13-function-import-export-section-sources.md)

## Durable takeaways

- Text-format function definitions bind optional function identifiers and local identifiers. Function-local parameter/local identifiers live in the local index space for the function body, while function identifiers extend the module's function index space.
- Text functions can use inline export abbreviations and inline import abbreviations. Official text syntax treats inline function import/export forms as abbreviations for ordinary import/export declarations plus a function declaration or import descriptor.
- Direct `call` validates against an existing function index and uses the referenced function type's parameter/result lists as the stack effect.
- `call_indirect` validates against both a selected function-reference-compatible table and a function type index; the table contributes the dynamic element-index operand's address type.
- `call_ref` is part of the core validation model, but current Starshine WAST text does not expose an ordinary `call_ref` keyword. Starshine WAST does expose `return_call_ref`; the ordinary core/generator `call_ref` surface remains a binary/core/generator route unless parser/printer support is added.
- The official module validation rule validates the optional start function, then exports, requires export names to be disjoint, and includes function indices from globals, memories, tables, elements, start, and exports in the module `refs` set for `ref.func` validation. Starshine's existing `ref.func` declaration page records the current local divergence for start-only declaration.

## Starshine implications

- `src/wast/keywords.mbt` registers `func`, `import`, `export`, `start`, `call`, `call_indirect`, and tail-call keywords; it does not currently register ordinary `call_ref`.
- `src/wast/parser.mbt` parses direct calls as `Call(Index)`, parses `call_indirect` with an optional table index defaulting to table `0`, parses ordinary function declarations with inline exports, and parses inline function imports as `ImportField` records. Current Starshine rejects inline exports on inline function-import shorthand and asks authors to use a separate explicit export field for that combination.
- `src/wast/lower_to_lib.mbt` pre-registers type ids, then imports, then defined functions. Function imports increment `ctx.next_func_idx` before defined functions, so WAST `$` names lower to the same imported-prefix absolute `FuncIdx` model used by binary decode and validation.
- Lowering resolves `call` to `Instruction::call(FuncIdx)`, resolves `call_indirect` to `Instruction::call_indirect(TypeIdx, TableIdx)`, resolves explicit/inline exports to `ExportSec`, and keeps only the last parsed `StartField` as the final `StartSec` value if multiple starts are present in WAST text.
- `src/wast/module_wast.mbt` prints direct calls and table-mediated calls with numeric/resolved indices; default-table text may roundtrip with an explicit `0`.
- `src/validate/typecheck.mbt` owns call stack typing for direct, indirect, reference, and tail-call forms. `src/validate/validate.mbt` owns import/function/export/start/code-section validation and duplicate export-name rejection.
- `src/validate/gen_valid.mbt` has separate feature toggles and counters for ordinary calls, indirect calls, tail calls, start sections, and import/export topology. `src/wast/arbitrary.mbt` can generate WAST modules with optional function imports, direct calls, indirect calls, exports, and starts, but remains a parser/printer surface rather than a typed-validity oracle.

## Caveats and supersession

- This snapshot narrows the WAST authoring side of the broader 2026-05-13 function/import/export/code-section snapshot. It does not replace the binary-section guide for section ids, code/function-section parallelism, or pass remap checklists.
- Keep `call_indirect` split between this page and the table-instruction page: this source snapshot records function/type/call facts, while [`../../wast/table-instruction-authoring.md`](../../wast/table-instruction-authoring.md) owns table index defaults, table64 caveats, and bulk table instruction shapes.
- Keep tail-call semantics on [`../../wast/tail-call-authoring.md`](../../wast/tail-call-authoring.md). Direct `return_call` shares function-index resolution with `call`, but tail calls are terminators with current-function return-type constraints.
- If Starshine adds ordinary WAST `call_ref`, update this snapshot, [`../../wast/function-call-and-module-authoring.md`](../../wast/function-call-and-module-authoring.md), [`../../wast/reference-instruction-authoring.md`](../../wast/reference-instruction-authoring.md), parser/printer/lowerer code, and WAST arbitrary coverage together.

## Local code map

- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt): WAST keyword registration for function/module/call keywords.
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt): function/import/export/start and call-family text parsing.
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt): imported-prefix function-id lowering, call lowering, export/start lowering, and function name/annotation lowering.
- [`../../../../src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt): call-family printing.
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt): `FuncIdx`, `Import`, `Export`, `StartSec`, `FuncSec`, `CodeSec`, and call instruction variants.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt): stack typing for call, `call_indirect`, `call_ref`, and tail-call forms.
- [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt): import/function/export/start/code-section validation and `ref.func` declaration scan.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt): valid-generator call, indirect-call, start, and import/export topology coverage.
- [`../../../../src/wast/arbitrary.mbt`](../../../../src/wast/arbitrary.mbt): WAST parser/printer arbitrary generation for calls, imports, exports, and starts.
