---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md
  - ../raw/wasm/2026-05-20-scalar-numeric-literal-and-rewrite-refresh.md
  - ../raw/wasm/2026-06-04-scalar-numeric-current-refresh.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/arbitrary.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - variable-instruction-authoring.md
  - memory-instruction-authoring.md
  - memory-argument-authoring.md
  - simd-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../validate/module-validation-phases.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Numeric Instruction Authoring

## Overview

Use this page when writing or reviewing scalar numeric WAST fixtures for `i32`, `i64`, `f32`, and `f64` instructions. It covers:

- constants: `i32.const`, `i64.const`, `f32.const`, and `f64.const`;
- integer tests and comparisons such as `i32.eqz`, `i64.eq`, and `i32.lt_s`;
- integer arithmetic, bitwise, shift, rotate, and count operations;
- float unary, binary, and comparison operations;
- conversions, reinterprets, sign-extension operations, and saturating truncations.

This page is scalar-only. Memory loads/stores use [`memory-instruction-authoring.md`](memory-instruction-authoring.md) for stack/effect behavior and [`memory-argument-authoring.md`](memory-argument-authoring.md) for `align=` / `offset=`, local/global operands use [`variable-instruction-authoring.md`](variable-instruction-authoring.md), vector instructions use [`simd-authoring.md`](simd-authoring.md), and byte-level instruction encoding is summarized in [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md). The checked primary-source and local-code manifest is [`../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md`](../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md). The targeted 2026-05-20 refresh in [`../raw/wasm/2026-05-20-scalar-numeric-literal-and-rewrite-refresh.md`](../raw/wasm/2026-05-20-scalar-numeric-literal-and-rewrite-refresh.md) sharpens the official-literal versus Starshine lexer/parser/lowerer split and the optimizer rewrite hazards around traps, saturation, reinterprets, signedness, NaNs, and signed zero. The 2026-06-04 current-source refresh in [`../raw/wasm/2026-06-04-scalar-numeric-current-refresh.md`](../raw/wasm/2026-06-04-scalar-numeric-current-refresh.md) rechecked the current WebAssembly Core 3.0 pages dated 2026-06-03 and found no new scalar numeric family or local-code drift that needs a separate page.

## Beginner Mental Model

WebAssembly numeric instructions are stack instructions. Constants push values. Most other scalar numeric instructions do not name operands; they pop operands from the stack and push a result.

```wat
(module
  (func (param $x i32) (result i32)
    (i32.add
      (local.get $x)
      (i32.const 1)))

  (func (param f64) (result i32)
    (i32.trunc_sat_f64_s
      (local.get 0)))

  (func (param i64) (result i32)
    (i64.eqz
      (local.get 0))))
```

After Starshine lowers this text, `$x` is already a numeric `LocalIdx`, constants are core `Instruction::I32Const` / `F64Const` values, and operators are no-argument instruction variants such as `I32Add`, `I32TruncSatF64S`, and `I64Eqz`.

## Layer Model

| Layer | Owner | Numeric facts to remember |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Registers scalar numeric spellings and classifies them as `Const`, `Unary`, `Binary`, `Test`, `Compare`, or `Convert`. Only `*.const` forms carry literal text. |
| WAST lowerer/printer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Parses literal text into core numeric wrappers, maps no-argument numeric opcodes through `wt_numeric_noarg`, and prints constants as keyword plus stored text. |
| Core instruction model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Keeps scalar numeric constants and operators as explicit `Instruction` variants and constructor helpers. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Uses `0x41`..`0x44` for scalar constants, one-byte opcodes for most scalar numeric ops, `0xC0`..`0xC4` for sign-extension, and `0xFC` subcodes `0`..`7` for saturating truncations. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) | Checks operand/result stack types. Constants push their type, comparisons and integer tests produce `i32`, conversions have fixed source/result pairs, `trunc_sat` has the same stack types as ordinary truncation but different runtime behavior, and constant expressions still run ordinary typechecking after the const-instruction filter. |
| Fuzz / generator evidence | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | `[FZG]002` proves a widened valid-generator scalar numeric matrix; WAST arbitrary currently mirrors representative text shapes, not every scalar numeric opcode. |

