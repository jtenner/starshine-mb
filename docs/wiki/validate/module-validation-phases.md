---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-13-module-validation-phase-sources.md
  - ../raw/wasm/2026-05-13-module-section-order-sources.md
  - ../raw/wasm/2026-05-13-ref-func-declaration-sources.md
  - ../raw/wasm/2026-05-20-start-section-validation-sources.md
  - ../raw/wasm/2026-05-19-validation-diagnostics-and-invalid-repro-sources.md
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../raw/wasm/2026-05-20-wast-parametric-select-sources.md
  - ../raw/wasm/2026-05-19-wast-reference-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-variable-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-memory-instruction-sources.md
  - ../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md
  - ../raw/wasm/2026-05-19-wast-resource-declaration-sources.md
  - ../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md
  - ../raw/wasm/2026-05-19-wast-call-and-function-sources.md
  - ../raw/wasm/2026-05-19-wast-gc-aggregate-instruction-sources.md
  - ../raw/wasm/2026-05-20-constant-expression-validation-sources.md
  - ../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md
  - ../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/typecheck_negative_tests.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate_trace/main.mbt
related:
  - ./constant-expressions.md
  - ./stack-polymorphism-and-bottom.md
  - ./import-export-and-external-type-matching.md
  - ./start-section.md
  - ./ref-func-declarations.md
  - ./diagnostics-and-invalid-repro.md
  - ./fuzz-hardening.md
  - ./trace-benchmark-baseline.md
  - ../binary/module-section-map.md
  - ../binary/custom-and-name-sections.md
  - ../binary/function-import-export-and-code-sections.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/data-element-and-datacount-sections.md
  - ../wast/control-flow-authoring.md
  - ../wast/parametric-instruction-authoring.md
  - ../wast/function-call-and-module-authoring.md
  - ../wast/reference-instruction-authoring.md
  - ../wast/gc-aggregate-instruction-authoring.md
  - ../wast/variable-instruction-authoring.md
  - ../wast/numeric-instruction-authoring.md
  - ../wast/memory-argument-authoring.md
  - ../wast/memory-instruction-authoring.md
  - ../wast/resource-declaration-authoring.md
  - ../wast/table-instruction-authoring.md
  - ../tooling/validation-gates.md
  - ../validation/moonbit-prove-strategy.md
---

# Module Validation Phases

## Overview

Starshine validates a module by building a WebAssembly validation context, checking cross-section invariants, and then typechecking every defined function body against that completed context. The official WebAssembly validation model is context-driven: module fields create entries such as types, functions, tables, memories, globals, tags, elements, data segments, exports, and declared function references, while instructions are checked with a typed operand stack and control-label stack. The source snapshot in [`../raw/wasm/2026-05-13-module-validation-phase-sources.md`](../raw/wasm/2026-05-13-module-validation-phase-sources.md) records the current official WebAssembly 3.0 validation sources plus the Starshine implementation evidence.

The local implementation is split deliberately:

- [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) owns whole-module phases, section validation, constant-expression checks, diagnostics, trace phases, invalid-generator feature ledgers, and cross-section checks.
- [`src/validate/env.mbt`](../../../src/validate/env.mbt) owns the validation context (`Env`): types, functions, resource index spaces, locals, labels, and return type.
- [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) owns expression and instruction stack typing; the byte-level instruction and immediate contract that feeds it is summarized in [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md).
- [`src/validate/match.mbt`](../../../src/validate/match.mbt) owns subtype/import/export matching, exact reference equivalence, and limit matching.
- [`src/validate_proof/`](../../../src/validate_proof/) owns the small proved helper kernel used by validation; proof policy is documented in [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md).

Use this page as the validator-side companion to the binary layout map in [`../binary/module-section-map.md`](../binary/module-section-map.md). The binary page explains wire-order and section ids; this page explains why Starshine validates in semantic dependency order.

## Beginner Model

