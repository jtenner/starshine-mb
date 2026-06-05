---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md
  - ../raw/wasm/2026-06-04-custom-descriptor-current-recheck.md
  - ../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md
  - ../raw/wasm/2026-05-20-type-section-validation-and-subtyping-refresh.md
  - ../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md
  - ../raw/research/0022-2026-03-22-ref-get-desc-type-immediate.md
  - ../raw/research/0023-2026-03-22-wast-legacy-gc-ref-aliases.md
  - ../raw/research/0024-2026-03-22-wast-struct-get-surface.md
  - ../raw/research/0025-2026-03-22-wast-global-import-exact-ref-types.md
  - ../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md
  - ../raw/research/0027-2026-03-22-exact-ref-null-immediates.md
  - ../raw/research/0028-2026-03-22-ref-get-desc-bottom-null-operands.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/typecheck_negative_tests.mbt
related:
  - ./descriptor-instruction-surface.md
  - ../wast/gc-type-authoring.md
  - ../wast/reference-instruction-authoring.md
  - ../validate/type-section-and-subtyping.md
  - ../validate/stack-polymorphism-and-bottom.md
  - ./static-fixtures.md
  - ./exact-reference-equivalence.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/legacy_gc_aliases_test.mbt
  - ../../../src/wast/struct_get_surface_test.mbt
  - ../../../src/wast/global_import_ref_type_test.mbt
  - ../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/lib/types.mbt
---

# `ref_get_desc.wast` Fixture Path

## Overview

`ref.get_desc` is the custom-descriptors instruction that asks for the descriptor object associated with a described struct type. In Starshine it is a full-stack feature path:

1. WAST accepts `ref.get_desc` with a type immediate.
2. Lowering resolves that immediate to a flat `TypeIdx`.
3. Binary encode/decode preserves the instruction.
4. Typechecking verifies that the inspected type has descriptor metadata, that the operand is compatible with the inspected type, and that the result exactness follows the operand.
5. The static harness keeps `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` on the checked static path while separating runtime-skip debt from conformance evidence.

Use this page for `ref.get_desc` fixture, lowering, validator, generator, or pass work. Use [`descriptor-instruction-surface.md`](descriptor-instruction-surface.md) for the broader descriptor-aware instruction family (`struct.new_desc`, `struct.new_default_desc`, `ref.test_desc*`, and `ref.cast_desc_eq*`), [`exact-reference-equivalence.md`](exact-reference-equivalence.md) for the lower-level exact-ref structural equality rule, [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md) for authoring `describes` / `descriptor` metadata, and [`../validate/type-section-and-subtyping.md`](../validate/type-section-and-subtyping.md) for the validator phase that proves descriptor metadata pairs are structurally valid before instructions can rely on them.