## Text Shapes And Stack Rules

### Constants push values

```wat
(i32.const 7)       ;; pushes i32
(i64.const -1)      ;; pushes i64
(f32.const 3.5)     ;; pushes f32
(f64.const -inf)    ;; pushes f64
```

Starshine's WAST parser records the literal text, and the lowerer parses it later. The official text-value grammar is the portability target, but Starshine has several local paths that should not be conflated:

- The lexer recognizes decimal and hexadecimal numeric tokens, underscore-separated digit runs, hexadecimal floats, infinities, and `nan` / payload spellings. That proves tokenization, not full semantic acceptance by every downstream scalar-constant path.
- `i32.const` and `i64.const` lower through `wt_parse_i32` / `wt_parse_i64`, which currently delegate ordinary scalar integer text to signed parsing. Index parsing and SIMD-lane parsing have separate helper paths that strip underscores or parse unsigned hex explicitly, so do not use those surfaces as proof that every scalar integer literal spelling roundtrips. Keep non-decimal, separator-heavy, or unsigned-wrap scalar integer fixtures focused and test-backed.
- `f32.const` and `f64.const` body instructions forward integer and float tokens to lowering. The lowerer can canonicalize `nan*` text when it receives that text, while WAST assertion-result parsing has explicit `nan:canonical` / `nan:arithmetic` expectation variants. Broad roundtrip tests should not assume exact NaN payload spelling survives unless the test checks that path deliberately.
- In WAST spec assertions, constants also appear as expected values. `render_wast_value(...)` and `render_wast_result(...)` print the scalar constant spelling family for `assert_return` arguments, including the assertion-only NaN expectation spellings.

### Tests and comparisons produce `i32`

WebAssembly does not have a separate boolean value type. Integer tests and numeric comparisons push `i32` results:

| Shape | Stack before | Stack after |
| --- | --- | --- |
| `i32.eqz` | `... i32` | `... i32` |
| `i64.eqz` | `... i64` | `... i32` |
| `i32.lt_s`, `i32.lt_u`, `i32.eq`, ... | `... i32 i32` | `... i32` |
| `i64.lt_s`, `i64.lt_u`, `i64.eq`, ... | `... i64 i64` | `... i32` |
| `f32.lt`, `f32.eq`, ... | `... f32 f32` | `... i32` |
| `f64.lt`, `f64.eq`, ... | `... f64 f64` | `... i32` |

This matters for pass authors: folding `(i32.eq ...)` or `(f64.lt ...)` creates an `i32.const 0/1`-shaped value, not a reference, not `i8`, and not an untyped boolean.

### Unary, binary, and conversion families

| Family | Examples | Stack rule |
| --- | --- | --- |
| Integer unary/count | `i32.clz`, `i64.popcnt` | consumes one matching integer, pushes same integer type |
| Integer binary/arithmetic | `i32.add`, `i64.rem_s`, `i32.rotl` | consumes two matching integers, pushes same integer type |
| Float unary | `f32.abs`, `f64.sqrt`, `f32.nearest` | consumes one matching float, pushes same float type |
| Float binary | `f32.add`, `f64.min`, `f32.copysign` | consumes two matching floats, pushes same float type |
| Width/float conversions | `i32.wrap_i64`, `f64.promote_f32`, `f32.demote_f64` | fixed source/result pair in the opcode name |
| Reinterprets | `i32.reinterpret_f32`, `f64.reinterpret_i64` | same bit-width source/result pair; this is a bit reinterpretation, not numeric conversion |
| Sign extension | `i32.extend8_s`, `i64.extend32_s` | consumes and produces the same integer value type after sign-extending a narrower lane width |
| Saturating truncation | `i32.trunc_sat_f64_s`, `i64.trunc_sat_f32_u` | consumes float, pushes integer; differs from ordinary trunc by saturating instead of trapping on out-of-range/NaN inputs |

