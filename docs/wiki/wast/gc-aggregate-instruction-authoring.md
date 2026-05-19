---
kind: concept
status: supported
last_reviewed: 2026-05-19
sources:
  - ../raw/wasm/2026-05-19-wast-gc-aggregate-instruction-sources.md
  - ../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/lib/show.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/validate.mbt
related:
  - gc-type-authoring.md
  - reference-instruction-authoring.md
  - element-segment-authoring.md
  - table-instruction-authoring.md
  - memory-instruction-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/data-element-and-datacount-sections.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST GC Aggregate-Instruction Authoring

## Overview

Use this page when writing or reducing fixtures that allocate, read, or mutate WebAssembly GC aggregates: structs, arrays, packed fields, i31 values, and the nearby `any`/`extern` conversion instructions. The companion [`gc-type-authoring.md`](gc-type-authoring.md) page owns type declarations such as `(type $S (struct ...))` and `(type $A (array ...))`; this page owns the **instruction** layer that consumes those types.

The high-value local rule is a layer split:

```text
official Wasm GC instruction family
  -> Starshine core/binary/validator/generator support
  -> narrower current Starshine WAST text support
```

Starshine can model, encode, decode, validate, and generate the broad GC aggregate family in core modules. The higher-level `src/wast` parser/printer/lowerer is narrower today: it exposes struct constructors, struct reads, descriptor constructors, `ref.get_desc`, descriptor cast/test helpers, i31 operations, and `any`/`extern` conversions, but **does not expose official `struct.set` or any `array.*` WAST text keyword yet**. That means pass regressions involving `struct.set`, `array.new`, `array.get`, `array.init_data`, or `array.init_elem` should currently use core/binary/generated fixtures unless the task is explicitly to widen WAST text support first.

## Beginner Mental Model

A WebAssembly GC aggregate is a heap object whose static type describes its storage:

- a **struct** has a fixed set of indexed fields, possibly packed (`i8` / `i16`) and possibly mutable;
- an **array** has one element type and a runtime length;
- an **i31** is a small integer carried as a reference value.

Aggregate instructions either create a heap object, read storage, mutate storage, or copy/fill ranges. The instruction usually names a type index so validation can find the struct field or array element type. Binary decoding only proves the immediate is present; validation proves that the type exists, the referenced field/element is compatible, the storage is mutable when needed, and the operand stack has the right values in the right order.

## Text-Surface Matrix

| Family | Official examples | Starshine WAST text today | Starshine core/binary/validator today | Fixture guidance |
| --- | --- | --- | --- | --- |
| Struct constructors | `struct.new`, `struct.new_default` | Yes | Yes | Prefer WAST fixtures when constructor text/lowering is the point. |
| Descriptor struct constructors | `struct.new_desc`, `struct.new_default_desc` | Yes, local/custom-descriptor surface | Yes | Use with [`../custom-descriptors/static-fixtures.md`](../custom-descriptors/static-fixtures.md); do not treat as official 3.0 syntax. |
| Struct reads | `struct.get`, `struct.get_s`, `struct.get_u` | Yes | Yes | WAST fixtures are supported; signed/unsigned variants require packed fields. |
| Struct writes | `struct.set` | No | Yes | Use core/binary/generated fixtures, or add WAST keyword/parser/lowerer/printer coverage first. |
| Array constructors | `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, `array.new_elem` | No | Yes | Use core/binary/generated fixtures; data/element-backed forms also touch segment index spaces. |
| Array reads/writes | `array.get`, `array.get_s`, `array.get_u`, `array.set`, `array.len`, `array.fill`, `array.copy` | No | Yes | Use core/binary/generated fixtures; mutable operations require mutable array element storage. |
| Array segment init | `array.init_data`, `array.init_elem` | No | Yes | Pair with data/element segment docs before remapping resources. |
| i31 and extern conversions | `ref.i31`, `i31.get_s`, `i31.get_u`, `any.convert_extern`, `extern.convert_any` | Yes | Yes | WAST fixtures are supported and validated behind reference/GC feature assumptions. |

## Concrete WAST Shapes That Work Today

### Struct constructor plus read

```wat
(module
  (type $S (struct (field i32) (field (mut i8)) (field (mut i16))))
  (func (result i32)
    (struct.get $S 0
      (struct.new $S
        (i32.const 1)
        (i32.const 2)
        (i32.const 3)))))
```

This exercises named type-index lowering through [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt). The same shape can use numeric indices (`0 0`) when the fixture needs to test raw index handling.

### Packed field read variants

```wat
(module
  (type $S (struct (field (mut i8)) (field (mut i16))))
  (func (result i32)
    (struct.get_s $S 0
      (struct.new $S (i32.const -1) (i32.const 0))))
  (func (result i32)
    (struct.get_u $S 1
      (struct.new $S (i32.const 0) (i32.const 65535)))))
