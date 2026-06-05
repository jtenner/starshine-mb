---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md
  - ../raw/wasm/2026-06-04-custom-descriptor-current-recheck.md
  - ../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md
  - ../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/typecheck_negative_tests.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - ./ref-get-desc-fixture-path.md
  - ./exact-reference-equivalence.md
  - ./static-fixtures.md
  - ../wast/reference-instruction-authoring.md
  - ../wast/gc-aggregate-instruction-authoring.md
  - ../wast/gc-type-authoring.md
  - ../validate/type-section-and-subtyping.md
  - ../validate/stack-polymorphism-and-bottom.md
  - ../wasm-feature-status-and-proposal-boundaries.md
---

# Custom-Descriptor Instruction Surface

## Overview

Use this page when a fixture, validator change, generator change, or pass touches Starshine's custom-descriptor **instructions**:

- allocation forms: `struct.new_desc` and `struct.new_default_desc`;
- descriptor retrieval: `ref.get_desc`;
- descriptor-aware reference predicate/cast forms: `ref.test_desc`, `ref.test_desc_null`, `ref.cast_desc_eq`, and `ref.cast_desc_eq_null`.

The concept is easiest to learn in two steps. First, a **described struct** points at a **descriptor struct** through type metadata. Second, descriptor-specific instructions preserve the exact relationship between those two structs so a runtime cannot allocate or cast a described base type with a descriptor belonging to an incompatible subtype.

The current primary-source and local-code bridge is [`../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md). It rechecked the Phase-3 custom-descriptors proposal, the proposal issue/V8 fix for `ref.get_desc` bottom inputs, and current Starshine WAST/core/binary/validator/generator evidence. Keep the feature-status caveat visible: **Custom Descriptors is still an active Phase-3 proposal, not stable Core WebAssembly 3.0.** Starshine implements a useful local/proposal-shaped instruction subset, while broader JS prototype behavior and branch descriptor-cast forms remain undocumented local support.

## Beginner Mental Model

A descriptor is a separate object that describes another struct type. In a descriptor-bearing pair:

```wat
(rec
  (type $node
    (descriptor $node_desc)
    (struct (field (ref null $node))))
  (type $node_desc
    (describes $node)
    (struct)))
```

- `$node` is the described type;
- `$node_desc` is the descriptor type;
- the metadata relationship is part of type identity and must agree in both directions;
- allocation of `$node` needs a descriptor value of type `(ref null (exact $node_desc))`;
- descriptor retrieval from a `$node` value returns a non-null `$node_desc` reference whose exactness depends on the input exactness.

Ordinary `struct.new` is intentionally not enough for descriptor-bearing structs: it could allocate a described value without proving which descriptor object describes it. The descriptor-aware constructors take the descriptor operand explicitly.

## Layer Model

| Layer | Owner | Current contract |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Accepts metadata keywords plus descriptor allocation/retrieval/test/cast text. Parser tests cover `ref.get_desc`, `ref.test_desc*`, `ref.cast_desc_eq*`, and `struct.new*_desc`. |
| WAST lowerer/printer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Resolves type immediates to flat `TypeIdx` values and roundtrips descriptor instruction spellings. |
| Core instruction model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Carries `StructNewDesc`, `StructNewDefaultDesc`, `RefGetDesc`, `RefTestDesc`, and `RefCastDescEq`. |
| Binary codec | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) | Encodes/decodes descriptor instructions and has a focused descriptor instruction roundtrip test. Binary success is not validation success. |
| Type validation | [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`src/validate/env.mbt`](../../../src/validate/env.mbt), [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/match.mbt`](../../../src/validate/match.mbt) | Enforces struct-only descriptor metadata, descriptor/describes agreement, exact descriptor operands for allocation, exact/inexact `ref.get_desc` results, and descriptor-compatible test/cast targets. |
| Valid/invalid generation | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt) | Valid generation covers descriptor-bearing pairs and descriptor ops; negative tests cover non-reference operands, invalid target indices, incompatible hierarchies, and inexact descriptor allocation operands. |

