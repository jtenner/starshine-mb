---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-more-array-constructors-boundary-refresh.md
  - raw/wasm/2026-06-05-gc-core-boundary-refresh.md
  - raw/wasm/2026-06-04-constant-expression-current-refresh.md
  - raw/wasm/2026-06-04-data-count-code-data-index-recheck.md
  - raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md
  - ../../src/lib/types.mbt
  - ../../src/wast/keywords.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/validate.mbt
  - ../../src/validate/gen_valid.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-gc-core-boundary.md
  - wast/gc-aggregate-instruction-authoring.md
  - wast/text-surface-gap-ledger.md
  - validate/constant-expressions.md
  - validate/data-count-and-code-data-indices.md
  - wasm-multi-memory-boundary.md
  - validate/memory-table-address-widths.md
  - binary/instruction-and-expression-encoding.md
  - fuzzing/generator-coverage-ledger.md
---

# More Array Constructors Boundary

## Overview

Use this page when a claim mentions the active **More Array Constructors** proposal, especially when it sounds similar to WebAssembly GC array instructions that Starshine already models.

The current source bridge is [`raw/wasm/2026-06-05-more-array-constructors-boundary-refresh.md`](raw/wasm/2026-06-05-more-array-constructors-boundary-refresh.md). It rechecked the official WebAssembly proposals tracker, the More Array Constructors proposal repository/overview, current Core 3.0 array-instruction pages, and Starshine's local WAST/core/binary/validator/generator evidence.

The key split is:

```text
Core WebAssembly GC arrays
  -> array.new / array.new_default / array.new_fixed / array.new_data / array.new_elem / array.init_*
  -> Starshine core + binary + validator + generator support, but no high-level WAST array text yet

Active More Array Constructors proposal
  -> array.new_array / array.new_memory / array.new_table
  -> no current Starshine WAST/core/binary/validator/generator support
```

Beginner model: Starshine already knows about ordinary GC arrays in its in-memory module model. The proposal asks for **new ways to build arrays from a dynamic slice of another array, memory, or table**. Those new instructions are not the same as `array.new_data` / `array.new_elem`, even though the names and use cases overlap.

## Instruction Family Split

| Family | Status | Starshine layer today | Fixture guidance |
| --- | --- | --- | --- |
| `array.new` | Core WebAssembly GC | Core/binary/validator/generator support; no high-level WAST text; not admitted by Starshine's current constant-expression allow-list. | Use core builders, binary bytes, or generator fixtures. Do not use WAST text unless the WAST layer is widened first. |
| `array.new_default` | Core WebAssembly GC | Same local layer split as `array.new`; requires a defaultable element type. | Use core/binary/generated fixtures; route initializer claims through [`validate/constant-expressions.md`](validate/constant-expressions.md). |
| `array.new_fixed` | Core WebAssembly GC | Same local layer split as `array.new`; immediate length controls how many element values are consumed. | Use core/binary/generated fixtures; do not infer proposal support. |
| `array.new_data` / `array.init_data` | Core WebAssembly GC with data-index dependencies | Core/binary/validator support; no WAST text; data-index existence typechecks, but Starshine's pre-code missing-data-count scanner currently covers only `memory.init` / `data.drop`. | Pair with [`validate/data-count-and-code-data-indices.md`](validate/data-count-and-code-data-indices.md) and data-segment docs. |
| `array.new_elem` / `array.init_elem` | Core WebAssembly GC with element-index dependencies | Core/binary/validator support; no WAST text; element segment type must match the array element reference type. | Pair with [`wast/element-segment-authoring.md`](wast/element-segment-authoring.md) and `ref.func` declaration rules where element payloads create function refs. |
| `array.new_array` | More Array Constructors proposal | No current Starshine instruction variant, WAST keyword, binary arm, validator case, or generator row. | Treat as active-proposal no-support until a dedicated implementation slice lands. |
| `array.new_memory` | More Array Constructors proposal | No current Starshine support. This would be memory-index / address-width / bounds-sensitive proposal work, not `array.new_data`. | Recheck proposal binary/validation sources plus [`wasm-multi-memory-boundary.md`](wasm-multi-memory-boundary.md) and [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md) before implementation. |
| `array.new_table` | More Array Constructors proposal | No current Starshine support. This would be table-index / table64 / element-reference-sensitive proposal work, not `array.new_elem`. | Recheck proposal sources plus table64 and table authoring docs before implementation. |

## Current Starshine Support Map