Think of validation as three passes over the module shape:

```text
1. Build index spaces.
   imports + local definitions create FuncIdx/TableIdx/MemIdx/GlobalIdx/TagIdx spaces.

2. Check cross-section promises.
   funcsec and codesec lengths match, data-count matches data segments,
   start and exports point at valid definitions, ref.func uses are declared,
   structured name maps point at real entities.

3. Typecheck code bodies.
   each body gets params + locals + a function label + a return type;
   every instruction transforms a typed stack and must leave exactly the declared results.
```

Two practical consequences follow:

- A module can be locally stack-correct and still fail a cross-section phase. Example: a body containing `ref.func` for an existing function fails if no declaration source allows that first-class function reference.
- A module can have valid section ids and still fail semantic validation. Example: `func_sec` and `code_sec` are both present but have different lengths, or `memory.init` appears without a data-count section.

## Starshine Phase Order

[`validate_module_impl(...)`](../../../src/validate/validate.mbt) currently emits and executes these phases:

| Phase | What it checks/builds | Env or diagnostic effect | Main evidence |
| --- | --- | --- | --- |
| `typesec` | Validates recursive type groups, subtype references, descriptor metadata, exact-ref constraints, and appends normalized types. | Extends `Env.global_types` and `rec_stack`. | `validate_typesec`, `validate_rectype_and_extend`, descriptor tests in `validate.mbt`. |
| `importsec` | Validates imported extern types and extends imported-prefix index spaces; it does not match host-provided values during ordinary module validation. | Extends `funcs`, `func_type_idxs`, `tables`, `mems`, `globals`, and `tags`. | `validate_importsec`; focused import/export and matching guide in [`import-export-and-external-type-matching.md`](import-export-and-external-type-matching.md); imported-prefix section guide in [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md), with WAST function import syntax in [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md) and table/memory/global import syntax in [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md). |
| `funcsec` | Validates defined-function type indices. | Appends defined function signatures after imported functions. | `validate_funcsec`; code/function length tests. |
| `tablesec` | Validates table types and optional table initializer constant expressions. | Extends `tables` incrementally. | `validate_tablesec`, `validate_table`; the constant-expression contract is in [`constant-expressions.md`](constant-expressions.md), WAST table declarations and table element abbreviations are summarized in [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md), and instruction-side table use is in [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md). |
| `memsec` | Validates memory limits, memory64 address widths, and shared-memory maximum requirements. | Extends `mems` incrementally. | `validate_memsec`, `MemType` validation; WAST memory declaration caveats live in [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md), memory argument address-width effects in [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md), and runtime memory stack shapes plus the current `memory.fill` memory64 length caveat in [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md). |
| `tagsec` | Validates exception tag type indices and empty tag result types. | Extends `tags` incrementally. | `validate_tagsec`, `TagType` validation; WAST catch/throw authoring details live in [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md). |
| `globalsec` | Validates global types and constant initializers. Later globals see earlier globals only. | Extends `globals` incrementally. | `validate_globalsec`, `validate_const_expr`; the focused initializer and immutable-`global.get` rules live in [`constant-expressions.md`](constant-expressions.md), while WAST global declarations, imports, exports, and mutability syntax live in [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md). |
| `elemsec` | Validates passive/declarative/active element modes, element payload types, table targets, and constant offsets. | Extends `elems`. | `validate_elemsec`; segment guide in [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md). |
| `datasec` | Validates passive/active data modes, memory targets, and constant offsets. | Extends `datas`. | `validate_datasec`; WAST fixture guide in [`../wast/data-segment-authoring.md`](../wast/data-segment-authoring.md). |
| `datacnt` | Checks declared data-count equality with the data section. | Reports `DataCountSection` diagnostics. | `validate_datacnt`. |
| `datacnt_requirement` | Rejects bodies using `memory.init` / `data.drop` when the data-count section is absent. | Reports `FunctionBody` diagnostics with absolute imported-prefix function indices. | `validate_bulk_memory_data_count_requirement`; tests for `data count section required`. |
| `startsec` | Checks the optional start function exists and has no params/results. | Reports `StartSection`, carrying the target `FuncIdx` when present. | [`start-section.md`](start-section.md), `validate_startsec`, and start tests in `validate.mbt`. |
| `exportsec` | Checks export target indices and duplicate export names across all exported kinds. | Reports `ExportSection`. | [`import-export-and-external-type-matching.md`](import-export-and-external-type-matching.md), `validate_exportsec_unique`, and invalid-fuzzer duplicate-export / invalid-export-index strategies. |
| `ref_func_declarations` | Builds the declared-function bitmap, then checks every `ref.func` in globals/tables/elements/code against it. | Reports section-specific diagnostics, with body uses reported as `FunctionBody`. | [`./ref-func-declarations.md`](./ref-func-declarations.md). |
| `codesec` | Checks code/function section presence and length, maps defined body ordinals to absolute `FuncIdx`, validates the encoded non-parameter body locals against the function type's parameter prefix, and typechecks bodies decoded through the instruction/expression binary contract. | Reports `CodeSection` or `FunctionBody`. | `validate_codesec_diag`, `validate_func_body_against_functype`, `Typecheck` implementation, [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md), [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md). |
| `namesec` | Validates parsed structured name maps and rejects raw `name` custom sections stored outside `Module.name_sec`. | Reports `NameSection`. | `validate_name_sec`; [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md). |

