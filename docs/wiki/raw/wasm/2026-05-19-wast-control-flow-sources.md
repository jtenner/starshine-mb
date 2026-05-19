# WAST Control-Flow Source Snapshot (2026-05-19)

## Purpose

This manifest anchors the living WAST control-flow authoring guide. It covers ordinary structured control (`block`, `loop`, `if`), branch instructions (`br`, `br_if`, `br_table`), `return`, `unreachable`, and `select`. Tail calls and exceptions have separate focused manifests and pages.

## Primary external sources checked

- WebAssembly core spec, text instructions: <https://webassembly.github.io/spec/core/text/instructions.html>
  - Checked for current text grammar around folded/plain instructions, labels, block types, `block`, `loop`, `if`, `br`, `br_if`, `br_table`, `return`, `unreachable`, and typed `select`.
- WebAssembly core spec, syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Checked for the abstract instruction families and the split between structured control, branch instructions, parametric instructions, and reference/control proposal forms.
- WebAssembly core spec, binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html>
  - Checked for opcode families and structured-control encoding: `unreachable` `0x00`, `block` `0x02`, `loop` `0x03`, `if` `0x04`, `else` `0x05`, `br` `0x0C`, `br_if` `0x0D`, `br_table` `0x0E`, `return` `0x0F`, and `select` `0x1B` / typed `select` under `0x1C`.
- WebAssembly core spec, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Checked for stack typing: block/result labels, loop parameter labels, `i32` conditions/selectors, branch-target type matching, `select` operand/result typing, and unreachable-code stack polymorphism.
- WebAssembly core spec, validation algorithm appendix: <https://webassembly.github.io/spec/core/appendix/algorithm.html>
  - Checked for the control-stack / value-stack model and why unreachable code is stack-polymorphic while still enforcing concrete values pushed after an unreachable point.

## Local Starshine sources checked

- `src/wast/keywords.mbt`
  - Registers `block`, `loop`, `if`, `unreachable`, `br`, `br_if`, `br_table`, `return`, and `select`-family opcode keywords.
  - As of this snapshot, it does **not** register WAST text keywords for `br_on_null`, `br_on_non_null`, `br_on_cast`, or `br_on_cast_fail` even though those core instructions exist elsewhere locally.
- `src/wast/parser.mbt`
  - `parse_block_type(...)` accepts optional labels, type uses, and single-result shorthand.
  - Folded `if` parsing collects condition operand instructions before `then`/`else` bodies.
  - `parse_opcode_instruction(...)` lowers `br_table` by collecting one or more label indices and using the last index as the default target.
- `src/wast/lower_to_lib.mbt`
  - Resolves text labels to numeric `LabelIdx` depths for `br`, `br_if`, and `br_table`.
  - Pushes labels while lowering nested `block`, `loop`, and `if` bodies.
  - Converts typed/untyped `select` annotations to core value-type lists.
- `src/wast/module_wast.mbt`
  - Prints structured `block` / `loop` / `if` with explicit `end`, prints `br_table` as all table targets followed by the fallback, and prints typed `select` as `select (result ...)`.
- `src/lib/types.mbt`
  - Core `Instruction` variants include `Unreachable`, `Block`, `Loop`, `If`, `Br`, `BrIf`, `BrTable`, `Return`, `Select`, and also the reference-branch variants `BrOnNull`, `BrOnNonNull`, `BrOnCast`, and `BrOnCastFail`.
- `src/binary/decode.mbt` and `src/binary/encode.mbt`
  - Binary codec supports ordinary structured control and reference-branch opcode families, including `br_on_*` under prefixed encodings.
- `src/validate/typecheck.mbt`
  - Owns stack typing for `block`, `loop`, `if`, `br`, `br_if`, `br_table`, `return`, `select`, and `br_on_*` core instructions.
  - Important local detail: `typecheck_br_if(...)` checks branch payload availability but leaves payload values on the not-taken path after popping only the condition.
  - Important local detail: `typecheck_loop(...)` installs loop labels using block parameters, while `typecheck_block(...)` and `typecheck_if(...)` install labels using results.
- `src/wast/arbitrary.mbt`
  - The text generator has lightweight `Block`, `Loop`, `If`, `Br`, `BrIf`, `BrTable`, `Return`, and typed `Select` mirrors, but it is not a typed validity oracle.
- `src/validate/gen_valid.mbt`
  - The valid generator's `[FZG]003` core-control surface and `[FZG]009` reference-branch surface provide typed binary-AST evidence beyond the WAST text generator.

## Durable conclusions

1. Ordinary WAST control flow needs a focused authoring page because the stack/label rules are reused by validation, CFG, pass rewrites, FZG coverage, and WAST arbitrary widening.
2. `br_if` is the easiest branch to misread: in Starshine it validates the branch payload but preserves it on the fallthrough path, matching the stack-machine intuition that only the `i32` condition is always consumed.
3. `br_table` is terminal and all possible targets must have equivalent label argument types. In WAST text, the final listed label is the default target.
4. Loop labels are parameter-shaped, while block/if labels are result-shaped. This distinction is essential for fixtures that carry branch values.
5. Starshine has a current local text-surface gap: WAST cannot directly author `br_on_null`, `br_on_non_null`, `br_on_cast`, or `br_on_cast_fail`, even though core, binary, validation, and `gen_valid` surfaces know about them. Use core/binary fixtures or widen the WAST parser first when testing those instructions.
6. Tail-call and exception control transfers are intentionally routed to their own pages so this page can stay focused on ordinary structured control and branch values.
