---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md
  - ../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md
  - ../raw/wasm/2026-05-20-call-ref-source-refresh.md
  - ../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md
  - ../raw/wasm/2026-05-13-instruction-expression-binary-sources.md
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md
  - ../raw/wasm/2026-05-19-wast-reference-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-variable-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-memory-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-call-and-function-sources.md
  - ../raw/wasm/2026-05-19-wast-gc-aggregate-instruction-sources.md
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/binary/tests.mbt
related:
  - module-section-map.md
  - leb128-and-integer-encoding.md
  - function-import-export-and-code-sections.md
  - type-table-memory-global-tag-sections.md
  - data-element-and-datacount-sections.md
  - ../validate/module-validation-phases.md
  - ../validate/simd-lane-immediates.md
  - ../validate/stack-polymorphism-and-bottom.md
  - ../validate/ref-func-declarations.md
  - ../tooling/validation-gates.md
  - ../wast/gc-type-authoring.md
  - ../wast/gc-aggregate-instruction-authoring.md
  - ../wast/control-flow-authoring.md
  - ../wast/function-call-and-module-authoring.md
  - ../wast/reference-instruction-authoring.md
  - ../wast/variable-instruction-authoring.md
  - ../wast/numeric-instruction-authoring.md
  - ../wast/exception-tag-authoring.md
  - ../wast/memory-argument-authoring.md
  - ../wast/memory-instruction-authoring.md
  - ../wast/table-instruction-authoring.md
  - ../wast/simd-authoring.md
---

# Binary Instruction And Expression Encoding

## Overview

This page is the shared Starshine guide for the byte-level instruction and expression contract inside globals, tables, elements, function bodies, and data/element bulk-memory users. Section-level layout lives in [`module-section-map.md`](module-section-map.md); function/code-section pairing lives in [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md). This page answers the lower-level question: once an expression payload is reached, how do Starshine and the official WebAssembly binary format agree on opcodes, immediates, nesting, and validation responsibilities?

The official WebAssembly 3.0 source snapshot in [`../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md`](../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md) anchors the external rules. The local Starshine source map in [`../raw/wasm/2026-05-13-instruction-expression-binary-sources.md`](../raw/wasm/2026-05-13-instruction-expression-binary-sources.md) records the in-repo files that implement and test those rules.

The central invariant is a layer split:

```text
binary bytes -> syntactic Instruction / Expr decode -> module validation/typecheck
```

LEB128 integer spellings are part of the first layer. Starshine rejects unterminated, too-wide, out-of-range, or malformed-terminal LEB bytes during decode, but it still accepts official-compatible overlong encodings inside the byte-count bound. That focused contract now lives in [`leb128-and-integer-encoding.md`](leb128-and-integer-encoding.md).

`src/binary/decode.mbt` and `src/binary/encode.mbt` own bytes, opcode numbers, immediates, expression terminators, and malformed-encoding errors. `src/validate/typecheck.mbt` owns stack effects, block labels, index resolution, memory/table/data/element preconditions, and unreachable-code stack polymorphism; the bottom-value and concrete pushed-value boundary is now centralized in [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md).

## Core Shapes In Starshine

| Concept | Starshine representation | Binary/validation meaning |
| --- | --- | --- |
| Expression | [`Expr(Array[Instruction])`](../../../src/lib/types.mbt) | A sequence of instructions terminated on the wire by `0x0B` (`end`). |
| Function body | [`Func(Locals, Expr)`](../../../src/lib/types.mbt), inside [`CodeSec(Array[Func])`](../../../src/lib/types.mbt) | Code-section body: local declarations plus one expression. Body ordinal matches the same ordinal in `FuncSec`, while imports shift absolute `FuncIdx` values. |
| Instruction | [`Instruction`](../../../src/lib/types.mbt) enum | Decoded opcode plus typed immediates; includes one-byte core opcodes and prefixed families. |
| Block type | [`BlockType`](../../../src/lib/types.mbt) | Void (`0x40`), single value type, or absolute function-type index. Validator expands it to params/results. |
| Memory argument | [`MemArg(U32, MemIdx?, U64)`](../../../src/lib/types.mbt) | Alignment exponent, optional explicit memory index, and offset. Validator checks selected memory, alignment width, and address-width offset. |
| Catch clause | [`Catch`](../../../src/lib/types.mbt) | `try_table` catch encoding plus label target validation against tag payloads or `exnref`; see [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md) for text-level authoring and catch scope rules. |

