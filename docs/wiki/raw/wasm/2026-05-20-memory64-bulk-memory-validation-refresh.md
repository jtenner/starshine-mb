---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-20
sources:
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - https://webassembly.github.io/spec/core/syntax/instructions.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - https://webassembly.github.io/memory64/core/
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
related:
  - ../../wast/memory-instruction-authoring.md
  - ../../wast/memory-argument-authoring.md
  - ../../validate/module-validation-phases.md
  - ../../binaryen/passes/memory64-lowering/starshine-strategy.md
  - ../../binaryen/passes/memory64-lowering/starshine-port-readiness-and-validation.md
---

# Memory64 Bulk-Memory Validation Refresh - 2026-05-20

This refresh narrows one easy-to-miss Starshine/wiki wording issue: the current WebAssembly validation model does **not** give every bulk-memory stack slot the same width. Each slot is tied either to a selected memory address type or to a fixed `i32` data-segment offset/value role. Starshine mirrors most of that split, but `typecheck_memory_fill(...)` still types the length operand as `i32` for memory64.

## Primary external sources checked

- WebAssembly 3.0 instruction validation, current as checked on 2026-05-20: <https://webassembly.github.io/spec/core/valid/instructions.html>. This is the authority for the selected-memory address type `at`: `memory.size` and `memory.grow` use `at`; `memory.init` consumes destination `at`, source `i32`, and length `i32`; `memory.copy` consumes destination `at_1`, source `at_2`, and length as the minimum address type for the two memories; `memory.fill` consumes destination `at`, value `i32`, and length `at`.
- WebAssembly 3.0 instruction syntax, current as checked on 2026-05-20: <https://webassembly.github.io/spec/core/syntax/instructions.html>. This keeps scalar `memarg` immediates separate from bulk-memory `memidx` / `dataidx` instruction immediates.
- WebAssembly 3.0 binary instructions, current as checked on 2026-05-20: <https://webassembly.github.io/spec/core/binary/instructions.html>. This confirms that `0xFC` bulk-memory subcodes carry memory/data indices as immediates and do not encode the operand-stack width directly.
- WebAssembly memory64 proposal index, current as checked on 2026-05-20: <https://webassembly.github.io/memory64/core/>. This remains the proposal-level context for why selected memories may use 64-bit address operands while the text instruction names remain familiar.

## Starshine repository evidence checked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) maps `Limits::I32Limits` to `i32` and `Limits::I64Limits` to `i64` through `Limits::addr_valtype(...)`, and defines `min_addr_valtype(...)` for mixed-width copy length.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) routes `memory.size`, `memory.grow`, `memory.init` destination, and `memory.copy` destination/source/length through selected memory limits. It still hard-codes `typecheck_memory_fill(...)` to pop `len:i32`, `val:i32`, and `dst:at`.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) preserve explicit `MemIdx` immediates for `memory.init`, `memory.copy`, and `memory.fill`; the type difference is a validation/typechecking concern rather than a byte-encoding concern.

## Durable conclusions

1. The correct official operand matrix is positional, not family-wide:
   - `memory.init`: destination is selected-memory `at`; source offset and length stay `i32` because they index the passive data segment.
   - `memory.copy`: destination and source use their own selected memory address types; length uses the minimum address type of the two memories.
   - `memory.fill`: destination and length both use the selected memory address type; the byte value is `i32`.
2. Current Starshine has a narrow validator divergence only for `memory.fill` length on memory64. The existing `i32` length rule should be treated as a local follow-up, not as intended WebAssembly or future `memory64-lowering` port semantics.
3. WAST text coverage remains narrower than core/binary/validator coverage: current text lowering defaults bulk-memory memory operands to memory `0`, and current WAST declarations do not directly author memory64 memories. Direct core or binary fixtures are still the right way to prove memory64 bulk-memory validation today.
4. Future `memory64-lowering` docs and port plans should not say “Starshine already threads memory address width through `memory.fill`” without the caveat. A faithful lowering still needs to handle `memory.fill` destination and length independently, even though current local validation cannot yet prove the memory64 length operand with an accepted positive fixture.
