---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - ../raw/wasm/2026-06-04-constant-expression-current-refresh.md
  - ../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md
  - ../raw/wasm/2026-06-04-exception-tag-current-refresh.md
  - ../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md
  - ../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md
  - ../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md
  - ../raw/wasm/2026-05-20-resource-section-validation-refresh.md
  - ../../../src/lib/types.mbt
  - ../../../src/lib/module.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/binary/tests.mbt
related:
  - module-section-map.md
  - function-import-export-and-code-sections.md
  - instruction-and-expression-encoding.md
  - data-element-and-datacount-sections.md
  - custom-and-name-sections.md
  - ../validate/module-validation-phases.md
  - ../validate/type-section-and-subtyping.md
  - ../validate/resource-sections-and-limits.md
  - ../validate/import-export-and-external-type-matching.md
  - ../validate/constant-expressions.md
  - ../wast/gc-type-authoring.md
  - ../wast/resource-declaration-authoring.md
  - ../wast/variable-instruction-authoring.md
  - ../wast/exception-tag-authoring.md
  - ../wast/string-instruction-authoring.md
  - ../binaryen/passes/remove-unused-types/index.md
  - ../binaryen/passes/reorder-types/index.md
  - ../binaryen/passes/reorder-globals/index.md
  - ../binaryen/passes/string-gathering/index.md
---

# Binary Type, Table, Memory, Global, Tag, And Stringrefs Sections

## Overview

This page is the shared Starshine guide for the core module-definition sections that are not already covered by the function/body, instruction-expression, segment, or metadata pages. For the whole-module stream order and cross-section rewrite checklist, see [`module-section-map.md`](module-section-map.md). For the byte-level expression/immediate contract inside initializers and instructions, see [`instruction-and-expression-encoding.md`](instruction-and-expression-encoding.md). This page covers:

- **type section**: recursive function, struct, and array type definitions;
- **table section**: module-defined tables and optional table initializers;
- **memory section**: module-defined memories;
- **global section**: module-defined globals and their constant initializers;
- **tag section**: exception tag declarations; and
- **stringrefs section**: Starshine's local/proposal-facing literal pool for `string.const` binary round trips.

For fixture-facing table, memory, and global declarations, explicit imports, inline exports, table element abbreviations, and current WAST declaration caveats, pair this binary resource guide with [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md). For shared linear-memory flags, accepted-invalid shared-without-max byte shapes, and the threads-proposal versus stable-Core boundary, pair it with [`../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md). For type-section validation, recursive-group normalization, subtype matching, descriptor metadata checks, explicit type-use abbreviation caveats, and official-versus-local subtype caveats, pair it with [`../validate/type-section-and-subtyping.md`](../validate/type-section-and-subtyping.md) and the current GC type refresh [`../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md). For table/memory/global/tag/data/element limits, incremental resource environments, active segment offset checks, shared-memory maximum policy, and data-count validation, pair it with [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md). For import/export validation, duplicate export names, and external-type matching rules that consume these resource types, pair it with [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md). For the initializer and table-initializer constant-expression allow-list, local/spec caveats, and immutable-`global.get` visibility, pair it with [`../validate/constant-expressions.md`](../validate/constant-expressions.md) and the current refresh [`../raw/wasm/2026-06-04-constant-expression-current-refresh.md`](../raw/wasm/2026-06-04-constant-expression-current-refresh.md). For text-level exception fixtures, catch label semantics, `throw_ref`, `try_table`, and the modern-versus-legacy WAST boundary, pair it with [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md). The current exception refresh [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md) records an important tag-result split: current Core 3.0 tagtype validation is broader than Starshine's local section/import validation, while exception instruction rules still require empty-result tag expansions. For `string.const`, array-backed string helpers, and string-helper validation stack/storage rules, pair it with [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md).