Starshine's core representation is deliberately semantic enough for validators and passes, not a raw opcode token stream. For example, `Instruction::I32Load(MemArg(...))` remembers the access family and immediate fields; validation later proves that the memory exists and the operand/result stack is legal.

## Decode And Encode Flow

### Expressions and structured control

[`Decode for Expr`](../../../src/binary/decode.mbt) reads instructions until `0x0B`. For nested `block`, `loop`, `if`, and `try_table`, Starshine uses a structured-frame decoder rather than blindly recursing through bytes. That frame stack is important for three cases:

1. `end` closes the nearest structured frame or the outer expression, depending on nesting;
2. `else` (`0x05`) splits only an `if` frame's then/else bodies;
3. malformed nesting must fail without consuming unrelated trailing bytes.

The decoder also has an instruction nesting limit and reports `InstructionNestingLimitExceeded` for adversarially deep payloads; [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) has focused coverage for that guard. [`Encode for Expr`](../../../src/binary/encode.mbt) emits each instruction and then appends `0x0B`.

### Block types

`BlockType` is encoded as one of:

- `VoidBlockType` -> `0x40`;
- `ValTypeBlockType(vt)` -> the value type byte(s);
- `TypeIdxBlockType(TypeIdx(idx))` -> signed 33-bit type index.

Starshine rejects recursive-index blocktypes during binary encode (`CannotEncodeRecursiveIndexBlockType`) because long-lived binary output must use absolute type indices. During validation, [`Env::expand_blocktype`](../../../src/validate/env.mbt) resolves type-index blocktypes to a function type and returns its params/results.

### Memory arguments

Official core memory arguments are alignment plus offset. Starshine represents the multi-memory extension as `MemArg(U32(align_pow), Some(memidx), U64(offset))`; binary encode writes `align_pow + 64`, then the memory index, then the offset. With no explicit memory index, encode writes `align_pow` followed by the offset. The WAST text authoring caveats, including text-byte `align=` versus core exponent form and the current lack of explicit nonzero memory indices in WAST memargs, are documented in [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md).

The binary layer can reject malformed immediate ranges (`InvalidMemArgEncoding` / `InvalidMemArg`), but semantic legality is in [`memarg_check`](../../../src/validate/typecheck.mbt): selected memory must exist, alignment must fit the access width, and i32 memories reject offsets outside the 32-bit address range. This is why pass authors should not treat a well-formed `MemArg` as automatically valid after memory rewrites. Stack shapes, data-count requirements, and trap/effect guidance for scalar and bulk memory instructions live in [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md).

### Variable instructions

The local/global variable instruction family is byte-simple but semantically coupled to validation and text lowering: `local.get` / `local.set` / `local.tee` use opcodes `0x20` / `0x21` / `0x22` plus a `localidx`, while `global.get` / `global.set` use `0x23` / `0x24` plus a `globalidx`. The byte codec only proves that an index immediate was present; [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md) covers the WAST `$` identifier lowering, parameter-before-local numbering, `local.tee` stack-preservation rule, and `global.set` mutability check, while [`../validate/constant-expressions.md`](../validate/constant-expressions.md) owns immutable-`global.get` initializer/offset eligibility.

### Scalar numeric instructions

Scalar numeric constants and operators are mostly byte-simple but validation-sensitive. `i32.const`, `i64.const`, `f32.const`, and `f64.const` use opcodes `0x41` through `0x44` plus literal immediates; the integer constants use signed LEB encodings while the float constants use fixed little-endian payload bytes. The binary-invalid lane covers both integer malformed signed-LEB constants (`malformed-i32-const-sleb`, `malformed-i64-const-sleb`) and truncated fixed-width float constants (`malformed-f32-const-immediate`, `malformed-f64-const-immediate`). Most tests, comparisons, arithmetic, and conversions use one-byte opcodes; sign-extension uses `0xC0` through `0xC4`; and saturating truncations use `0xFC` subcodes `0` through `7`. The byte codec does not prove stack validity, trap preservation, signedness, or NaN behavior. Use [`leb128-and-integer-encoding.md`](leb128-and-integer-encoding.md) for integer-byte spelling and size accounting, [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md) for text literal caveats, scalar stack effects, and pass rewrite hazards, and [`../validate/constant-expressions.md`](../validate/constant-expressions.md) for which scalar forms Starshine currently permits in initializer/offset expressions.