```

Use `struct.get_s` and `struct.get_u` only for packed fields. Plain `struct.get` is the readable form for ordinary scalar/reference fields.

### Descriptor constructor surface

```wat
(module
  (rec
    (type $node
      (descriptor $node_desc)
      (struct (field (ref null $node))))
    (type $node_desc
      (describes $node)
      (struct)))
  (func (result (ref null $node))
    (struct.new_desc $node
      (struct.new $node_desc))))
```

This is Starshine's local custom-descriptor surface, not plain WebAssembly 3.0. Keep the distinction explicit when reducing Binaryen descriptor-family regressions.

### i31 and extern conversion forms

```wat
(module
  (func (param i32) (result i32)
    (i31.get_s
      (ref.i31 (local.get 0))))
  (func (param externref) (result externref)
    (extern.convert_any
      (any.convert_extern (local.get 0)))))
```

These forms are parsed as unary/convert instructions in the WAST path and typechecked by the same reference/GC validation layer as the core aggregate operations.

## Core/Binary-Only Shapes Today

The following are real Starshine `@lib.Instruction` families with binary codec and validator support, but not current higher-level WAST text support:

```text
StructSet(TypeIdx, fieldidx)
ArrayNew(TypeIdx)
ArrayNewDefault(TypeIdx)
ArrayNewFixed(TypeIdx, len)
ArrayNewData(TypeIdx, DataIdx)
ArrayNewElem(TypeIdx, ElemIdx)
ArrayGet(TypeIdx)
ArrayGetS(TypeIdx)
ArrayGetU(TypeIdx)
ArraySet(TypeIdx)
ArrayLen
ArrayFill(TypeIdx)
ArrayCopy(dst_type, src_type)
ArrayInitData(TypeIdx, DataIdx)
ArrayInitElem(TypeIdx, ElemIdx)
```

When a pass needs these instructions today, construct them directly in core fixtures, decode them from binary, or rely on `gen_valid` coverage. If a human-readable WAST fixture is needed, the first implementation slice is WAST support, not a pass workaround: add keywords, parser coverage, lowerer resolution for named type/data/element indices, printer coverage, and validator tests.

## Validation And Rewrite Checklist

1. **Keep type and instruction pages separate.** Add new struct/array declaration examples to [`gc-type-authoring.md`](gc-type-authoring.md); add allocation/access/mutation examples here.
2. **Resolve and remap every index space.** Struct/array instructions carry `TypeIdx`; `array.new_data` and `array.init_data` also carry `DataIdx`; `array.new_elem` and `array.init_elem` carry `ElemIdx`; element payloads may carry function indices and `ref.func` declaration sources.
3. **Respect mutability.** `struct.set`, `array.set`, `array.fill`, `array.copy`, and `array.init_*` require mutable storage in the destination aggregate type. Do not infer mutability from the presence of a setter opcode alone.
4. **Treat packed signedness as semantic.** Rewriting `*_get_s` to `*_get_u`, or to plain `get`, changes sign extension for packed fields/elements.
5. **Preserve traps and bounds checks.** Array index, range, copy, fill, data, and element operations can trap at runtime. Reordering or deleting them needs an effect/bounds proof, not just matching validation.
6. **Use the segment pages for data/element-backed arrays.** `array.init_data` and `array.new_data` depend on data segments and data-count-style resource validity; `array.init_elem` and `array.new_elem` depend on element segments and function-reference declaration surfaces. See [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md), [`element-segment-authoring.md`](element-segment-authoring.md), and [`table-instruction-authoring.md`](table-instruction-authoring.md).
7. **Widen WAST arbitrary only after text support exists.** The generator coverage ledger proves core valid generation for many aggregate operations, but `src/wast/arbitrary.mbt` should not emit unsupported `struct.set` or `array.*` text until the WAST path accepts and prints it.

## Source Map

- Primary-source and local-code manifest: [`../raw/wasm/2026-05-19-wast-gc-aggregate-instruction-sources.md`](../raw/wasm/2026-05-19-wast-gc-aggregate-instruction-sources.md)
- Type declaration companion: [`gc-type-authoring.md`](gc-type-authoring.md)
- WAST keyword/parser/printer/lowerer: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Core model and binary codec: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/lib/show.mbt`](../../../src/lib/show.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validation and generation: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md)
- Related WAST pages: [`reference-instruction-authoring.md`](reference-instruction-authoring.md), [`element-segment-authoring.md`](element-segment-authoring.md), [`memory-instruction-authoring.md`](memory-instruction-authoring.md), [`table-instruction-authoring.md`](table-instruction-authoring.md)
