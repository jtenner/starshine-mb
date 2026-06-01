---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md
  - ../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md
  - ../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate_proof/rectype_index.mbt
related:
  - module-validation-phases.md
  - constant-expressions.md
  - import-export-and-external-type-matching.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../wast/gc-type-authoring.md
  - ../custom-descriptors/ref-get-desc-fixture-path.md
  - ../custom-descriptors/exact-reference-equivalence.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../validation/moonbit-prove-strategy.md
---

# Type-Section Validation And Subtyping

## Overview

The type section is the root of Starshine's module type context. It defines every module-level function, struct, and array type that later sections and instructions name through `TypeIdx`, `HeapType`, `RefType`, function signatures, table element types, globals, tags, casts, GC aggregate instructions, element payloads, and custom-descriptor metadata.

Use this page for the **validator** contract: what `validate_typesec(...)` accepts, what it normalizes, and what later phases may rely on. Use [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md) for text syntax, `(rec ...)` authoring, type-use abbreviations, parser/lowerer behavior, and flat-index examples before validation. Use [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md) for binary section ids, `TypeSec(Array[RecType])`, and whole-module remap obligations.

The current source bridge is [`../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md`](../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md). It rechecks current WebAssembly Core 3.0 type syntax, binary type encoding, validation, matching, and module-validation sources plus Starshine validator/proof-helper evidence.

## Beginner Model

A recursive group is a scope for type definitions, but its members still become flat module type indices:

```wat
(module
  (rec
    (type $node (struct (field (ref null $node)))) ;; TypeIdx 0
    (type $box  (struct (field (ref null $node))))) ;; TypeIdx 1
  (type $leaf (sub $node (struct)))                 ;; TypeIdx 2
  (func (result (ref null $node))
    (ref.null $node)))
```

During validation Starshine needs two views at once:

1. a temporary **recursive view** so group-local `RecIdx` references can resolve while the current group validates; and
2. the permanent **global view** that later code uses after all group-local references have been normalized to absolute `TypeIdx` values.

That is why a parsed or lowered type is not automatically valid. The type section must still prove that referenced types exist, field/storage/reference types are valid, supertypes are compatible, descriptor metadata is consistent, and exact references name defined heap types.

## Starshine Validation Flow

`validate_typesec(typesec, env0)` in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) is incremental:

1. Start with an `Env` whose `global_types` array contains any already-accepted earlier types.
2. For each `RecType`, call `validate_rectype_and_extend(...)`.
3. Build a temporary recursive context with the current group visible through `env_with_rectype(...)`.
4. Run `Validate for RecType`, which validates all member `SubType` values and then runs descriptor metadata group checks.
5. Normalize `RecIdx` occurrences in supertypes and descriptor metadata to absolute `TypeIdx` values with `normalize_rectype_for_global_env(...)`.
6. Append the normalized subtype members to `Env.global_types` with `Env::append_rectype_types(...)`.

The permanent validation environment in [`src/validate/env.mbt`](../../../src/validate/env.mbt) then resolves later type references through:

| Resolver | Purpose |
| --- | --- |
| `resolve_subtype(TypeIdx)` / `resolve_typeidx_subtype(TypeIdx)` | Finds a normalized `SubType` by global `TypeIdx`, or by the latest `RecIdx` only while a recursive context is active. |
| `resolve_comptype(TypeIdx)` | Extracts the underlying `func`, `struct`, or `array` composite type. |
| `resolve_functype(TypeIdx)` | Accepts only function composite types for function sections, block types, tags, calls, and type-use sites. |
| `resolve_heaptype_subtype(HeapType)` | Bridges reference/cast/exactness validation from heap types back to subtypes when the heap type is defined. |

## Subtyping And Matching Rules

`Validate for SubType` checks each declared supertype by resolving it and requiring the child composite type to match the supertype composite type. The executable matching relation lives in [`src/validate/match.mbt`](../../../src/validate/match.mbt), not in the parser.

Important matching rules future maintainers should keep in mind:

- **Function types** are contravariant in parameters and covariant in results.
- **Struct types** can match a prefix of fields: a subtype may have extra trailing fields, but the shared prefix must match field-by-field.
- **Array types** match through their single field type.
- **Immutable fields** are covariant; **mutable fields** are invariant.
- **Reference types** combine heap-type matching with nullability (`non-null <: nullable`) and exactness constraints.
- **Abstract heap types** keep the usual families visible: `struct` / `array` / `i31` under `eq`, `eq` under `any`, `nofunc` under `func`, `noextern` under `extern`, and so on.

The official Core 3.0 rules are stricter than mere Starshine parser acceptance. As of this review, the documented and fuzzed local TypeSection invalid families cover out-of-range supertypes, incompatible supertype shapes, focused function parameter/result variance mismatches, mutable struct-field variance mismatches, descriptor metadata on non-struct types, and descriptor-pair field references to missing heap types. Do **not** claim full coverage of every official side condition, such as single-supertype, earlier-supertype, or final-supertype restrictions, unless a focused validator test or implementation audit proves it.

## Descriptor Metadata And Exact References

Custom descriptors add proposal-local metadata on top of the core type-section flow. Starshine validates that surface in the same `RecType` group pass, but the durable proposal explanation belongs in the custom-descriptor pages.

Current local descriptor checks in [`validate_descriptor_metadata_group(...)`](../../../src/validate/validate.mbt):

- `describes` / `descriptor` clauses may appear only on struct types;
- `describes` targets must be valid, previously defined struct types;
- `descriptor` targets must be valid struct types;
- paired `descriptor` and `describes` clauses must agree with each other;
- descriptor-bearing subtypes cannot silently drop descriptor metadata required by their supertypes; and
- describing subtypes must stay compatible with describing supertypes.

