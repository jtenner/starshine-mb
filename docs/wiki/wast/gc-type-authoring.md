---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md
  - ../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md
  - ../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md
  - ../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md
  - ../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md
  - ../raw/research/0018-2026-03-22-wast-struct-type-surface.md
  - ../raw/research/0019-2026-03-22-wast-array-type-surface.md
  - ../raw/research/0020-2026-03-22-wast-rec-group-surface.md
  - ../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md
related:
  - index.md
  - ../binary/data-element-and-datacount-sections.md
  - element-segment-authoring.md
  - exception-tag-authoring.md
  - gc-aggregate-instruction-authoring.md
  - reference-instruction-authoring.md
  - static-assertion-harness.md
  - ../custom-descriptors/static-fixtures.md
  - ../custom-descriptors/ref-get-desc-fixture-path.md
  - ../custom-descriptors/exact-reference-equivalence.md
  - ../validate/type-section-and-subtyping.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast_tests.mbt
  - ../../../src/wast/rec_group_typeuse_test.mbt
---

# Higher-Level WAST GC Type Authoring

## Overview

Starshine's higher-level `src/wast` path can author, print, lower, and validate useful GC type fixtures directly from text. Use it for new GC/custom-descriptor tests before falling back to binary-only fixtures: the text AST carries the source structure developers need to debug, while `src/wast/lower_to_lib.mbt` translates that structure into the flat type-index space used by the binary module model. For GC-typed element segment authoring, typed empty or non-`funcref` element fixtures, and the current declarative-element preservation plus typed-declarative text caveats, pair this page with [`element-segment-authoring.md`](element-segment-authoring.md) and the broader binary segment map in [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md). For reference instructions over those types, including `ref.null`, `ref.func`, cast/test forms, and the current ordinary `ref.test` / `ref.cast` / `br_on_*` WAST parser gap, use [`reference-instruction-authoring.md`](reference-instruction-authoring.md). For exception tags with reference-typed payloads, `try_table`, and `exnref` catch-reference flows, use the focused [`exception-tag-authoring.md`](exception-tag-authoring.md) guide.

The current type-use, recursive-type, and subtype refresh is [`../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md), which rechecked the current WebAssembly Core 3.0 type/text/binary/validation pages dated 2026-06-03 against Starshine's WAST parser, lowerer, validator, and invalid-fuzzer evidence. The older WAST type-use bridge [`../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md`](../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md) and validator-side bridge [`../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md`](../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md) remain useful provenance for the original page split. The descriptor metadata baseline is [`../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md`](../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md), and the focused `ref.get_desc` / exactness refresh is [`../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md`](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md). WebAssembly's core type forms are `func`, `struct`, and `array`; recursive groups give each member its own flat type index; subtypes can name supertypes and finality; type-use sites either name an existing function type or spell inline function signature clauses that the official text model treats as an abbreviation/check against the referenced function type. Custom descriptors add `describes` / `descriptor` metadata and exact descriptor-aware struct construction; the runtime instruction and exactness rules live in [`../custom-descriptors/ref-get-desc-fixture-path.md`](../custom-descriptors/ref-get-desc-fixture-path.md) and [`../custom-descriptors/exact-reference-equivalence.md`](../custom-descriptors/exact-reference-equivalence.md). Starshine follows the core `func` / `struct` / `array`, rec-group, subtype, and type-use model, and intentionally documents the local places where the proposal surface is broader or still provisional. For instructions that allocate, read, or mutate those aggregate types, including the current WAST text gap around official `struct.set` and `array.*` operations, use [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md).

## Starshine Surface

### Parsed AST shape

- `TypeDefBody` supports `Func`, `Struct`, and `Array` bodies in [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt).
- `TypeDef` records `is_sub`, `final_`, zero or more `supers`, and generic `TypeDefMetadata { describes, descriptor }`.
- Module fields distinguish one-off `TypeField(...)` entries from grouped `RecField(Array[TypeDef])` entries, so `(rec ...)` is not lost during parsing.
- `parse_type_metadata_clauses(...)` requires `describes` before `descriptor`, rejects duplicates, and keeps the order rule explicit instead of silently normalizing reversed input.
- `parse_type_use(...)` accepts an optional `(type $id)` or `(type 0)` reference followed by optional inline `(param ...)` and `(result ...)` clauses. It is reused by functions, imports, tags, block types, `call_indirect`, `return_call_indirect`, and `return_call_ref`; those consumers should link here for type-use rules instead of restating them.

### Printed text shape

- [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) renders metadata in canonical `describes`-then-`descriptor` order.
- Empty, singleton, and multi-member `rec` groups are preserved textually; roundtrip coverage in [`../../../src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt) asserts that grouped entries stay grouped after printing and reparsing.

### Lowering shape

- `wt_type_metadata(...)`, `wt_sub_type(...)`, and `wt_type_group(...)` in [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) lower parsed type definitions into `@lib.TypeMetadata`, `@lib.SubType`, and `@lib.RecType`.
- Lowering resolves named and numeric type uses against the already-built flat type space. For grouped rec entries, this means the source `RecField` is preserved in the AST while each subtype still contributes one flat type index.
- Inline type uses lower through `wt_resolve_type_use(...)`: named `(type ...)` references resolve directly, while inline signatures are matched against existing flat function types by `wt_find_matching_func_type_index(...)` or appended after the current flattened type space by `wt_append_type(...)`.
- `wt_flat_type_count(...)` is the guardrail: it counts every subtype inside every grouped `RecType`, not just the number of top-level `rec` containers.

## Invariants And Edge Cases