| Layer | Current state | Evidence |
| --- | --- | --- |
| Core model | Current Core GC array instructions are represented as `ArrayNew`, `ArrayNewDefault`, `ArrayNewFixed`, `ArrayNewData`, `ArrayNewElem`, `ArrayGet*`, `ArraySet`, `ArrayLen`, `ArrayFill`, `ArrayCopy`, `ArrayInitData`, and `ArrayInitElem`. There are no `array.new_array`, `array.new_memory`, or `array.new_table` variants. | [`src/lib/types.mbt`](../../src/lib/types.mbt) |
| WAST text | No ordinary `array.*` aggregate WAST text is currently exposed. That absence covers both Core arrays and More Array Constructors. | [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md), [`wast/text-surface-gap-ledger.md`](wast/text-surface-gap-ledger.md) |
| Binary codec | Current Core GC array opcodes roundtrip through the local `0xFB` aggregate lane. Proposal constructor opcodes are not decoded or encoded. | [`src/binary/decode.mbt`](../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../src/binary/encode.mbt), [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md) |
| Validation | Current Core array constructors/access/mutation/init are typechecked for type indices, packed signedness, mutability, data/element indices, and stack shapes. Proposal constructors have no validator cases. | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`validate/data-count-and-code-data-indices.md`](validate/data-count-and-code-data-indices.md) |
| Constant expressions | Current Core 3.0 admits `array.new`, `array.new_default`, and `array.new_fixed` as constant-expression instructions, but Starshine does not currently admit those array constructors in `validate_const_instr(...)`. More Array Constructors does not change that local allow-list. | [`validate/constant-expressions.md`](validate/constant-expressions.md), [`src/validate/validate.mbt`](../../src/validate/validate.mbt) |
| Generator/fuzz | `gen_valid` can exercise current Core GC aggregate arrays through local feature/profile decisions. There is no More Array Constructors proposal gate or coverage row. | [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md) |

## Why The Names Are Easy To Confuse

### `array.new_data` is not `array.new_memory`

`array.new_data` copies from a **data segment**. It carries a `DataIdx`, depends on the module's data segment list, and participates in the data-count rule for code-section data-index users.

`array.new_memory` would copy from a **linear memory**. A future Starshine implementation would need memory-index handling, selected-memory address-width rules, runtime bounds/trap behavior, multi-memory routing, and effects/trap modeling. Do not reuse the data-count rule as evidence for it.

### `array.new_elem` is not `array.new_table`

`array.new_elem` copies from an **element segment**. It carries an `ElemIdx`, and the segment reference type must match the destination array element reference type.

`array.new_table` would copy from a **runtime table**. A future implementation would need table-index handling, table64 address-width rules, runtime bounds/trap behavior, and table element-type matching. Do not treat existing element-segment support as table-copy support.

### `array.new_fixed` is not the proposal's dynamic-slice story

`array.new_fixed` constructs an array from a statically known immediate element count. It is already Core GC. More Array Constructors is motivated by dynamic-length, dynamic-content construction, especially for immutable arrays.

## Future Implementation Checklist

If Starshine implements More Array Constructors, start with a source recheck because this page intentionally records no local support today.

1. Recheck the proposal tracker, proposal repository, rendered draft syntax/binary/validation pages, and at least one tool implementation chosen as an oracle.
2. Add explicit core instruction variants for `array.new_array`, `array.new_memory`, and `array.new_table` rather than overloading existing Core array constructors.
3. Add binary decode/encode only after confirming final subopcode assignments.
4. Add typechecker rules for each source kind: array-to-array storage compatibility, memory-to-array numeric/vector storage constraints, table-to-array reference compatibility, mutability/immutability expectations, selected index/address types, and runtime trap boundaries.
5. Decide WAST syntax separately. Existing Starshine does not expose ordinary Core `array.*` WAST text, so proposal WAST support should not leapfrog the Core array text gap accidentally.
6. Add valid-generator and invalid-fuzzer coverage with a dedicated proposal feature gate if the feature remains proposal-gated.
7. Update [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md), [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md), [`wast/text-surface-gap-ledger.md`](wast/text-surface-gap-ledger.md), [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md), and validator pages in the same change.

## Sources

- Current focused bridge: [`raw/wasm/2026-06-05-more-array-constructors-boundary-refresh.md`](raw/wasm/2026-06-05-more-array-constructors-boundary-refresh.md)
- GC Core boundary: [`raw/wasm/2026-06-05-gc-core-boundary-refresh.md`](raw/wasm/2026-06-05-gc-core-boundary-refresh.md), [`wasm-gc-core-boundary.md`](wasm-gc-core-boundary.md)
- Aggregate instruction authoring: [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md)
- Constant-expression boundary: [`validate/constant-expressions.md`](validate/constant-expressions.md), [`raw/wasm/2026-06-04-constant-expression-current-refresh.md`](raw/wasm/2026-06-04-constant-expression-current-refresh.md)
- Data-count/data-index boundary: [`validate/data-count-and-code-data-indices.md`](validate/data-count-and-code-data-indices.md), [`raw/wasm/2026-06-04-data-count-code-data-index-recheck.md`](raw/wasm/2026-06-04-data-count-code-data-index-recheck.md)
- Starshine local code: [`src/lib/types.mbt`](../../src/lib/types.mbt), [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`src/binary/decode.mbt`](../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../src/binary/encode.mbt), [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../src/validate/validate.mbt), [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
