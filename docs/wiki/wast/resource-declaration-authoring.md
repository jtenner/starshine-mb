---
kind: concept
status: supported
last_reviewed: 2026-05-19
sources:
  - ../raw/wasm/2026-05-19-wast-resource-declaration-sources.md
  - ../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/wast/arbitrary.mbt
related:
  - index.md
  - function-call-and-module-authoring.md
  - table-instruction-authoring.md
  - memory-instruction-authoring.md
  - memory-argument-authoring.md
  - data-segment-authoring.md
  - variable-instruction-authoring.md
  - element-segment-authoring.md
  - exception-tag-authoring.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../binary/data-element-and-datacount-sections.md
  - ../validate/module-validation-phases.md
  - ../validate/import-export-and-external-type-matching.md
  - ../fuzzing/generator-coverage-ledger.md
---

# WAST Resource Declaration Authoring

## Overview

Use this page when writing or debugging WAST module fields that **declare table, memory, or global resources**:

- explicit imports: `(import "m" "n" (table ...))`, `(import "m" "n" (memory ...))`, and `(import "m" "n" (global ...))`;
- local definitions: `(table ...)`, `(memory ...)`, and `(global ...)`;
- inline exports and explicit exports of those resources;
- table element abbreviations attached to a table field; and
- global mutability plus initializer expressions.

This page deliberately does **not** own runtime operations or segment payloads on those resources. Use [`table-instruction-authoring.md`](table-instruction-authoring.md) for `table.get` / `table.init` / `call_indirect`, [`memory-instruction-authoring.md`](memory-instruction-authoring.md) for loads, stores, `memory.copy`, and `memory.init`, [`memory-argument-authoring.md`](memory-argument-authoring.md) for `offset=` / `align=`, [`data-segment-authoring.md`](data-segment-authoring.md) for `(data ...)` fields and the current inline memory-data abbreviation caveat, and [`variable-instruction-authoring.md`](variable-instruction-authoring.md) for `global.get` / `global.set`. The binary/core section guide remains [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md).

The current primary-source and local-code manifest is [`../raw/wasm/2026-05-19-wast-resource-declaration-sources.md`](../raw/wasm/2026-05-19-wast-resource-declaration-sources.md). It reconciles the current official WebAssembly text/module/type/validation sources with Starshine's WAST parser, lowerer, printer, core model, binary codec, validator, valid generator, and WAST arbitrary surface.

## Beginner Mental Model

A WebAssembly module has separate index spaces for tables, memories, and globals. Imports of a resource kind come first, then locally-defined resources of the same kind follow.

```wat
(module
  (import "env" "tab" (table $host_table 1 funcref)) ;; TableIdx 0
  (import "env" "mem" (memory $host_mem 1 2))        ;; MemIdx 0
  (import "env" "g" (global $host_g i32))            ;; GlobalIdx 0

  (table $local_table 2 funcref)                      ;; TableIdx 1
  (memory $local_mem 1)                               ;; MemIdx 1
  (global $local_g (mut i32) (i32.const 0))           ;; GlobalIdx 1

  (export "mem" (memory $local_mem))
  (func (result i32) (global.get $host_g)))
```

After lowering, Starshine does not keep `$local_mem` or `$host_g` as instruction immediates. [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) resolves them to imported-prefix numeric indices. That is the same imported-prefix rule used by the binary sections and validator environment.

## Text Shapes

### Explicit resource imports

```wat
(import "env" "tab" (table $tab 1 4 funcref))
(import "env" "mem" (memory $mem 1 2))
(import "env" "counter" (global $counter (mut i32)))
```

Explicit imports are the stable Starshine WAST shape for imported tables, memories, and globals. The id after the resource keyword is optional, but it is useful for readable fixtures and for proving that lowering resolves named resources through the same imported-prefix index space as numeric references.

Current Starshine WAST does **not** implement inline import shorthand for these three resource declarations:

```wat
;; Do not use these as current Starshine fixtures:
(table $tab (import "env" "tab") 1 funcref)
(memory $mem (import "env" "mem") 1)
(global $g (import "env" "g") i32)
```

