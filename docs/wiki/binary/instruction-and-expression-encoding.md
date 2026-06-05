---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-05-multi-memory-core-boundary-refresh.md
  - ../raw/wasm/2026-06-05-memory-control-boundary-refresh.md
  - ../raw/wasm/2026-06-05-wide-arithmetic-boundary-refresh.md
  - ../raw/wasm/2026-06-05-relaxed-atomics-boundary-refresh.md
  - ../raw/wasm/2026-06-04-simd-lane-validation-current-refresh.md
  - ../raw/wasm/2026-06-04-leb128-current-refresh.md
  - ../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md
  - ../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md
  - ../raw/wasm/2026-05-20-call-ref-source-refresh.md
  - ../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md
  - ../raw/wasm/2026-05-13-instruction-expression-binary-sources.md
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../raw/wasm/2026-06-04-stack-polymorphism-current-refresh.md
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
  - ../wasm-multi-memory-boundary.md
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
  - ../wasm-memory-control-boundary.md
  - ../wasm-wide-arithmetic-boundary.md
  - ../wasm-relaxed-atomics-boundary.md
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

Official core memory arguments are alignment plus offset plus selected-memory behavior in current Core multi-memory contexts. Starshine represents explicit selected memories as `MemArg(U32(align_pow), Some(memidx), U64(offset))`; binary encode writes `align_pow + 64`, then the memory index, then the offset. With no explicit memory index, encode writes `align_pow` followed by the offset. The focused status and layer boundary is [`../wasm-multi-memory-boundary.md`](../wasm-multi-memory-boundary.md); WAST text authoring caveats, including text-byte `align=` versus core exponent form and the current lack of explicit nonzero memory indices in WAST memargs, are documented in [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md).

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
| `0xFC` | Saturating conversion, bulk memory, and table operations | `i32.trunc_sat_f32_s`, `memory.init`, `data.drop`, `memory.copy`, `table.init`, `elem.drop`; active-proposal Memory Control opcodes such as `memory.discard` and active-proposal Wide Arithmetic opcodes such as `i64.add128` / `i64.mul_wide_u` are not current Starshine decode/encode cases |
| `0xFD` | SIMD | `v128.load`, `i8x16.shuffle`, lane extract/replace, relaxed SIMD forms; relaxed opcodes are fixture-locked at exact subopcodes `256..275`; byte-level lane immediates still need post-decode shape validation in [`../validate/simd-lane-immediates.md`](../validate/simd-lane-immediates.md), and WAST fixture rules live in [`../wast/simd-authoring.md`](../wast/simd-authoring.md). |
| `0xFE` | Atomics | ordinary atomic load/store/rmw/cmpxchg, wait/notify, fence, plus shared-GC `struct.atomic.get*` subcodes; core/binary/generator support and the current WAST text gap live in [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md). Active-proposal Relaxed Atomics adds ordering-bearing encodings and `pause`, which are not current Starshine codec cases; see [`../wasm-relaxed-atomics-boundary.md`](../wasm-relaxed-atomics-boundary.md). |
| `0xFB` | GC/aggregate/reference/string-family local surface | `struct.new`, `struct.get`, `struct.set`, `array.new`, descriptor-aware operations, `string.const`, and Starshine's supported array-backed string helpers; WAST/core support boundaries live in [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../custom-descriptors/descriptor-instruction-surface.md`](../custom-descriptors/descriptor-instruction-surface.md), and [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md). |

String and custom-descriptor instructions have additional proposal/local caveats; see [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md) for shared status vocabulary, plus [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md), [`../strings/string-const-surface.md`](../strings/string-const-surface.md), [`../custom-descriptors/descriptor-instruction-surface.md`](../custom-descriptors/descriptor-instruction-surface.md), [`../custom-descriptors/static-fixtures.md`](../custom-descriptors/static-fixtures.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), and [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) for the local `StringRefsSec` caveat. Memory Control also has proposal/local caveats: [`../wasm-memory-control-boundary.md`](../wasm-memory-control-boundary.md) records that `memory.discard` / commit / protection / mapping surfaces have no current Starshine `Instruction` or binary opcode support. Wide Arithmetic has its own active-proposal caveat: [`../wasm-wide-arithmetic-boundary.md`](../wasm-wide-arithmetic-boundary.md) records that current Starshine has no `i64.add128`, `i64.sub128`, `i64.mul_wide_s`, or `i64.mul_wide_u` instruction or binary support, and that the proposal sources currently disagree about the exact `0xFC` subopcode range.

