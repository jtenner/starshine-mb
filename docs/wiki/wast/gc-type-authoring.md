---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md
  - ../raw/research/0018-2026-03-22-wast-struct-type-surface.md
  - ../raw/research/0019-2026-03-22-wast-array-type-surface.md
  - ../raw/research/0020-2026-03-22-wast-rec-group-surface.md
  - ../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md
related:
  - ../binary/data-element-and-datacount-sections.md
  - ../custom-descriptors/static-fixtures.md
  - ../custom-descriptors/exact-reference-equivalence.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast_tests.mbt
  - ../../../src/wast/rec_group_typeuse_test.mbt
---

# Higher-Level WAST GC Type Authoring

## Overview

Starshine's higher-level `src/wast` path can author, print, lower, and validate useful GC type fixtures directly from text. Use it for new GC/custom-descriptor tests before falling back to binary-only fixtures: the text AST carries the source structure developers need to debug, while `src/wast/lower_to_lib.mbt` translates that structure into the flat type-index space used by the binary module model. For GC-typed element segment authoring and the current declarative-element lowering caveat, pair this page with [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md).

The current primary-source baseline is WebAssembly 3.0's GC type model plus the custom-descriptors proposal snapshot captured in [`../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md`](../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md). WebAssembly's core type forms are `func`, `struct`, and `array`; recursive groups give each member its own flat type index; custom descriptors add `describes` / `descriptor` metadata and exact descriptor-aware struct construction. Starshine follows the core `func` / `struct` / `array` and rec-group model, and intentionally documents the local places where the proposal surface is broader or still provisional.

## Starshine Surface

### Parsed AST shape

- `TypeDefBody` supports `Func`, `Struct`, and `Array` bodies in [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt).
- `TypeDef` records `is_sub`, `final_`, zero or more `supers`, and generic `TypeDefMetadata { describes, descriptor }`.
- Module fields distinguish one-off `TypeField(...)` entries from grouped `RecField(Array[TypeDef])` entries, so `(rec ...)` is not lost during parsing.
- `parse_type_metadata_clauses(...)` requires `describes` before `descriptor`, rejects duplicates, and keeps the order rule explicit instead of silently normalizing reversed input.

### Printed text shape

- [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) renders metadata in canonical `describes`-then-`descriptor` order.
- Empty, singleton, and multi-member `rec` groups are preserved textually; roundtrip coverage in [`../../../src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt) asserts that grouped entries stay grouped after printing and reparsing.

### Lowering shape

- `wt_type_metadata(...)`, `wt_sub_type(...)`, and `wt_type_group(...)` in [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) lower parsed type definitions into `@lib.TypeMetadata`, `@lib.SubType`, and `@lib.RecType`.
- Lowering resolves named and numeric type uses against the already-built flat type space. For grouped rec entries, this means the source `RecField` is preserved in the AST while each subtype still contributes one flat type index.
- `wt_flat_type_count(...)` is the guardrail: it counts every subtype inside every grouped `RecType`, not just the number of top-level `rec` containers.

## Invariants And Edge Cases

| Invariant | Why it matters | Evidence |
| --- | --- | --- |
| Preserve `RecField` grouping in the text AST. | Future fixture authors need to express recursive type identity and grouping exactly. | `src/wast/parser.mbt` `ModuleField::RecField`; `src/wast/module_wast_tests.mbt` rec-group roundtrips. |
| Resolve type uses through flat subtype indices during lowering. | Wasm validation indexes every type member, including every member of a rec group. | [`../../../src/wast/rec_group_typeuse_test.mbt`](../../../src/wast/rec_group_typeuse_test.mbt) checks an implicit function type after a two-member rec group lands at flat type index `2`. |
| Keep `describes` before `descriptor`. | The parser has an explicit deterministic metadata order rule; printed text should never depend on input clause order. | `parse_type_metadata_clauses(...)` and the `wast_to_module rejects descriptor clauses before describes clauses` test in `module_wast_tests.mbt`. |
| Treat descriptor metadata on arrays as a local compatibility caveat. | The current custom-descriptors proposal restricts metadata clauses to struct definitions, but Starshine stores metadata generically and has array metadata lowering coverage. | Proposal snapshot in `raw/wasm/...`; `wast_to_binary_module lowers array type defs with descriptor metadata` in `lower_to_lib.mbt`. |
| Do not confuse source grouping with implicit function-type insertion. | Inline function signatures may synthesize function types after existing type definitions; grouped rec entries must still occupy their flat indices first. | `wt_append_lib_func_type(...)`, `wt_flat_type_count(...)`, and `rec_group_typeuse_test.mbt`. |

## Concrete Authoring Examples

### Rec group with descriptor pair

```wat
(module
  (rec
    (type $node
      (descriptor $node_desc)
      (struct (field (ref null $node))))
    (type $node_desc
      (describes $node)
      (struct))))
```

Use this shape when a fixture needs mutual recursion between a concrete type and its descriptor type. The source remains one `RecField([node, node_desc])`; lowering turns it into one grouped `@lib.RecType` with two subtypes.

### Flat index after grouped entries

```wat
(module
  (rec
    (type $a (struct))
    (type $b (struct)))
  (func (param (ref $a)) (result (ref null $b))
    (ref.null $b)))
```

The inline function signature is appended after both rec-group members, so the generated function section points at flat type index `2`, not at top-level field index `1`. This is the practical bug class that [`../../../src/wast/rec_group_typeuse_test.mbt`](../../../src/wast/rec_group_typeuse_test.mbt) prevents.

### Order-negative metadata fixture

```wat
(module
  (rec
    (type $a (descriptor $b) (struct))
    (type $b (descriptor $c) (describes $a) (struct))
    (type $c (describes $b) (struct))))
```

Starshine rejects the second type because `describes` appears after `descriptor`. Keep this rejection: it makes the grammar deterministic and keeps printed output from hiding source-order mistakes.

## Validation And Signoff Guidance

- Parser or printer changes should exercise [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt) and [`../../../src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt) before changing lowering.
- Lowering changes should add focused coverage in [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) or a sibling `*_test.mbt`, then validate the lowered module with `@validate.validate_module(...)` when the fixture is meant to be semantically valid.
- Descriptor fixture lifts should cross-check the static custom-descriptor harness in [`../custom-descriptors/static-fixtures.md`](../custom-descriptors/static-fixtures.md) and the exact-reference compatibility rules in [`../custom-descriptors/exact-reference-equivalence.md`](../custom-descriptors/exact-reference-equivalence.md).
- If upstream custom-descriptors remains struct-only, do not cite Starshine's array metadata lowering test as proposal evidence. Either keep it documented as a local broad surface or narrow the parser/validator in a dedicated behavior change.

## Sources

- Current primary-source snapshot: [`../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md`](../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md)
- Archived research docs:
  [`../raw/research/0018-2026-03-22-wast-struct-type-surface.md`](../raw/research/0018-2026-03-22-wast-struct-type-surface.md),
  [`../raw/research/0019-2026-03-22-wast-array-type-surface.md`](../raw/research/0019-2026-03-22-wast-array-type-surface.md),
  [`../raw/research/0020-2026-03-22-wast-rec-group-surface.md`](../raw/research/0020-2026-03-22-wast-rec-group-surface.md),
  [`../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md`](../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md)
- Current implementation and tests:
  - [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt)
  - [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt)
  - [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
  - [`../../../src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt)
  - [`../../../src/wast/rec_group_typeuse_test.mbt`](../../../src/wast/rec_group_typeuse_test.mbt)