| Invariant | Why it matters | Evidence |
| --- | --- | --- |
| Preserve `RecField` grouping in the text AST. | Future fixture authors need to express recursive type identity and grouping exactly. | `src/wast/parser.mbt` `ModuleField::RecField`; `src/wast/module_wast_tests.mbt` rec-group roundtrips. |
| Resolve type uses through flat subtype indices during lowering. | Wasm validation indexes every type member, including every member of a rec group. | [`../../../src/wast/rec_group_typeuse_test.mbt`](../../../src/wast/rec_group_typeuse_test.mbt) checks an implicit function type after a two-member rec group lands at flat type index `2`. |
| Treat `(sub final? super* ...)` as syntax plus validation, not syntax alone. | The parser records `final_` and `supers`, but only validation can prove the named supertypes are legal and compatible; current docs keep official subtype side-condition coverage explicit rather than implied. | `parse_type_def(...)` / `try_parse_type_sub_wrapper(...)` in [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), `wt_sub_type(...)` in [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), and [`../validate/type-section-and-subtyping.md`](../validate/type-section-and-subtyping.md). |
| Keep inline type-use abbreviation effects visible. | `(func (param i32))` and `(func (type $sig))` can lower to different `TypeIdx` behavior even when the visible signature is equivalent. Current Starshine lowering also returns the explicit `(type ...)` index without checking that any inline `(param ...)` / `(result ...)` clauses match that referenced function type, while the official text model treats those clauses as a consistency check/abbreviation. | `parse_type_use(...)`, `wt_resolve_type_use(...)`, `wt_find_matching_func_type_index(...)`, current refresh [`../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md), and call/tail-call/table instruction pages that carry type-use immediates. |
| Keep `describes` before `descriptor`. | The parser has an explicit deterministic metadata order rule; printed text should never depend on input clause order. | `parse_type_metadata_clauses(...)` and the `wast_to_module rejects descriptor clauses before describes clauses` test in `module_wast_tests.mbt`. |
| Treat descriptor metadata on arrays as a local compatibility caveat. | The current custom-descriptors proposal remains outside stable Core WebAssembly and still frames `describes` / `descriptor` as a struct-type feature. Starshine stores metadata generically and has array metadata lowering coverage, while validator-side descriptor metadata still rejects non-struct types. | Current refresh [`../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md), descriptor refresh [`../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md`](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md), and `wast_to_binary_module lowers array type defs with descriptor metadata` in `lower_to_lib.mbt`. |
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

### Subtype, finality, and named supertype

```wat
(module
  (type $base (struct (field i32)))
  (type $child
    (sub final $base
      (struct (field i32) (field (ref null $base)))))
  (func (param (ref null $child))
    local.get 0
    drop))
```

Use this shape when a fixture needs to prove the text parser/lowerer carries `sub`, `final`, and the supertype reference through to the core `SubType`. Parsing this text is not enough to prove semantic legality: validation still owns subtype compatibility, duplicate-super checks, final-super rejection, and other hierarchy rules. After changing this surface, run module validation rather than relying on WAST lowering success.

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

### Type-use sites and implicit function type insertion

```wat
(module
  (rec
    (type $a (struct))
    (type $b (struct)))
  (type $sig (func (param i32) (result i32)))
  (table 1 funcref)
  (func $target (type $sig)
    (i32.const 0))
  (elem (i32.const 0) func $target)
  (func (param i32 i32) (result i32)
    local.get 0
    local.get 1
    call_indirect (type $sig))
  (func (param i32)
    local.get 0
    (block (param i32)
      drop)))
```

The same type-use parser feeds function definitions, imports, tags, block types, `call_indirect`, `return_call_indirect`, and `return_call_ref`. Named type uses should resolve to an existing flat `TypeIdx`; inline signatures may reuse an equivalent function type or append one after all current rec-group members. When a fixture combines an explicit `(type $sig)` with inline `(param ...)` / `(result ...)` clauses, do not treat Starshine lowering success as proof that the inline signature matched `$sig`: current `wt_resolve_type_use(...)` returns the explicit type index and does not perform the official abbreviation/equality check. Validate the lowered module and add a focused lowering/validator test before using that combined shape as portable WAST evidence. That is why call, table, tail-call, and control-flow pages should link here for `TypeIdx` / type-use behavior.

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
- Type-use changes should cover at least one named `(type $sig)` site, one inline signature site, and one explicit `(type $sig)` plus inline-clause consistency case when that surface is touched; then validate the lowered module. Include a rec-group-before-inline-signature shape when changing implicit function type insertion or flat type-index accounting.
- Lowering changes should add focused coverage in [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) or a sibling `*_test.mbt`, then validate the lowered module with `@validate.validate_module(...)` when the fixture is meant to be semantically valid.
- Descriptor fixture lifts should cross-check the static custom-descriptor harness in [`../custom-descriptors/static-fixtures.md`](../custom-descriptors/static-fixtures.md), the `ref.get_desc` operand/result exactness flow in [`../custom-descriptors/ref-get-desc-fixture-path.md`](../custom-descriptors/ref-get-desc-fixture-path.md), and the exact-reference compatibility rules in [`../custom-descriptors/exact-reference-equivalence.md`](../custom-descriptors/exact-reference-equivalence.md).
- If upstream custom-descriptors remains struct-only, do not cite Starshine's array metadata lowering test as proposal evidence. Either keep it documented as a local broad surface or narrow the parser/validator in a dedicated behavior change.

## Sources

- Current GC type-use / subtyping refresh: [`../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md)
- Older WAST type-use/subtype refresh: [`../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md`](../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md)
- Older validator-side type-section refresh: [`../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md`](../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md), [`../validate/type-section-and-subtyping.md`](../validate/type-section-and-subtyping.md)
- Custom-descriptor `ref.get_desc` / exactness refresh: [`../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md`](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md)
- Custom-descriptor and GC-type snapshot: [`../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md`](../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md)
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