The binary-invalid lane now has focused single-byte core reserved-opcode fixtures for representative non-prefix gaps: control `0x06` (`invalid-core-control-reserved-opcode-byte`), reference/call `0x19` (`invalid-core-reference-reserved-opcode-byte`), variable/memory boundary `0x27` (`invalid-core-memory-reserved-opcode-byte`), and post-sign-extension `0xC5` (`invalid-core-post-signext-reserved-opcode-byte`), in addition to the high reserved core byte `0xFF` (`invalid-opcode-byte`). Its white-box inventory also asserts decode rejection for the current non-prefix reserved core bytes `0x06`, `0x07`, `0x09`, `0x16..0x19`, `0x1D`, `0x1E`, `0x27`, `0xC5..0xCF`, `0xD7..0xFA`, and `0xFF`; expression terminator `0x0B` and proposal prefixes `0xFB..0xFE` are intentionally tracked separately. It also has focused truncated-prefix fixtures for function bodies ending immediately after supported proposal prefix opcodes (`truncated-gc-prefix-opcode`, `truncated-bulk-prefix-opcode`, `truncated-simd-prefix-opcode`, and `truncated-atomic-prefix-opcode`), malformed- and overwide-subopcode ULEB fixtures for the supported `0xFB`, `0xFC`, `0xFD`, and `0xFE` prefixed spaces (`malformed-gc-prefix-subopcode-uleb`, `malformed-bulk-prefix-subopcode-uleb`, `malformed-simd-prefix-subopcode-uleb`, `malformed-atomic-prefix-subopcode-uleb`, `overwide-gc-prefix-subopcode-uleb`, `overwide-bulk-prefix-subopcode-uleb`, `overwide-simd-prefix-subopcode-uleb`, and `overwide-atomic-prefix-subopcode-uleb`) plus reserved-subopcode fixtures for the generic bulk/table lane (`invalid-prefix-subopcode-byte`), explicit GC/bulk/SIMD lanes (`invalid-gc-prefix-subopcode-byte`, `invalid-bulk-prefix-subopcode-byte`, `invalid-simd-prefix-subopcode-byte`), and atomics (`invalid-atomic-prefix-subopcode-byte`). It also has wrong-trailing-immediate fixtures that intentionally reach a valid prefixed subopcode before corrupting the operand-context immediate: `malformed-gc-struct-new-trailing-immediate`, `malformed-bulk-table-init-trailing-immediate`, `malformed-simd-extract-lane-trailing-immediate`, and `malformed-atomic-load-trailing-immediate`. The SIMD byte lane has malformed and overwide memarg carriers for `v128.load` / `v128.store`: `malformed-simd-load-memarg-align-uleb`, `malformed-simd-store-memarg-align-uleb`, `malformed-simd-load-memarg-offset-uleb`, `malformed-simd-store-memarg-offset-uleb`, `overwide-simd-load-memarg-align-uleb`, `overwide-simd-store-memarg-align-uleb`, `overwide-simd-load-memarg-offset-uleb`, and `overwide-simd-store-memarg-offset-uleb`. These reach past valid `0xFD 0x00` `v128.load` and `0xFD 0x0B` `v128.store` subopcodes before corrupting the following memarg alignment or offset ULEB. The same SIMD operand-context matrix now covers lane load/store forms with `malformed-simd-load-lane-memarg-align-uleb`, `malformed-simd-store-lane-memarg-align-uleb`, `malformed-simd-load-lane-memarg-offset-uleb`, `malformed-simd-store-lane-memarg-offset-uleb`, `overwide-simd-load-lane-memarg-align-uleb`, `overwide-simd-store-lane-memarg-align-uleb`, `overwide-simd-load-lane-memarg-offset-uleb`, and `overwide-simd-store-lane-memarg-offset-uleb`, reaching past valid `0xFD 0x54` / `0xFD 0x58` lane subopcodes before corrupting their memarg ULEBs. The relaxed-SIMD laneselect operand-context lane adds `malformed-relaxed-simd-laneselect-mask-local-index-uleb` and `overwide-relaxed-simd-laneselect-mask-local-index-uleb`, which keep two `v128.const` operands plus the valid `0xFD 0x89 0x02` `i8x16.relaxed_laneselect` bytes in the body while corrupting the mask operand's `local.get` index ULEB. The atomics byte lane mirrors that operand-context coverage for `i32.atomic.load`, `i32.atomic.store`, `memory.atomic.notify`, `i32.atomic.wait`, `i32.atomic.rmw.add`, and `i32.atomic.rmw.cmpxchg`: `malformed-atomic-load-memarg-align-uleb`, `malformed-atomic-store-memarg-align-uleb`, `malformed-atomic-notify-memarg-align-uleb`, `malformed-atomic-wait-memarg-align-uleb`, `malformed-atomic-rmw-memarg-align-uleb`, `malformed-atomic-cmpxchg-memarg-align-uleb`, `overwide-atomic-load-memarg-align-uleb`, `overwide-atomic-store-memarg-align-uleb`, `overwide-atomic-notify-memarg-align-uleb`, `overwide-atomic-wait-memarg-align-uleb`, `overwide-atomic-rmw-memarg-align-uleb`, `overwide-atomic-cmpxchg-memarg-align-uleb`, `malformed-atomic-load-memarg-offset-uleb`, `malformed-atomic-store-memarg-offset-uleb`, `malformed-atomic-notify-memarg-offset-uleb`, `malformed-atomic-wait-memarg-offset-uleb`, `malformed-atomic-rmw-memarg-offset-uleb`, `malformed-atomic-cmpxchg-memarg-offset-uleb`, `overwide-atomic-load-memarg-offset-uleb`, `overwide-atomic-store-memarg-offset-uleb`, `overwide-atomic-notify-memarg-offset-uleb`, `overwide-atomic-wait-memarg-offset-uleb`, `overwide-atomic-rmw-memarg-offset-uleb`, and `overwide-atomic-cmpxchg-memarg-offset-uleb`. These reach past valid `0xFE 0x10`, `0xFE 0x17`, `0xFE 0x00`, `0xFE 0x01`, `0xFE 0x1E`, and `0xFE 0x48` atomics subopcodes before corrupting the following memarg alignment or offset ULEB.