This is semantic validation order, not wire order. For example, the binary data-count section is encoded before code and data, but Starshine validates data segments before the data-count equality check because the check needs the local `DataSec` length.

## Stack Typechecking Model

Instruction typechecking starts with a [`TcState`](../../../src/validate/typecheck.mbt) containing:

- the current `Env`;
- the operand stack as `Array[ValType]`;
- a `reachable` flag;
- an escape marker (`NoTcEscape`, `BranchTcEscape`, or `TerminalTcEscape`).

Every instruction consumes and produces typed stack values. Function calls check callee function/type/table indices plus parameter/result stack effects: direct `call` consumes the target function parameters and produces its results, while `call_indirect` also consumes a table element index and validates the selected table. The WAST fixture-facing call and function/import/export/start rules live in [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md). Variable instructions check the current function's local space or the module global space: `local.get` / `global.get` push declared types, `local.set` / mutable `global.set` consume them, and `local.tee` consumes then re-pushes the local value. The WAST fixture-facing version of those local/global rules lives in [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md). Scalar numeric instructions check arity and exact value types: constants push their scalar type, comparisons and integer tests produce `i32`, conversion/reinterpret/sign-extension opcodes have fixed source/result pairs, and saturating truncation keeps its own nontrapping runtime contract. The fixture-facing scalar numeric rules live in [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md). Memory instructions check selected memories/data segments and stack operand widths above their binary immediates: scalar loads/stores use `MemArg` plus address types, `memory.size` / `memory.grow` use the selected memory address type, and bulk-memory instructions add positional data-count/resource checks. `memory.init` keeps data-segment source and length as `i32`; mixed-width `memory.copy` uses the minimum address type for length; current Starshine still diverges from the official memory64 `memory.fill` length rule. Table instructions have a parallel but separate address-width surface: `table.copy` and `table.init` are partly width-aware, while current `table.fill` still types length as `i32` and several ordinary table ops still use `i32` assumptions. The fixture-facing split is [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md), [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md), and [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md). Reference instructions check nullability, `ref.func` existence/declaration, cast/test hierarchy compatibility, and reference-branch label payloads; the fixture-facing layer split and current ordinary `ref.test` / `ref.cast` / `br_on_*` WAST gap live in [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md). GC aggregate instructions check type indices, field/element shapes, packed signedness, storage mutability, array bounds/resource operands, and segment references; the fixture-facing split between supported struct/i31 WAST text and core/binary-only `struct.set` / `array.*` forms lives in [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md). String instructions check `stringref` production, packed `i8`/`i16` array storage, mutable destinations for encode helpers, and the local `StringRefsSec` literal boundary; fixture-facing rules live in [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md). Control instructions temporarily extend the label stack and validate branch payloads against label types: block/if labels use results, loop labels use parameters, `br_if` validates payload availability while leaving payload values on the not-taken path, and `br_table` requires all target labels to agree. The ordinary-control WAST fixture-facing version of those rules lives in [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md). Parametric instructions sit beside that control surface: `drop` consumes one value, untyped `select` consumes two mutually matching candidates plus an `i32` condition, and typed `select (result ...)` uses an explicit annotation; the local/spec caveats for untyped reference select and multi-value typed select live in [`../wast/parametric-instruction-authoring.md`](../wast/parametric-instruction-authoring.md). Tail calls validate against the current function return type and then make local continuation unreachable; WAST authoring details live in [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md). Function bodies additionally require an exact end stack: after the declared results are consumed, no extra concrete values may remain.

