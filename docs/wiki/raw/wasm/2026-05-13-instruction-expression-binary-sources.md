# Starshine Instruction And Expression Binary Source Map (2026-05-13)

## Scope

Repository-source map for the Starshine wiki page [`../../binary/instruction-and-expression-encoding.md`](../../binary/instruction-and-expression-encoding.md). The companion official-source snapshot is [`2026-05-13-instruction-expression-encoding-sources.md`](2026-05-13-instruction-expression-encoding-sources.md). This note exists so future wiki health passes can refresh local code links without re-reading every large codec file from scratch.

## Local Sources Checked

1. [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) - Owns the core shapes: `Expr`, `Func`, `CodeSec`, `BlockType`, `MemArg`, `Catch`, and the large `Instruction` enum.
2. [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) - Owns strict LEB/number decoding errors, blocktype and memarg decoding, expression termination, structured-instruction frame decoding, nesting-depth guard, prefixed opcode decoding, and code-section decode.
3. [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) - Owns strict LEB/number encoding, blocktype and memarg encoding, expression terminator emission, instruction opcode/immediate emission, typed-control prefix rewriting, and code-section encode.
4. [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) - Owns expression and instruction stack typing, stack-polymorphic unreachable behavior, block/loop/if/try-table checks, memory/table/data/element instruction checks, branch-label rules, and call/tail-call checks.
5. [`../../../../src/validate/env.mbt`](../../../../src/validate/env.mbt) and [`../../../../src/validate/match.mbt`](../../../../src/validate/match.mbt) - Own blocktype expansion, type-index lookup, resource lookup, and subtype/match predicates used by instruction validation.
6. [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) and [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) - Own the text instruction AST, text memory-argument parsing/lowering, blocktype lowering, and text-to-core instruction mapping.
7. [`../../../../src/binary/tests.mbt`](../../../../src/binary/tests.mbt) - Owns arbitrary roundtrip coverage for `Instruction`, `BlockType`, `MemArg`, and `CodeSec`, plus focused tests for deep nesting, unencodable recursive blocktypes, invalid memargs, SIMD lane order, and empty code-section edge cases.

## Durable Local Takeaways

- Starshine keeps binary syntax and semantic validation split: `decode.mbt` / `encode.mbt` manipulate bytes and immediates; `typecheck.mbt` proves stack and index legality after the module environment is available.
- `MemArg(U32, MemIdx?, U64)` is richer than the core MVP memory-argument pair because Starshine can represent explicit multi-memory indices. Encoding uses the alignment bucket plus `64` to signal a present memory index.
- `BlockType` intentionally has only void, value, and absolute type-index variants in the public core type. The encoder rejects recursive-index blocktypes because long-lived binary output needs absolute type indices.
- The decoder uses an explicit structured-frame stack plus a maximum nesting-depth guard. This is both a correctness detail for nested `end` / `else` handling and a fuzz-hardening boundary.
- Binary roundtrip fuzz is broad but not a semantic validator. A pass that rewrites instructions must still run module validation and, when optimizing, pass-oracle comparison where relevant.

## Refresh Guidance

When changing the instruction enum, opcode tables, memory-argument representation, code-body encoding, or typechecker stack rules, refresh this source map, the companion wiki page, and any section-specific pages that link to instruction carriers.
