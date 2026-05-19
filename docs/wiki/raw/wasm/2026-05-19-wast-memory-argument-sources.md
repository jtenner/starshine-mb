---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-19
sources:
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - https://webassembly.github.io/spec/core/_download/WebAssembly.pdf
  - https://webassembly.github.io/multi-memory/core/text/modules.html
  - https://webassembly.github.io/memory64/core/
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast.mbt
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/lib/eq.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/tests.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/validate.mbt
  - ../../../../src/validate/gen_valid.mbt
related:
  - ../../wast/memory-argument-authoring.md
  - ../../wast/simd-authoring.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../binary/data-element-and-datacount-sections.md
  - ../../validate/module-validation-phases.md
  - ../../fuzzing/generator-coverage-ledger.md
---

# WAST Memory Argument Authoring Sources - 2026-05-19

This manifest captures the primary-source and in-repository evidence used to add the focused WAST memory-argument guide.

## Official WebAssembly sources checked

- WebAssembly 3.0 core text instructions: memory operations have text forms with memory immediates and default-to-zero abbreviations for single-memory-style authoring. URL: <https://webassembly.github.io/spec/core/text/instructions.html>.
- WebAssembly 3.0 core binary instructions: memory operations encode memory arguments as immediates, and bulk-memory instructions encode memory and data indices as instruction immediates. URL: <https://webassembly.github.io/spec/core/binary/instructions.html>.
- WebAssembly 3.0 instruction validation and PDF snapshot: a memory argument is valid only when the selected memory exists, its address type matches the stack operand, the alignment does not exceed the access width, and the static offset fits the address type; `memory.size` / `memory.grow` result and operand widths follow the selected memory's address type; `memory.copy` uses destination and source memory address types plus a minimum address type for length. URLs: <https://webassembly.github.io/spec/core/valid/instructions.html> and <https://webassembly.github.io/spec/core/_download/WebAssembly.pdf>.
- WebAssembly multi-memory proposal text modules: memory indices can be numeric or symbolic in the text context, which is the proposal-level source for nonzero memory operands. URL: <https://webassembly.github.io/multi-memory/core/text/modules.html>.
- WebAssembly memory64 proposal index page: memory64 extends the address-width story so memory operations are not always `i32`-addressed. URL: <https://webassembly.github.io/memory64/core/>.

## Starshine sources checked

- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) has a WAST-local `MemArg` with `align` and `offset` only. `WastParser::parse_mem_arg(...)` accepts `offset=N` and `align=N` in either order, and scalar/SIMD load/store parsers call that helper with instruction-specific default byte alignments.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) converts text alignment bytes to exponent-form core `@lib.MemArg` via `wt_align_pow_from_text_align(...)` / `wt_mem_arg(...)`, rejects non-power-of-two or zero text alignments, and currently lowers text load/store memory arguments with `mem = None` rather than an explicit `MemIdx`. The same file currently defaults WAST `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init` to memory `0`.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints WAST memory arguments as `offset=` when nonzero plus an `align=` field, using the WAST-local byte-alignment representation.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines the long-lived core `MemArg(U32, MemIdx?, U64)` carrier, scalar memory operations, atomic memory operations, SIMD memory operations, and bulk-memory instructions carrying `MemIdx` / `DataIdx` immediates.
- [`src/lib/eq.mbt`](../../../../src/lib/eq.mbt) intentionally treats `MemArg(..., None, ...)` and `MemArg(..., Some(MemIdx(0)), ...)` as equal, but keeps nonzero explicit memory indices distinct.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) preserve explicit memory indices in binary `MemArg` via the local `align + 64` encoding convention, reject invalid immediate ranges, and preserve explicit memory indices on `memory.init`, `memory.copy`, and `memory.fill`.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) is the semantic authority: `memarg_check(...)` resolves the selected memory, checks alignment exponent and offset range, chooses `i32` versus `i64` address operands from memory limits, stack-types `memory.size` / `memory.grow`, and types mixed-width `memory.copy` positions separately.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) and [`docs/wiki/fuzzing/generator-coverage-ledger.md`](../../fuzzing/generator-coverage-ledger.md) already track valid-generator coverage for nonzero memargs and memory limit/proposal variants; WAST text support remains narrower than core/binary/generator memory-index support.

## Durable conclusions

1. WAST `align=` is a byte count, while Starshine's core `MemArg` stores an alignment exponent. Lowering is the only place that should convert the representation.
2. WAST `offset=` is a static unsigned immediate, not an address operand. The dynamic address is still on the operand stack and has the selected memory's address type.
3. Current Starshine WAST parsing/lowering does not preserve explicit nonzero memory indices for ordinary memory instructions. Core IR, binary decode/encode, validation, and generator surfaces can represent them; WAST text fixtures cannot yet exercise the whole multi-memory instruction surface.
4. `None` and `Some(MemIdx(0))` are intentionally equivalent for core equality, but nonzero explicit memory indices remain observable and must be preserved by binary/code-rewrite paths.
5. Memory64 changes address/result widths but does not change the meaning of `offset=`: i32 memories reject static offsets outside `2^32`, while i64 memories allow any `UInt64` offset locally.
6. Bulk-memory instruction indices and active data-segment memory indices are related but not the same as scalar/SIMD load/store `MemArg` fields. Segment offset expressions are constant expressions, whereas `MemArg.offset` is an immediate added to a dynamic address.
