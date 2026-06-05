---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md
  - ../raw/research/0711-2026-06-04-cli-print-utility-routing.md
  - ../raw/wasm/2026-05-19-wast-identifier-name-sources.md
  - ../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md
  - ../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md
  - ../raw/wasm/2026-05-20-name-section-label-subsection-correction.md
  - ../raw/wasm/2026-05-13-custom-and-name-section-sources.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast_tests.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/cmd/cmd.mbt
  - ../../../src/cmd/cmd_wbtest.mbt
related:
  - ../binary/custom-and-name-sections.md
  - ../binary/function-import-export-and-code-sections.md
  - ../tooling/cli-command-and-dispatcher.md
  - ../binary/module-section-map.md
  - ../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - code-metadata-and-function-annotations.md
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

Use this page when a text fixture depends on `$` identifiers, debug names, `--no-inline=<pattern>` matching, `--print-* <name|index>` lookup, or the boundary between source identifiers and binary name-section metadata. For the deeper Starshine/Binaryen annotation split—function/import-only `(@...)`, `metadata.code.inline`, branch hints, and internal no-inline markers—use [`code-metadata-and-function-annotations.md`](code-metadata-and-function-annotations.md). The short rule is:

- **WAST identifiers** are authoring-time symbols. They make text readable and let later text references resolve to the right type, function, table, memory, global, tag, element, data, local, or label index.
- **The binary name section** is debug metadata. It can preserve human-readable names after lowering, but it is not how WebAssembly validation resolves operands.
- **Starshine function annotations** are a local metadata lane for function and function-import annotations. They are not the same as the official text `@custom` placement model.

The official WebAssembly text spec treats identifiers as text syntax, while the custom-section appendix defines the standardized custom section named `name`. Starshine sits between those layers: [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) keeps source identifiers in the WAST AST, [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) resolves them into core numeric indices, and only function/imported-function identifiers currently become structured `NameSec.func_names` entries. The focused primary-source snapshot is [`../raw/wasm/2026-05-19-wast-identifier-name-sources.md`](../raw/wasm/2026-05-19-wast-identifier-name-sources.md); the binary metadata contract is [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md). The later 2026-05-20 correction note splits the current official `name` subsections from Starshine-local label/table/memory/global/element/data maps, and the 2026-06-04 current-source refresh confirms the split while adding a sharper official-text caveat: `(@name ...)` is portable name-section authoring syntax upstream, but Starshine currently treats leading `(@...)` only as local function/import annotations. Function/import annotations now have a dedicated focused page, [`code-metadata-and-function-annotations.md`](code-metadata-and-function-annotations.md), because they are WAST/in-memory policy metadata rather than source identifier or name-section metadata.

## Layer Map

| Layer | What it stores | Starshine evidence | Practical consequence |
| --- | --- | --- | --- |
| WAST AST | Source ids such as `$f`, `$t`, `$x`, and `$e`; references are `Index::Id(...)` or `Index::Num(...)`. | [`Index`](../../../src/wast/parser.mbt), source structs with `id : String?`, and [`module_wast.mbt`](../../../src/wast/module_wast.mbt) printing ids back from the AST. | Good for authoring and text roundtrips inside `src/wast`; not a binary preservation promise by itself. |
| Lowering context | Maps from source ids to numeric core indices. | `WTLowerCtx` maps in [`lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), plus resolver calls for type/function/table/memory/global/tag/elem/data references. | Validation and binary encoding see indices, not `$` strings. |
| Structured name section | Debug-name maps in `Module.name_sec`. | `wt_push_func_name(...)` and the `wast_to_binary_module lowers function identifiers into function names` test in [`lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt). | Today only WAST function/imported-function ids are promoted here by the text lowerer; the current official subsection set stops at module/function/local/type/field/tag, while Starshine-local label/table/memory/global/element/data maps remain richer compatibility metadata. |
| Function annotation section | Function-index-keyed annotations. | `parse_annotation(...)`, `attach_annotations(...)`, `wt_func_annotations(...)`, and the function-annotation lowering tests. | Used by Starshine/Binaryen-policy code such as inlining; not official `@name` lowering and not full `@custom` placement support. |
| CLI print selectors | Post-lowering debug selectors for `type`, `func`, `import`, `table`, `memory`, `global`, `export`, `tag`, `elem`, and `data`. | [`cmd_resolve_pipeline_print_entry(...)`](../../../src/cmd/cmd.mbt), the 2026-06-04 print audit, and `src/cmd/cmd_wbtest.mbt`. | Name selectors read structured `NameSec` maps for most module items, import/export payload names for import/export rows, and absolute imported-prefix function indices for functions. |
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

