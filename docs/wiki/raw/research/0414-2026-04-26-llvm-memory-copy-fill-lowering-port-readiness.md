---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-llvm-memory-copy-fill-lowering-port-readiness-primary-sources.md
  - ../binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../binaryen/passes/llvm-memory-copy-fill-lowering/index.md
  - ../../binaryen/passes/llvm-memory-copy-fill-lowering/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/ir/effects.mbt
  - ../../../../src/validate/validate.mbt
---

# `llvm-memory-copy-fill-lowering` port-readiness follow-up

## Question

Is the existing `llvm-memory-copy-fill-lowering` dossier precise enough for a future Starshine implementation, or does it still hide Binaryen-specific details that could cause an incorrect port?

## Answer

It needed one more pass-readiness bridge. The original dossier correctly taught that the pass replaces `memory.copy` and `memory.fill` with helper calls, but it left the helper ABI and boundaries schematic. Rechecking official Binaryen sources showed implementation-critical details:

1. Binaryen generates local helper functions named from `__memory_copy` and `__memory_fill`; they are not helper imports.
2. Both helpers use `(i32, i32, i32) -> none` signatures.
3. The pass is memory32, single-memory, non-passive-segment, non-table-bulk only. It fatals on memory64, multi-memory, passive data/element/table surfaces, `table.copy`, and `table.fill`.
4. The pass disables the bulk-memory feature after lowering.
5. The generated copy helper includes bounds checks and overlap-sensitive forward/backward byte loops; the fill helper bounds-checks then writes bytes in a loop.
6. Binaryen explicitly says LLVM undefined behavior, notably pointer overflow, is not modeled by this pass.

## Durable Starshine implications

- A faithful local port should be a module-aware pass that can add and populate helper functions, not just a HOT opcode-to-call peephole.
- The safest first mutating slice is memory32 + single-memory only; memory64 and multi-memory should be rejected or left untouched until a separate compatibility policy exists.
- The oracle fixtures should include `memory.copy`, `memory.fill`, no-op unsupported-table/passive cases as policy tests, and a feature-section/bulk-memory cleanup check if Starshine models that metadata.
- Existing Starshine effect summaries already classify `MemoryCopy` and `MemoryFill` conservatively, but replacing them with calls means validation and any downstream effect logic must see the generated helper functions consistently.

## Wiki changes made

- Added a raw current-source bridge for the port-readiness details.
- Added `starshine-port-readiness-and-validation.md` to the living dossier.
- Refreshed overview, Binaryen strategy, implementation/test-map, helper-boundary, WAT-shape, Starshine strategy, pass catalog, tracker, global index, and log entries so future readers land on the exact helper/function/fatal-boundary contract.

## Uncertainties

- Starshine still has no registry category for this spelling. The first local decision is whether to keep it unknown until implemented or reserve it as boundary-only.
- Helper body parity should be rechecked against Binaryen immediately before coding; this research note is a 2026-04-26 source snapshot, not a permanent ABI standard.
