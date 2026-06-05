---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md
  - ../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - ../raw/wasm/2026-06-04-constant-expression-current-refresh.md
  - ../raw/wasm/2026-06-04-element-segment-current-refresh.md
  - ../raw/wasm/2026-06-04-exception-tag-current-refresh.md
  - ../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md
  - ../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md
  - ../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md
  - ../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md
  - ../raw/wasm/2026-05-20-resource-section-validation-refresh.md
  - ../raw/wasm/2026-05-20-constant-expression-validation-sources.md
  - ../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md
  - ../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md
  - ../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md
  - ../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md
  - ../raw/wasm/2026-05-13-data-element-and-datacount-sources.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/lib/types.mbt
related:
  - module-validation-phases.md
  - constant-expressions.md
  - import-export-and-external-type-matching.md
  - diagnostics-and-invalid-repro.md
  - data-count-and-code-data-indices.md
  - memory-table-address-widths.md
  - fuzz-hardening.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../binary/data-element-and-datacount-sections.md
  - ../wasm-custom-page-sizes-boundary.md
  - ../wasm-linear-memory-threads-boundary.md
  - ../wast/resource-declaration-authoring.md
  - ../wast/data-segment-authoring.md
  - ../wast/element-segment-authoring.md
  - ../wast/table-instruction-authoring.md
  - ../wast/memory-instruction-authoring.md
  - ../fuzzing/generator-coverage-ledger.md
---

# Resource Sections And Limits Validation

## Overview

Use this page for the validator-side contract behind **tables, memories, globals, tags, data segments, element segments, data-count, and their limits**. These resources are easy to confuse because they all live at module scope and many of them can be imported, defined locally, exported, named, and referenced by instructions or segments.

This page deliberately sits between three neighboring guides:

- [`module-validation-phases.md`](module-validation-phases.md) explains the full `validate_module_impl(...)` phase order.
- [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md) and [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md) explain binary section ids, core representations, and rewrite carriers.
- [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md), [`../wast/data-segment-authoring.md`](../wast/data-segment-authoring.md), and [`../wast/element-segment-authoring.md`](../wast/element-segment-authoring.md) explain text fixture shapes and current WAST gaps.