## Validation Contract

After decode, module validation supplies the environment needed for instruction typing. The full phase order is in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md); instruction validation depends on that page because code bodies are typechecked only after types, imports, function declarations, tables, memories, tags, globals, elements, data, start/export checks, and `ref.func` declaration bookkeeping are ready.

Key typechecker responsibilities:

- [`Typecheck for Expr`](../../../src/validate/typecheck.mbt) runs instructions in order and threads a `TcState` containing environment, operand stack, reachability, and escape state.
- `block`, `loop`, `if`, and `try_table` expand their `BlockType`, install labels, typecheck child expressions, and verify result stacks; ordinary WAST control-flow fixture rules live in [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md), while `try_table` catch payload/label rules are summarized in [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md).
- `call`, `call_indirect`, and ordinary `call_ref` validate function/type/table/reference operands plus callee parameter/result stack effects above the byte layer; WAST fixture guidance for direct calls, function imports/exports/starts, the function/type side of `call_indirect`, and the current ordinary-`call_ref` core/binary-versus-text split lives in [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md).
- `br`, `br_if`, `br_table`, `return`, and tail calls use label or function result types rather than raw byte structure; ordinary branch payload/fallthrough guidance lives in [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md), and WAST fixture guidance for `return_call`, `return_call_indirect`, and `return_call_ref` lives in [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md).
- `local.get`, `local.set`, `local.tee`, `global.get`, and `global.set` validate local/global index existence, stack operand types, and global mutability above the byte layer; fixture and rewrite rules live in [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md).
- Scalar numeric constants, comparisons, arithmetic, conversions, reinterprets, sign-extension, and saturating truncations validate stack arity and exact operand/result value types above the byte layer; text fixture rules and rewrite hazards live in [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md).
- `memory.init`, `data.drop`, `memory.copy`, and `memory.fill` validate memory/data resource indices, stack operands, and data-count preconditions above the binary `0xFC` immediates; malformed and overwide invalid-binary fixtures now cover the data/memory index carriers for `data.drop`, `memory.init`, `memory.copy`, and `memory.fill`. Use [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md) for the runtime memory stack/effect contract and [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md) for `align=` / `offset=`. `table.get`, `table.set`, `table.size`, `table.grow`, `table.fill`, `table.init`, `elem.drop`, and `table.copy` validate table/segment resource indices and stack operands separately, and malformed/overwide invalid-binary fixtures cover the table/element index carriers for those table instructions plus `elem.drop`; for text-level table-index defaults, `table.init` ordering, and table64 caveats, use [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md).
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
- Add or refresh binary roundtrip coverage in [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) for new opcodes, immediates, lane arrays, memargs, or blocktypes.
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
- **Explicit memory indices are encoded through Starshine's selected-memory memarg form.** Passes touching memories must update `MemArg` carriers, `memory.size`, `memory.grow`, `memory.fill`, both `memory.copy` operands, `memory.init`, and active data modes together; route selected-memory status and WAST gaps through [`../wasm-multi-memory-boundary.md`](../wasm-multi-memory-boundary.md).
- **Prefixed spaces are part of instruction coverage.** A one-byte opcode audit misses scalar `0xFC` saturating truncations, bulk memory, table bulk operations, SIMD, atomics, and GC/custom-descriptor operations. It can also overclaim active-proposal coverage: Memory Control's prototype `memory.discard` discussion and Wide Arithmetic's proposed `i64.add128` / `i64.mul_wide_*` discussion are not current Starshine `0xFC` decode/encode cases, and Relaxed Atomics' ordering-bearing `0xFE` encodings plus `pause` are not current Starshine atomics cases. For scalar numeric text fixtures, pair this binary guide with [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md) so constants, signedness, trap behavior, and `[FZG]002` coverage stay aligned; for Wide Arithmetic specifically, use [`../wasm-wide-arithmetic-boundary.md`](../wasm-wide-arithmetic-boundary.md) because it needs a proposal-gated multi-result numeric slice. For GC aggregate fixtures, pair it with [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md) so the current WAST support gap around `struct.set` and `array.*` does not get mistaken for core/binary absence. For table text fixtures specifically, pair this binary guide with [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md) so default table indices and `table.init` element/table ordering stay aligned across text, core, and binary layers. For SIMD, pair it with [`../wast/simd-authoring.md`](../wast/simd-authoring.md) so lane-shaped text fixtures stay aligned with the canonical 16-byte core representation. For ordinary atomics, pair it with [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md) so `0xFE` byte coverage, `[FZG]017` generator evidence, and missing WAST text support stay separated; for Relaxed Atomics specifically, use [`../wasm-relaxed-atomics-boundary.md`](../wasm-relaxed-atomics-boundary.md) before deciding whether a byte is unsupported-feature evidence or a future codec slice. For Memory Control proposal bytes, use [`../wasm-memory-control-boundary.md`](../wasm-memory-control-boundary.md) before deciding whether the right evidence is unsupported-feature classification or a future codec slice.
- **SIMD lane immediates need shape-specific evidence.** Starshine's WAST lowerer enforces exact lane bounds; binary decode still uses a coarse generic `<16` lane guard except for shuffle's `<32` decoder, and the typechecker now rejects decoded but shape-invalid single-lane forms such as `i64x2.extract_lane 2` or `v128.store32_lane 4`. See [`../validate/simd-lane-immediates.md`](../validate/simd-lane-immediates.md) and [`../wast/simd-authoring.md`](../wast/simd-authoring.md) before treating binary-origin decode acceptance as validation parity.
- **Deep nesting is a fuzz-hardening boundary.** Raising or removing the decoder limit should be treated as a security/performance-sensitive codec change.

