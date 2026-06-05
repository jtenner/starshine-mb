---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-gc-core-boundary-refresh.md
  - raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md
  - raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md
  - raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md
  - raw/wasm/2026-06-04-constant-expression-current-refresh.md
  - raw/wasm/2026-06-04-struct-atomic-get-sources.md
  - raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md
  - raw/wasm/2026-06-04-custom-descriptor-current-recheck.md
  - ../../src/lib/types.mbt
  - ../../src/wast/parser.mbt
  - ../../src/wast/lower_to_lib.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/validate.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/gen_valid.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-typed-function-references-boundary.md
  - wast/gc-type-authoring.md
  - wast/gc-aggregate-instruction-authoring.md
  - wast/reference-instruction-authoring.md
  - wast/text-surface-gap-ledger.md
  - validate/type-section-and-subtyping.md
  - validate/constant-expressions.md
  - binary/type-table-memory-global-tag-sections.md
  - binary/instruction-and-expression-encoding.md
  - custom-descriptors/descriptor-instruction-surface.md
  - fuzzing/generator-coverage-ledger.md
---

# WebAssembly GC Core Boundary

## Overview

Use this page when a claim mentions “WebAssembly GC” and you need to know which layer is meant. The ordinary GC feature is now a finished/Core-3.0 WebAssembly surface: it covers recursive `func` / `struct` / `array` types, abstract heap types such as `any`, `eq`, `struct`, `array`, and `i31`, typed references, ordinary cast/test/branch/call reference instructions, and struct/array aggregate instructions. The `call_ref` / `return_call_ref` slice is cross-linked to the focused typed-function-reference boundary at [`wasm-typed-function-references-boundary.md`](wasm-typed-function-references-boundary.md). That does **not** mean every Starshine layer exposes every Core syntax spelling today.

The current bridge is [`raw/wasm/2026-06-05-gc-core-boundary-refresh.md`](raw/wasm/2026-06-05-gc-core-boundary-refresh.md). It rechecked current official Core 3.0 / finished-proposal sources and the local Starshine model. The important routing rule is:

```text
Core WebAssembly GC
  -> Starshine core model + binary codec + validator + generator surface
  -> narrower Starshine WAST text authoring surface
  -> narrower Starshine constant-expression initializer allow-list
  -> separate active-proposal/local custom-descriptor surface
```

Beginners can read this as: **GC is the heap-object and reference-type part of modern Wasm, but Starshine does not expose every GC thing through the same entrypoint yet.** If a WAST file cannot be parsed, the same module shape might still be valid as a core builder, generated module, or binary fixture.

## Layer Map

