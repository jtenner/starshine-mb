# WebAssembly `ref.func` Declaration Refresh

- Capture date: 2026-05-20
- Source family: current WebAssembly Core 3.0 validation/syntax sources plus Starshine validator evidence
- Primary sources:
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
- Repository evidence checked:
  - `src/validate/validate.mbt`
  - `src/validate/typecheck.mbt`
  - `src/validate/invalid_fuzzer.mbt`
  - `src/validate/gen_invalid.mbt`
  - `docs/wiki/validate/ref-func-declarations.md`
  - `docs/wiki/validate/start-section.md`
  - `docs/wiki/validate/module-validation-phases.md`
  - `docs/wiki/wast/element-segment-authoring.md`
  - `docs/wiki/wast/function-call-and-module-authoring.md`
  - `docs/wiki/wast/reference-instruction-authoring.md`

## Durable takeaways

- The current instruction-validation rule still gives `ref.func x` two independent obligations: `x` must name an existing function, and `x` must be present in the validation context's declared-reference set `refs`.
- The current module-validation rule still builds `refs` from the function indices found in globals, memories, tables, element segments, optional start, and exports. The memory member remains a source-expression family in the official formula; ordinary Starshine memory definitions do not currently carry function indices directly.
- The current start-function validation rule remains only the empty-signature function-index check, but the broader module rule still includes optional start in the `refs` source set. This preserves the known official-versus-Starshine divergence: start is valid metadata locally, but start alone does not declare a `ref.func` target in Starshine.
- The current syntax page still explains declarative element segments as forward declarations for references formed by code such as `ref.func`. This supports keeping declarative-element examples in the validator guide even though Starshine's WAST lowering still does not preserve declarative mode.
- `ref.func` is still on the official constant-expression allow-list. That only proves constant-expression eligibility; the declaration membership rule remains a separate whole-module invariant.

## Starshine reconciliation

- `typecheck_ref_func(...)` in `src/validate/typecheck.mbt` checks function-index existence and computes the concrete non-null function reference type. It intentionally does not check declaration membership.
- `collect_declared_funcs_bitmap(...)` in `src/validate/validate.mbt` currently marks exported functions, `ref.func` values in global initializers, `ref.func` values in optional table initializer expressions, function-index element payloads, and `ref.func` values in element expression payloads.
- The local bitmap deliberately does not mark `start_sec`, even though the official current module rule includes optional start in `refs`. The regression `validate_module does not treat start as a ref.func declaration source` remains the executable policy anchor.
- `validate_ref_func_declarations_in_module(...)` scans global/table/element/code expressions after the bitmap is built. Body failures are reported as `FunctionBody` diagnostics carrying the absolute imported-prefix `FuncIdx`, while initializer/element failures report their section family.
- The AST invalid strategy `UndeclaredRefFunc` and public stable id `undeclared-ref-func` still route to the `FunctionBody` diagnostic family, so a future start-alignment change must update validator tests, invalid-fuzzer expectations if they change, and the focused wiki pages together.

## Supersession and uncertainty

- This refresh supersedes the source-date portion of `docs/wiki/raw/wasm/2026-05-13-ref-func-declaration-sources.md`; it does not invalidate that snapshot's Starshine-local implementation map.
- No teaching-relevant official drift was found between the 2026-05-13 snapshot and the current 2026-05-14 WebAssembly Core pages for `ref.func`, `refs`, start participation, declarative elements, or constant-expression membership.
- The future policy question remains open: Starshine can either keep the stricter start-exclusion policy as an intentional local divergence or align with the official `refs` rule by marking `start_sec` as a declaration source. Until code and tests change, docs should describe the stricter local behavior as current fact, not as the portable WebAssembly rule.
