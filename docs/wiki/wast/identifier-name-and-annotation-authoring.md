---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-19-wast-identifier-name-sources.md
  - ../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md
  - ../raw/wasm/2026-05-13-custom-and-name-section-sources.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast_tests.mbt
  - ../../../src/lib/types.mbt
related:
  - ../binary/custom-and-name-sections.md
  - ../binary/function-import-export-and-code-sections.md
  - ../binary/module-section-map.md
  - ../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ../binaryen/passes/reorder-locals/index.md
  - ../binaryen/passes/remove-unused-module-elements/index.md
  - element-segment-authoring.md
  - resource-declaration-authoring.md
  - static-assertion-harness.md
  - variable-instruction-authoring.md
  - gc-type-authoring.md
---

# WAST Identifier, Name Section, And Annotation Authoring

## Overview

Use this page when a text fixture depends on `$` identifiers, debug names, `--no-inline=<pattern>` matching, or Binaryen-style function annotations. The short rule is:

- **WAST identifiers** are authoring-time symbols. They make text readable and let later text references resolve to the right type, function, table, memory, global, tag, element, data, local, or label index.
- **The binary name section** is debug metadata. It can preserve human-readable names after lowering, but it is not how WebAssembly validation resolves operands.
- **Starshine function annotations** are a local metadata lane for function and function-import annotations. They are not the same as the official text `@custom` placement model.

The official WebAssembly text spec treats identifiers as text syntax, while the custom-section appendix defines the standardized custom section named `name`. Starshine sits between those layers: [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) keeps source identifiers in the WAST AST, [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) resolves them into core numeric indices, and only function/imported-function identifiers currently become structured `NameSec.func_names` entries. The focused primary-source snapshot is [`../raw/wasm/2026-05-19-wast-identifier-name-sources.md`](../raw/wasm/2026-05-19-wast-identifier-name-sources.md); the binary metadata contract is [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md). That contract now records the 2026-05-20 source correction: current official name-section subsections are narrower than Starshine's local `NameSec`, so table, memory, global, element, and data name maps are local richer metadata rather than current official WebAssembly 3.0 name subsections.

## Layer Map

| Layer | What it stores | Starshine evidence | Practical consequence |
| --- | --- | --- | --- |
| WAST AST | Source ids such as `$f`, `$t`, `$x`, and `$e`; references are `Index::Id(...)` or `Index::Num(...)`. | [`Index`](../../../src/wast/parser.mbt), source structs with `id : String?`, and [`module_wast.mbt`](../../../src/wast/module_wast.mbt) printing ids back from the AST. | Good for authoring and text roundtrips inside `src/wast`; not a binary preservation promise by itself. |
| Lowering context | Maps from source ids to numeric core indices. | `WTLowerCtx` maps in [`lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), plus resolver calls for type/function/table/memory/global/tag/elem/data references. | Validation and binary encoding see indices, not `$` strings. |
| Structured name section | Debug-name maps in `Module.name_sec`. | `wt_push_func_name(...)` and the `wast_to_binary_module lowers function identifiers into function names` test in [`lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt). | Today only WAST function/imported-function ids are promoted here by the text lowerer. |
| Function annotation section | Function-index-keyed annotations. | `parse_annotation(...)`, `attach_annotations(...)`, `wt_func_annotations(...)`, and the function-annotation lowering tests. | Used by Starshine/Binaryen-policy code such as inlining; not full custom-section placement support. |
| Custom sections | Opaque non-`name` custom payloads plus the special structured `name` section. | [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md), [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt). | Binary roundtrips preserve payloads but normalize placement; exact WAST `@custom` placement is not currently modeled. |

## Concrete Shapes

### Function identifiers become function names

```wat
(module
  (type $t (func))
  (import "env" "imp" (func $imp (type $t)))
  (func $work (type $t))
  (func (call $work)))
```

Lowering resolves `$imp` and `$work` to absolute function indices. It also creates a structured function-name map with entries for those function indices. `wt_name_from_id(...)` strips the leading `$`, so the stored names are `imp` and `work`, not `$imp` and `$work`.

This is why command-level inlining policy can match ordinary WAT function identifiers through the structured name surface: [`../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md`](../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md) describes the `--no-inline=<pattern>` split and its reliance on function names.

### Local identifiers resolve operands but do not become local-name metadata

```wat
(module
  (func $add1 (param $x i32) (result i32)
    (local $tmp i32)
    (local.set $tmp (i32.add (local.get $x) (i32.const 1)))
    (local.get $tmp)))
```

The lowerer builds a per-function local-id map from `type_use.param_ids` and local declarations, then resolves `local.get`, `local.set`, and `local.tee` operands to numeric local indices before constructing the core function body. The shared type-use rules that create those parameter ids live in [`gc-type-authoring.md`](gc-type-authoring.md). Current WAST lowering does **not** create a name-section local-name subsection from `$x` or `$tmp`. The exact stack and rewrite rules for these operands live in [`variable-instruction-authoring.md`](variable-instruction-authoring.md).

That distinction matters for passes. A pass that rewrites locals must keep validation correct even if no local-name metadata exists; if it does preserve or create local names, it must update the function-scoped map when indices change. The local-name repair topic is why [`../binaryen/passes/reorder-locals/index.md`](../binaryen/passes/reorder-locals/index.md), [`variable-instruction-authoring.md`](variable-instruction-authoring.md), and the custom/name guide all call out stale local-name metadata.

