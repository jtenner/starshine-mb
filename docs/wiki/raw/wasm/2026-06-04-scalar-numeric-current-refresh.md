---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-04
sources:
  - https://webassembly.github.io/spec/core/syntax/instructions.html
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/text/values.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - https://webassembly.github.io/spec/core/exec/numerics.html
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/validate.mbt
related:
  - ../../wast/numeric-instruction-authoring.md
  - ../../validate/constant-expressions.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../wast/simd-authoring.md
---

# Scalar Numeric Current Source Refresh (2026-06-04)

## Purpose

This refresh rechecks the scalar numeric WAST guide against the current official WebAssembly Core 3.0 pages dated 2026-06-03 and the current Starshine parser/lowerer/binary/validator code. It supersedes no earlier conclusion; it narrows the durable claim that the May 2026 scalar numeric page is still source-current while keeping the known Starshine-local literal and constant-expression differences visible.

## Primary external sources checked

- WebAssembly Core 3.0 syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Rechecked that scalar numeric instructions remain grouped as constants, integer/float unary operations, integer/float binary operations, integer tests, integer/float relational operations, conversions, reinterprets, sign-extension-style `extend`, and `trunc_sat` float-to-int conversions. No new scalar instruction family needs to move from the SIMD, reference, memory, or GC pages into the scalar numeric guide.
- WebAssembly Core 3.0 text instructions: <https://webassembly.github.io/spec/core/text/instructions.html>
  - Rechecked the text layer split: scalar numeric operator names are ordinary instruction names, and only constant forms carry literal operands. Folded syntax supplies the stack operands as child expressions; plain syntax supplies them earlier on the stack.
- WebAssembly Core 3.0 text values: <https://webassembly.github.io/spec/core/text/values.html>
  - Rechecked that official integer literals permit decimal or hexadecimal notation with optional underscores, with range constraints depending on size/signedness. Rechecked that official floating literals include decimal/hex forms, infinities, canonical NaNs, and payload NaNs. Starshine still needs its local path split documented because lexer recognition, body-constant lowering, index parsing, SIMD lane parsing, and assertion-result rendering are not one identical path.
- WebAssembly Core 3.0 binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html>
  - Rechecked the byte families used by the guide: scalar constants are `0x41`..`0x44`, most scalar numeric operators live in the one-byte numeric opcode range, sign-extension opcodes are `0xC0`..`0xC4`, and saturating truncations are `0xFC` subcodes `0`..`7` before the prefix space continues into bulk-memory/table forms.
- WebAssembly Core 3.0 instruction validation: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Rechecked the stack-type rules: scalar constants push their number type, unary operations preserve their number type, binary operations consume two matching numbers and push one matching number, tests/relations produce `i32`, and the official constant-expression predicate admits numeric constants plus only integer `i32`/`i64` `add`/`sub`/`mul` among scalar numeric no-arg operators.
- WebAssembly Core 3.0 numeric execution: <https://webassembly.github.io/spec/core/exec/numerics.html>
  - Rechecked the rewrite-safety distinction between ordinary truncation and saturating truncation: ordinary `trunc` is undefined for NaN, infinities, and out-of-range inputs, while `trunc_sat` returns `0` or saturates to the target integer range. That remains the core reason optimizer docs must not treat the two families as type-equivalent replacements.

## Local Starshine sources checked

- `src/wast/keywords.mbt` still registers scalar numeric constants, tests, relations, arithmetic/bitwise/float ops, conversions, reinterprets, sign-extension, and `trunc_sat` spellings.
- `src/wast/parser.mbt` still classifies scalar numeric opcodes into `Const`, `Unary`, `Binary`, `Test`, `Compare`, or `Convert`, with focused parser coverage for conversions, reinterprets, `trunc_sat`, and sign extension.
- `src/wast/lower_to_lib.mbt` still maps no-argument scalar numeric WAST opcodes to concrete `@lib.Instruction` constructors through `wt_numeric_noarg(...)`; constant literals still take the separate parse-literal path.
- `src/binary/decode.mbt` and `src/binary/encode.mbt` still map `0xFC` subcodes `0`..`7` to `I32TruncSatF32S` through `I64TruncSatF64U`, followed by memory/table prefix forms from subcode `8` onward.
- `src/validate/typecheck.mbt` still gives scalar tests/comparisons `i32` results, preserves the input numeric type for unary/binary operators, assigns fixed source/result pairs to conversions/reinterprets, and gives `trunc_sat` the same stack types as ordinary truncation while leaving runtime behavior distinct.
- `src/validate/validate.mbt` still keeps Starshine's constant-expression allow-list broader than the official scalar numeric subset: many scalar numeric no-argument operators are locally admitted in initializers, then ordinary typechecking enforces arity and result type.

## Durable conclusions

1. The existing scalar numeric WAST guide remains current for the official WebAssembly 3.0 scalar instruction families as of 2026-06-04.
2. The most important cross-layer teaching split is still **syntax/type equivalence does not imply runtime equivalence**: ordinary truncation and saturating truncation share source/result types but not trap/NaN/out-of-range behavior.
3. Official text numeric literal support is broader than the safe Starshine authoring claim for every local path. The living page should continue to recommend focused tests for large unsigned wraparound, separator-heavy scalars, hex floats, and NaN payload spellings.
4. Official constant expressions allow scalar numeric constants plus only integer `i32`/`i64` `add`/`sub`/`mul`; Starshine deliberately admits a much broader local scalar numeric no-arg set in `validate_const_instr(...)`. This is a local validator policy, not a portable WebAssembly claim.
5. No new living page is needed. The right maintenance action is to refresh `wast/numeric-instruction-authoring.md`, keep `validate/constant-expressions.md` as the focused allow-list page, and route vector/relaxed numeric details through `wast/simd-authoring.md`.