### Parametric instructions

The untyped `select` carrier is opcode `0x1B`; typed `select` is opcode `0x1C` followed by a vector of value types. The binary-invalid lane now has separate decode-rejection fixtures for malformed typed-select type-count ULEBs (`malformed-select-type-count-uleb` and `overwide-select-type-count-uleb`) and an invalid value-type byte inside that vector (`invalid-typed-select-valtype-byte`). Stack compatibility, bottom handling, and result typing remain validator responsibilities above the byte layer.

### Reference instructions

Reference and reference-call instructions are split across one-byte opcodes and GC-prefixed forms. Starshine encodes/decodes the basic `0xD0`-family forms (`ref.null`, `ref.is_null`, `ref.func`, `ref.eq`, `ref.as_non_null`, `br_on_null`, and `br_on_non_null`), the ordinary reference-call opcodes `call_ref` `0x14` and `return_call_ref` `0x15`, and `0xFB` subcodes for ordinary/descriptor test-cast plus cast-branch forms. The binary-invalid lane includes malformed/overwide heaptype-immediate decode fixtures for the one-byte `ref.null` carrier plus both `0xFB 0x14` `ref.test` and `0xFB 0x16` `ref.cast` prefixed carriers, and it now mirrors that overwide-ULEB coverage for selected GC aggregate index carriers such as `struct.new`, `struct.get`, and `array.new_data`. The text authoring surface is narrower: current WAST supports the basic `ref.*` subset, descriptor forms, and `return_call_ref`, but not ordinary `ref.test` / `ref.cast` / `br_on_*` or ordinary non-tail `call_ref` text keywords. Use [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md) and [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md) before drawing parser, binary, or validation conclusions from one layer alone.

### Prefixed opcode families

Do not audit instruction coverage by one-byte opcodes only. Starshine's current codec includes several prefixed spaces:

| Prefix | Family in Starshine | Examples |
| ---: | --- | --- |
| `0xFC` | Saturating conversion, bulk memory, and table operations | `i32.trunc_sat_f32_s`, `memory.init`, `data.drop`, `memory.copy`, `table.init`, `elem.drop` |
| `0xFD` | SIMD | `v128.load`, `i8x16.shuffle`, lane extract/replace, relaxed SIMD forms; byte-level lane immediates must still satisfy the focused validation contract in [`../validate/simd-lane-immediates.md`](../validate/simd-lane-immediates.md), and WAST fixture rules live in [`../wast/simd-authoring.md`](../wast/simd-authoring.md). |
| `0xFE` | Atomics | atomic load/store/rmw/cmpxchg, wait/notify, fence; core/binary/generator support and the current WAST text gap live in [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md). |
| `0xFB` | GC/aggregate/reference/string-family local surface | `struct.new`, `struct.get`, `struct.set`, `array.new`, descriptor-aware operations, `string.const`, and Starshine's supported array-backed string helpers; WAST/core support boundaries live in [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md) and [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md). |

String and custom-descriptor instructions have additional proposal/local caveats; see [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md), [`../strings/string-const-surface.md`](../strings/string-const-surface.md), [`../custom-descriptors/static-fixtures.md`](../custom-descriptors/static-fixtures.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), and [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) for the local `StringRefsSec` caveat.

The binary-invalid lane now has focused malformed- and overwide-subopcode ULEB fixtures for the supported `0xFB`, `0xFC`, `0xFD`, and `0xFE` prefixed spaces (`malformed-gc-prefix-subopcode-uleb`, `malformed-bulk-prefix-subopcode-uleb`, `malformed-simd-prefix-subopcode-uleb`, `malformed-atomic-prefix-subopcode-uleb`, `overwide-gc-prefix-subopcode-uleb`, `overwide-bulk-prefix-subopcode-uleb`, `overwide-simd-prefix-subopcode-uleb`, and `overwide-atomic-prefix-subopcode-uleb`) plus reserved-subopcode fixtures for bulk/table (`invalid-prefix-subopcode-byte`) and atomics (`invalid-atomic-prefix-subopcode-byte`).

## Validation Contract

After decode, module validation supplies the environment needed for instruction typing. The full phase order is in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md); instruction validation depends on that page because code bodies are typechecked only after types, imports, function declarations, tables, memories, tags, globals, elements, data, start/export checks, and `ref.func` declaration bookkeeping are ready.

