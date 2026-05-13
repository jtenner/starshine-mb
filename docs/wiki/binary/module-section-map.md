---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/wasm/2026-05-13-module-section-order-sources.md
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/binary/tests.mbt
related:
  - custom-and-name-sections.md
  - function-import-export-and-code-sections.md
  - type-table-memory-global-tag-sections.md
  - data-element-and-datacount-sections.md
  - ../binaryen/passes/remove-unused-module-elements/index.md
  - ../tooling/validation-gates.md
---

# Binary Module Section Map

## Overview

This is the high-level map for Starshine's whole-module binary contract. It ties together the section-specific pages for custom/name metadata, functions/imports/exports/code, non-function resource sections, and segments so pass authors can answer one common question: "If I change this module field, what else must move with it?"

The official WebAssembly 3.0 binary format has two ordering rules that are easy to conflate:

1. **Standard sections appear in a fixed family order.** The stream begins with magic/version bytes, then standard sections appear at most once in the spec order, with custom sections allowed in gaps.
2. **Index spaces are semantic, not just section-local.** Imports and local definitions of the same kind share one index space; imported functions/tables/memories/globals/tags occupy the prefix before local definitions.

Starshine follows those rules in its core module representation and validation environment, while making two local choices explicit: non-`name` custom-section placement is normalized on encode, and `StringRefsSec` section id `14` is local/proposal-facing rather than a stable core WebAssembly section.

## Whole-Module Section Order