Use explicit import fields instead. If you need to export an imported resource, write a separate explicit export:

```wat
(import "env" "mem" (memory $mem 1))
(export "mem" (memory $mem))
```

Function and tag pages have their own inline-import caveats because their parser paths differ; see [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md) and [`exception-tag-authoring.md`](exception-tag-authoring.md).

### Table definitions

```wat
(table $t (export "table") 4 funcref)
```

A table definition has optional id, optional inline exports, limits, and an element reference type. Current WAST declarations lower limits through [`wt_limits(...)`](../../../src/wast/lower_to_lib.mbt) to `@lib.Limits::i32(...)`, so use direct core or binary fixtures for table64 evidence until the text surface is widened.

Starshine also parses the official table element abbreviation:

```wat
(module
  (func $f)
  (table $t funcref (elem $f)))
```

Important local/core split: this WAST abbreviation lowers to an active element segment in `ElemSec`, not to the optional core/binary `Table(..., Some(expr))` initializer field. Use [`element-segment-authoring.md`](element-segment-authoring.md) for active/passive/declarative element modes, and use [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md) when working directly with the optional core table initializer representation.

### Memory definitions

```wat
(memory $mem (export "memory") 1 4)
```

A memory definition has optional id, optional inline exports, and min/max limits. In the current WAST declaration path:

- limits are natural numbers parsed by [`parse_limits(...)`](../../../src/wast/parser.mbt);
- lowering uses `@lib.Limits::i32(...)`;
- there is no WAST declaration spelling for shared memory; and
- memory64 / shared-memory resource-definition tests should use direct core or binary fixtures today.

The core and binary layers are broader than this text surface: [`src/lib/types.mbt`](../../../src/lib/types.mbt) has `I64Limits` and `MemType(..., shared)`, and [`src/binary/decode.mbt`](../../../src/binary/decode.mbt) / [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) support the corresponding binary tags. Do not cite current WAST memory declarations as full coverage for memory64 or shared-memory behavior.

### Global definitions

```wat
(global $counter (export "counter") (mut i32) (i32.const 0))
(global $answer i32 (i32.const 42))
```

A global definition has optional id, optional inline exports, a global type, and an initializer expression. Immutable globals omit `(mut ...)`; mutable globals wrap the value type in `(mut ...)`.

Global initializers validate as constant expressions. Starshine also supports a local extended-const rule for immutable `global.get`: an initializer can read an imported immutable global or an earlier immutable defined global, but not a mutable global and not a later sibling.

```wat
(module
  (global $base i32 (i32.const 8))
  (global $copy i32 (global.get $base)) ;; accepted locally
  (global $mut (mut i32) (i32.const 0))
  ;; (global $bad i32 (global.get $mut)) ;; rejected: mutable global in const expr
)
```

The runtime instruction rules for `global.get` and `global.set` live in [`variable-instruction-authoring.md`](variable-instruction-authoring.md). The focused initializer allow-list and local/spec caveats live in [`../validate/constant-expressions.md`](../validate/constant-expressions.md); the broader validator phase order lives in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md).

## Lowering And Printing Flow

| Stage | Starshine behavior | Evidence |
| --- | --- | --- |
| WAST parse | Parses table, memory, global, import, and export fields in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt). | `parse_table(...)`, `parse_memory(...)`, `parse_global(...)`, `parse_import(...)`, `parse_export(...)` |
| Identifier collection | Records table, memory, and global ids in the module lowering context after imports and definitions are assigned absolute indices. | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) |
| Inline exports | Turns inline table/memory/global exports into ordinary `ExportSec` entries targeting the resolved index. | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) |
| Table abbreviations | Converts table-attached `(elem ...)` payloads into active element definitions with the table index and default `i32.const 0` offset when omitted. | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`element-segment-authoring.md`](element-segment-authoring.md) |
| Core model | Stores imports in `ImportSec`, local tables in `TableSec`, local memories in `MemSec`, and local globals in `GlobalSec`. | [`src/lib/types.mbt`](../../../src/lib/types.mbt) |
| WAST print | Prints table, memory, global, import, and export fields, including inline exports and table element abbreviations, using the current WAST-local natural-limit spelling. | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) |
| Validation | Imports extend resource index spaces before local sections; globals are validated incrementally so later globals cannot be referenced by earlier initializers. | [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) |

