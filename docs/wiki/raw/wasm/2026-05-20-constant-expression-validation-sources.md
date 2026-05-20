# 2026-05-20 constant-expression validation sources

Purpose: primary-source and repository-source bridge for the living Starshine wiki page [`../../validate/constant-expressions.md`](../../validate/constant-expressions.md).

## External primary sources checked

- WebAssembly 3.0 module validation, current generated docs dated 2026-05-14 and rechecked during this 2026-05-20 run: <https://webassembly.github.io/spec/core/valid/modules.html>
  - Global definitions validate their initializer expression against the declared value type and require that expression to be constant.
  - Global validation is incremental: each later global is checked under a context extended by earlier globals.
  - Table definitions with initializer expressions validate that initializer against the table reference type and require it to be constant.
  - Active data modes require the selected memory to exist and require the offset expression to be a constant expression of the selected memory address type.
  - Element segments require each element expression to be constant at the element type, and active element modes require a constant offset expression of the selected table address type.
- WebAssembly 3.0 instruction validation, current generated docs dated 2026-05-14 and rechecked during this 2026-05-20 run: <https://webassembly.github.io/spec/core/valid/instructions.html#constant-expressions>
  - Constant expressions are ordinary valid expressions plus an instruction-level constant predicate.
  - The current official constant-instruction list includes numeric/vector constants, `ref.null`, `ref.i31`, `ref.func`, `struct.new`, `struct.new_default`, `array.new`, `array.new_default`, `array.new_fixed`, `any.convert_extern`, `extern.convert_any`, immutable `global.get`, and integer `i32`/`i64` `add`/`sub`/`mul`.
  - The official note says `global.get` visibility is context-constrained: globals can refer to imported or previous globals, while table constant expressions may only refer to imported globals in the current spec text.
  - The same page warns that the definition may grow in future WebAssembly versions.

## Local repository evidence checked

- [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt)
  - `validate_const_instr(...)` owns Starshine's constant-instruction allow-list.
  - `validate_const_expr(...)` first rejects non-constant instructions, then typechecks with empty locals, empty labels, no return type, requires reachability, requires exactly one final value, and matches it against the expected type.
  - The reviewed local allow-list does not currently include `ArrayNew`, `ArrayNewDefault`, or `ArrayNewFixed`, even though those instructions exist in core/typechecking and are listed by the current official constant-expression predicate.
  - `validate_globalsec(...)` validates globals incrementally under an environment containing imports plus earlier defined globals.
  - `Validate for DataMode` and `validate_elem_mode(...)` use selected memory/table address types for active offsets.
  - `validate_table(...)`, `validate_global(...)`, `ElemKind` validation, and `DataMode` validation are the main call sites.
  - Tests around lines 8095-8480 lock `ref.func` declaration sources, imported/earlier immutable `global.get`, arithmetic const expressions, mutable-global rejection, table-initializer immutable-global behavior, non-constant data offsets, and `ref.null` initializers. The descriptor test just after that locks local `struct.new_default_desc` initializer support.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)
  - `allow_const_expr_variants` controls generator widening for immutable `global.get`, `ref.func`, safe GC constructor initializers, table initializers, and active segment offsets.
  - `GenValidFeatureKey::ConstExprVariants` records coverage of widened constant-expression forms.
- [`../../../../src/validate/invalid_fuzzer.mbt`](../../../../src/validate/invalid_fuzzer.mbt)
  - Stable invalid-AST strategies include `mutable-global-get-in-const-init`, `mutable-global-get-in-table-init`, `non-constant-data-offset`, and `non-constant-elem-offset`.
- Related local wiki pages checked for cross-links: [`../../validate/module-validation-phases.md`](../../validate/module-validation-phases.md), [`../../wast/resource-declaration-authoring.md`](../../wast/resource-declaration-authoring.md), [`../../wast/variable-instruction-authoring.md`](../../wast/variable-instruction-authoring.md), [`../../wast/numeric-instruction-authoring.md`](../../wast/numeric-instruction-authoring.md), [`../../wast/data-segment-authoring.md`](../../wast/data-segment-authoring.md), [`../../wast/element-segment-authoring.md`](../../wast/element-segment-authoring.md), [`../../binary/type-table-memory-global-tag-sections.md`](../../binary/type-table-memory-global-tag-sections.md), [`../../binary/data-element-and-datacount-sections.md`](../../binary/data-element-and-datacount-sections.md), and [`../../fuzzing/generator-coverage-ledger.md`](../../fuzzing/generator-coverage-ledger.md).

## Reconciliation notes

- Starshine's current constant-expression gate is deliberately broader than the current official WebAssembly 3.0 list in several places: it admits many scalar numeric comparisons, conversions, floating-point ops, saturating truncations, `ref.eq`, `ref.as_non_null`, `string.const`, and local custom-descriptor struct constructors.
- Starshine is also narrower than the current official WebAssembly 3.0 list for array constructors in constant expressions: `ArrayNew`, `ArrayNewDefault`, and `ArrayNewFixed` are typechecked as ordinary instructions but are not accepted by `validate_const_instr(...)` today.
- Starshine's global visibility rule for immutable `global.get` is also broader than the current official table-initializer note: local tests accept table initializer `global.get` from an imported immutable reference global, and `validate_const_instr(...)` relies on the current environment rather than a table-only imported-global subcontext.
- Do not silently teach local acceptances or local omissions as portable WebAssembly. The living page marks them as Starshine-local behavior and keeps pass/generator signoff guidance separate from upstream portability claims.
