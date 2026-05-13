# WebAssembly Instruction And Expression Encoding Sources (2026-05-13)

## Scope

Primary-source snapshot for the Starshine wiki page [`../../binary/instruction-and-expression-encoding.md`](../../binary/instruction-and-expression-encoding.md). This note records the official WebAssembly sources behind instruction/expression binary encoding, immediates, code bodies, and validation stack behavior.

## Sources Checked

1. WebAssembly Core Specification 3.0, binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html> (searched/opened 2026-05-13; page release shown by the site as 2026-05-12 in the opened view). Canonical source for instruction opcode families, immediates, expression termination, structured body boundaries, memory arguments, prefixed opcode spaces, SIMD lane immediates, GC/reference operations, and atomic/bulk-memory encodings.
2. WebAssembly Core Specification 3.0, binary modules: <https://webassembly.github.io/spec/core/binary/modules.html> (searched/opened 2026-05-13; page release shown by the site as 2026-05-12 in the opened view). Canonical source for the code-section body shape: a section vector of function bodies, each body carrying locals followed by an expression.
3. WebAssembly Core Specification 3.0, binary values and conventions: <https://webassembly.github.io/spec/core/binary/values.html> and <https://webassembly.github.io/spec/core/binary/conventions.html> (searched/opened 2026-05-13; page release shown by the site as 2026-05-12 in the opened view). Canonical sources for integer/floating-point immediate encoding, vectors, names, indices, signed 33-bit blocktype immediates, and LEB128 constraints.
4. WebAssembly Core Specification 3.0, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html> (searched/opened 2026-05-13; page release shown by the site as 2026-05-12 in the opened view). Canonical source for validation stack effects, blocktype expansion, branch labels, memory/table instruction preconditions, expression end-stack checking, and stack-polymorphic unreachable code.

## Durable Takeaways

- Binary expressions are instruction sequences terminated by `0x0B` (`end`). Nested structured instructions also contain terminated subexpressions, so a decoder must distinguish an inner `end` from the containing expression's `end`.
- Structured control instructions carry a block type. Void block types encode as `0x40`; single-result block types use value-type encoding; multi-value/function-typed blocks use a signed type-index immediate.
- Most scalar numeric and variable instructions are one-byte opcodes plus typed immediates. Larger families use prefixed opcode spaces such as `0xFC` for saturating conversion / bulk-memory / table operations, `0xFD` for SIMD, and `0xFE` for atomics. Starshine also implements GC/custom-descriptor-family instructions under `0xFB` in its current local surface.
- Memory arguments carry alignment and offset. Validation must prove the selected memory exists, the alignment is legal for the access width, and the offset fits the memory address width.
- Code-section bodies are defined-function bodies only. The function section provides the parallel type-index declarations; each code body contains locals and one expression.
- Binary decoding is syntactic. Semantic checks such as stack effects, branch-label arity, blocktype resolution, `memory.init` data-count requirements, and `ref.func` declaration legality are validator responsibilities.

## Caveats

- This snapshot documents the official sources needed by Starshine's current instruction/binary wiki coverage. It is not a full opcode table and should not be treated as a guarantee that every current or future proposal instruction is locally implemented.
- Starshine's local `StringRefsSec` / `string.const` pool and custom-descriptor instruction variants remain proposal-facing or local-extension surfaces; use the string and custom-descriptor wiki pages for their standardization caveats.
- Exact opcode rows should stay in the official spec and in `src/binary/{decode,encode}.mbt`; the living wiki page summarizes invariants, local shapes, and repair obligations.