## Validation And Rewrite Guidance

When a pass, generator, or fixture touches resource declarations, check these invariants:

1. **Imports are part of the same index space.** A local table/memory/global is not necessarily index `0`; imported resources of the same kind occupy the prefix.
2. **Definitions and imports live in different core sections.** Do not move an imported memory into `MemSec` or a local global into `ImportSec`; use the right representation for the resource's provenance.
3. **Inline exports are real exports.** A table, memory, or global inline export lowers into `ExportSec` and participates in duplicate-export validation and rewrite checklists.
4. **Table abbreviations are element-segment sugar.** If a pass deletes or remaps tables or functions, repair the generated active element segments too.
5. **Global initializers see only imports and earlier globals.** Reordering globals can invalidate or change initializer `global.get` references unless all `GlobalIdx` carriers are rewritten and validation is rerun.
6. **Current WAST resource declarations are not memory64/shared evidence.** Use direct core, binary, or generator fixtures for `I64Limits`, table64/memory64 declaration behavior, and shared-memory validation until WAST text support exists.
7. **Import/export declarations are module-boundary facts, not host-linking proof.** Explicit imports extend local index spaces; inline and explicit exports lower to `ExportSec` and duplicate-name checks. The external-type matching relation for future linker/embedding work lives in [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md).
8. **Re-run full module validation after resource rewrites.** Section-level changes affect imports, exports, names, instructions, segments, constant expressions, and pass-local summaries.

Useful related signoff pages:

- [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md) for core/binary remap surfaces;
- [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md) for validation phase order;
- [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md) for import/export index checks, duplicate export names, and external-type matching;
- [`table-instruction-authoring.md`](table-instruction-authoring.md), [`memory-instruction-authoring.md`](memory-instruction-authoring.md), and [`variable-instruction-authoring.md`](variable-instruction-authoring.md) for instruction users of the declared resources;
- [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) for valid-generator coverage claims that go beyond WAST parser/printer fixtures.

## Common Mistakes

- Assuming `(memory 1)` proves memory64 behavior. Current WAST declaration lowering produces `I32Limits`; memory64 declaration evidence needs core or binary fixtures.
- Writing inline table/memory/global import shorthand and expecting Starshine to lower it today. Use explicit import fields.
- Treating a table-attached `(elem ...)` abbreviation as a `Table(..., Some(expr))` core initializer. Starshine WAST lowers it to an element segment.
- Using official inline memory-data abbreviation syntax as current Starshine WAST evidence. Use separate `(memory ...)` and `(data ...)` fields until [`data-segment-authoring.md`](data-segment-authoring.md) says otherwise.
- Forgetting imported-prefix indices when updating `table.get`, `memory.init`, `global.get`, exports, names, or segment modes after resource reordering.
- Treating a valid import declaration as proof that a host can satisfy it. Module validation and host external-type matching are separate contracts.
- Reordering globals without preserving incremental constant-expression visibility.
- Treating WAST arbitrary resource fields as semantic validation. WAST arbitrary is parser/printer coverage; `gen_valid`, binary tests, and validator tests are the typed-validity lanes.

## Sources

- Source manifest: [`../raw/wasm/2026-05-19-wast-resource-declaration-sources.md`](../raw/wasm/2026-05-19-wast-resource-declaration-sources.md)
- Import/export matching source bridge: [`../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md`](../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md)
- Broader binary/core resource manifest: [`../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md`](../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md)
- Official WebAssembly sources checked: <https://webassembly.github.io/spec/core/text/modules.html>, <https://webassembly.github.io/spec/core/text/types.html>, <https://webassembly.github.io/spec/core/syntax/modules.html>, <https://webassembly.github.io/spec/core/binary/modules.html>, <https://webassembly.github.io/spec/core/valid/modules.html>, <https://webassembly.github.io/memory64/core/>
- Starshine implementation: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt)