The most important beginner trap is unreachable-code stack polymorphism. When code is unreachable, Starshine can synthesize `BotValType` for missing operands, matching the official validation model. But values pushed after an unreachable point are still real values. The focused contract, examples, and regression map live in [`stack-polymorphism-and-bottom.md`](stack-polymorphism-and-bottom.md). Tests such as `validate_module rejects concrete stack junk after return inside block`, `validate_module rejects wrong concrete loop result after infinite inner loop`, and the end-of-body stack-shape diagnostics lock this boundary.

## Constant Expressions

[`constant-expressions.md`](constant-expressions.md) is now the focused contract for Starshine initializer and active-offset validation. In short, `validate_const_expr(...)` first applies a constant-instruction allow-list, then typechecks the expression with empty locals, empty labels, and no return type; the result must remain reachable, leave exactly one value, and match the expected type.

Use the focused page for the local/spec split around Starshine's broader constant-instruction list, immutable `global.get` visibility, `ref.func` and declaration-source interactions, active data/element offset typing, generator `[FZG]008` coverage, and invalid-AST strategies for mutable-global reads or non-constant offsets.

## Diagnostics And Trace Contract

Public validation returns a typed [`ValidationError`](../../../src/validate/validate.mbt) containing a [`ValidationDiagnostic`](../../../src/validate/validate.mbt), which carries:

- a `ValidationIssue` variant such as `TypeSection`, `ExportSection`, `CodeSection`, `NameSection`, or `FunctionBody`;
- an optional absolute `FuncIdx` for diagnostics tied to a function body or start target.

The focused diagnostic-family and invalid-repro contract lives in [`diagnostics-and-invalid-repro.md`](diagnostics-and-invalid-repro.md): use it when deciding whether a rejection should be `code` versus `function-body`, how stable invalid-AST ids map to `ValidationIssueFamily`, and how `--emit-invalid-repro` preserves expected/actual stage and family metadata.

`validate_module_with_trace(...)` uses the same implementation with tracing enabled. Trace output is intentionally stable enough for docs and benchmarks:

```text
pass[validate_module]:start declared_funcs=<n> code_bodies=<n>
phase=typesec:start
phase=typesec:done elapsed_ms=<n>
...
phase=ref_func_declarations:codesec:progress scanned=<n> total=<n> elapsed_ms=<n>
func[<ordinal>] helper_timing body_ms=<n> body_calls=<n>
hotspots f<ordinal>:body=<us>:locals=<n>:top=<n> ...
phase_totals typesec_ms=<n> typesec_calls=1 ...
helper_totals body_ms=<n> body_calls=<n>
pass[validate_module]:done elapsed_ms=<n>
```