## Current Instruction Matrix

| Instruction family | WAST text today | Core/binary/validator today | Stack shape | Result | Main caveat |
| --- | --- | --- | --- | --- | --- |
| `struct.new_desc $T` | Yes | Yes | field values for `$T`, then `(ref null (exact descriptor($T)))` | `(ref (exact $T))` | `$T` must be a descriptor-bearing struct; ordinary fields are still validated in declaration order. |
| `struct.new_default_desc $T` | Yes | Yes | `(ref null (exact descriptor($T)))` | `(ref (exact $T))` | Every field of `$T` must have a default value, just like ordinary `struct.new_default`. |
| `ref.get_desc $T` | Yes | Yes | reference-or-bottom compatible with `$T` | non-null descriptor ref; exact iff operand is exact/bottom | Immediate names the described type `$T`, not the descriptor type. |
| `ref.test_desc[_null] ht` | Yes | Yes | concrete reference operand | `i32` | Predicate form: no stack-polymorphic bottom shortcut in reachable code; target and operand must be descriptor-compatible. |
| `ref.cast_desc_eq[_null] ht` | Yes | Yes | reference-or-bottom operand | target reference type | Trapping/refining cast form: accepts unreachable bottom, otherwise checks descriptor compatibility. |
| Proposal branch descriptor casts | No documented Starshine WAST/core support | No focused local evidence | N/A | N/A | Do not infer support from non-branch `ref.cast_desc_eq` or from Binaryen descriptor-cast pass docs. |

For ordinary official `ref.test` / `ref.cast` and `br_on_*`, use [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md). For ordinary GC struct and array instructions, use [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md). Descriptor instructions are a proposal/local lane with stricter descriptor metadata and exactness rules.

## Concrete WAST Shapes

### Descriptor-aware allocation

```wat
(module
  (rec
    (type $node
      (descriptor $node_desc)
      (struct (field (ref null $node))))
    (type $node_desc
      (describes $node)
      (struct)))
  (func (result (ref (exact $node)))
    (struct.new_desc $node
      (ref.null none)
      (struct.new $node_desc))))
```

The last operand is the descriptor. It must be nullable and exact for `$node_desc`, so `(ref null $node_desc)` is not precise enough for the descriptor operand. This exactness requirement is what prevents allocating a base described struct with a subtype's descriptor.

### Default descriptor allocation

```wat
(module
  (rec
    (type $cell
      (descriptor $cell_desc)
      (struct (field i32)))
    (type $cell_desc
      (describes $cell)
      (struct)))
  (func (result (ref (exact $cell)))
    (struct.new_default_desc $cell
      (struct.new $cell_desc))))
```

This is valid only when all fields in `$cell` have defaults. If a non-null reference field has no default, validation must reject just as it rejects ordinary `struct.new_default`.

### Descriptor retrieval and exact result typing

```wat
(module
  (rec
    (type $node (descriptor $node_desc) (struct))
    (type $node_desc (describes $node) (struct)))
  (func (param (ref (exact $node))) (result (ref (exact $node_desc)))
    (ref.get_desc $node
      (local.get 0))))
```

`ref.get_desc` inspects `$node`, resolves its descriptor type to `$node_desc`, and returns a non-null reference. Exact operands and stack-polymorphic bottom produce exact descriptor references. Inexact-compatible operands produce non-null but inexact descriptor references. The focused exactness and bottom-input flow lives in [`ref-get-desc-fixture-path.md`](ref-get-desc-fixture-path.md).

### Descriptor predicate and cast forms

```wat
(module
  (type $d (struct))
  (func (param (ref null $d)) (result i32)
    (ref.test_desc_null $d
      (local.get 0)))
  (func (param (ref null $d)) (result (ref null $d))
    (ref.cast_desc_eq_null $d
      (local.get 0))))
```

`ref.test_desc_null` asks a question and returns `i32`. `ref.cast_desc_eq_null` refines/traps and returns the target reference type. Both forms validate the target reference type first and then require descriptor compatibility with the operand. These are descriptor-family forms, not proof that ordinary `ref.test` / `ref.cast` WAST text exists locally.