The current resource-section source bridge is [`../raw/wasm/2026-05-20-resource-section-validation-refresh.md`](../raw/wasm/2026-05-20-resource-section-validation-refresh.md). It rechecks WebAssembly Core validation, binary, and syntax pages plus Starshine's validator and invalid-fuzzer evidence. The 2026-06-05 Custom Page Sizes bridge in [`../raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md`](../raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md) makes an additional memory-type boundary explicit: Starshine validates address-width limits and local sharedness, but current `MemType` has no page-size field to validate or match. The 2026-06-04 import/export matching refresh in [`../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md`](../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md) keeps Core 3.0 memory matching as address-type-plus-limits and documents Starshine's `shared`-flag equality as a local/proposal extension. The focused living router for Threads/shared-memory claims is [`../wasm-linear-memory-threads-boundary.md`](../wasm-linear-memory-threads-boundary.md), backed by the 2026-06-04 linear-memory threads/shared-memory refresh in [`../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md): stable Core 3.0 is not the owner for Starshine's `shared` flag, while the threads proposal/draft is the right source for shared memories and the shared-memory maximum requirement. The 2026-06-04 constant-expression refresh in [`../raw/wasm/2026-06-04-constant-expression-current-refresh.md`](../raw/wasm/2026-06-04-constant-expression-current-refresh.md) sharpens the context split for initializer `global.get`: globals can see imports plus earlier globals, optional table initializers are imported-only, and Starshine's table phase runs before local globals. The 2026-06-04 element refresh in [`../raw/wasm/2026-06-04-element-segment-current-refresh.md`](../raw/wasm/2026-06-04-element-segment-current-refresh.md) confirms the mode-sensitive active/passive/declarative element validation split and keeps Starshine's WAST declarative-mode loss separate from validator/core support. The 2026-06-04 address-width refresh in [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md) confirms that accepting memory64/table64 limits at the resource layer is not enough to claim every memory/table instruction is address-width-complete; the focused living matrix is [`memory-table-address-widths.md`](memory-table-address-widths.md). The 2026-06-04 data/data-count refresh in [`../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md`](../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md) and focused recheck in [`../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md`](../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md) similarly separate Starshine's local bulk-memory-only missing-data-count precheck from the current official rule for any code-section data index; the reusable guide is [`data-count-and-code-data-indices.md`](data-count-and-code-data-indices.md). The 2026-06-04 exception refresh in [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md) separates Starshine's strict tag-section result check from current Core 3.0's broader tagtype validity and narrower EH-instruction empty-result requirements.

## Beginner Model

Think of resource validation as building several independent index spaces:

```text
imports first, then local definitions

TableIdx:  imported tables  | table section entries
MemIdx:    imported memories| memory section entries
GlobalIdx: imported globals | global section entries
TagIdx:    imported tags    | tag section entries
ElemIdx:   element section entries only
DataIdx:   data section entries only
```

A module can have valid bytes and still fail resource validation. Examples:

- a memory has `min > max`, or an i32 memory exceeds the `65536`-page cap;
- a shared memory is missing a maximum under Starshine's local threads/proposal-facing model;
- a table initializer uses a mutable `global.get`, which is not a valid constant expression;
- an active data segment names a missing memory or has an offset expression with the wrong address type;
- an active element segment's payload reference type does not match the target table's element type;
- a data-count section is present but does not equal the number of data segments; or
- a function body uses a code-section data-index instruction such as `memory.init`, `data.drop`, `array.new_data`, or `array.init_data` while the module has no data-count section.

## Shared Limit Primitive

[`ValidateMax for Limits`](../../../src/validate/validate.mbt) is the common range checker. For both `I32Limits(min, max?)` and `I64Limits(min, max?)`, validation requires:

1. `min <= family_max`; and
2. if `max` exists, then `min <= max <= family_max`.

Starshine then chooses the family maximum by resource kind:

| Resource | Local max passed to `ValidateMax` | Why it matters |
| --- | ---: | --- |
| i32 memory | `65536` pages | WebAssembly's ordinary memory32 page-count cap. |
| i64 memory | `18446744073709551615` pages | Starshine's local memory64 surface allows the full `UInt64` page-count range. |
| table | `4294967295` elements | The current table-type validator uses a 32-bit element-count cap for both `I32Limits` and `I64Limits`; instruction-side table64 address-width caveats are separate and documented in [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md). |

`Validate for MemType` adds the Starshine-local threads/proposal-facing shared-memory rule: when `shared=true`, either `I32Limits` or `I64Limits` must carry `Some(max)`. The binary decoder accepts shared-without-max flags so invalid fixtures can reach validation, but those modules must fail here. The invalid-fuzzer keeps both `shared-memory-without-max` and `shared-memory64-without-max` as `MemorySection` strategies in [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt).

Custom Page Sizes is not part of this local validation contract yet. The active proposal adds page size as a separate memory-type dimension, but [`src/lib/types.mbt`](../../../src/lib/types.mbt) models memory declarations as `MemType(Limits, shared)`, [`src/binary/decode.mbt`](../../../src/binary/decode.mbt) rejects unsupported memory-type flags before validation, and [`Validate for MemType`](../../../src/validate/validate.mbt) has no page-size rule. Use [`../wasm-custom-page-sizes-boundary.md`](../wasm-custom-page-sizes-boundary.md) for that future-port boundary.

## Section Validators

| Section / type | Starshine validator | Main rule | Common failure family |
| --- | --- | --- | --- |
| Table type and table section | `Validate for TableType`, `validate_table(...)`, `validate_tablesec(...)` | Reference type must validate, limits must be in range, and an optional core table initializer must be a constant expression of the table element type. Because Starshine validates tables before the local global section, table initializers can use immutable imported globals but not local defined globals. Accepted tables extend `Env.tables` incrementally. | `TableSection` |
| Memory type and memory section | `Validate for MemType`, `validate_memsec(...)` | Limits must be in range; shared memories require a maximum; accepted memories extend `Env.mems`. Shared-without-max binary flags are decode-accepted invalid-validation specimens, not valid module examples. Custom page size is not represented or validated locally yet. | `MemorySection` |
| Tag type and tag section | `Validate for TagType`, `validate_tagsec(...)` | Tag type index must resolve to a function type, parameter types must validate, and Starshine currently rejects non-empty result lists during import/tag-section validation. Current Core 3.0 tagtype validity is broader and puts the empty-result requirement on `throw` / `catch` / `catch_ref` use sites, so resultful tags are local validator-gap evidence. Accepted tags extend `Env.tags`. | `TagSection` |
| Global section | `validate_global(...)`, `validate_globalsec(...)` | Global type must validate; initializer must be a constant expression of the declared type. Globals are checked and appended one by one, so each initializer sees imports plus earlier globals only. | `GlobalSection` |
| Data section | `Validate for DataMode`, `Validate for Data`, `validate_datasec(...)` | Passive data has no parent; active data must name an existing memory and have a constant offset of that memory's address type. Accepted data segments extend `Env.datas`. | `DataSection` |
| Element section | `validate_elem_mode(...)`, `Validate for ElemKind`, `Validate for Elem`, `validate_elemsec(...)` | Payload function indices or expressions must validate; active elements must name an existing table, have a compatible element type, and have a constant offset of the selected table's address type. Passive/declarative modes have no parent table or offset; declarative still matters to declaration-source semantics outside runtime payload use. Accepted elements extend `Env.elems`. | `ElementSection` |
| Data-count | `validate_datacnt(...)`, `validate_bulk_memory_data_count_requirement(...)` | A present count must equal the number of data segments; separately, body uses of covered data-index instructions require the data-count section to exist. Current official WebAssembly requires data-count for any code-section data index, so `array.new_data` / `array.init_data` remain a documented local precheck gap; see [`data-count-and-code-data-indices.md`](data-count-and-code-data-indices.md). | `DataCountSection` or `FunctionBody`, depending on which rule fails |

The table and global initializer rows route through the same focused constant-expression contract as active segment offsets: [`constant-expressions.md`](constant-expressions.md). That page owns Starshine's local allow-list, immutable-`global.get` visibility, official-versus-local initializer differences, the imported-only optional table-initializer context, and active data/element offset examples.

## Concrete Shapes

### Incremental global visibility

```wat
(module
  (global $a i32 (i32.const 1))
  (global $b i32 (global.get $a)) ;; accepted locally: earlier immutable global
  ;; (global $bad i32 (global.get $later)) ;; rejected if $later is defined later
  (global $later i32 (i32.const 2)))
```

`validate_globalsec(...)` validates each global under the environment that contains only imports and previously accepted globals, then appends the new `GlobalType`. Reordering globals can therefore invalidate initializer expressions unless every `GlobalIdx` carrier and constant-expression visibility assumption is rechecked.

### Table initializer versus table element abbreviation

```wat
(module
  (func $f)
  (table $t funcref (elem $f)))
```

In Starshine WAST this table-attached `(elem ...)` abbreviation lowers to an **active element segment**, not to the optional core [`Table(TableType, Expr?)`](../../../src/lib/types.mbt) initializer field. The optional core table initializer is still real and validated by `validate_table(...)`, but it is checked before local globals in `validate_module_impl(...)`; use imported immutable globals or non-global reference constants there. Text fixtures that use the abbreviation should route through [`../wast/element-segment-authoring.md`](../wast/element-segment-authoring.md) and [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md).

### Active data offset address type

```wat
(module
  (memory 1)
  (data (i32.const 8) "abc"))
```

For an i32 memory, `Validate for DataMode` expects the active offset expression to produce `i32`. For a memory64 core/binary fixture, the selected memory's `Limits::addr_valtype()` changes that expected offset type to `i64`. This is separate from load/store `MemArg.offset`, which is an immediate byte offset documented in [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md).

### Active element type matching

```wat
(module
  (type $f (func))
  (func $target)
  (table 1 (ref null $f))
  (elem (i32.const 0) (ref null $f) (item (ref.func $target))))
```

`Validate for ElemKind` checks each payload expression against the element segment's declared reference type. Then `validate_elem_mode(...)` checks that the segment reference type matches the target table element type. If the selected table exists but expects an incompatible reference type, the failure is an `ElementSection` issue rather than a function-body stack error.

## Current Local Caveats

- **WAST table/memory declarations are narrower than core/binary.** Current WAST lowering uses `Limits::i32(...)` for table and memory declarations. Use direct core, binary, or generator fixtures for memory64/table64 declaration validation until the text surface is widened.
- **Shared memory is proposal/local-facing here.** Starshine rejects shared memories without maximum through `Validate for MemType`, matching the threads proposal's maximum requirement rather than stable Core 3.0 alone. Treat `0x02` / `0x06` shared-without-max memory-type bytes as decode-accepted invalid-validation fixtures.
- **Custom page size is proposal-only for Starshine today.** Address width and sharedness are represented locally; page size is not. Do not file a custom-page-size fixture as a resource-validator positive until `MemType`, binary decode/encode, external matching, generators, and WAST policy are widened together.
- **Table64 and memory64 instruction widths are not fully solved by resource validation.** A memory or table can have i64 limits while particular instruction validators still carry caveats. The current refreshed split is: memory `size`/`grow`, `memory.init`, `memory.copy`, `table.copy`, and `table.init` are aligned with the official address-width matrix; `memory.fill` length, `table.fill` length, ordinary table get/set/size/grow, and indirect-call table indices still have local `i32` assumptions. Keep [`memory-table-address-widths.md`](memory-table-address-widths.md), [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md), [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md), and [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md) linked when changing address-width behavior.
- **Declarative elements are core/binary-visible, but WAST lowering is still narrower.** Starshine core, binary, generator, and validator paths can represent declarative elements. Current high-level WAST lowering has a declarative-mode preservation gap, and official typed declarative element text is broader than the local `declare func` parser branch; the text-facing contract is [`../wast/element-segment-authoring.md`](../wast/element-segment-authoring.md).
- **Tag result-shape validation is locally stricter than current Core 3.0.** Starshine still rejects resultful tag imports and tag-section entries before instruction validation. If Starshine widens this later, the empty-result check must remain in `throw` / `catch` / `catch_ref` validation and the invalid-AST tag strategies should be reclassified deliberately. The fixture-placement matrix lives in [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md#tag-result-shape-split-declaration-versus-eh-use-site): declaration-only resultful tags are `validate.mbt` widening evidence, while resultful-tag EH uses should be `typecheck.mbt` instruction evidence after that widening.
- **Data-count equality is not the same as data-count requirement.** A bad `DataCntSec` length is a `DataCountSection` issue. A missing data-count section needed by `memory.init` / `data.drop` is reported against the body as `FunctionBody` with the relevant absolute `FuncIdx`. Current official Core 3.0 also covers `array.new_data` / `array.init_data`; Starshine typechecks those data indices but does not yet include them in the pre-code missing-data-count scan. Keep detailed changes routed through [`data-count-and-code-data-indices.md`](data-count-and-code-data-indices.md).

## Rewrite And Signoff Checklist

When a pass, generator, or fixture mutates resource sections, check all affected index carriers:

1. **Tables:** table imports/definitions, table initializers, element active modes, table instructions, `call_indirect` / `return_call_indirect`, table exports, and table name maps.
2. **Memories:** memory imports/definitions, active data modes, memory instructions, memory exports, memory name maps, and data-count dependencies for bulk-memory and data-backed GC array instructions.
3. **Globals:** global imports/definitions, global initializer visibility, `global.get` / `global.set`, exports, names, and pass-local global summaries.
4. **Tags:** tag imports/definitions, `throw`, `try_table` catches, exports, names, and exception-handler validation assumptions.
5. **Data and elements:** segment modes, payload function/reference/data indices, active offsets, `memory.init` / `data.drop`, `table.init` / `elem.drop`, GC aggregate data/element instructions, names, and declaration-source effects for `ref.func`.
6. **Diagnostics:** update invalid-AST strategy expected families when a validator rule moves between `DataCountSection`, `ElementSection`, `DataSection`, or `FunctionBody`.

Validation signoff should include the focused tests or fuzz lanes for the changed family. Existing anchors include `validate_invalid_ast_mutate_*` strategies in [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), limit-variant generator tests in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), and the broad gate map in [`../tooling/validation-gates.md`](../tooling/validation-gates.md).

## Sources

- Custom Page Sizes boundary refresh: [`../raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md`](../raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md), [`../wasm-custom-page-sizes-boundary.md`](../wasm-custom-page-sizes-boundary.md)
- Current linear-memory threads/shared-memory refresh: [`../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md)
- Current element-segment refresh: [`../raw/wasm/2026-06-04-element-segment-current-refresh.md`](../raw/wasm/2026-06-04-element-segment-current-refresh.md)
- Current exception/tag-result refresh: [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md)
- Current memory/table address-width refresh: [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md), [`memory-table-address-widths.md`](memory-table-address-widths.md)
- Current data/data-count refresh: [`../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md`](../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md)
- Focused data-count/data-index recheck: [`../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md`](../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md), [`data-count-and-code-data-indices.md`](data-count-and-code-data-indices.md)
- Source bridge: [`../raw/wasm/2026-05-20-resource-section-validation-refresh.md`](../raw/wasm/2026-05-20-resource-section-validation-refresh.md)
- Current constant-expression refresh: [`../raw/wasm/2026-06-04-constant-expression-current-refresh.md`](../raw/wasm/2026-06-04-constant-expression-current-refresh.md)
- Focused initializer contract: [`constant-expressions.md`](constant-expressions.md)
- Current import/export matching refresh: [`../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md`](../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md)
- Import/export and host-matching split: [`import-export-and-external-type-matching.md`](import-export-and-external-type-matching.md)
- Binary resource maps: [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md), [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md)
- WAST resource and segment maps: [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md), [`../wast/data-segment-authoring.md`](../wast/data-segment-authoring.md), [`../wast/element-segment-authoring.md`](../wast/element-segment-authoring.md)
- Starshine validator: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt)
- Invalid and valid generator evidence: [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt)