The current instruction-surface bridge is [`../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md), building on [`../raw/wasm/2026-06-04-custom-descriptor-current-recheck.md`](../raw/wasm/2026-06-04-custom-descriptor-current-recheck.md), which supersedes the source-freshness layer of the May [`ref.get_desc` / exactness refresh](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md). These rechecks covered the Phase-3 custom-descriptors proposal, the upstream bottom-input discussion, the V8 fix, and current Starshine parser/lowerer/typechecker/static-harness code. Durable conclusion: proposal descriptor metadata is still struct-oriented, while Starshine WAST can still parse/lower broader local array-metadata fixtures that validation rejects as non-struct descriptor metadata.

## Concrete Flow

### Minimal described/descriptor pair

```wat
(module
  (rec
    (type $node (descriptor $node_desc)
      (struct))
    (type $node_desc (describes $node)
      (struct)))
  (func (param (ref $node)) (result (ref $node_desc))
    (local.get 0)
    (ref.get_desc $node)))
```

The inspected type immediate is `$node`, not `$node_desc`. Starshine resolves that source id through `wt_resolve_named_or_num_index(...)` during lowering and stores `Instruction::RefGetDesc(TypeIdx($node))` in the core expression.

### Exact operand keeps exact descriptor result

```wat
(module
  (rec
    (type $node (descriptor $node_desc) (struct))
    (type $node_desc (describes $node) (struct)))
  (func (param (ref (exact $node))) (result (ref (exact $node_desc)))
    (local.get 0)
    (ref.get_desc $node)))
```

`Env::descriptor_result_type(...)` checks the operand against both the ordinary expected type `(ref $node)` and the exact expected type `(ref (exact $node))`. If the operand matches the exact target, the result is a non-null exact descriptor reference. If the operand only matches the inexact target, the result is non-null but inexact.

### Bottom/null operands are exact enough

```wat
(module
  (rec
    (type $node (descriptor $node_desc) (struct))
    (type $node_desc (describes $node) (struct)))
  (func (result (ref (exact $node_desc)))
    (ref.null none)
    (ref.get_desc $node)))
```

The custom-descriptors issue and V8 fix rechecked for this page both call out the bottom-input edge case: `none` / unreachable inputs are more specific than an exact target, so they produce an exact descriptor result. Starshine's current implementation has the same behavior through two paths:

- `typecheck_ref_get_desc(...)` gets `None` from `pop_ref_or_bot()` for unreachable stack-polymorphic input, and `Env::descriptor_result_type(...)` treats the missing concrete operand as exact. The general bottom-value rule and concrete-stack-junk boundary live in [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md).
- `Match::matches(...)` has an exact-target path where inexact abstract bottom refs such as `none` (for struct/array targets) and `nofunc` (for function targets) can match exact defined targets.

### Missing descriptor or wrong operand remains invalid

```wat
(module
  (type $plain (struct))
  (func (param (ref $plain))
    (local.get 0)
    (ref.get_desc $plain))) ;; invalid: type without descriptor
```

The validator starts by resolving the inspected type through `Env::resolve_struct_descriptor_type(...)`. That path requires a struct subtype with descriptor metadata. A non-reference operand, an unknown type index, a type without a descriptor, or an operand from an incompatible hierarchy is rejected by `typecheck_ref_get_desc(...)` / `descriptor_result_type(...)`; focused negative tests live in [`src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt).

## Starshine Implementation Map