Key typechecker responsibilities:

- [`Typecheck for Expr`](../../../src/validate/typecheck.mbt) runs instructions in order and threads a `TcState` containing environment, operand stack, reachability, and escape state.
- `block`, `loop`, `if`, and `try_table` expand their `BlockType`, install labels, typecheck child expressions, and verify result stacks; ordinary WAST control-flow fixture rules live in [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md), while `try_table` catch payload/label rules are summarized in [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md).
- `call`, `call_indirect`, and ordinary `call_ref` validate function/type/table/reference operands plus callee parameter/result stack effects above the byte layer; WAST fixture guidance for direct calls, function imports/exports/starts, the function/type side of `call_indirect`, and the current ordinary-`call_ref` core/binary-versus-text split lives in [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md).
- `br`, `br_if`, `br_table`, `return`, and tail calls use label or function result types rather than raw byte structure; ordinary branch payload/fallthrough guidance lives in [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md), and WAST fixture guidance for `return_call`, `return_call_indirect`, and `return_call_ref` lives in [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md).
- `local.get`, `local.set`, `local.tee`, `global.get`, and `global.set` validate local/global index existence, stack operand types, and global mutability above the byte layer; fixture and rewrite rules live in [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md).
- Scalar numeric constants, comparisons, arithmetic, conversions, reinterprets, sign-extension, and saturating truncations validate stack arity and exact operand/result value types above the byte layer; text fixture rules and rewrite hazards live in [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md).
- `memory.init`, `data.drop`, `memory.copy`, and `memory.fill` validate memory/data resource indices, stack operands, and data-count preconditions above the binary `0xFC` immediates; malformed and overwide invalid-binary fixtures now cover the data/memory index carriers for `data.drop`, `memory.init`, and `memory.copy`. Use [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md) for the runtime memory stack/effect contract and [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md) for `align=` / `offset=`. `table.get`, `table.set`, `table.size`, `table.grow`, `table.fill`, `table.init`, `elem.drop`, and `table.copy` validate table/segment resource indices and stack operands separately, and malformed/overwide invalid-binary fixtures cover the table/element index carriers for those table instructions plus `elem.drop`; for text-level table-index defaults, `table.init` ordering, and table64 caveats, use [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md).
- Reference and GC aggregate instructions have layered semantics: `ref.func` is syntactically just an immediate but also needs whole-module declaration checking; `ref.test` / `ref.cast` and `br_on_*` need hierarchy, nullability, and label-payload checks; `struct.*` / `array.*` need type, field, mutability, segment, and packed-signedness checks above the byte layer. Malformed and overwide invalid-binary fixtures now cover selected GC aggregate type/field/data/element index immediates (`struct.new`, `struct.get`, `array.new_data`, and `array.new_elem`) while validation remains responsible for semantic legality after those immediates decode. See [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), and [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md).
- Unreachable code is stack-polymorphic: missing operands can become bottom values, while concrete values pushed after unreachable still have to be consumed correctly. Use [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md) for the focused validator mechanics and regression map.

## Concrete Before/After Mental Models

### Code section body versus absolute function index

```text
ImportSec: 1 imported function
FuncSec:   [typeidx for $a, typeidx for $b]
CodeSec:   [body for $a, body for $b]

absolute FuncIdx(0) = imported function
absolute FuncIdx(1) = CodeSec body 0 ($a)
absolute FuncIdx(2) = CodeSec body 1 ($b)
```

Instruction immediates such as `call`, `return_call`, `ref.func`, exports, starts, and element payloads use absolute `FuncIdx` values. Code-section body ordinals do not. That distinction is why function-remapping passes must update both section vectors and every instruction/metadata carrier. Direct call and function-module WAST authoring lives in [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md); the `return_call*` family is also covered from the WAST and CFG side in [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md).

### Structured expression nesting

```wat
(block
  (i32.const 1)
  (if
    (then (nop))
    (else (unreachable))))
```

On the wire, the inner `if` has an `else` and its own `end`; the outer block has another `end`; the containing expression has its final `end`. Starshine's structured decoder turns this into nested `Instruction::Block` / `Instruction::If` values and refuses inputs that exceed the nesting guard.

### Memory argument after memory rewrites

A valid instruction before a pass:

```text
I32Load(MemArg(align_pow=2, mem=None, offset=0))
```

