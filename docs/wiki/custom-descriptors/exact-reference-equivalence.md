---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md
  - ../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md
  - ../raw/research/0029-2026-03-22-passive-typed-empty-elem-surface.md
  - ../raw/research/0030-2026-03-22-exact-struct-ref-equivalence.md
  - ../raw/research/0031-2026-03-22-exact-func-ref-equivalence.md
  - ../../../src/validate/match.mbt
  - ../../../src/validate/match_tests.mbt
  - ../../../src/wast/exact_type_equivalence_test.mbt
related:
  - ./static-fixtures.md
  - ./ref-get-desc-fixture-path.md
  - ../wast/gc-type-authoring.md
  - ../wast/element-segment-authoring.md
  - ../../../src/wast/passive_typed_elem_surface_test.mbt
  - ../../../src/wast/exact_type_equivalence_test.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/wast/spec_harness.mbt
---

# Exact Reference Equivalence

## Overview

Exact reference types are stricter than ordinary `(ref $t)` / `(ref null $t)` types. They mean “exactly this defined heap type shape,” not “this type or one of its declared subtypes.” Starshine needs this distinction for the custom-descriptor proposal because descriptor-bearing allocation and `ref.get_desc` exactness depend on whether the runtime object is known to be exactly the described type.

Two rules are easy to confuse:

1. **Subtype matching** still handles ordinary reference compatibility: non-null is a subtype of nullable, declared subtypes can match supertypes, and structs can widen by trailing fields when the target is inexact.
2. **Exact matching** is a structural-equivalence check for exact refs. Starshine does not require raw `TypeIdx` identity; it compares the full reachable defined-type closure with cycle guards so independently declared but structurally identical exact types can match.

This page owns the second rule. The `ref.get_desc` operand/result exactness flow lives in [`ref-get-desc-fixture-path.md`](ref-get-desc-fixture-path.md), and the broader WAST type authoring surface lives in [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md).

The current primary-source bridge is [`../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md`](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md). It rechecked the custom-descriptors proposal, the WebAssembly proposals tracker, the `ref.get_desc` bottom-input discussion, the V8 fix, and the current Starshine validator sources.

## Concrete Shapes

### Structs: identical closure matches even with different indices

```wat
(module
  (rec
    (type $a (struct (field i32)))
    (type $b (struct (field i32))))
  ;; Starshine can treat (ref (exact $a)) and (ref (exact $b)) as compatible
  ;; because their complete exact structural shape is equivalent.
)
```

This is the durable conclusion from the March exact-struct work and the current `exact_heaptype_matches(...)` path in [`src/validate/match.mbt`](../../../src/validate/match.mbt). The comparison descends through subtype metadata, supertypes, function params/results, struct fields, array fields, storage types, mutability, nullability, and exactness flags.

### Structs: subtype widening is not exact equivalence

```wat
(module
  (rec
    (type $base (struct (field i32)))
    (type $leaf (sub $base (struct (field i32) (field i64)))))
  ;; (ref (exact $leaf)) must not silently match (ref (exact $base)).
)
```

The ordinary inexact matching relation can accept a struct with extra trailing fields when matching a supertype-shaped target. Exact matching does **not** use that widening rule: the exact struct branch requires equal field count and recursively equal field shapes.

### Functions: exactness compares the full signature

```wat
(module
  (type $f0 (func (param i32) (result i64)))
  (type $f1 (func (param i32) (result i64)))
  ;; Exact function refs compare params and results structurally.
)
```

Function exactness uses the same structural-closure engine as structs. Parameter and result lists must have the same length and exact-compatible value types. That keeps exact function refs useful without tying fixtures to incidental flat type-index identity.

### Cycles: recursion is guarded, not flattened away

For recursive types, exact matching tracks visited `(TypeIdx, TypeIdx)` pairs. Seeing the same pair again means the recursive shape has already agreed along that path; it does not mean every unrelated cycle matches. Fuel based on the number of global types protects against accidental unbounded recursion.

## Starshine Implementation Map