| Layer | Owner files | Current contract |
| --- | --- | --- |
| Text keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`src/wast/lexer.mbt`](../../../src/wast/lexer.mbt) | Recognizes `ref.get_desc` and parses its `Index` immediate; parses `describes` / `descriptor` metadata clauses with `describes` before `descriptor`. |
| Text printer | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Prints `ref.get_desc <idx>` and type metadata clauses so roundtrip tests expose lost immediates or metadata. |
| Lowering | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) | Resolves the instruction immediate and metadata ids to flat `TypeIdx` values; validates descriptor metadata order in WAST-to-module tests. |
| Core/binary | [`src/lib/types.mbt`](../../../src/lib/types.mbt), [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) | Carries `Instruction::RefGetDesc(TypeIdx)` through core construction and binary roundtrip. |
| Typechecking | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/env.mbt`](../../../src/validate/env.mbt), [`src/validate/match.mbt`](../../../src/validate/match.mbt) | Pops a reference-or-bottom operand, checks the inspected type's descriptor metadata and operand compatibility, and computes exact/non-exact result type. |
| Static fixture harness | [`custom-descriptors/static-fixtures.md`](static-fixtures.md), [`src/wast/spec_harness.mbt`](../../../src/wast/spec_harness.mbt) | Keeps `ref_get_desc.wast` on the static path and prevents runtime skips from being counted as descriptor conformance. |

## Invariants And Edge Cases

- **The immediate names the described type.** Do not rewrite `ref.get_desc $node` to point at `$node_desc`; the descriptor type is reached through `$node`'s metadata.
- **The inspected type must be a descriptor-bearing struct.** Current upstream proposal text is struct-only, and Starshine's validator `resolve_struct_descriptor_type(...)` follows that rule even though some WAST metadata parsing/lowering tests still cover local array metadata as proposal-tracking evidence. If a fixture reaches validation with array descriptor metadata, it is negative validation evidence, not a successful `ref.get_desc` surface.
- **Exactness is dataflow-sensitive.** Exact operands and bottom/unreachable operands produce exact descriptor refs. Inexact-compatible operands produce inexact descriptor refs.
- **Bottom-null is not a generic cast escape hatch.** `none` and `nofunc` are accepted only where their abstract family is compatible with the expected exact defined type. Other incompatible refs still fail.
- **Descriptor metadata is type identity.** Rewriting passes that reorder, deduplicate, remove, or remap types must update `describes`, `descriptor`, `ref.get_desc` immediates, exact reference types, constructor/cast descriptor operands, and any name/debug maps together.
- **Static spec success is not runtime JS interop proof.** The custom-descriptors proposal includes JS interop motivation and prototype behavior; Starshine's current static harness coverage is about text/lowering/validation semantics.

## Pass And Rewrite Checklist

A pass that mutates type indices or descriptor-bearing types must preserve every carrier:

1. `TypeMetadata.describes` and `TypeMetadata.descriptor` on all affected type definitions.
2. `Instruction::RefGetDesc(TypeIdx)` immediates.
3. Exact `(ref (exact $t))` / nullable exact `(ref null (exact $t))` type annotations.
4. Descriptor-aware constructors, predicate/cast operations, and current proposal-local caveats documented in [`descriptor-instruction-surface.md`](descriptor-instruction-surface.md), with WAST routing through [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md) and [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md).
5. Static fixtures or reduced tests that assert exact descriptor results from `none` / bottom inputs.
6. Binary encode/decode and name/debug section expectations if the pass rewrites type order.

After any rewrite, rerun validation. The common failure modes are `type without descriptor`, `ref.get_desc target does not match operand type`, and exact result drift caused by accidentally retagging an exact operand as inexact.

## Signoff Guidance

- For parser/printer changes, add focused tests near the existing descriptor keyword and module WAST tests in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) or [`src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt).
- For lowering changes, use [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) fixtures that inspect the lowered `TypeIdx` / metadata shape and then call `@validate.validate_module(...)` when the fixture should be valid.
- For validator changes, add or update positive tests in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) and negative tests in [`src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt).
- For exactness changes, also update [`exact-reference-equivalence.md`](exact-reference-equivalence.md) and the structural matching tests in [`src/validate/match_tests.mbt`](../../../src/validate/match_tests.mbt).
- For spec-harness changes, keep pass/skip/fail semantics routed through [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md) and [`static-fixtures.md`](static-fixtures.md).

## Sources

- Current instruction-surface bridge: [`../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md), [`descriptor-instruction-surface.md`](descriptor-instruction-surface.md)
- Current primary-source bridge: [`../raw/wasm/2026-06-04-custom-descriptor-current-recheck.md`](../raw/wasm/2026-06-04-custom-descriptor-current-recheck.md)
- Earlier exactness/source bridge: [`../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md`](../raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md)
- GC/custom-descriptor source snapshot: [`../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md`](../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md)
- Archived fixture-path research: [`../raw/research/0022-2026-03-22-ref-get-desc-type-immediate.md`](../raw/research/0022-2026-03-22-ref-get-desc-type-immediate.md), [`../raw/research/0023-2026-03-22-wast-legacy-gc-ref-aliases.md`](../raw/research/0023-2026-03-22-wast-legacy-gc-ref-aliases.md), [`../raw/research/0024-2026-03-22-wast-struct-get-surface.md`](../raw/research/0024-2026-03-22-wast-struct-get-surface.md), [`../raw/research/0025-2026-03-22-wast-global-import-exact-ref-types.md`](../raw/research/0025-2026-03-22-wast-global-import-exact-ref-types.md), [`../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md`](../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md), [`../raw/research/0027-2026-03-22-exact-ref-null-immediates.md`](../raw/research/0027-2026-03-22-exact-ref-null-immediates.md), [`../raw/research/0028-2026-03-22-ref-get-desc-bottom-null-operands.md`](../raw/research/0028-2026-03-22-ref-get-desc-bottom-null-operands.md)
- Current implementation and tests: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt); shared bottom-value contract: [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md)
