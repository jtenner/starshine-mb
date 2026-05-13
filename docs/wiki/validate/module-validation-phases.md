---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/wasm/2026-05-13-module-validation-phase-sources.md
  - ../raw/wasm/2026-05-13-module-section-order-sources.md
  - ../raw/wasm/2026-05-13-ref-func-declaration-sources.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate_trace/main.mbt
related:
  - ./ref-func-declarations.md
  - ./fuzz-hardening.md
  - ./trace-benchmark-baseline.md
  - ../binary/module-section-map.md
  - ../binary/custom-and-name-sections.md
  - ../binary/function-import-export-and-code-sections.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/data-element-and-datacount-sections.md
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
| `importsec` | Validates imported extern types and extends imported-prefix index spaces. | Extends `funcs`, `func_type_idxs`, `tables`, `mems`, `globals`, and `tags`. | `validate_importsec`; imported-prefix section guide in [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md). |
| `funcsec` | Validates defined-function type indices. | Appends defined function signatures after imported functions. | `validate_funcsec`; code/function length tests. |
| `tablesec` | Validates table types and optional table initializer constant expressions. | Extends `tables` incrementally. | `validate_tablesec`, `validate_table`. |
| `memsec` | Validates memory limits, memory64 address widths, and shared-memory maximum requirements. | Extends `mems` incrementally. | `validate_memsec`, `MemType` validation. |
| `tagsec` | Validates exception tag type indices and empty tag result types. | Extends `tags` incrementally. | `validate_tagsec`, `TagType` validation. |
| `globalsec` | Validates global types and constant initializers. Later globals see earlier globals only. | Extends `globals` incrementally. | `validate_globalsec`, `validate_const_expr`. |
| `elemsec` | Validates passive/declarative/active element modes, element payload types, table targets, and constant offsets. | Extends `elems`. | `validate_elemsec`; segment guide in [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md). |
| `datasec` | Validates passive/active data modes, memory targets, and constant offsets. | Extends `datas`. | `validate_datasec`. |
| `datacnt` | Checks declared data-count equality with the data section. | Reports `DataCountSection` diagnostics. | `validate_datacnt`. |
| `datacnt_requirement` | Rejects bodies using `memory.init` / `data.drop` when the data-count section is absent. | Reports `FunctionBody` diagnostics with absolute imported-prefix function indices. | `validate_bulk_memory_data_count_requirement`; tests for `data count section required`. |
| `startsec` | Checks the optional start function exists and has no params/results. | Reports `StartSection`, carrying the target `FuncIdx` when present. | `validate_startsec`; start tests in `validate.mbt`. |
| `exportsec` | Checks export target indices and duplicate export names. | Reports `ExportSection`. | `validate_exportsec_unique`; invalid-fuzzer duplicate-export strategy. |
| `ref_func_declarations` | Builds the declared-function bitmap, then checks every `ref.func` in globals/tables/elements/code against it. | Reports section-specific diagnostics, with body uses reported as `FunctionBody`. | [`./ref-func-declarations.md`](./ref-func-declarations.md). |
| `codesec` | Checks code/function section presence and length, maps defined body ordinals to absolute `FuncIdx`, validates locals, and typechecks bodies decoded through the instruction/expression binary contract. | Reports `CodeSection` or `FunctionBody`. | `validate_codesec_diag`, `validate_func_body_against_functype`, `Typecheck` implementation, [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md). |
| `namesec` | Validates parsed structured name maps and rejects raw `name` custom sections stored outside `Module.name_sec`. | Reports `NameSection`. | `validate_name_sec`; [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md). |

This is semantic validation order, not wire order. For example, the binary data-count section is encoded before code and data, but Starshine validates data segments before the data-count equality check because the check needs the local `DataSec` length.

## Stack Typechecking Model

Instruction typechecking starts with a [`TcState`](../../../src/validate/typecheck.mbt) containing:

- the current `Env`;
- the operand stack as `Array[ValType]`;
- a `reachable` flag;
- an escape marker (`NoTcEscape`, `BranchTcEscape`, or `TerminalTcEscape`).

Every instruction consumes and produces typed stack values. Control instructions temporarily extend the label stack and validate branch payloads against label result types. Function bodies additionally require an exact end stack: after the declared results are consumed, no extra concrete values may remain.

The most important beginner trap is unreachable-code stack polymorphism. When code is unreachable, Starshine can synthesize `BotValType` for missing operands, matching the official validation model. But values pushed after an unreachable point are still real values. Tests such as `validate_module rejects concrete stack junk after return inside block`, `validate_module rejects wrong concrete loop result after infinite inner loop`, and the end-of-body stack-shape diagnostics lock this boundary.

## Constant Expressions

`validate_const_expr(...)` enforces a stricter gate before using ordinary typechecking:

1. each instruction must be allowed in a constant-expression context;
2. the expression is typechecked with empty locals, empty labels, and no return type;
3. the expression must remain reachable;
4. it must leave exactly one value;
5. that value must match the expected type.