The trace benchmark harness in [`src/validate_trace/main.mbt`](../../../src/validate_trace/main.mbt) and the durable baseline in [`./trace-benchmark-baseline.md`](./trace-benchmark-baseline.md) depend on phase names and totals. If a validator change renames, merges, or splits phases, update this page, the trace baseline, and any affected command docs together.

## Local Policy Extensions And Spec Divergences

| Surface | Official source model | Current Starshine behavior | What to keep visible |
| --- | --- | --- | --- |
| `ref.func` declared references | The official module `refs` set includes module-level declaration sources, including start. | Starshine computes a declaration bitmap from exports, global/table initializer `ref.func`, element payloads, and element expressions, but excludes `start_sec`. | Keep [`./start-section.md`](./start-section.md), [`./ref-func-declarations.md`](./ref-func-declarations.md), and the negative start regression aligned until a deliberate policy change lands. |
| Structured `name` section | Core custom sections are not normally semantic validation blockers; current WebAssembly 3.0 name-section subsections cover module/function/local/label/type/field/tag names. | Starshine rejects raw `name` custom sections in `custom_secs`, validates official maps, and also validates local table/memory/global/elem/data name maps against their index spaces. | Link [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md) when changing name metadata or pass rewrite rules; keep its 2026-05-20 official-versus-local subsection caveat visible. Tag-name rewrites should also follow [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md). |
| Data-count requirement diagnostics | Bulk-memory validation requires a data-count section when data-segment instructions appear. | Starshine has a distinct `datacnt_requirement` phase so missing data-count use in a body reports as `FunctionBody` with absolute `FuncIdx`. | Keep invalid-fuzzer expected family and imported-prefix tests updated. |
| Import declaration versus host matching | The official model separates module import declarations from runtime external-value matching at instantiation. | `validate_importsec(...)` validates the declared external types and extends local index spaces, while [`src/validate/match.mbt`](../../../src/validate/match.mbt) owns the reusable external-type compatibility relation; there is no active public host-linking contract here. | Keep [`import-export-and-external-type-matching.md`](import-export-and-external-type-matching.md) linked when changing import validation, future linker APIs, or `Match for ExternType`. |
| Memory64 `memory.fill` length | Official validation types `memory.fill` destination and length with the selected memory address type, while the byte value is `i32`. | Starshine currently types the destination as selected-memory `at` but still pops `len:i32`, so memory64 positive fixtures need a direct validator follow-up before they can be accepted locally. | Keep [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md) and [`../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md) linked when changing memory64 bulk-memory typing. |
| Table64 table-operation widths | Official validation uses the selected table address type for `table.get` / `set` / `size` / `grow`, both destination and length in `table.fill`, mixed-width `table.copy`, and active element offsets; `table.init` keeps element source and length as `i32`. | Starshine currently hard-codes `i32` for get/set/size/grow and indirect-call table indices, uses address widths for `table.copy` and `table.init` destination, and only widens the `table.fill` destination while keeping `len:i32`. | Keep [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md) and [`../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md`](../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md) linked when changing table64 instruction typing. |
| Local `StringRefsSec` | The checked official core sources used by the wiki do not define Starshine's local section id `14` as stable core WebAssembly. | Starshine validates `string.const`, validates supported array-backed string helpers, and carries local stringrefs roundtrip plumbing. | Do not describe `StringRefsSec` as stable core Wasm until upstream sources are refreshed; route fixture stack/storage details through [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md). |

## Mutating-Pass Checklist

After a pass changes module structure, ask these validator questions before relying on output validity:

1. Did every changed type, function, table, memory, global, tag, element, data, import, export, or name index get remapped in all carrier instructions and metadata?
2. Do `FuncSec` and `CodeSec` still agree on defined-function count after imports are accounted for?
3. If a pass deletes or rewrites functions, do surviving `ref.func` instructions still have declaration sources?
4. If a pass deletes data segments or bulk-memory instructions, is `DataCntSec` still correct, are data-index users repaired, and do WAST fixture expectations still match [`../wast/data-segment-authoring.md`](../wast/data-segment-authoring.md)?
5. If a pass rewrites globals, tables, elements, data, or GC aggregate instructions, are initializer expressions still constant under the current environment order, did table-instruction carriers follow the table rewrite checklist in [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md), and did aggregate type/data/element carriers follow [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md)?
6. If a pass rewrites bodies, do end-of-body result checks still pass with no extra stack values?
7. If a pass changes public or debug metadata, are structured name maps and raw name payloads cleared or repaired?
8. Does the invalid-fuzzer family expectation still match the user-visible diagnostic after the change?

The shared validation gate map lives in [`../tooling/validation-gates.md`](../tooling/validation-gates.md); pass-specific Binaryen parity evidence belongs in the affected pass dossier.

## Fuzzing, Proof, And Signoff

- Invalid AST fuzzing in [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt) has deterministic strategies for every current `ValidationIssue` family. Add or update a strategy when a new public validator family or major cross-section rule lands, following the stable-id and family guidance in [`diagnostics-and-invalid-repro.md`](diagnostics-and-invalid-repro.md).
- Public invalid-generation helpers in [`src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt) are downstream API surfaces; preserve stable ids when possible.
- Validator proof helpers live under [`src/validate_proof/`](../../../src/validate_proof/). Run `moon prove src/validate_proof` when those contracts change, and keep solver/tooling limitations explicit as described in [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md).
- For ordinary validator behavior changes, use focused `moon test src/validate` style loops when available, then the shared validation gate appropriate to the change. For trace/performance work, use [`./trace-benchmark-baseline.md`](./trace-benchmark-baseline.md) instead of committing local wall-time anecdotes.