Official WebAssembly text also has `(@name "...")` name annotations that can supply or override names at supported binding sites. That official form is not implemented by Starshine's name-lowering path today. If a fixture writes `(@name "debug")` before a Starshine-supported function, the current parser records a local function annotation named `name`; it does **not** write `debug` into `NameSec.func_names`. Use ordinary `$` function/import identifiers for current Starshine function-name lowering, or add explicit `@name` parser/lowerer tests before claiming portable `@name` support.

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

### CLI print selectors consume lowered names, not raw `$` ids

```text
starshine --print-func main --print-import env.host --print-type 0 input.wasm
```

Command-line print steps run after WAST text has already been lowered or binary bytes have already been decoded into a core `Module`. That means a `--print-*` name selector is **not** a direct lookup in the source text. It uses one of three post-lowering sources:

| Printable kind | Name source | Practical rule |
| --- | --- | --- |
| `type`, `func`, `table`, `memory`, `global`, `tag`, `elem`, `data` | The corresponding structured `NameSec` map. | A WAST `$work` function/import id usually works because Starshine lowers function ids into `func_names`; a WAST `$tmp` local id or `$mem` memory id does not automatically create a printable name map. Numeric selectors still work when no name map exists. |
| `import` | The import declaration payload. | `field` selects the first matching field name; `module.field` selects an exact module/field pair. This is independent of the binary name section. |
| `export` | The public export-name string. | Export selectors use the user-visible export name and inherit the duplicate-export-name validation invariant from [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md). |

`--print-func` indices are absolute imported-prefix `FuncIdx` values, not code-section body ordinals. With one imported function, `--print-func 0` selects the import and the first defined body is `--print-func 1`; see [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md). The dispatcher page owns the full supported-kind list, queue flushing, stderr log shape, and failure behavior: [`../tooling/cli-command-and-dispatcher.md`](../tooling/cli-command-and-dispatcher.md).

This is a useful debugging bridge for beginners: if `--print-func main` fails on a WAT fixture, first ask whether `$main` was a function/import id that lowered into `NameSec.func_names`; if it was a local, type, memory, or data id, either use a numeric selector or add explicit structured name-section support before relying on a name selector.

### Function annotations are function metadata, not general custom annotations

```wat
(module
  (@binaryen.js.called)
  (import "env" "imp" (func $imp))
  (@binaryen.idempotent)
  (@metadata.code.inline "\00")
  (func $f))
```

`parse_annotated_module_field(...)` accepts one or more `(@...)` forms immediately before a module field. `attach_annotations(...)` currently allows them only on defined functions and function imports. Lowering writes them into `FuncAnnotationSec` entries keyed by function index. The exact code-metadata, branch-hint, binary-roundtrip, no-inline-marker, and pass-remap caveats now live in [`code-metadata-and-function-annotations.md`](code-metadata-and-function-annotations.md).

Do not infer official text `@custom` placement support from this. The official custom-section text model carries placement and arbitrary payload semantics; Starshine's current function-annotation path is a narrow function metadata lane used by passes and policy tests.

## Flow For Authors And Pass Writers

