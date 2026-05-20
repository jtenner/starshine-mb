# WAST Parametric Select Source Refresh (2026-05-20)

## Purpose

This manifest anchors the living WAST parametric-instruction authoring guide. It covers `drop`, untyped `select`, typed `select (result ...)`, the binary `0x1A` / `0x1B` / `0x1C` split, and the current Starshine caveats around untyped reference select and vector-valued typed select.

## Primary external sources checked

- WebAssembly core spec, syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Checked the parametric instruction family, `drop`, and `select` abstract instruction shapes.
- WebAssembly core spec, text instructions: <https://webassembly.github.io/spec/core/text/instructions.html>
  - Checked WAT folded/plain instruction syntax and the typed-select `select (result ...)` text form.
- WebAssembly core spec, binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html>
  - Checked parametric opcodes: `drop` under `0x1A`, untyped `select` under `0x1B`, and typed `select` under `0x1C` with a value-type vector immediate.
- WebAssembly core spec, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Checked stack typing for `drop`, untyped `select`, typed `select`, the `i32` condition requirement, and the current official text that still frames typed select as an optional single value type while noting future multi-value select.
- WebAssembly core spec, execution instructions: <https://webassembly.github.io/spec/core/exec/instructions.html>
  - Checked runtime behavior: `drop` discards one value; `select` consumes two candidate values and an `i32` condition, choosing the first on a nonzero condition and the second on zero.

## Local Starshine sources checked

- `src/wast/keywords.mbt`
  - Registers `drop` and `select` keywords.
- `src/wast/parser.mbt`
  - Parses `Select` by optionally consuming a folded `(result ...)` annotation immediately after the opcode.
  - Existing parser tests cover untyped `select` and single-result typed `select`.
- `src/wast/lower_to_lib.mbt`
  - Converts typed-select WAST `ValueType`s to core `ValType`s through `wt_select_types(...)`.
- `src/wast/module_wast.mbt`
  - Prints untyped select as `select` and typed select as `select (result ...)`, iterating every annotated value type.
- `src/lib/types.mbt`
  - Represents `Drop` and `Select(Array[ValType]?)`; `Instruction::select(types?)` preserves an optional value-type array.
- `src/binary/decode.mbt`
  - Decodes `0x1A` to `Drop`, `0x1B` to `Select(None)`, and `0x1C` to `Select(Some(vts))` after decoding a value-type vector.
- `src/binary/encode.mbt`
  - Encodes `Drop`, `Select(None)`, and `Select(Some(vts))` with the same opcode split and vector-valued typed-select immediate.
- `src/validate/typecheck.mbt`
  - `typecheck_drop(...)` pops one value.
  - `typecheck_select_untyped(...)` pops an `i32` condition, pops two candidate values, and requires mutual `Match::matches(...)` in reachable code.
  - `typecheck_select_typed(...)` validates every annotation type, pops two copies of the full annotation vector, and pushes that vector.
  - Existing typecheck tests cover `drop`, untyped `select`, single-result typed `select`, and untyped mismatched-value rejection.
- `src/validate/match.mbt`
  - Owns the matching relation used by untyped select and typed-select operand checking.
- `src/validate/gen_valid.mbt`
  - Tracks typed select through the `[FZG]003` core-control surface and `TypedSelect` coverage counter.
- `src/wast/arbitrary.mbt`
  - Emits representative WAST text shapes independently from `gen_valid`; WAST arbitrary remains parser/printer coverage rather than a typed validity oracle.

## Durable conclusions

1. Starshine needed a dedicated parametric-instruction page because the older control-flow page mentioned `select` only briefly and did not separate select's stack/type caveats from branch-label mechanics.
2. The current official WebAssembly sources still create a portability caveat around typed select: binary/text carry a value-type vector shape, while validation text describes a single optional value type and notes that multi-value select may be allowed in the future.
3. Starshine currently models typed select with `Array[ValType]` all the way through WAST parsing, core instruction construction, binary encode/decode, printing, and typechecking. That makes multi-value typed select a real local regression surface, but not a safe portable fixture unless the conformance target is clarified.
4. Starshine's untyped select validator currently checks mutual matching between operands, but does not separately enforce the official untyped-select restriction to numeric/vector types. Treat accepted untyped reference select as current local behavior, not upstream conformance evidence, until a focused validator decision is made.
5. Future pass rewrites should preserve typed-select annotations unless they deliberately prove that erasing the annotation preserves validation and intended portability.