### Type and resource identifiers resolve indices but are not yet promoted to all name maps

```wat
(module
  (type $node (struct))
  (table $tab 1 funcref)
  (memory $mem 1)
  (global $g i32 (i32.const 0))
  (tag $exn)
  (elem $elem func)
  (data $data "payload"))
```

Starshine tracks ids for type, table, memory, global, tag, element, and data definitions so later references can resolve. Fixture-facing table, memory, and global declaration syntax plus the current inline-import and memory64/shared caveats live in [`resource-declaration-authoring.md`](resource-declaration-authoring.md); this page only covers how `$tab`, `$mem`, and `$g` behave as source ids and name metadata. Today those source ids are lowering aids, not a general promise to populate type/table/memory/global/tag/element/data name-section maps. If a future feature needs that metadata to survive binary roundtrip or pass remapping, add explicit name-map lowering and tests for the affected index space.

### Function annotations are function metadata, not general custom annotations

```wat
(module
  (@binaryen.js.called)
  (import "env" "imp" (func $imp))
  (@binaryen.idempotent)
  (@metadata.code.inline "\00")
  (func $f))
```

`parse_annotated_module_field(...)` accepts one or more `(@...)` forms immediately before a module field. `attach_annotations(...)` currently allows them only on defined functions and function imports. Lowering writes them into `FuncAnnotationSec` entries keyed by function index.

Do not infer official text `@custom` placement support from this. The official custom-section text model carries placement and arbitrary payload semantics; Starshine's current function-annotation path is a narrow function metadata lane used by passes and policy tests.

## Flow For Authors And Pass Writers

1. **Parse text.** [`parse_index(...)`](../../../src/wast/parser.mbt) keeps numeric and symbolic references distinct. Entity parsers store optional ids directly on WAST AST nodes.
2. **Build definition maps.** [`wt_lower_module(...)`](../../../src/wast/lower_to_lib.mbt) pre-collects type ids, then walks imports and definitions to assign the imported-prefix index spaces used by the core module model.
3. **Resolve references.** Instruction, type, element, data, export, start, and initializer lowering convert `Index::Id(...)` references into numeric `TypeIdx`, `FuncIdx`, `TableIdx`, `MemIdx`, `GlobalIdx`, `TagIdx`, element indices, data indices, or local indices. For function type-use ids and rec-group flat type-index caveats, use [`gc-type-authoring.md`](gc-type-authoring.md).
4. **Emit metadata selectively.** Function ids are copied into `NameSec.func_names`; function annotations become `func_annotation_sec`; other ids remain source-level unless a specific lowering path says otherwise.
5. **Validate after lowering.** The core validator checks numeric index spaces and structured name-section maps. The final name-section phase is documented in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md) and the binary metadata page.

## Invariants And Edge Cases

- **A `$` identifier is not a core semantic object.** It must resolve before binary encoding or validation can reason about it.
- **Function-name metadata stores the trimmed name.** `$foo` in WAST becomes `foo` in `NameSec.func_names`; matching code should not require the leading `$` unless it is intentionally operating on WAST AST text.
- **Imported functions share the same function index space.** Function names from WAST imports and definitions are keyed by the absolute imported-prefix `FuncIdx`; pair this page with [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md).
- **Local ids are useful even without local-name metadata.** They make text fixtures readable, but local-name preservation is a separate name-section feature.
- **Passes that delete or reorder functions must repair both policy metadata and names.** Inlining and module-element removal already document this because stale names can make later `--no-inline=<pattern>` policy or diagnostics point at the wrong function.
- **Do not hide unsupported or local name maps behind tests that only parse WAST.** If a test needs type/tag debug names or Starshine-local table/memory/global/elem/data debug names after binary lowering, assert the corresponding `NameSec` map explicitly and link the binary metadata caveat.
- **Function annotations have a narrow legal placement.** Current parser support is function/import-only; a module-, global-, or section-level annotation should be rejected unless the WAST front end is deliberately widened.

## Validation And Signoff Guidance

- Parser/printer-only id work belongs in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), and [`src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt).
- Lowering work should add focused `wast_to_binary_module(...)` coverage in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) or a sibling `*_test.mbt`, then validate the lowered module when it is meant to be semantically valid.
- Name-section widening must update [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md), name-section validation tests, and any pass that remaps the affected index space.
- Policy or annotation widening should update the inlining policy pages and command/dispatcher docs when CLI flags or user-facing matching behavior changes.

## Sources

- Focused primary-source snapshot: [`../raw/wasm/2026-05-19-wast-identifier-name-sources.md`](../raw/wasm/2026-05-19-wast-identifier-name-sources.md)
- Correcting binary name-section refresh: [`../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md`](../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md)
- Earlier superseded binary name-section source snapshot: [`../raw/wasm/2026-05-13-custom-and-name-section-sources.md`](../raw/wasm/2026-05-13-custom-and-name-section-sources.md)
- WAST parser/printer/lowerer: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt)
- Core module metadata: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md)
- Resource declaration syntax: [`resource-declaration-authoring.md`](resource-declaration-authoring.md)