1. **Parse text.** [`parse_index(...)`](../../../src/wast/parser.mbt) keeps numeric and symbolic references distinct. Entity parsers store optional ids directly on WAST AST nodes.
2. **Build definition maps.** [`wt_lower_module(...)`](../../../src/wast/lower_to_lib.mbt) pre-collects type ids, then walks imports and definitions to assign the imported-prefix index spaces used by the core module model.
3. **Resolve references.** Instruction, type, element, data, export, start, and initializer lowering convert `Index::Id(...)` references into numeric `TypeIdx`, `FuncIdx`, `TableIdx`, `MemIdx`, `GlobalIdx`, `TagIdx`, element indices, data indices, or local indices. For function type-use ids and rec-group flat type-index caveats, use [`gc-type-authoring.md`](gc-type-authoring.md).
4. **Emit metadata selectively.** Function ids are copied into `NameSec.func_names`; function annotations become `func_annotation_sec`; other ids remain source-level unless a specific lowering path says otherwise.
5. **Debug or inspect by post-lowering names.** CLI `--print-*` selectors see the lowered/decoded `Module`, so function/import ids that became `NameSec.func_names` can be selected by name while source-only ids usually cannot.
6. **Validate after lowering.** The core validator checks numeric index spaces and structured name-section maps. The final name-section phase is documented in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md) and the binary metadata page.

## Invariants And Edge Cases

- **A `$` identifier is not a core semantic object.** It must resolve before binary encoding or validation can reason about it.
- **Function-name metadata stores the trimmed name.** `$foo` in WAST becomes `foo` in `NameSec.func_names`; matching code and `--print-func foo` should not require the leading `$` unless intentionally operating on WAST AST text.
- **Imported functions share the same function index space.** Function names from WAST imports and definitions are keyed by the absolute imported-prefix `FuncIdx`; pair this page with [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md).
- **Local ids are useful even without local-name metadata.** They make text fixtures readable, but local-name preservation is a separate name-section feature.
- **Passes that delete or reorder functions must repair both policy metadata and names.** Inlining and module-element removal already document this because stale names can make later `--no-inline=<pattern>` policy or diagnostics point at the wrong function.
- **Do not hide unsupported or local name maps behind tests that only parse WAST.** If a test needs type/tag debug names, Starshine-local label/table/memory/global/elem/data debug names after binary lowering, or name-based `--print-*` selectors for those spaces, assert the corresponding `NameSec` map explicitly and link the binary metadata caveat.
- **Function annotations have a narrow legal placement.** Current parser support is function/import-only; a module-, global-, or section-level annotation should be rejected unless the WAST front end is deliberately widened.
- **Official `@name` / `@custom` text annotations need dedicated support.** Starshine's local `(@...)` parser can accept those names only where function annotations are legal, and then stores them as `FuncAnnotationSec`; it does not implement official name-section or custom-section text semantics.

## Validation And Signoff Guidance

- Parser/printer-only id work belongs in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), and [`src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt).
- Lowering work should add focused `wast_to_binary_module(...)` coverage in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) or a sibling `*_test.mbt`, then validate the lowered module when it is meant to be semantically valid.
- Name-section widening, including official `@name` text support, must update [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md), WAST parser/lowerer/printer tests, name-section validation tests, `--print-*` selector expectations when the new names become user-visible, and any pass that remaps the affected index space.
- Policy or annotation widening should update the inlining policy pages and command/dispatcher docs when CLI flags or user-facing matching behavior changes.

## Sources

- Current custom/name/text-annotation refresh: [`../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md`](../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md)
- CLI print-utility routing audit: [`../raw/research/0711-2026-06-04-cli-print-utility-routing.md`](../raw/research/0711-2026-06-04-cli-print-utility-routing.md)
- Focused primary-source snapshot: [`../raw/wasm/2026-05-19-wast-identifier-name-sources.md`](../raw/wasm/2026-05-19-wast-identifier-name-sources.md)
- Correcting binary name-section refresh: [`../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md`](../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md)
- Label-subsection correction: [`../raw/wasm/2026-05-20-name-section-label-subsection-correction.md`](../raw/wasm/2026-05-20-name-section-label-subsection-correction.md)
- Earlier superseded binary name-section source snapshot: [`../raw/wasm/2026-05-13-custom-and-name-section-sources.md`](../raw/wasm/2026-05-13-custom-and-name-section-sources.md)
- WAST parser/printer/lowerer: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt)
- Core module metadata: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md)
- CLI print selector implementation and tests: [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt), [`../../../src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt), [`../tooling/cli-command-and-dispatcher.md`](../tooling/cli-command-and-dispatcher.md)
- Resource declaration syntax: [`resource-declaration-authoring.md`](resource-declaration-authoring.md)