| Stream position | Section | Id | Starshine field | Canonical page | Notes |
| --- | --- | ---: | --- | --- | --- |
| Header | Magic + version | n/a | n/a | this page | [`Encode for Module`](../../../src/binary/encode.mbt#L1651-L1653) writes `00 61 73 6d 01 00 00 00`; [`decode_module_with_detail`](../../../src/binary/decode.mbt#L1235-L1242) requires the same bytes. |
| Any gap | Custom | `0` | `custom_secs`, `name_sec`, `raw_name_sec_payload` | [`custom-and-name-sections.md`](custom-and-name-sections.md) | Decode accepts custom sections before each standard family and at the tail; encode emits non-`name` custom sections first and the structured `name` section at the tail. |
| 1 | Type | `1` | `type_sec` | [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) | Defines the type index space used by signatures, blocks, casts, GC ops, tags, and resource types. |
| 2 | Import | `2` | `import_sec` | [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md), [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) | Imports extend function/table/memory/global/tag index spaces before local definition sections. |
| 3 | Function declarations | `3` | `func_sec` | [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md) | One type index per defined function; imported functions are excluded. |
| 4 | Table | `4` | `table_sec` | [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) | Local table definitions after table imports; optional table initializer expressions are preserved. |
| 5 | Memory | `5` | `mem_sec` | [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) | Local memory definitions after memory imports; shared memories need maxima in Starshine validation. |
| 6 | Tag | `13` | `tag_sec` | [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) | Post-MVP section id, but Starshine decodes/encodes it before globals to match the current core spec order. |
| 7 | Local stringrefs | local `14` | `stringrefs_sec` | [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) | Local literal pool used by `string.const` binary round trips; not a stable core section in the checked official sources. |
| 8 | Global | `6` | `global_sec` | [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) | Local globals validate incrementally, so earlier globals are visible to later initializers but not vice versa. |
| 9 | Export | `7` | `export_sec` | [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md) | Export names must be unique and indices must resolve in their target spaces. |
| 10 | Start | `8` | `start_sec` | [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md) | Target function must exist and have no params/results. |
| 11 | Element | `9` | `elem_sec` | [`data-element-and-datacount-sections.md`](data-element-and-datacount-sections.md) | Table-initialization resources plus passive/declarative element pools. |
| 12 | Data count | `12` | `data_cnt_sec` | [`data-element-and-datacount-sections.md`](data-element-and-datacount-sections.md) | Appears before code so `memory.init` / `data.drop` immediates can be validated before the data section payload is reached. |
| 13 | Code | `10` | `code_sec` | [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md) | Body count must match defined-function declaration count, and body ordinal maps to absolute `FuncIdx(imported_func_count + ordinal)`. |
| 14 | Data | `11` | `data_sec` | [`data-element-and-datacount-sections.md`](data-element-and-datacount-sections.md) | Active/passive byte payloads for memory initialization and bulk-memory use. |

This table is grounded in the primary-source snapshot [`../raw/wasm/2026-05-13-module-section-order-sources.md`](../raw/wasm/2026-05-13-module-section-order-sources.md) and the local whole-module encode/decode paths in [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) and [`src/binary/decode.mbt`](../../../src/binary/decode.mbt).

## Starshine Encode, Decode, And Validation Flow

### Decode

[`decode_module_with_detail`](../../../src/binary/decode.mbt#L1225-L1552) walks the standard-section order and calls [`decode_custom_sections_with_detail`](../../../src/binary/decode.mbt#L1153-L1202) before every standard section plus the tail. Non-`name` custom sections are accumulated in `custom_secs`; the first `name` custom section is parsed into `NameSec` and preserved as `raw_name_sec_payload`; a second `name` section is rejected.

A decode-time `stringrefs` context is installed only around the sections that can contain `string.const` immediates in Starshine's representation: globals, element/data-count/code/data tail handling, and especially code-body expressions. The result is a structured [`Module`](../../../src/lib/types.mbt#L351-L368), not a byte-for-byte placement model.

### Encode

[`Encode for Module`](../../../src/binary/encode.mbt#L1651-L1727) always emits a canonical layout:

1. magic/version;
2. all non-`name` `custom_secs` before standard sections;
3. standard sections in Starshine's current order: type, import, function, table, memory, tag, local stringrefs, global, export, start, element, data-count, code, data;
4. the structured or raw-preserved `name` custom section at the tail.

That means ordinary round trips preserve custom-section payloads and structured name data, but they do **not** preserve exact original custom-section placement. If a future consumer needs exact placement, the representation needs a placement-bearing custom-section model rather than a pass-local workaround.

### Validation

[`validate_module_impl`](../../../src/validate/validate.mbt#L2895-L3266) builds the module environment in dependency order:

```text
types
imports
function declarations
tables, memories, tags, globals
elements, data
data-count equality and bulk-memory requirement
start
exports
ref.func declaration checks
code bodies
name section
```

This order is not identical to wire order in every detail, because validation needs semantic dependencies rather than byte layout. For example, Starshine validates `data_sec` before the `data_cnt_sec` equality check even though the binary data-count section is encoded before code and data. The key invariant is that every index space and section-level precondition needed by function-body validation exists before `code_sec` is typechecked.

## Index-Space Checklist For Mutating Passes

Use this checklist before implementing or reviewing any pass that deletes, reorders, merges, appends, or retags module-level entities.

| Changed thing | Must repair or revalidate |
| --- | --- |
| Type definitions | Function signatures, block types, table/global/tag types, imports/exports, GC instructions, casts, element types, type names, and any pass-local type caches. |
| Function imports/definitions | `func_sec` / `code_sec` parallelism, direct calls, tail calls, `ref.func`, start, exports, element payloads, global/table initializer expressions, function names, local/label names keyed under retained functions, and `func_annotation_sec` when present from WAST lowering. |
| Tables | `TableIdx` instructions, `call_indirect` / `return_call_indirect`, active element modes, imports/exports, table names, and optional table initializer expressions. |
| Memories | `MemArg` memory operands, memory management instructions, active data modes, imports/exports, memory names, and memory64/lowering assumptions. |
| Globals | `global.get` / `global.set`, global initializer expressions, imports/exports, global names, global summaries, and constant-propagation caches. |
| Tags | `throw`, catch clauses, imports/exports, tag names, and exception validation assumptions. |
| Elements or data segments | Segment indices, active parent table/memory indices, `table.init` / `elem.drop` / `memory.init` / `data.drop`, name maps, data-count equality, and startup-trap policy. |
| Custom/name metadata | Clear `raw_name_sec_payload` after structured rewrites, update affected name maps, preserve unrelated non-`name` custom payloads unless the pass explicitly owns a stripping policy. |
| Local `stringrefs` pool | Keep `StringRefsSec`, `Instruction::StringConst`, and string pass assumptions consistent; do not describe id `14` as stable core Wasm without refreshing upstream sources. |

The pass dossiers most sensitive to this checklist include [`remove-unused-module-elements`](../binaryen/passes/remove-unused-module-elements/index.md), [`duplicate-function-elimination`](../binaryen/passes/duplicate-function-elimination/index.md), [`duplicate-import-elimination`](../binaryen/passes/duplicate-import-elimination/index.md), [`reorder-functions`](../binaryen/passes/reorder-functions/index.md), [`reorder-globals`](../binaryen/passes/reorder-globals/index.md), [`remove-unused-types`](../binaryen/passes/remove-unused-types/index.md), [`reorder-types`](../binaryen/passes/reorder-types/index.md), and [`memory-packing`](../binaryen/passes/memory-packing/index.md).

## Edge Cases And Invariants

- **Section id is not always sort key.** Data-count id `12` appears before code id `10`, and tag id `13` appears before global id `6` in Starshine's current spec-aligned order.
- **Presence and emptiness are separate.** Some empty optional sections can be semantically equivalent to absence, but pass authors should not rely on byte-level preservation of empty sections unless tests say so.
- **Imports are not duplicated in definition sections.** `FuncSec`, `TableSec`, `MemSec`, `GlobalSec`, and `TagSec` contain local definitions only; the validation environment holds imported prefixes plus local suffixes.
- **Code bodies are defined-function bodies only.** `CodeSec` ordinal `0` is not always `FuncIdx(0)`; imports shift absolute function indices.
- **Custom-section placement is normalized.** Non-`name` custom payloads survive, but exact gap placement does not.
- **Structured `name` validation is stronger than core custom-section semantics.** Starshine validates parsed name maps because they are used for diagnostics, printing, and pass rewrite checks.
- **`func_annotation_sec` is a Starshine/WAST-side metadata surface.** It is present in [`Module`](../../../src/lib/types.mbt#L351-L368) and maintained by some module passes, but it is not part of the core binary section stream described by this page.

## Sources

- Primary-source snapshot: [`../raw/wasm/2026-05-13-module-section-order-sources.md`](../raw/wasm/2026-05-13-module-section-order-sources.md)
- Core module representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
- Binary decode/encode: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Validation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
- Section-specific pages: [`custom-and-name-sections.md`](custom-and-name-sections.md), [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md), [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md), [`data-element-and-datacount-sections.md`](data-element-and-datacount-sections.md)