The official WebAssembly 3.0 source snapshot in [`../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md`](../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md) is the primary external source for section ids and the core type/table/memory/global/tag validation model. The shared feature-status vocabulary lives in [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md). The current stringref refresh [`../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md) sharpens the caveat: the active Phase-1 Reference-Typed Strings proposal defines draft section id `14` and Starshine mirrors it, but current Core WebAssembly 3.0 still does **not** define a stable core `stringrefs` section.

## Section Shapes

| Section | Binary id | Starshine representation | Main invariant |
| --- | ---: | --- | --- |
| Type | `1` | [`TypeSec(Array[RecType])`](../../../src/lib/types.mbt) | Defines the module's global type index space. Rec-group-relative `RecIdx` references are normalized to absolute `TypeIdx` values when accepted into the long-lived validator environment. |
| Table | `4` | [`TableSec(Array[Table])`](../../../src/lib/types.mbt), where `Table(TableType, Expr?)` can carry an optional initializer. | Table imports precede definitions in the table index space; table definitions validate their reference type, limits, and optional constant initializer through [`../validate/constant-expressions.md`](../validate/constant-expressions.md). Optional table initializers are checked before local globals in Starshine and are imported-only for `global.get` in the current official rule. |
| Memory | `5` | [`MemSec(Array[MemType])`](../../../src/lib/types.mbt) | Memory imports precede definitions in the memory index space; shared memories require a maximum in Starshine validation. Starshine decodes and can encode shared-without-max flags for invalid-fixture coverage, but those modules must fail validation. |
| Global | `6` | [`GlobalSec(Array[Global])`](../../../src/lib/types.mbt) | Each global validates under the environment containing imports and earlier globals only; its initializer must be a constant expression of the declared type under [`../validate/constant-expressions.md`](../validate/constant-expressions.md). |
| Tag | `13` | [`TagSec(Array[TagType])`](../../../src/lib/types.mbt) | Tag imports precede definitions in the tag index space; Starshine currently requires each tag type index to resolve to a function type with no results, although current Core 3.0 only enforces the empty-result shape at EH instruction use sites. |
| Stringrefs | proposal/local `14` | [`StringRefsSec(Array[Bytes])`](../../../src/lib/types.mbt) | Literal pool used by Starshine's binary encoder/decoder for `string.const`; the active stringref proposal defines the same section id, but current Core WebAssembly 3.0 does not. WAST-side string helper semantics live in [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md). |

Imports are deliberately not duplicated in these definition sections. An imported memory, for example, appears in `ImportSec` as `MemExternType` and then occupies `MemIdx(0)` before the first locally defined memory. The same imported-prefix rule applies to table, global, and tag indices. If a host value later needs to satisfy that import, the type-compatibility relation is the external-type matching contract in [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md).

## Beginner-To-Advanced Mental Model

Think of validation as building index spaces in order:

```text
type definitions        -> TypeIdx space
imports                 -> imported funcs/tables/mems/globals/tags
function declarations   -> defined FuncIdx suffix
table section           -> defined TableIdx suffix
memory section          -> defined MemIdx suffix
tag section             -> defined TagIdx suffix
global section          -> defined GlobalIdx suffix, incrementally
segments, exports, code -> use those finished spaces
```

The consequence is subtle but important: changing one of these sections is rarely local to that field. Reordering globals changes `GlobalIdx` immediates in instructions, exports, names, and initializer expressions. Reordering or compacting types changes heap-type references in function signatures, globals, table types, tags, casts, GC allocations, element types, and name maps.

## Decode And Encode Flow

| Stage | Starshine behavior | Evidence |
| --- | --- | --- |
| Decode type/table/memory/global/tag | [`Decode for TypeSec`](../../../src/binary/decode.mbt), `TableSec`, `MemSec`, `GlobalSec`, and `TagSec` read ids `1`, `4`, `5`, `6`, and `13` into structured module fields. [`Decode for MemType`](../../../src/binary/decode.mbt) accepts the memory32 `0x00` / `0x01` / `0x02` / `0x03` and memory64 `0x04` / `0x05` / `0x06` / `0x07` flag matrix, including shared-without-max forms that are intentionally left for resource validation to reject. The binary-invalid lane includes `invalid-functype-byte` for malformed type-section function-type tags, `malformed-functype-param-count-uleb`, `malformed-functype-result-count-uleb`, `overwide-functype-param-count-uleb`, and `overwide-functype-result-count-uleb` for signature vector-count ULEB corruption, plus `invalid-functype-param-valtype-byte` and `invalid-functype-result-valtype-byte` for signature value-type byte corruption, alongside table/global/memory/tag descriptor-byte and index corruptions. The value-type decoder accepts the bare `0x64` stringref shorthand when the explicit non-null-ref form cannot be completed, while still accepting explicit nullable `0x63 0x64` and explicit non-null `0x64 0x64` stringref forms. Bare and explicit nullable stringref re-encode as Starshine's canonical `0x63 0x64`; explicit non-null stringref re-encodes as `0x64 0x64`. | `src/binary/decode.mbt`, [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) |
| Decode explicit table initializers | [`Decode for Table`](../../../src/binary/decode.mbt) recognizes the `0x40 0x00` prefix, then decodes a table type and initializer expression; otherwise it decodes an ordinary table type with no initializer. | `src/binary/decode.mbt` |
| Decode stringrefs | [`Decode for StringRefsSec`](../../../src/binary/decode.mbt) reads section id `14`, requires a leading `0x00` payload marker, and installs a decode context so `string.const` instruction immediates can resolve to literal bytes. | `src/binary/decode.mbt` |
| Encode core sections | [`Encode for TypeSec`](../../../src/binary/encode.mbt), `TableSec`, `MemSec`, `GlobalSec`, and `TagSec` write ids `1`, `4`, `5`, `6`, and `13`. | `src/binary/encode.mbt` |
| Encode explicit table initializers | [`Encode for Table`](../../../src/binary/encode.mbt) emits `0x40 0x00` before the table type and initializer expression when `Table(..., Some(expr))` is present. | `src/binary/encode.mbt` |
| Encode stringrefs | [`encode_module_stringrefs(...)`](../../../src/binary/encode.mbt) collects unique `string.const` payloads from globals and code, merges any existing `StringRefsSec`, emits section id `14`, and encodes `string.const` through the active literal pool. | `src/binary/encode.mbt`, [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) |
| Whole-module order | [`Encode for Module`](../../../src/binary/encode.mbt) writes type, import, function, table, memory, tag, proposal/local stringrefs, global, export, start, element, data-count, code, data, and name metadata in canonical order. | `src/binary/encode.mbt` |

## Validation Contract

Starshine's validator mirrors the section dependency order in [`validate_module_impl`](../../../src/validate/validate.mbt): types first, then imports, function declarations, tables, memories, tags, globals, segments, start/exports/ref declarations, code, and names. The full validator-side phase map lives in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md); the focused table/memory/global/tag/data/element limit and environment-extension rules live in [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md).

Important section-specific rules:

- [`validate_typesec(...)`](../../../src/validate/validate.mbt) accepts each `RecType` under a recursive context, checks subtype matching, rejects final-supertype extension and recursive-group supertype cycles, checks descriptor metadata, then appends normalized absolute subtype references to `Env.global_types`. This is why later code-body validation can resolve types without needing the original rec-group-relative context. The focused validator contract, including the current local/spec caveat around still-unclaimed single-supertype and forward-supertype policy, is [`../validate/type-section-and-subtyping.md`](../validate/type-section-and-subtyping.md).
- [`validate_importsec(...)`](../../../src/validate/validate.mbt) validates each imported extern type and appends imported function/table/memory/global/tag entries before local definition sections run. It does not match host values; see [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md) for the validation-versus-instantiation split.
- [`Validate for TableType`](../../../src/validate/validate.mbt) checks the reference type and limit maximum; [`validate_table(...)`](../../../src/validate/validate.mbt) additionally checks optional initializers as constant expressions of the table element type. Use [`../validate/constant-expressions.md`](../validate/constant-expressions.md) for the local allow-list and table-initializer `global.get` caveat: imported immutable globals are visible, but local defined globals are not because the table section validates before the global section.
- [`Validate for MemType`](../../../src/validate/validate.mbt) checks limit bounds and requires shared memories to have a maximum. This is the validity boundary for decoded shared-memory bytes: `0x03` / `0x07` bounded shared memories can validate if their limits are in range, while `0x02` / `0x06` shared-without-max forms are decode-accepted invalid-module specimens.
- [`Validate for TagType`](../../../src/validate/validate.mbt) requires the tag's type index to resolve to a function type and rejects non-empty result lists. The 2026-06-04 current-source refresh records this as a Starshine-local stricter rule: Core 3.0 tagtype validity accepts function-type expansions with results, while `throw` / `catch` / `catch_ref` validation still requires the selected tag expansion to have empty results.
- [`validate_globalsec(...)`](../../../src/validate/validate.mbt) validates globals incrementally. A global initializer can use imported or earlier globals, but not a later sibling.
- `StringRefsSec` is not separately typechecked by `validate_module_impl`; the binary layer resolves the local literal pool before instructions are represented as `Instruction::StringConst(Bytes)`, and ordinary instruction validation then sees the string instruction form.

## Concrete Examples

### Recursive type group

```wasm
(module
  (rec
    (type $node (sub (struct (field (mut (ref null $node))))))
    (type $leaf (sub $node (struct))))
  (func (result (ref null $node))
    (ref.null $node)))
```

Starshine lowers this to a `TypeSec` containing a grouped `RecType`. During validation, group-local `RecIdx` references are accepted in the recursive context and then normalized into absolute `TypeIdx` references before the types become part of `Env.global_types`.

### Imported-prefix table/memory/global/tag spaces

```wasm
(module
  (type $e (func (param i32)))
  (import "env" "tab" (table 1 funcref))      ;; TableIdx(0)
  (import "env" "mem" (memory 1))             ;; MemIdx(0)
  (import "env" "g" (global i32))             ;; GlobalIdx(0)
  (import "env" "tag" (tag (type $e)))        ;; TagIdx(0)
  (table 1 funcref)                            ;; TableIdx(1)
  (memory 1)                                   ;; MemIdx(1)
  (global i32 (i32.const 7)))                  ;; GlobalIdx(1)
```

This mirrors the function imported-prefix model documented in [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md): imported same-kind entries are absolute indices before definitions, even though definitions live in separate table/memory/global/tag sections.

### Global initializer visibility

```wasm
(module
  (global $a i32 (i32.const 1))
  (global $b i32 (global.get $a)))
```

The second initializer validates because `$a` is already in the global environment. A reverse reference from `$a` to `$b` would fail because globals are checked and appended one at a time. For the WAST-side `global.get` / `global.set` stack rules and mutability checks, see [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md); for initializer-specific immutable-`global.get` visibility, see [`../validate/constant-expressions.md`](../validate/constant-expressions.md).

### Local stringrefs round trip

```wasm
(module
  (func (result stringref)
    (string.const "hello")))
```

When Starshine encodes a module containing `Instruction::StringConst`, it collects literal bytes into `StringRefsSec`, emits section `14`, and writes instruction immediates through that pool. This mirrors the active stringref proposal draft and is useful for Starshine's string pass work, but it should not be presented as a stable Core WebAssembly section until the proposal advances into the core spec.

## Pass Rewrite Checklist

A module pass that changes any of these sections must audit more than the section being edited:

- **Type rewrites** must update function signatures, block types, table element types, global types, tag types, casts, GC construction/access instructions, element segment types, export/import types, names, and any pass-local type caches. Revalidate recursive-group normalization and subtype matching with [`../validate/type-section-and-subtyping.md`](../validate/type-section-and-subtyping.md) before relying on output validity.
- **Table rewrites** must update `TableIdx` carriers: table instructions, `call_indirect` / `return_call_indirect`, active element modes, table exports/imports, names, and table initializers. For WAST text defaults and instruction-stack caveats, use [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md).
- **Memory rewrites** must update `MemIdx` carriers: load/store `MemArg` memory operands, `memory.size`, `memory.grow`, `memory.copy`, `memory.fill`, `memory.init`, active data modes, exports/imports, and names. The explicit-memory-index `MemArg` encoding is summarized in [`instruction-and-expression-encoding.md`](instruction-and-expression-encoding.md).
- **Global rewrites** must update `GlobalIdx` carriers: `global.get`, `global.set`, exports/imports, name maps, global initializer expressions, and any pass summaries that cache global mutability or constant values. The fixture-facing `global.set` mutability and const-expression `global.get` rules are in [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md).
- **Tag rewrites** must update `TagIdx` carriers: `throw`, `try_table` `catch` / `catch_ref` clauses, imports/exports, names, and exception-handling validation assumptions; the focused WAST-side checklist is in [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md).
- **String literal-pool rewrites** must keep `StringRefsSec`, `string.const` instructions, supported array-backed string helper assumptions, string-gathering/lowering/lifting passes, and binary round trips consistent. Use [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md) for WAST stack/storage and proposal/local support boundaries.

Related pass dossiers that depend on this checklist include [`remove-unused-types`](../binaryen/passes/remove-unused-types/index.md), [`reorder-types`](../binaryen/passes/reorder-types/index.md), [`reorder-globals`](../binaryen/passes/reorder-globals/index.md), [`global-refining`](../binaryen/passes/global-refining/index.md), [`multi-memory-lowering`](../binaryen/passes/multi-memory-lowering/index.md), [`memory64-lowering`](../binaryen/passes/memory64-lowering/index.md), [`string-gathering`](../binaryen/passes/string-gathering/index.md), and [`remove-unused-module-elements`](../binaryen/passes/remove-unused-module-elements/index.md).

## Edge Cases And Invariants

- **Definition sections exclude imports.** Do not infer `TableSec.length()` equals total table count when imports exist; use the validation environment or imported-count accounting.
- **Global initializers are not mutually recursive.** Later globals are invisible to earlier initializers.
- **Table initializers are uncommon but real.** Preserve the optional `Expr` on `Table`; dropping it changes initialization semantics. Do not assume it can see a local global just because a later global initializer can—the Starshine and current official table-initializer `global.get` context is imported-only.
- **Shared memory needs a maximum locally and in the threads proposal.** Keep this validator rule visible when adding threads or memory-lowering tests. If a binary fixture uses shared-without-max memory flags, label it as invalid-validation evidence, not as a valid module round trip.
- **Tag types are function types, but Starshine still rejects resultful ones at declaration time.** Current Core 3.0's tagtype validity rule is broader; current Starshine intentionally or accidentally keeps the older empty-result declaration rule, so resultful tag sections are local validator-gap fixtures, not ordinary portable positives.
- **`StringRefsSec` is proposal/local-facing.** It is implemented and round-tripped by Starshine and now matches the active Phase-1 stringref draft's section-id-`14` shape, but current Core WebAssembly 3.0 does not make it a stable core section.
- **Name-section maps are coupled.** Type, table, memory, global, and tag name maps in [`custom-and-name-sections.md`](custom-and-name-sections.md) must be rewritten or cleared whenever those index spaces change.

## Sources

- Current linear-memory threads/shared-memory refresh: [`../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md)
- Current constant-expression refresh: [`../raw/wasm/2026-06-04-constant-expression-current-refresh.md`](../raw/wasm/2026-06-04-constant-expression-current-refresh.md)
- Current stringref proposal/core refresh: [`../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md)
- Current exception/tag-result refresh: [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md)
- Primary-source snapshot: [`../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md`](../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md)
- Current GC type/subtyping refresh: [`../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md)
- Older type-section validation refresh: [`../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md`](../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md)
- Resource-section validation refresh: [`../raw/wasm/2026-05-20-resource-section-validation-refresh.md`](../raw/wasm/2026-05-20-resource-section-validation-refresh.md)
- Core representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/lib/module.mbt`](../../../src/lib/module.mbt)
- Decode and encode: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Validation environment and rules: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt)
- WAST lowering: [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Related docs: [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md), [`data-element-and-datacount-sections.md`](data-element-and-datacount-sections.md), [`custom-and-name-sections.md`](custom-and-name-sections.md), [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md), [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md), [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md), [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md)