Starshine allows current extended constant-expression families such as immutable `global.get`, arithmetic over constants, `ref.null`, `ref.func`, `string.const`, and selected GC constructors used by local fixtures. It rejects mutable-global reads, non-constant offsets, unreachable constant expressions, wrong result counts, and wrong result types. Segment pages such as [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md) and resource-section pages such as [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md) should point here when explaining why initializer order matters.

## Diagnostics And Trace Contract

Public validation returns a typed [`ValidationError`](../../../src/validate/validate.mbt) containing a [`ValidationDiagnostic`](../../../src/validate/validate.mbt), which carries:

- a `ValidationIssue` family such as `TypeSection`, `ExportSection`, `CodeSection`, `NameSection`, or `FunctionBody`;
- an optional absolute `FuncIdx` for diagnostics tied to a function body or start target.

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
| `ref.func` declared references | The official module `refs` set includes module-level declaration sources, including start. | Starshine computes a declaration bitmap from exports, global/table initializer `ref.func`, element payloads, and element expressions, but excludes `start_sec`. | Keep [`./ref-func-declarations.md`](./ref-func-declarations.md) and the negative start regression aligned until a deliberate policy change lands. |
| Structured `name` section | Core custom sections are not normally semantic validation blockers. | Starshine rejects raw `name` custom sections in `custom_secs` and validates structured name maps against function/local/label/type/table/memory/global/elem/data/field/tag bounds. | Link [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md) when changing name metadata or pass rewrite rules. |
| Data-count requirement diagnostics | Bulk-memory validation requires a data-count section when data-segment instructions appear. | Starshine has a distinct `datacnt_requirement` phase so missing data-count use in a body reports as `FunctionBody` with absolute `FuncIdx`. | Keep invalid-fuzzer expected family and imported-prefix tests updated. |
| Local `StringRefsSec` | The checked official core sources used by the wiki do not define Starshine's local section id `14` as stable core WebAssembly. | Starshine validates `string.const` and carries local stringrefs roundtrip plumbing. | Do not describe `StringRefsSec` as stable core Wasm until upstream sources are refreshed. |

## Mutating-Pass Checklist

After a pass changes module structure, ask these validator questions before relying on output validity:

1. Did every changed type, function, table, memory, global, tag, element, data, or name index get remapped in all carrier instructions and metadata?
2. Do `FuncSec` and `CodeSec` still agree on defined-function count after imports are accounted for?
3. If a pass deletes or rewrites functions, do surviving `ref.func` instructions still have declaration sources?
4. If a pass deletes data segments or bulk-memory instructions, is `DataCntSec` still correct and still present only when required?
5. If a pass rewrites globals, tables, elements, or data, are initializer expressions still constant under the current environment order?
6. If a pass rewrites bodies, do end-of-body result checks still pass with no extra stack values?
7. If a pass changes public or debug metadata, are structured name maps and raw name payloads cleared or repaired?
8. Does the invalid-fuzzer family expectation still match the user-visible diagnostic after the change?

The shared validation gate map lives in [`../tooling/validation-gates.md`](../tooling/validation-gates.md); pass-specific Binaryen parity evidence belongs in the affected pass dossier.

## Fuzzing, Proof, And Signoff

- Invalid AST fuzzing in [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt) has deterministic strategies for every current `ValidationIssue` family. Add or update a strategy when a new public validator family or major cross-section rule lands.
- Public invalid-generation helpers in [`src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt) are downstream API surfaces; preserve stable ids when possible.
- Validator proof helpers live under [`src/validate_proof/`](../../../src/validate_proof/). Run `moon prove src/validate_proof` when those contracts change, and keep solver/tooling limitations explicit as described in [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md).
- For ordinary validator behavior changes, use focused `moon test src/validate` style loops when available, then the shared validation gate appropriate to the change. For trace/performance work, use [`./trace-benchmark-baseline.md`](./trace-benchmark-baseline.md) instead of committing local wall-time anecdotes.

## Sources

- Source snapshot: [`../raw/wasm/2026-05-13-module-validation-phase-sources.md`](../raw/wasm/2026-05-13-module-validation-phase-sources.md)
- Section-order snapshot: [`../raw/wasm/2026-05-13-module-section-order-sources.md`](../raw/wasm/2026-05-13-module-section-order-sources.md)
- `ref.func` snapshot: [`../raw/wasm/2026-05-13-ref-func-declaration-sources.md`](../raw/wasm/2026-05-13-ref-func-declaration-sources.md)
- Implementation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt)
- Invalid fuzzing and trace: [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`../../../src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt), [`../../../src/validate_trace/main.mbt`](../../../src/validate_trace/main.mbt)
- Related pages: [`./ref-func-declarations.md`](./ref-func-declarations.md), [`./fuzz-hardening.md`](./fuzz-hardening.md), [`./trace-benchmark-baseline.md`](./trace-benchmark-baseline.md), [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md), [`../tooling/validation-gates.md`](../tooling/validation-gates.md)
