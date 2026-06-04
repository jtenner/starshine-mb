# WebAssembly `ref.func` / Start `refs` Current Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core 3.0 validation, syntax, and binary sources plus Starshine validator evidence
- Primary sources:
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/binary/modules.html>
- Repository evidence checked:
  - `src/validate/validate.mbt`
  - `src/validate/typecheck.mbt`
  - `docs/wiki/validate/ref-func-declarations.md`
  - `docs/wiki/validate/start-section.md`
  - `docs/wiki/validate/module-validation-phases.md`
  - `docs/wiki/wast/function-call-and-module-authoring.md`
  - `docs/wiki/binary/function-import-export-and-code-sections.md`

## Durable takeaways

- Current official instruction validation still gives `ref.func x` two obligations: `x` must name an existing function in the validation context and `x` must be present in `C.refs`.
- Current official module validation still builds `C.refs` from function indices occurring in globals, memories, tables, element segments, optional start, and exports. This confirms the older wiki claim that optional start and function exports are portable `refs` sources.
- Current official start validation is still only the start-function rule: the target function must exist and expand to an empty parameter/result function type.
- Current official binary format still assigns the start section id `8` and decodes it to one optional function index.
- Current official syntax still describes declarative element segments as forward declarations for references formed by `ref.func`-like code.

## Starshine reconciliation

- `collect_declared_funcs_bitmap(...)` in `src/validate/validate.mbt` marks exported functions, `ref.func` values in global initializer expressions, `ref.func` values in table initializer expressions, raw function-index element payloads, and `ref.func` values in element expression payloads.
- The local bitmap still deliberately excludes `start_sec`. The regression test `validate_module does not treat start as a ref.func declaration source` remains current executable evidence that start-only declaration is rejected locally.
- `validate_ref_func_declarations_in_module(...)` still checks globals, table initializers, element payloads, and code bodies after the bitmap is built; body failures report as `FunctionBody` diagnostics.
- `typecheck_ref_func(...)` still owns function-index existence and result-type computation, not whole-module declaration membership. That split keeps `ref.func` declaration validation as a module-level invariant.
- The local behavior remains a stricter Starshine policy, not a change in the portable WebAssembly contract. Any future alignment with the official start-in-`refs` rule must update `collect_declared_funcs_bitmap(...)`, the start-only negative regression, invalid-fuzzer expectations if diagnostic families change, and the focused start/ref.func/function-call wiki pages together.

## Supersession and uncertainty

- This refresh supersedes the source-date portion of `docs/wiki/raw/wasm/2026-05-20-ref-func-declaration-refresh.md` and refreshes the `refs` membership claim against the current 2026-06-03 official Core 3.0 pages.
- No teaching-relevant official drift was found for `ref.func`, `C.refs`, optional-start membership, function-export membership, start validation, start binary section id, or declarative-element purpose.
- The memory member in the official `refs` formula remains easy to overread. Ordinary Starshine memory declarations do not currently carry direct function indices, but the official formula still includes memories as a function-index extraction family.