## Sources

- Multi-memory Core boundary refresh: [`../raw/wasm/2026-06-05-multi-memory-core-boundary-refresh.md`](../raw/wasm/2026-06-05-multi-memory-core-boundary-refresh.md), [`../wasm-multi-memory-boundary.md`](../wasm-multi-memory-boundary.md)
- Relaxed Atomics boundary refresh: [`../raw/wasm/2026-06-05-relaxed-atomics-boundary-refresh.md`](../raw/wasm/2026-06-05-relaxed-atomics-boundary-refresh.md), [`../wasm-relaxed-atomics-boundary.md`](../wasm-relaxed-atomics-boundary.md)
- Current SIMD lane-immediate validation refresh: [`../raw/wasm/2026-06-04-simd-lane-validation-current-refresh.md`](../raw/wasm/2026-06-04-simd-lane-validation-current-refresh.md), [`../validate/simd-lane-immediates.md`](../validate/simd-lane-immediates.md)
- Original SIMD lane-immediate validation refresh: [`../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md`](../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md)
- LEB128 binary integer refresh: [`../raw/wasm/2026-06-04-leb128-current-refresh.md`](../raw/wasm/2026-06-04-leb128-current-refresh.md), [`../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md`](../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md), [`leb128-and-integer-encoding.md`](leb128-and-integer-encoding.md)
- Official source snapshot: [`../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md`](../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md)
- Local code source map: [`../raw/wasm/2026-05-13-instruction-expression-binary-sources.md`](../raw/wasm/2026-05-13-instruction-expression-binary-sources.md)
- Core representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
- Binary codec and tests: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Validation: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt), [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md)
- Text path: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md), [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md), [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md), [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md), [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md), [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md), [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../wast/simd-authoring.md`](../wast/simd-authoring.md)