The text form does not put immediate operands after these operators. In folded syntax, child expressions provide stack operands:

```wat
(i32.add (i32.const 4) (i32.const 5))
(i64.extend32_s (local.get 0))
(f32.reinterpret_i32 (i32.const 0x3f800000))
```

In plain instruction syntax, the same values appear before the operator:

```wat
i32.const 4
i32.const 5
i32.add
```

## Current Source Refresh

The 2026-06-04 source refresh confirms the current official Core 3.0 scalar numeric surface still matches this guide's family split: constants, tests, comparisons, unary/binary integer and float operations, conversions, reinterprets, sign extension, and saturating truncation stay scalar; SIMD and relaxed-SIMD remain on [`simd-authoring.md`](simd-authoring.md), memory opcodes remain on [`memory-instruction-authoring.md`](memory-instruction-authoring.md), and reference/GC/string opcodes remain on their focused pages.

Two source-current caveats are worth keeping visible:

- **Official text literals are broader than every Starshine local path.** Current WebAssembly text permits decimal/hex integer forms with separators and several float special forms. Starshine recognizes many of these at the lexer/lowerer boundary, but scalar body constants, index parsing, SIMD lane parsing, and WAST assertion result rendering still use different helper paths. Keep large unsigned wraparound, separator-heavy scalar integers, hex floats, and NaN payload roundtrips focused and test-backed.
- **Official and Starshine constant-expression lists differ.** The current official constant-expression predicate admits scalar numeric constants plus only integer `i32`/`i64` `add`/`sub`/`mul` among scalar numeric no-argument operators. Starshine's [`validate_const_instr(...)`](../../../src/validate/validate.mbt) deliberately admits many more scalar numeric operators locally, then relies on ordinary typechecking for arity and result type. Use [`../validate/constant-expressions.md`](../validate/constant-expressions.md) when a pass or fixture depends on initializer portability.

## Binary And Validation Contract

The binary layer and validation layer deliberately answer different questions.

- Binary decode/encode proves the opcode and literal/immediate bytes are well-formed.
- Validation proves the instruction is legal in context and has the right stack types.

Important byte families:

| Byte family | Instructions |
| --- | --- |
| `0x41`..`0x44` | `i32.const`, `i64.const`, `f32.const`, `f64.const` plus literal immediates |
| `0x45`..`0xA6` | scalar tests, comparisons, integer/float arithmetic, and float unary/binary operations |
| `0xA7`..`0xBF` | scalar conversions and reinterprets |
| `0xC0`..`0xC4` | integer sign-extension instructions |
| `0xFC 0`..`0xFC 7` | saturating truncations before the same prefix space continues into bulk-memory/table operations |

For WAST authors, the biggest mistake is confusing byte presence with semantic validity. `i32.add` has no immediate and can always decode, but validation still fails if the stack does not contain two `i32` values. Conversely, `i32.trunc_sat_f64_s` and `i32.trunc_f64_s` have related source/result types but different runtime failure behavior: ordinary truncation traps for NaN or out-of-range inputs, while saturating truncation returns zero or clamps to the target integer range. A pass cannot swap them just because typechecking stays green.

## Constant Expressions

Starshine's constant-expression filter is intentionally broader than the current official scalar numeric constant-expression set. Official Core 3.0 admits scalar numeric constants plus integer `i32`/`i64` `add`/`sub`/`mul`; Starshine locally admits scalar numeric constants and many more no-argument scalar numeric operators, then runs ordinary stack typechecking and enforces exactly one expected result.

That means this is locally meaningful as a constant initializer when the operands and result type line up:

```wat
(module
  (global $g i32
    (i32.add (i32.const 40) (i32.const 2))))
```

But the const-instruction filter is not a free pass:

- wrong operand types are still rejected by typechecking;
- expressions that leave too many or too few values are rejected;
- unreachable constant expressions are rejected;
- local variables are unavailable in constant-expression environments;
- resource-sensitive instructions still follow their focused pages, such as immutable `global.get` in [`variable-instruction-authoring.md`](variable-instruction-authoring.md), segment offsets in [`data-segment-authoring.md`](data-segment-authoring.md) / [`element-segment-authoring.md`](element-segment-authoring.md), and the validator-side allow-list in [`../validate/constant-expressions.md`](../validate/constant-expressions.md).

## Rewrite And Signoff Guidance

When a pass changes scalar numeric code, check these invariants before accepting output:

1. **Stack type:** comparisons and tests produce `i32`; conversions must preserve the exact source/result pair implied by the opcode name.
2. **Trap behavior:** ordinary integer division/remainder and non-saturating float-to-int truncations can trap; `trunc_sat` does not trap for the same out-of-range/NaN cases. Do not fold through a trap boundary without proof.
3. **Signedness:** `_s` and `_u` suffixes are semantic. They are not alternate spellings and cannot be interchanged because a fixture happens to use a small positive literal.
4. **Bit-level identity:** `reinterpret` preserves bits, while `convert`, `promote`, `demote`, `wrap`, and `extend` compute numeric conversions. Optimizers must keep that distinction visible.
5. **NaN and float corner cases:** float `min`/`max`, NaN payloads, signed zero, and rounding operations need oracle or source-backed evidence before canonicalization. The 2026-05-20 literal/rewrite refresh is the current wiki anchor for why typechecking alone is not enough here.
6. **Constant expression context:** if a pass moves numeric work into globals, table initializers, element/data offsets, or other initializer contexts, rerun module validation rather than assuming body-valid code is initializer-valid.
7. **Coverage vocabulary:** use [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) for `[FZG]002` valid-generator evidence, and [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md) when the same syntax is only parser/printer coverage.

Useful local signoff lanes for numeric authoring changes are `moon test src/wast`, `moon test src/binary`, `moon test src/validate`, then the normal validation gate from [`../tooling/validation-gates.md`](../tooling/validation-gates.md). Optimizer changes still need pass-specific Binaryen oracle comparison when an upstream pass owns the transform family.

## Common Mistakes

- Adding an immediate after `i32.add`, `f64.sqrt`, `i64.extend32_s`, or `i32.trunc_sat_f64_s`. Only the four scalar constants have literal immediates.
- Treating comparison results as a separate boolean type. They are `i32` values.
- Folding `i32.trunc_f64_s` to `i32.trunc_sat_f64_s` or the reverse without proving the runtime trap behavior is preserved.
- Assuming unsigned and signed suffixes are cosmetic.
- Assuming exact NaN payload text survives every local parser/lowerer/printer path without focused tests; body instructions and assertion-result expectations do not currently use identical token handling.
- Using WAST arbitrary coverage as proof that every `[FZG]002` scalar numeric opcode has typed valid-generator coverage; those are related but separate surfaces.

## Sources

- Primary-source manifest: [`../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md`](../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md)
- Targeted literal/rewrite refresh: [`../raw/wasm/2026-05-20-scalar-numeric-literal-and-rewrite-refresh.md`](../raw/wasm/2026-05-20-scalar-numeric-literal-and-rewrite-refresh.md)
- Current-source refresh: [`../raw/wasm/2026-06-04-scalar-numeric-current-refresh.md`](../raw/wasm/2026-06-04-scalar-numeric-current-refresh.md)
- Official WebAssembly instruction sources: <https://webassembly.github.io/spec/core/text/instructions.html>, <https://webassembly.github.io/spec/core/syntax/instructions.html>, <https://webassembly.github.io/spec/core/binary/instructions.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>
- Official numeric execution and text values sources: <https://webassembly.github.io/spec/core/exec/numerics.html>, <https://webassembly.github.io/spec/core/text/values.html>
- Local parser/lowerer/printer sources listed in the frontmatter above.
