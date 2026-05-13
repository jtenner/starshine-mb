# WebAssembly `ref.func` Declaration Validation Source Snapshot

- Capture date: 2026-05-13
- Source family: WebAssembly Core Specification 3.0 draft plus current Starshine validator evidence
- Primary sources:
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
- Repository evidence checked:
  - `src/validate/validate.mbt`
  - `src/validate/typecheck.mbt`
  - `src/validate/invalid_fuzzer.mbt`
  - `src/validate/gen_invalid.mbt`
  - `docs/wiki/raw/wasm/2026-05-13-function-import-export-section-sources.md`
  - `docs/wiki/binary/function-import-export-and-code-sections.md`
  - `docs/wiki/binary/data-element-and-datacount-sections.md`

## Durable takeaways

- The official instruction rule for `ref.func x` has two layers: the function index must exist in the module validation context, and the same index must also be present in the context's `refs` set.
- The official module-validation rule builds the `refs` set from function indices appearing in globals, memories, tables, element segments, an optional start section, and exports. The memory member of that source list is currently harmless for ordinary core modules because memories do not carry function indices directly, but it is still part of the official source expression.
- The official syntax page describes declarative element segments as unavailable at runtime and useful for forward-declaring references formed by instructions such as `ref.func`.
- The official constant-expression rule includes `ref.func`, so a `ref.func` can appear in module-level initializer expressions and still be a constant expression; it must also satisfy the same declared-reference rule.
- Current Starshine implements a separate `ref_func_declarations` validation phase after start/export validation and before code-section body validation. This phase scans globals, table initializers, element expressions, and code bodies for `Instruction::RefFunc` uses, checks them against a precomputed declaration bitmap, and reports undeclared body uses as `FunctionBody` diagnostics with the absolute imported-prefix `FuncIdx`.
- Current Starshine's declaration bitmap is intentionally source-limited to exports, global initializer `ref.func`, table initializer `ref.func`, element payload function indices, and element expression `ref.func` values. It does **not** mark the start target as declared. This diverges from the official module-validation source set and is locked by the test named `validate_module does not treat start as a ref.func declaration source`.
- Current Starshine also separates two checks that beginners often conflate: ordinary typechecking verifies the referenced function index exists and infers a concrete function reference type, while the later declaration phase verifies that the index is in the declaration bitmap.
- Invalid fuzzing has a first-class AST mutation for undeclared `ref.func` and expects the `FunctionBody` diagnostic family, so changes to this policy must update both validator tests and invalid-fuzzer expectations.

## Starshine implications

- Treat `ref.func` validation as a module-level cross-reference invariant, not just an instruction type rule.
- Passes that delete, merge, reorder, import, export, or synthesize functions must repair both ordinary `FuncIdx` uses and the set of declaration sources that allow surviving `ref.func` instructions to validate.
- A future change that makes `start_sec` a Starshine declaration source would align local behavior with the official module-validation rule, but it must be deliberate because the current test suite and wiki record the divergence.
- For documentation, keep the focused validator page separate from the broader function/import/export/code section page: the section page owns the index-space model, while the validator page owns the `refs` bitmap, phase order, examples, and divergence.

## Follow-up questions

- Should Starshine align with the official start-as-declaration-source rule, or keep the current stricter local policy as an intentional compatibility choice?
- If start alignment lands, add one positive validator test for `start`-declared `ref.func`, retire the current negative regression, update invalid-generation strategy expectations if needed, and refresh the focused validator page.
- If future proposals add new module-level function-index carriers, update the declaration-source bitmap and this source snapshot rather than assuming exports/elements/globals/tables remain exhaustive.
