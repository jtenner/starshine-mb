# WebAssembly Function And Code Section Source Refresh

- Capture date: 2026-05-20
- Source family: WebAssembly Core Specification 3.0 draft, plus Starshine repository evidence
- Primary sources:
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Text Format / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/text/modules.html>

## Durable takeaways

- The current official module syntax still uses separate zero-based index spaces; function imports precede defined functions in the function index space, while locals are a function-body-only index space whose parameters precede body locals.
- Binary function definitions remain split: section `3` carries the type-index vector for defined functions, while section `10` carries the parallel code-entry vector. The binary source still explicitly says the two lengths must match.
- Each code entry is length-prefixed and then stores compressed local declaration runs plus the body expression. The local runs describe only non-parameter locals; parameter locals come from the function type.
- Start validation still requires an existing function with an empty parameter/result signature. Export validation still resolves the target external index and the enclosing module validation still requires disjoint export names.
- The official module-validation rule still includes function indices appearing in globals, memories, tables, elements, optional start, and exports when forming the `refs` set used by `ref.func` validation. That preserves the previously recorded Starshine caveat: current Starshine intentionally does not treat `start` alone as a `ref.func` declaration source.
- Text format still has inline import/export abbreviations for functions, and multiple anonymous locals can be combined in one `(local ...)` declaration before lowering to the core locals list.

## Starshine reconciliation

- Starshine mirrors the official split with `Module.import_sec`, `func_sec`, `export_sec`, `start_sec`, `code_sec`, `FuncSec(Array[TypeIdx])`, `CodeSec(Array[Func])`, and absolute `FuncIdx` values in `src/lib/types.mbt`.
- `src/wast/lower_to_lib.mbt` resolves import functions first, then defined functions. Function parameter identifiers occupy local indices first; explicit WAST locals are offset after the parameter count and become the `Locals` stored in each `Func` body.
- `src/binary/decode.mbt` decodes section ids `2`, `3`, `7`, `8`, and `10`; code-body decode checks the expanded local count does not exceed `2^32 - 1` before decoding the expression. `src/binary/encode.mbt` writes code entries by encoding locals and expression into a temporary body payload, prefixing its byte length, and then writing the raw body bytes.
- `src/validate/validate.mbt` validates imports before defined function declarations, computes the imported-function prefix before code validation, accepts empty-present function/code sections only when the present side is empty, rejects non-empty mismatches, maps each code body ordinal to `FuncIdx(imported_func_count + body_idx)`, and validates bodies against their resolved function type.
- The existing source snapshot `2026-05-13-function-import-export-section-sources.md` remains useful for broader function/import/export/start/code section context; this refresh adds the code-entry/local-run details and confirms no current official drift in the start-versus-`ref.func` declaration source caveat.

## Follow-up questions

- If Starshine changes the start-section declaration policy for `ref.func`, refresh this file's downstream wiki page together with `validate/ref-func-declarations.md` and validator regression tests.
- If Starshine gains a function-ordering or code-body compaction pass, preserve the distinction between absolute `FuncIdx` remapping and defined-body ordinal remapping. The code-body ordinal is only meaningful after subtracting the imported-function prefix.
- If WAST printing or lowering starts preserving source-level grouped local declarations, document that as text metadata; the core `Func` body should still be understood as compressed run data for non-parameter locals plus expression semantics.
