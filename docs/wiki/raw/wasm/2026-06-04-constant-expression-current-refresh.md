# WebAssembly Constant-Expression Current Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core 3.0 validation sources plus Starshine validator/generator/invalid-fuzzer evidence
- Primary sources:
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/valid/instructions.html#constant-expressions>
  - WebAssembly Core Specification, `Syntax / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- Repository evidence checked:
  - `src/validate/validate.mbt`
  - `src/validate/typecheck.mbt`
  - `src/validate/gen_valid.mbt`
  - `src/validate/invalid_fuzzer.mbt`
  - `docs/wiki/validate/constant-expressions.md`
  - `docs/wiki/wast/variable-instruction-authoring.md`
  - `docs/wiki/validate/resource-sections-and-limits.md`
  - `docs/wiki/binary/type-table-memory-global-tag-sections.md`
  - `docs/wiki/wast/gc-aggregate-instruction-authoring.md`

## Durable takeaways

- Current official module validation still treats global initializers, table initializers, active data offsets, active element offsets, and element payload expressions as constant-expression contexts that must also type-match their target value/reference/address type.
- Current official global-section validation remains incremental: each global is checked under a context extended by previously accepted globals, so a global initializer can read imported immutable globals and earlier immutable defined globals but not later siblings.
- Current official table-validation text still has the narrower `global.get` context note: table initializer constant expressions may refer only to imported globals. This is easy to overgeneralize from the global-initializer rule.
- Current official constant-expression instruction validation still uses an instruction-level constant predicate plus ordinary expression validation, and still warns that the instruction list may grow in later WebAssembly versions.
- The current official constant-instruction family still includes scalar/vector constants, `ref.null`, `ref.i31`, `ref.func`, `struct.new`, `struct.new_default`, `array.new`, `array.new_default`, `array.new_fixed`, `any.convert_extern`, `extern.convert_any`, immutable `global.get`, and integer `i32`/`i64` `add`/`sub`/`mul`.

## Starshine reconciliation

- `validate_const_instr(...)` remains the local allow-list gate. It admits the official scalar/reference/core subset above, but it is broader for many scalar integer/float/comparison/conversion/reinterpret/sign-extension/saturating-truncation operations, `ref.eq`, `ref.as_non_null`, `string.const`, and local descriptor constructors.
- Starshine remains narrower than current Core 3.0 for array constructors in constant expressions: `ArrayNew`, `ArrayNewDefault`, and `ArrayNewFixed` exist in core/typechecking, but are not currently accepted by `validate_const_instr(...)`.
- `validate_const_expr(...)` still typechecks constant expressions with empty locals, labels, and return type, then requires a reachable final state, exactly one stack value, and `Match::matches(...)` against the expected type.
- Starshine's global initializer visibility matches the incremental model for imported plus earlier immutable globals because `validate_globalsec(...)` validates and appends globals one by one.
- Starshine's optional core table initializers are validated before the local global section in `validate_module_impl(...)`. In practice, a table initializer can read immutable imported globals, but cannot read locally defined globals because those definitions have not been appended yet. This aligns with the current official imported-only table note, even though the local `validate_const_instr(...)` helper itself only asks whether the selected global exists in the current environment and is immutable.
- Starshine validates element and data sections after globals, so active offsets and element payload constant expressions can see already accepted local immutable globals as well as imports, subject to the same local allow-list and type matching.
- Stable invalid-AST strategies keep mutable `global.get` failures visible for global initializers and table initializers, while GenValid records context/op-family coverage for imported immutable `global.get` and other widened initializer families.

## Supersession and uncertainty

- This refresh supersedes the source-date portion of `docs/wiki/raw/wasm/2026-05-20-constant-expression-validation-sources.md`; the older source bridge remains useful for the first detailed local-code audit.
- No teaching-relevant official drift was found in the current 2026-06-03 pages versus the 2026-05-20 bridge for the constant-expression instruction family, incremental global validation, table initializer imported-only `global.get` note, active data/element offset typing, or element-expression constant requirement.
- The important wiki correction from this refresh is not a spec drift but a routing/wording fix: do not group table initializers with later-validated data/element/global contexts when explaining which local defined globals a constant-expression `global.get` can see.