## Invariants And Edge Cases

- **Struct-only validation is the current proposal-aligned rule.** Starshine WAST parsing/lowering still carries local array descriptor metadata in tests, but `validate_descriptor_metadata_group(...)` rejects non-struct descriptor metadata. Treat array metadata success before validation as parser/lowerer compatibility evidence, not descriptor conformance.
- **Descriptor metadata must agree.** If `$A` says `(descriptor $D)`, `$D` must say `(describes $A)` where the validator can see the relationship. Descriptor-less subtypes cannot silently extend descriptor-bearing supertypes.
- **The `ref.get_desc` immediate names the described type.** Do not rewrite it to the descriptor type. The descriptor type is looked up through metadata.
- **Exactness is semantic, not display-only.** `struct.new_desc` and `struct.new_default_desc` require nullable exact descriptor references and produce exact described references; `ref.get_desc` preserves exactness when the operand proves exact.
- **Bottom is exact enough only in the documented places.** The proposal issue/V8 fix makes `ref.get_desc` bottom/`none` exactness concrete. Starshine also lets `ref.cast_desc_eq` accept stack-polymorphic bottom through the ordinary typechecker bottom path. Do not generalize that into ignoring concrete incompatible references.
- **Descriptor-compatible is not arbitrary subtype-compatible.** `ref.test_desc*` and `ref.cast_desc_eq*` route through `descriptor_compatible(...)`, which handles exact structural matching and abstract bottom-family rules. Keep [`exact-reference-equivalence.md`](exact-reference-equivalence.md) nearby when changing that relation.
- **JS interop is not locally proven.** The proposal's JS prototype/embedding design is outside current Starshine runtime evidence. Static-harness success and module validation only prove static semantics.

## Rewrite And Signoff Checklist

1. **Remap all descriptor carriers together.** Type remapping must update `describes` / `descriptor` metadata, `StructNewDesc` / `StructNewDefaultDesc` type immediates, `RefGetDesc` immediates, descriptor cast/test heap types, exact reference annotations, names, and debug metadata together.
2. **Preserve ordinary field/default checks.** Descriptor constructors add a descriptor operand; they do not remove ordinary struct field typing, packed/reference validity, or defaultability requirements.
3. **Keep trap and predicate behavior separate.** `ref.test_desc*` returns an `i32` predicate. `ref.cast_desc_eq*` can trap/refine. Optimizers must not replace one with the other without preserving trap behavior and result type.
4. **Validate after any descriptor rewrite.** Common failures are `type without descriptor`, `descriptor/describes clauses must agree`, `descriptor target must be a struct type`, `struct.new_desc requires a descriptor-bearing struct type`, `type mismatch` for inexact descriptor operands, and `target does not match operand type` for descriptor test/cast instructions.
5. **Use the right fixture layer.** Use WAST fixtures for text/lowering behavior, core or binary fixtures for instruction-carrier rewrites, validator tests for stack and exactness rules, and static-harness fixtures only for script/static assertion coverage.
6. **Keep proposal status visible.** When documenting these instructions, cite this page or [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md) so readers do not confuse Starshine's proposal/local subset with stable Core WebAssembly 3.0.

## Sources

- Current instruction-surface bridge: [`../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md)
- Broader current descriptor recheck: [`../raw/wasm/2026-06-04-custom-descriptor-current-recheck.md`](../raw/wasm/2026-06-04-custom-descriptor-current-recheck.md)
- Earlier exactness/source bridge: [`../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md`](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md)
- Earlier GC/custom-descriptor source snapshot: [`../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md`](../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md)
- Focused living companions: [`ref-get-desc-fixture-path.md`](ref-get-desc-fixture-path.md), [`exact-reference-equivalence.md`](exact-reference-equivalence.md), [`static-fixtures.md`](static-fixtures.md), [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../validate/type-section-and-subtyping.md`](../validate/type-section-and-subtyping.md), [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md)
- Current implementation/tests: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt)
