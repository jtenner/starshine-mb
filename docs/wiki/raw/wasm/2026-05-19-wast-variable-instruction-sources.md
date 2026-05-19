# WAST Variable Instruction Source Snapshot (2026-05-19)

## Purpose

This manifest anchors the living WAST variable-instruction authoring guide for `local.get`, `local.set`, `local.tee`, `global.get`, and `global.set`. It focuses on text syntax, index resolution, stack typing, binary opcode/immediate shape, constant-expression limits, and Starshine rewrite/signoff obligations.

## Primary external sources checked

- WebAssembly core spec, text instructions: <https://webassembly.github.io/spec/core/text/instructions.html>
  - Checked the current text instruction grammar for folded and plain instruction forms, identifier or numeric immediates, and the variable instruction names `local.get`, `local.set`, `local.tee`, `global.get`, and `global.set`.
- WebAssembly core spec, syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Checked the abstract variable-instruction family and the stack effects that distinguish local reads, local writes, local tee, global reads, and global writes.
- WebAssembly core spec, binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html>
  - Checked the one-byte opcode/immediate mapping: `local.get` `0x20`, `local.set` `0x21`, `local.tee` `0x22`, `global.get` `0x23`, and `global.set` `0x24`, each followed by the relevant unsigned index immediate.
- WebAssembly core spec, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Checked stack typing for locals and globals, including the rule that `global.set` requires a mutable global and an operand matching the global's declared value type.
- WebAssembly core spec, validation modules and constant expressions: <https://webassembly.github.io/spec/core/valid/modules.html>
  - Checked validation context/index-space rules and constant-expression placement. Starshine intentionally allows the current extended immutable-`global.get` constant-expression subset documented in the local validation page, while still rejecting mutable-global reads in constant-expression positions.

## Local Starshine sources checked

- `src/wast/keywords.mbt`
  - Registers the five variable instruction keywords.
- `src/wast/parser.mbt`
  - Parses numeric and `$` identifier immediates for local and global variable instructions; focused parser tests cover local get/set/tee and global get/set text forms.
- `src/wast/lower_to_lib.mbt`
  - Builds each defined function's local-id map from type-use parameter ids plus local declarations, resolves `$` local ids to numeric `LocalIdx` values, and resolves global identifiers through the module-level `global_ids` map.
- `src/wast/module_wast.mbt`
  - Prints variable instructions with numeric indices (`local.get N`, `local.set N`, `local.tee N`, `global.get N`, `global.set N`) rather than reconstructing original `$` identifiers.
- `src/lib/types.mbt`
  - Core `Instruction` variants and constructors include `LocalGet`, `LocalSet`, `LocalTee`, `GlobalGet`, and `GlobalSet`.
- `src/binary/decode.mbt` and `src/binary/encode.mbt`
  - Decode and encode the one-byte opcode mapping plus LEB index immediates for all five variable instructions.
- `src/validate/typecheck.mbt`
  - Owns instruction-stack typing: `local.get` and `global.get` push the indexed value type, `local.set` and mutable `global.set` consume it, and `local.tee` consumes then re-pushes the local value type.
- `src/validate/validate.mbt`
  - Owns constant-expression filtering. Starshine's extended constant-expression policy permits immutable imported or previously-defined `global.get` in selected initializer/offset positions, and rejects mutable `global.get` in constant expressions.
- `src/validate/gen_valid.mbt`
  - Generates variable-instruction bodies and records `[FZG]003` `local.tee` and `[FZG]008` immutable-`global.get` constant-expression evidence.
- `src/validate/invalid_fuzzer.mbt` and `src/validate/gen_invalid.mbt`
  - Preserve invalid strategies for mutable `global.get` in const global/table initializer contexts.

## Durable conclusions

1. Variable instructions need a focused WAST page because they sit at the boundary between text identifiers, core numeric index spaces, binary opcodes, validation stack effects, local/global mutation passes, and generator coverage.
2. Text `$` local identifiers are compile-time aliases only. Starshine lowers them to numeric `LocalIdx` values and currently does not reconstruct local-name metadata from them; name-section metadata remains a separate binary/custom-section concern.
3. `local.tee` is not a shorthand for pure `local.get`: it evaluates and stores its operand like `local.set`, then leaves the same value on the stack. Passes that rewrite tees must preserve operand evaluation and the remaining stack value.
4. `global.set` is validation-sensitive in two independent ways: the target global must exist and be mutable, and the consumed operand must match the declared global value type.
5. Starshine's extended immutable-`global.get` constant-expression support is a local policy surface that must stay visible when authoring globals, table initializers, element/data offsets, invalid-fuzzer seeds, and mutating passes.
6. Binary opcode evidence is intentionally simple here (`0x20` through `0x24`), but correctness is not byte-only: identifier resolution, imported-prefix index spaces, mutability, stack typing, name metadata, and constant-expression filtering all live above the byte codec.
