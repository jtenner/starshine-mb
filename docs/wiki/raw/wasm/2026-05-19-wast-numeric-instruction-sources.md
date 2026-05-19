---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-19
sources:
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/syntax/instructions.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - https://webassembly.github.io/spec/core/text/values.html
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast.mbt
  - ../../../../src/wast/arbitrary.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/validate.mbt
  - ../../../../src/validate/gen_valid.mbt
related:
  - ../../wast/numeric-instruction-authoring.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../validate/module-validation-phases.md
  - ../../fuzzing/generator-coverage-ledger.md
  - ../../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Numeric Instruction Source Snapshot (2026-05-19)

## Purpose

This manifest anchors the living WAST scalar numeric instruction guide for `i32`, `i64`, `f32`, and `f64` constants, integer and float unary/binary operations, comparisons, conversions, sign-extension operations, and saturating truncations. It deliberately excludes SIMD/vector instructions, memory loads/stores, reference instructions, and variable instructions, which already have focused pages.

## Primary external sources checked

- WebAssembly core spec, text instructions: <https://webassembly.github.io/spec/core/text/instructions.html>
  - Checked that numeric text instructions are ordinary plain or folded instructions with constant literals only on the four `*.const` forms. The table includes the scalar arithmetic, comparison, conversion, sign-extension, reinterpret, and saturating truncation names used by Starshine.
- WebAssembly core spec, abstract syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Checked the abstract numeric instruction families: constants, tests, comparisons, unary operations, binary operations, conversions, reinterprets, extend operations, and saturating conversions.
- WebAssembly core spec, binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html>
  - Checked the byte-level shape: scalar numeric constants use `0x41` through `0x44` plus literal immediates, most scalar numeric operations are one-byte opcodes from the numeric range, sign-extension uses `0xC0` through `0xC4`, and saturating truncations use `0xFC` subcodes `0` through `7`.
- WebAssembly core spec, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Checked the stack typing for numeric families: constants push their value type, integer `eqz` consumes the matching integer and produces `i32`, comparisons produce `i32`, arithmetic preserves the input numeric type, and conversions/reinterprets have fixed source/result value types.
- WebAssembly core spec, text values: <https://webassembly.github.io/spec/core/text/values.html>
  - Checked the current official numeric literal grammar and special floating-point spellings such as infinities and NaN payload forms. Starshine has multiple local float-literal paths: the lowerer can canonicalize `nan*` text when it receives that text, WAST result parsing preserves `nan:canonical` / `nan:arithmetic` assertion expectations, and the ordinary body-instruction `f32.const` / `f64.const` parser currently only forwards `Nat` / `Int` / `Float` tokens. Exact NaN text spelling therefore belongs to targeted tests rather than broad authoring assumptions.

## Local Starshine sources checked

- `src/wast/keywords.mbt`
  - Registers scalar numeric constants, tests, comparisons, arithmetic operations, conversions, reinterprets, sign-extension instructions, and saturating truncation spellings.
- `src/wast/parser.mbt`
  - Classifies scalar numeric opcodes into `Const`, `Unary`, `Binary`, `Test`, `Compare`, or `Convert` WAST AST nodes. Integer constants accept `Nat` / `Int` tokens; float constants accept `Nat` / `Int` / `Float` tokens. Non-constant numeric operators do not carry immediates.
- `src/wast/lower_to_lib.mbt`
  - Parses literal text into core `I32`, `I64`, `F32`, and `F64` values and maps no-argument numeric AST nodes to concrete `@lib.Instruction` constructors through `wt_numeric_noarg`. Its float parser recognizes `nan*` text when that text reaches lowering, but the body-instruction parser does not forward every special token spelling today.
- `src/wast/module_wast.mbt`
  - Prints `Const(op, text)` as the keyword plus text literal and prints no-argument numeric operators through the opcode keyword table.
- `src/wast/arbitrary.mbt`
  - Generates representative numeric text constants and a smaller conversion/opcode surface; it is not a full mirror of the valid generator's `[FZG]002` scalar numeric matrix.
- `src/lib/types.mbt`
  - Defines the scalar numeric `Instruction` variants, constructors, unary/binary helper op enums, and scalar numeric value wrappers used after WAST lowering and binary decode.
- `src/binary/decode.mbt` and `src/binary/encode.mbt`
  - Decode and encode scalar numeric constants, one-byte scalar numeric operations, sign-extension opcodes, and `0xFC` saturating truncation subcodes.
- `src/validate/typecheck.mbt`
  - Owns stack typing for scalar numeric constants and operators, including comparison result `i32`, conversion source/result pairs, sign-extension source/result preservation, and saturating truncation typing.
- `src/validate/validate.mbt`
  - Allows scalar numeric constants and scalar numeric no-argument operators in Starshine's extended constant-expression filter, then relies on ordinary typechecking to reject wrong arity, wrong operand types, or wrong result counts.
- `src/validate/gen_valid.mbt`
  - Owns `[FZG]002` coverage-forced scalar numeric evidence: expanded integer div/rem/shift/rotate, integer and float comparisons, float rounding/min/max/copysign, unsigned conversions, sign-extension, and saturating truncation forms.

## Durable conclusions

1. Scalar numeric WAST deserves a focused guide because it is the shared glue between parser syntax, literal parsing, byte opcodes, validation stack effects, pass rewrite safety, and generator coverage.
2. Only `i32.const`, `i64.const`, `f32.const`, and `f64.const` carry literal immediates. Arithmetic, comparison, conversion, reinterpret, sign-extension, and saturating truncation spellings are no-argument instructions whose operands come from the value stack or folded child expressions.
3. Starshine's integer literal lowering currently parses signed 64-bit text and then narrows `i32` via the local `I32` wrapper. Authors should avoid relying on huge unsigned textual wraparound unless a focused test proves the exact local path.
4. Starshine's float literal handling is path-sensitive: ordinary body instructions forward integer/float tokens, assertion-result parsing preserves `nan:canonical` / `nan:arithmetic` expectations, and the lowerer can canonicalize `nan*` text when it receives that text. Broad WAST roundtrips should not assume exact NaN payload spelling survives without a targeted test.
5. Ordinary truncations and integer div/rem may trap at runtime; saturating truncations are the nontrapping `0xFC` conversion family. They share similar typechecker source/result types but not runtime failure behavior.
6. Comparisons and integer tests always produce `i32`, not a separate boolean type. Any pass that folds or hoists comparison results must preserve that stack type.
7. `[FZG]002` is generator coverage, not text-parser completeness. `src/wast/arbitrary.mbt` currently mirrors representative numeric text syntax and should point to the authoring guide until it deliberately grows a full scalar numeric matrix.
