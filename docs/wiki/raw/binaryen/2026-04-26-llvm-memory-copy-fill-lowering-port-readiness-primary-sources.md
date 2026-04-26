---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LLVMMemoryCopyFillLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/LLVMMemoryCopyFillLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - ../../../binaryen/passes/llvm-memory-copy-fill-lowering/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/ir/effects.mbt
  - ../../../../src/validate/validate.mbt
---

# Binaryen `llvm-memory-copy-fill-lowering` port-readiness primary-source bridge

## Scope

This source bridge rechecks official Binaryen `version_129` and current `main` sources for details that matter to a future Starshine port of `llvm-memory-copy-fill-lowering`.

The earlier dossier correctly identified the pass as bulk-memory compatibility lowering, but it left several implementation-critical details too vague for an implementer: the helper names are local functions rather than imports, the pass rejects memory64/multi-memory/passive-segment/table-bulk shapes, and it disables bulk-memory feature bits after lowering.

## Official Binaryen facts confirmed on 2026-04-26

- `LLVMMemoryCopyFillLowering.cpp` still says the purpose is replacing `memory.copy` and `memory.fill` with calls implementing the same semantics for LLVM-style output; LLVM undefined behavior, especially pointer overflow, is intentionally not handled.
- `visitMemoryCopy` replaces a copy with a call named `__memory_copy` carrying destination, source, and size operands. It asserts the destination and source memory are the same, so this is not a multi-memory lowering.
- `visitMemoryFill` replaces a fill with a call named `__memory_fill` carrying destination, value, and size operands.
- `run` returns early when bulk memory is not enabled, fatals when memory64 or multi-memory is enabled, fatals on passive data or passive element/table-segment surfaces, clears the bulk-memory feature, creates temporary empty helper stubs, runs the postwalker replacement, removes unused helpers, and then clears the bulk-memory optional feature bit.
- The helper functions are module-local functions made with names based on `__memory_copy` and `__memory_fill`, not imports. Both have `(i32, i32, i32) -> none` signatures.
- The generated `__memory_copy` helper computes the memory size in bytes, traps on out-of-bounds source or destination ranges, chooses forward or backward byte-copy order based on overlap, then loops using byte load/store.
- The generated `__memory_fill` helper computes the memory size in bytes, traps on out-of-bounds destination range, then loops backward writing bytes.
- `visitTableCopy` and `visitTableFill` fatal because the pass is not designed for bulk table operations.
- `pass.cpp` registers the public name `llvm-memory-copy-fill-lowering` with help text that says it lowers `memory.copy` and `memory.fill` to wasm MVP and disables the bulk-memory feature.
- A current-main spot check found no teaching-relevant drift from the tagged `version_129` contract above.

## Starshine local facts rechecked

- `src/passes/optimize.mbt:118-129` omits `llvm-memory-copy-fill-lowering` from boundary-only names; there is also no removed-name entry for this spelling. Requests are therefore unknown today.
- `src/ir/effects.mbt:140-143` already classifies `HotOp::MemoryCopy` as memory-read plus memory-write and `HotOp::MemoryFill` as memory-write.
- `src/validate/validate.mbt:2086-2118` only uses data-count validation for `MemoryInit` and `DataDrop`, not `MemoryCopy` or `MemoryFill`, matching the Binaryen distinction between helper-call lowering and passive segment use.

## Corrections this bridge applies to the living dossier

- Replace vague “helper import” wording with Binaryen's actual helper-function model: temporary empty module-local functions are created before the walk, populated after use is confirmed, and removed if unused.
- Treat memory64, multi-memory, passive data/table-segment, `table.copy`, and `table.fill` as hard upstream fatal boundaries, not merely open design questions.
- Preserve the feature-metadata side effect: Binaryen disables bulk-memory features after successful lowering.
- Keep LLVM UB caveat explicit: a Starshine oracle test must not require stronger pointer-overflow behavior than Binaryen promises for this compatibility pass.

## Remaining uncertainty

- This bridge records source behavior, not an implementation request. Starshine still has no pass owner or registry category for this spelling.
- If Binaryen changes the generated helper bodies before a Starshine port starts, the owner file should be rechecked again and this bridge should be superseded rather than silently edited.
