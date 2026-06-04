---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md
  - ../raw/wasm/2026-05-19-wast-string-instruction-sources.md
  - ../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md
  - ../strings/string-const-surface.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/wast/arbitrary.mbt
related:
  - ../strings/string-const-surface.md
  - gc-type-authoring.md
  - gc-aggregate-instruction-authoring.md
  - numeric-instruction-authoring.md
  - memory-instruction-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../validate/module-validation-phases.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST String-Instruction Authoring

## Overview

Use this page when writing, reducing, or widening fixtures that mention Starshine's current string instruction surface:

- `string.const "..."`;
- array-backed construction: `string.new_utf8_array`, `string.new_wtf16_array`, `string.new_lossy_utf8_array`, and `string.new_wtf8_array`;
- array-backed encoding: `string.encode_utf8_array`, `string.encode_wtf16_array`, `string.encode_lossy_utf8_array`, and `string.encode_wtf8_array`.

The current primary-source and local-code refresh is [`../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md), superseding only the source-status and array-operand wording in the older [`2026-05-19` manifest](../raw/wasm/2026-05-19-wast-string-instruction-sources.md). The key reconciliation is that **Starshine has a real WAST/core/binary/validator surface for a narrow stringref-proposal subset, but that surface is not the full active Phase-1 Reference-Typed Strings proposal and is not stable Core WebAssembly 3.0.** Keep binary literal-pool and section-id claims routed through [`../strings/string-const-surface.md`](../strings/string-const-surface.md) and [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md).

## Beginner Mental Model

A `stringref` value is a reference to an immutable string-like runtime value. Starshine can currently create one directly from a text literal with `string.const`, or construct one from a range in a GC array. It can also encode a `stringref` back into a mutable GC array and return the number of code units or bytes written.

That means string instructions sit at the intersection of three concepts:

1. **literal identity**: `string.const` carries bytes that must survive parsing, lowering, binary encode/decode, and optimizer rewrites;
2. **GC arrays**: the array helpers require concrete array heap types with matching packed element storage;
3. **proposal/local binary support**: Starshine mirrors the active stringref proposal's `0xfb 0x82` / `0xfb 0xb0..0xb7` opcode assignments and section-id-`14` literal pool shape, but the WebAssembly proposals tracker still lists Reference-Typed Strings at Phase 1; do not describe these bytes as stable Core WebAssembly 3.0.

## Layer Model

| Layer | Owner | String-instruction facts to remember |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Registers the nine supported string opcodes. `string.const` requires one text literal; the array helpers have no immediate in WAST text. |
| WAST lowerer/printer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Lowers each supported text opcode to the matching core `Instruction`; prints the same spellings and quotes `string.const` bytes. |
| Core instruction model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Models `StringConst(Bytes)`, eight string array new/encode helpers, `ValType::stringref()`, and the string abstract heap type. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Uses local `0xFB` subcode `0x82` for `string.const` and `0xB0` through `0xB7` for the array helpers. `string.const` encode/decode depends on the local string-literal section. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | Checks literal production, array storage (`i8` vs `i16`), destination-array mutability for encode helpers, and ordinary stack operand order. |
| Fuzz / WAST arbitrary | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | `[FZG]012` proves valid-generator coverage for supported string ops when matching GC array types exist. WAST arbitrary currently has no dedicated string-helper emission path. |

## Current Surface Matrix

| Family | WAST text support today | Core/binary/validator support today | Fixture guidance |
| --- | --- | --- | --- |
| `string.const` | Yes | Yes | Prefer WAST fixtures for literal parsing/lowering and binary roundtrip fixtures for local/proposal `StringRefsSec` behavior. |
| UTF-8 / WTF-8 array construction | `string.new_utf8_array`, `string.new_lossy_utf8_array`, `string.new_wtf8_array` | Yes | Requires an array reference whose element storage is packed `i8`, then `i32` start and exclusive `i32` end. |
| WTF-16 array construction | `string.new_wtf16_array` | Yes | Requires an array reference whose element storage is packed `i16`, then `i32` start and exclusive `i32` end. |
| UTF-8 / WTF-8 array encoding | `string.encode_utf8_array`, `string.encode_lossy_utf8_array`, `string.encode_wtf8_array` | Yes | Requires `stringref`, a mutable packed-`i8` array reference, and an `i32` start; produces `i32`. |
| WTF-16 array encoding | `string.encode_wtf16_array` | Yes | Requires `stringref`, a mutable packed-`i16` array reference, and an `i32` start; produces `i32`. |
| Wider stringref proposal operations | No | No current Starshine AST/validator evidence | Measurement, comparison, hash, view/iterator, and memory-buffer forms need implementation evidence before docs or tests claim support. |

## Stack And Validation Shapes

Starshine's typechecker sees stack operands right-to-left, as usual for nested WAST. In source order, use these shapes:

| Instruction | Source-shape intuition | Result | Important caveat |
| --- | --- | --- | --- |
| `string.const "x"` | no stack operands | `stringref` | Literal bytes must remain exact; binary encoding needs module string-pool context. |
| `string.new_utf8_array` | array, start `i32`, exclusive end `i32` | `stringref` | Array element storage must be packed `i8`. |
| `string.new_lossy_utf8_array` | array, start `i32`, exclusive end `i32` | `stringref` | Same storage rule as UTF-8; lossy behavior is runtime/proposal semantics, not a validator distinction. |
| `string.new_wtf8_array` | array, start `i32`, exclusive end `i32` | `stringref` | Same storage rule as UTF-8/WTF-8. |
| `string.new_wtf16_array` | array, start `i32`, exclusive end `i32` | `stringref` | Array element storage must be packed `i16`. |
| `string.encode_utf8_array` | stringref, mutable array, start `i32` | `i32` | Destination array must be mutable packed `i8`. |
| `string.encode_lossy_utf8_array` | stringref, mutable array, start `i32` | `i32` | Destination array must be mutable packed `i8`. |
| `string.encode_wtf8_array` | stringref, mutable array, start `i32` | `i32` | Destination array must be mutable packed `i8`. |
| `string.encode_wtf16_array` | stringref, mutable array, start `i32` | `i32` | Destination array must be mutable packed `i16`. |

For the GC array type declarations and setup instructions that make these fixtures valid, pair this page with [`gc-type-authoring.md`](gc-type-authoring.md) and [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md). Current WAST text can declare the array types, but many ordinary `array.*` setup instructions are still core/binary/generator-only in Starshine WAST; use simple defaults from generator/core fixtures or add WAST aggregate support first when a human-authored text fixture needs them.

## Concrete WAST Shapes That Work Today

### Literal string production

```wat
(module
  (func (result stringref)
    (string.const "hello")))
```

Use this for parser/lowerer/typechecker tests that only need a string value. Use [`../strings/string-const-surface.md`](../strings/string-const-surface.md) when the test is really about literal-pool identity, local `StringRefsSec` emission, or bare `stringref` value-type binary decoding.

### Constructing from a packed `i8` array

```wat
(module
  (type $bytes (array (mut i8)))
  (func (param (ref null $bytes)) (result stringref)
    (string.new_utf8_array
      (local.get 0)
      (i32.const 0)
      (i32.const 4))))
```

This shape is useful for stack/typechecking tests. It proves the source array is a concrete array type with `i8` storage and that the second integer is accepted as the proposal's exclusive `end` operand. It does not prove runtime contents, bounds, or encoding behavior.

### Constructing from a packed `i16` array

```wat
(module
  (type $units (array (mut i16)))
  (func (param (ref null $units)) (result stringref)
    (string.new_wtf16_array
      (local.get 0)
      (i32.const 0)
      (i32.const 2))))
```

Use this when a regression is specific to the `i16` storage lane. Here the second integer is the exclusive `end`, not a separate length field; a fixture that accidentally uses an `i8` array should fail validation for `string.new_wtf16_array`.

### Encoding into a mutable packed array

```wat
(module
  (type $bytes (array (mut i8)))
  (func (param stringref) (param (ref null $bytes)) (result i32)
    (string.encode_utf8_array
      (local.get 0)
      (local.get 1)
      (i32.const 0))))
```

Encoding helpers require mutability. If the destination type is `(array i8)` rather than `(array (mut i8))`, Starshine should reject the body even though the storage width matches.

## Proposal And Local-Support Boundaries

The checked stringref proposal source is broader than Starshine's current model. Do **not** infer support for these families from the existence of `stringref` or `string.const`:

- string measurement, comparison, hash, equality, or ordering helpers;
- string views, iterators, or code-point walking helpers;
- memory-buffer forms such as non-array UTF-8/WTF-16 new/encode helpers;
- a stable Core WebAssembly `stringrefs` binary section id, even though the active proposal draft currently defines section id `14`.

When adding one of those families, the implementation needs at least a new core instruction shape, binary decode/encode evidence, typechecker coverage, WAST keyword/parser/lowerer/printer support if text is exposed, generator/arbitrary coverage if fuzzing claims are made, and a wiki/source-manifest refresh.

## Rewrite And Validation Checklist

1. **Preserve literal identity.** `string.const` carries bytes, not just a display string. Do not deduplicate, re-escape, or reorder literals unless the local `StringRefsSec` and all `string.const` indices remain deterministic and semantically equivalent.
2. **Keep array storage proofs explicit.** UTF-8/WTF-8 helpers require packed `i8` arrays; WTF-16 helpers require packed `i16` arrays. Validation should fail on the wrong width even when the source WAST is otherwise well formed.
3. **Respect destination mutability.** Encode helpers write into the destination array. Rewrites must preserve mutable-array requirements and should not replace a mutable destination with an immutable one.
4. **Do not erase runtime traps accidentally.** Array range, null-reference, and encoding operations can have runtime failure modes. Moving or deleting them needs effect/range/nullability proof, not just a green static typecheck.
5. **Separate text, core, binary, and generator claims.** `[FZG]012` proves core valid-generator coverage for supported string ops; it does not prove `src/wast/arbitrary.mbt` emits those text shapes today.
6. **Keep proposal status visible.** Link [`../strings/string-const-surface.md`](../strings/string-const-surface.md) and [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md) whenever documenting local `StringRefsSec` bytes or section order.
7. **Validate after mutation.** String rewrites commonly touch reference types, GC array types, globals, the local string pool, and pass-local effect assumptions. Run module validation plus the relevant Binaryen-oracle lane where the pass has an upstream equivalent.

## Source Map

- Current primary-source and local-code refresh: [`../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md)
- Original broad primary-source and local-code manifest: [`../raw/wasm/2026-05-19-wast-string-instruction-sources.md`](../raw/wasm/2026-05-19-wast-string-instruction-sources.md)
- Literal-pool companion: [`../strings/string-const-surface.md`](../strings/string-const-surface.md)
- WAST keyword/parser/printer/lowerer: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Core model and binary codec: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md), [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md)
- Validation and generation: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md), [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md)
- Related WAST pages: [`gc-type-authoring.md`](gc-type-authoring.md), [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md), [`numeric-instruction-authoring.md`](numeric-instruction-authoring.md), [`memory-instruction-authoring.md`](memory-instruction-authoring.md)