Exact references are validated separately in `Validate for RefType`: exact refs require a defined heap type. The deeper exact structural-equivalence and `ref.get_desc` result rules live in [`../custom-descriptors/exact-reference-equivalence.md`](../custom-descriptors/exact-reference-equivalence.md) and [`../custom-descriptors/ref-get-desc-fixture-path.md`](../custom-descriptors/ref-get-desc-fixture-path.md).

## Concrete Shapes

### Valid recursive self-reference

```wat
(module
  (rec
    (type $node (struct (field (mut (ref null $node)))))))
```

The group-local self reference is valid because `validate_rectype_and_extend(...)` validates under a recursive context. After the group passes validation, Starshine normalizes that local reference so later phases do not need the original source-group context.

### Invalid supertype index

A lowered module that adds a subtype with `TypeIdx(9999)` as its supertype should fail the TypeSection family. This is the invalid-AST strategy `InvalidSubtypeSuperIndex` in [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt).

```text
SubType(final=false, supers=[TypeIdx(9999)], comp=func [] -> [])
```

### Invalid supertype shape

A function subtype cannot extend an incompatible function type. Starshine's `InvalidSubtypeSuperShape` mutation first appends a `func [] -> []` supertype, then appends a `func [i32] -> []` child that names it. Validation rejects this as a TypeSection-family shape mismatch.

### Invalid function subtype variance

Function subtype matching is contravariant in parameters and covariant in results. The `InvalidSubtypeFuncVariance` mutation appends a supertype `func [(ref any)] -> [(ref eq)]` and a child `func [(ref eq)] -> [(ref any)]`, so the child accepts a narrower parameter and returns a wider result than its declared supertype permits. The focused repair fixture flips the relation to a valid supertype `func [(ref eq)] -> [(ref any)]` with child `func [(ref any)] -> [(ref eq)]`.

### Descriptor pair inside one rec group

```wat
(module
  (rec
    (type $t
      (descriptor $d)
      (struct))
    (type $d
      (describes $t)
      (struct))))
```

This shape depends on both recursive-group scoping and descriptor-pair agreement. The WAST parser/lowerer examples are in [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md); the validator-specific behavior is the descriptor metadata group check described above.

### Descriptor metadata on non-struct type

```text
SubType(comp=func [] -> [], metadata={ descriptor = TypeIdx(0) })
```

Starshine rejects this through `validate_descriptor_metadata_group(...)`. The invalid-AST strategy is `DescriptorOnFuncType`.

### Invalid final supertype edge

A lowered module can otherwise declare a subtype whose supertype is marked `final`. Starshine rejects that as a TypeSection-family invalid subtype while still allowing a `final` subtype to extend a non-final supertype. The invalid-AST strategy is `InvalidSubtypeFinalSuper` with stable id `invalid-subtype-final-super`; this isolates final-supertype policy from supertype shape, variance, index, and cycle failures.

### Invalid recursive-group supertype cycle

A lowered module can otherwise form a recursive group whose members name each other as supertypes. Starshine now rejects that graph as a TypeSection-family `subtype supertype cycle` before descriptor checks. The invalid-AST strategy is `InvalidSubtypeSuperCycle` with stable id `invalid-subtype-super-cycle`; this classifies the refinement as a supertype-cycle family, distinct from descriptor-pair agreement and missing-index failures.

### Invalid descriptor field heap type

A lowered module can otherwise form a valid descriptor/describes pair while placing a field on the descriptor type whose reference heap type points past the flattened type section. Starshine rejects this through the ordinary type-reference validation path while the descriptor edge keeps the failure distinct from table/global ref-type strategies. The invalid-AST strategy is `InvalidDescriptorFieldRefType` with stable id `invalid-descriptor-field-ref-type`.

## Rewrite And Signoff Guidance

When changing type-section validation, WAST type lowering, or a pass that rewrites types:

1. **Keep parser/lowerer success separate from validation success.** Parsing `(rec ...)`, `(sub ...)`, `final`, `describes`, or `descriptor` proves syntax only.
2. **Preserve flat type-index accounting.** Every member of every `RecType` contributes a `TypeIdx`; inline function types appended by WAST lowering must come after existing flattened members.
3. **Normalize group-local references before later phases.** Later validation phases should resolve ordinary absolute `TypeIdx` values from `Env.global_types`; do not leak stale group-local `RecIdx` values into pass output or binary emission.
4. **Audit every type carrier after rewrites.** Function signatures, block types, table element types, global types, tag types, casts, GC constructors/accessors, element segment types, imports/exports, and name maps can all carry type references.
5. **Use focused invalid families.** Extend `InvalidSubtypeSuperIndex`, `InvalidSubtypeSuperShape`, or `DescriptorOnFuncType` when adding visible rejection behavior; add a new stable invalid strategy if the user-visible family or semantics differ.
6. **Run the proof lane when touching index arithmetic.** `src/validate_proof/rectype_index.mbt` proves the suffix/group-relative helpers imported by the validator. Follow [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md) for `moon prove src/validate_proof` expectations.

## Sources

- Source bridge: [`../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md`](../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md)
- WAST type-use and subtype source bridge: [`../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md`](../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md)
- Custom-descriptor exactness bridge: [`../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md`](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md)
- Validator implementation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt)
- Invalid fuzzing: [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`../../../src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt)
- Proof helpers: [`../../../src/validate_proof/rectype_index.mbt`](../../../src/validate_proof/rectype_index.mbt), [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md)
- Companion pages: [`module-validation-phases.md`](module-validation-phases.md), [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md), [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md), [`../custom-descriptors/exact-reference-equivalence.md`](../custom-descriptors/exact-reference-equivalence.md), [`../custom-descriptors/ref-get-desc-fixture-path.md`](../custom-descriptors/ref-get-desc-fixture-path.md)