| Layer | Starshine owner | What this proves | Main caveat |
| --- | --- | --- | --- |
| Core type model | [`src/lib/types.mbt`](../../src/lib/types.mbt) | `AbsHeapType`, `HeapType`, `RefType`, `CompType::{Struct,Array,Func}`, `SubType`, `RecType`, `TypeMetadata`, and GC/reference/aggregate `Instruction` variants exist in the in-memory module model. | Core presence is not WAST text support or initializer support. |
| WAST type text | [`src/wast/parser.mbt`](../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt) | Starshine can author useful `(type ... (struct ...))`, `(type ... (array ...))`, `(rec ...)`, subtype, exact-ref, and descriptor metadata fixtures. | Detailed type-use caveats live in [`wast/gc-type-authoring.md`](wast/gc-type-authoring.md), including explicit `(type ...)` plus inline param/result consistency. |
| WAST instruction text | [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../src/wast/parser.mbt), [`src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt) | Basic refs, `ref.eq`, `ref.as_non_null`, `ref.i31`, `i31.get_*`, `any.convert_extern`, `extern.convert_any`, `struct.new*`, `struct.get*`, `struct.atomic.get*`, and descriptor test/cast helpers are text-exposed. | Ordinary `ref.test` / `ref.cast`, `br_on_*`, ordinary non-tail `call_ref`, `struct.set`, and `array.*` are current WAST gaps. |
| Binary codec | [`src/binary/decode.mbt`](../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../src/binary/encode.mbt) | GC type encodings, reference instructions, and broader aggregate instruction opcodes roundtrip at the byte/core level. | Decode success does not prove type validity, declaration membership, mutability, or bounds/effect safety. |
| Validation/typechecking | [`src/validate/validate.mbt`](../../src/validate/validate.mbt), [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) | Type sections, subtyping, reference casts/tests/branches/calls, struct/array instructions, packed signedness, mutability, and data/element-backed array operations are semantically checked. | Constant-expression validation is a separate allow-list and is narrower than ordinary body typechecking. |
| Valid generation | [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) | Fuzzing can exercise GC/reference-shaped modules through local feature/profile toggles. | `GenValidProposalFeature` / toggles are local fuzz vocabulary, not standards-status evidence. |
| Custom descriptors | [`custom-descriptors/descriptor-instruction-surface.md`](custom-descriptors/descriptor-instruction-surface.md) | Starshine has local/proposal-facing descriptor metadata, exact refs, descriptor allocation, `ref.get_desc`, and non-branch descriptor predicate/cast forms. | Custom descriptors are active proposal evidence, not ordinary Core GC. The upstream proposal remains struct-oriented; Starshine array metadata behavior is local unless separately source-confirmed. |

## Concrete Shapes

### Core GC type and reference shape

```wat
(module
  (type $box (struct (field i32)))
  (func (param (ref null $box)) (result i32)
    (ref.is_null (local.get 0))))
```

This is the safe starting point for WAST fixtures: a struct type plus a nullable reference instruction that the current Starshine text path accepts. Pair it with [`wast/gc-type-authoring.md`](wast/gc-type-authoring.md) for recursive-group and subtype details before adding self-recursive or mutually recursive types.

### Aggregate instruction shape with a text/core split

```wat
(module
  (type $s (struct (field i32) (field (mut i8))))
  (func (result i32)
    (struct.get 0 0
      (struct.new 0 (i32.const 7) (i32.const 1)))))
```

`struct.new` and `struct.get*` are WAST-supported today. By contrast, `struct.set` and `array.*` are still core/binary/validator/generator surfaces rather than high-level WAST text surfaces; use core builders, binary bytes, or generated modules for those until the WAST path is widened. The detailed matrix is [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md).

### Reference branch/cast shape with a text/core split

```text
RefTest(nullable, HeapType)
RefCast(nullable, HeapType)
BrOnNull(LabelIdx)
BrOnNonNull(LabelIdx)
BrOnCast(...)
BrOnCastFail(...)
CallRef(TypeIdx)
```

These are real Starshine core/binary/validator concepts, but not ordinary WAST text keywords in the current snapshot. Do not call them proposal-only; call them **Starshine WAST gaps**. Route ordinary reference branches/casts through [`wast/reference-instruction-authoring.md`](wast/reference-instruction-authoring.md), function-call text through [`wast/function-call-and-module-authoring.md`](wast/function-call-and-module-authoring.md), and the `call_ref` / `return_call_ref` standards-versus-local-WAST split through [`wasm-typed-function-references-boundary.md`](wasm-typed-function-references-boundary.md).

### Constant-expression caveat

A struct constructor accepted in a function body is not automatically accepted in a global/table/element/data initializer, and an array constructor accepted by ordinary instruction typechecking is not necessarily accepted by Starshine's initializer allow-list. Always route initializer claims through [`validate/constant-expressions.md`](validate/constant-expressions.md) and [`raw/wasm/2026-06-04-constant-expression-current-refresh.md`](raw/wasm/2026-06-04-constant-expression-current-refresh.md).

## Rewrite And Validation Risks

1. **Type-index rewrites are whole-module rewrites.** GC type changes can affect function signatures, refs, tables, globals, element expressions, tags, casts/tests, aggregate instructions, and custom descriptors. Pair type changes with [`validate/type-section-and-subtyping.md`](validate/type-section-and-subtyping.md) and [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md).
2. **Reference branch/cast instructions have two path types.** `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` refine branch and fallthrough stacks differently. Optimizer rewrites must preserve both paths, not just final validation.
3. **Packed field signedness is semantic.** `struct.get_s` / `array.get_s` and `*_get_u` differ by sign extension for packed storage. Do not canonicalize them without a proof.
4. **Array operations carry traps and segment dependencies.** Index/range, mutable-storage, data-index, and elem-index checks matter. Segment-backed array instructions should also consult [`validate/data-count-and-code-data-indices.md`](validate/data-count-and-code-data-indices.md), [`wast/data-segment-authoring.md`](wast/data-segment-authoring.md), and [`wast/element-segment-authoring.md`](wast/element-segment-authoring.md).
5. **Descriptor exactness is not ordinary reference nullability.** `CastOp` for `br_on_cast` stores source/target nullability; descriptor exactness and descriptor compatibility live in the custom-descriptor pages.
6. **Shared-GC atomics are separate from linear-memory atomics.** Current text support is `struct.atomic.get*` only. Do not infer `struct.atomic.set`, aggregate RMW/cmpxchg, or array atomic support from linear-memory atomic pages.

## Signoff Guidance

- For WAST parser/printer changes, update tests in `src/wast/*` first and keep the text-surface gap ledger current.
- For core/binary changes, roundtrip through [`src/binary/decode.mbt`](../../src/binary/decode.mbt) / [`src/binary/encode.mbt`](../../src/binary/encode.mbt) tests and validate the decoded module.
- For validator changes, add focused positive/negative checks near [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../src/validate/validate.mbt), invalid-fuzzer families, or GenValid coverage as appropriate.
- For pass work, compare against Binaryen only after naming the exact GC layer involved: type graph, reference cast/branch/call, aggregate allocation/access/mutation, descriptor exactness, or initializer behavior. Use the pass-specific Binaryen dossier for upstream behavior and this page for Starshine layer routing.

## Sources

- GC boundary source bridge: [`raw/wasm/2026-06-05-gc-core-boundary-refresh.md`](raw/wasm/2026-06-05-gc-core-boundary-refresh.md)
- Type-use/subtyping: [`raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md), [`wast/gc-type-authoring.md`](wast/gc-type-authoring.md), [`validate/type-section-and-subtyping.md`](validate/type-section-and-subtyping.md)
- Reference/call/cast/branch: [`raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md`](raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md), [`raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md`](raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md), [`wast/reference-instruction-authoring.md`](wast/reference-instruction-authoring.md), [`wasm-typed-function-references-boundary.md`](wasm-typed-function-references-boundary.md)
- Aggregate instructions: [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md), [`raw/wasm/2026-06-04-struct-atomic-get-sources.md`](raw/wasm/2026-06-04-struct-atomic-get-sources.md)
- Constant expressions: [`validate/constant-expressions.md`](validate/constant-expressions.md), [`raw/wasm/2026-06-04-constant-expression-current-refresh.md`](raw/wasm/2026-06-04-constant-expression-current-refresh.md)
- Custom descriptors: [`custom-descriptors/descriptor-instruction-surface.md`](custom-descriptors/descriptor-instruction-surface.md), [`raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md)