can become invalid if a pass deletes the default memory, changes an i64 memory to i32 with an oversized offset, or copies the memarg to a narrower access where the alignment is now too large. Re-run module validation after memory-index or memory-type rewrites, and use [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md) when the same case must be explained as WAST text.

## Pass And Tooling Checklist

Before committing a pass, fuzzer change, or binary/WAST codec change that touches instructions:

- Update both decode and encode paths for every new instruction variant; keep prefixed opcode families symmetric.
- Add or refresh binary roundtrip coverage in [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) for new immediates, lane arrays, memargs, or blocktypes.
- Add validator/typechecker coverage for semantic stack effects, not just decode success.
- If an instruction refers to functions, tables, memories, globals, tags, types, elements, data segments, locals, labels, or the local string pool, update the relevant section page's rewrite checklist.
- For text support, update the WAST parser/lowerer/printer path as well as binary encode/decode.
- For optimizer work, run the normal validation gate from [`../tooling/validation-gates.md`](../tooling/validation-gates.md); pass parity still needs Binaryen oracle comparison where the pass has an upstream equivalent.

## Edge Cases And Invariants

- **Binary well-formedness is not validation.** A decoded instruction can still have invalid stack effects or unresolved indices.
- **LEB well-formedness is byte-layer only.** Do not reject official-compatible overlong encodings as malformed, but do reject EOF, too-many-byte, out-of-range, and invalid terminal unused/sign-extension-bit forms before validation; the focused examples live in [`leb128-and-integer-encoding.md`](leb128-and-integer-encoding.md).
- **Expression terminators are structural.** Do not preserve or synthesize raw `end` opcodes in the `Instruction` enum; they are owned by expression/control encoding. Use [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md) when the same shape needs text-level label, `br_if`, or `br_table` guidance.
- **Blocktype type indices must name function types.** Struct/array type indices are not legal blocktype expansions.
- **Recursive-index blocktypes are not binary-output-safe.** Normalize to absolute type indices before encode.
- **Explicit memory indices are encoded through Starshine's extended memarg form.** Passes touching memories must update `MemArg` carriers, not only `memory.size` / `memory.grow` instructions.
- **Prefixed spaces are part of instruction coverage.** A one-byte opcode audit misses scalar `0xFC` saturating truncations, bulk memory, table bulk operations, SIMD, atomics, and GC/custom-descriptor operations. For scalar numeric text fixtures, pair this binary guide with [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md) so constants, signedness, trap behavior, and `[FZG]002` coverage stay aligned. For GC aggregate fixtures, pair it with [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md) so the current WAST support gap around `struct.set` and `array.*` does not get mistaken for core/binary absence. For table text fixtures specifically, pair this binary guide with [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md) so default table indices and `table.init` element/table ordering stay aligned across text, core, and binary layers. For SIMD, pair it with [`../wast/simd-authoring.md`](../wast/simd-authoring.md) so lane-shaped text fixtures stay aligned with the canonical 16-byte core representation. For atomics, pair it with [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md) so `0xFE` byte coverage, `[FZG]017` generator evidence, and missing WAST text support stay separated.
- **SIMD lane immediates need shape-specific evidence.** Starshine's WAST lowerer enforces exact lane bounds, but binary decode currently uses a coarse generic `<16` lane guard except for shuffle's `<32` decoder; see [`../validate/simd-lane-immediates.md`](../validate/simd-lane-immediates.md) and [`../wast/simd-authoring.md`](../wast/simd-authoring.md) before treating binary-origin lane acceptance as validation parity.
- **Deep nesting is a fuzz-hardening boundary.** Raising or removing the decoder limit should be treated as a security/performance-sensitive codec change.

## Sources

- SIMD lane-immediate validation refresh: [`../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md`](../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md), [`../validate/simd-lane-immediates.md`](../validate/simd-lane-immediates.md)
- LEB128 binary integer refresh: [`../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md`](../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md), [`leb128-and-integer-encoding.md`](leb128-and-integer-encoding.md)
- Official source snapshot: [`../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md`](../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md)
- Local code source map: [`../raw/wasm/2026-05-13-instruction-expression-binary-sources.md`](../raw/wasm/2026-05-13-instruction-expression-binary-sources.md)
- Core representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
- Binary codec and tests: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Validation: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt), [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md)
- Text path: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md), [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md), [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md), [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md), [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md), [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md), [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../wast/simd-authoring.md`](../wast/simd-authoring.md)