## Sources

- Source snapshot: [`../raw/wasm/2026-05-13-module-validation-phase-sources.md`](../raw/wasm/2026-05-13-module-validation-phase-sources.md)
- Constant-expression source bridge: [`../raw/wasm/2026-05-20-constant-expression-validation-sources.md`](../raw/wasm/2026-05-20-constant-expression-validation-sources.md)
- Stack-polymorphism source bridge: [`../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md`](../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md)
- Import/export matching source bridge: [`../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md`](../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md)
- Section-order snapshot: [`../raw/wasm/2026-05-13-module-section-order-sources.md`](../raw/wasm/2026-05-13-module-section-order-sources.md)
- `ref.func` snapshot: [`../raw/wasm/2026-05-13-ref-func-declaration-sources.md`](../raw/wasm/2026-05-13-ref-func-declaration-sources.md)
- Diagnostics/repro snapshot: [`../raw/wasm/2026-05-19-validation-diagnostics-and-invalid-repro-sources.md`](../raw/wasm/2026-05-19-validation-diagnostics-and-invalid-repro-sources.md)
- Scalar numeric snapshot: [`../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md`](../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md)
- GC aggregate snapshot: [`../raw/wasm/2026-05-19-wast-gc-aggregate-instruction-sources.md`](../raw/wasm/2026-05-19-wast-gc-aggregate-instruction-sources.md)
- Table64 instruction-width correction: [`../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md`](../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md)
- Implementation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt)
- Invalid fuzzing and trace: [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`../../../src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt), [`../../../src/validate_trace/main.mbt`](../../../src/validate_trace/main.mbt)
- Related pages: [`./import-export-and-external-type-matching.md`](./import-export-and-external-type-matching.md), [`./ref-func-declarations.md`](./ref-func-declarations.md), [`./diagnostics-and-invalid-repro.md`](./diagnostics-and-invalid-repro.md), [`./fuzz-hardening.md`](./fuzz-hardening.md), [`./trace-benchmark-baseline.md`](./trace-benchmark-baseline.md), [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md), [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md), [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md), [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md), [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md), [`../tooling/validation-gates.md`](../tooling/validation-gates.md)