| Layer | Owner files | Contract |
| --- | --- | --- |
| Matching entry point | [`src/validate/match.mbt`](../../../src/validate/match.mbt) | `Match::matches` dispatches ordinary ref matching and calls `exact_heaptype_matches(...)` when both sides need exact equality. |
| Exact structural engine | [`src/validate/match.mbt`](../../../src/validate/match.mbt) | `exact_typeidx_matches_fuel(...)`, `exact_subtype_matches_fuel(...)`, and helper functions compare subtype metadata, supertypes, comps, fields, storage, vals, and refs with cycle guards. |
| Focused tests | [`src/validate/match_tests.mbt`](../../../src/validate/match_tests.mbt), [`src/wast/exact_type_equivalence_test.mbt`](../../../src/wast/exact_type_equivalence_test.mbt) | Prove equal and unequal exact-shape behavior through validator-level helpers and WAST-facing fixtures. |
| Static fixture policy | [`custom-descriptors/static-fixtures.md`](static-fixtures.md), [`src/wast/spec_harness.mbt`](../../../src/wast/spec_harness.mbt) | Keeps custom-descriptor static assertion success separate from runtime skips and mixed-runtime fixture debt. |
| Element declaration support | [`../wast/element-segment-authoring.md`](../wast/element-segment-authoring.md), [`src/wast/passive_typed_elem_surface_test.mbt`](../../../src/wast/passive_typed_elem_surface_test.mbt) | The `exact.wast` front-end path also depends on typed empty element syntax; declarative-mode preservation has its own WAST caveat. |

## Invariants And Edge Cases

- **Exact-to-exact is structural, not index-only.** Two different flat type indices may match if their entire reachable shapes match.
- **Exact matching preserves declared-supertype metadata.** The structural comparison includes `final`, supertype lists, and type metadata, so descriptor-bearing types with different `describes` / `descriptor` relationships do not become accidentally equal.
- **Exact refs are not subtype wildcards.** A subtype/supertype pair that is valid under ordinary inexact matching should still fail exact matching when the full shape differs.
- **Bottom-null families are special at the reference-matching boundary.** The exact-ref matcher has explicit paths for inexact abstract bottom refs (`none` for struct/array targets, `nofunc` for function targets) when the expected type is exact. The `ref.get_desc` page explains why that matters for exact descriptor results.
- **Proposal caveat:** the upstream custom-descriptors proposal is still Phase 3 and currently restricts descriptor metadata to struct type definitions. Starshine's exact matching engine can structurally compare functions and arrays too because exact refs and local tests use the shared type system; do not infer that every such local surface is standardized descriptor syntax.

## Signoff Guidance

When changing exact reference matching:

1. Add the smallest failing fixture first in [`src/validate/match_tests.mbt`](../../../src/validate/match_tests.mbt) or [`src/wast/exact_type_equivalence_test.mbt`](../../../src/wast/exact_type_equivalence_test.mbt).
2. Include both positive and negative shapes: equal different-index structs/functions, trailing-field struct non-equivalence, metadata mismatch, nullable mismatch, exactness-flag mismatch, and recursive-cycle cases when relevant.
3. If the change affects descriptor-bearing types, also rerun or update the static-fixture policy in [`static-fixtures.md`](static-fixtures.md) and the `ref.get_desc` flow in [`ref-get-desc-fixture-path.md`](ref-get-desc-fixture-path.md).
4. Keep WAST declarative element evidence routed through [`../wast/element-segment-authoring.md`](../wast/element-segment-authoring.md); exact-reference changes should not silently claim that current WAST lowering preserves declarative element mode.

## Sources

- Current primary-source bridge: [`../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md`](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md)
- GC/custom-descriptor source snapshot: [`../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md`](../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md)
- Archived research docs: [`../raw/research/0029-2026-03-22-passive-typed-empty-elem-surface.md`](../raw/research/0029-2026-03-22-passive-typed-empty-elem-surface.md), [`../raw/research/0030-2026-03-22-exact-struct-ref-equivalence.md`](../raw/research/0030-2026-03-22-exact-struct-ref-equivalence.md), [`../raw/research/0031-2026-03-22-exact-func-ref-equivalence.md`](../raw/research/0031-2026-03-22-exact-func-ref-equivalence.md)
- Current implementation and tests: [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt), [`../../../src/validate/match_tests.mbt`](../../../src/validate/match_tests.mbt), [`../../../src/wast/exact_type_equivalence_test.mbt`](../../../src/wast/exact_type_equivalence_test.mbt)
