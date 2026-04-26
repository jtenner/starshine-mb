---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LLVMMemoryCopyFillLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/LLVMMemoryCopyFillLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/tree/version_129/test/lit/passes
  - https://github.com/WebAssembly/binaryen/tree/main/test/lit/passes
---

# Binaryen `llvm-memory-copy-fill-lowering` primary-source manifest

## Scope

This file captures the official Binaryen source surfaces used on 2026-04-26 to add a living Starshine wiki dossier for upstream `llvm-memory-copy-fill-lowering`.

The pass is not currently tracked in Starshine's pass registry. It is still worth documenting because Starshine already models `memory.copy` and `memory.fill` in WAT, lib IR, binary encoding, validation, HOT lift/lower, and effect summaries, so a future compatibility-lowering request would otherwise be easy to confuse with `memory-packing`, `multi-memory-lowering`, or generic bulk-memory validation.

## Official Binaryen sources checked

- `version_129/src/passes/LLVMMemoryCopyFillLowering.cpp`
  - Owner file for the pass.
  - Source-backed contract: lower WebAssembly bulk-memory `memory.copy` / `memory.fill` instructions into calls to helper imports compatible with the old LLVM/Emscripten bulk-memory legalization path.
- `version_129/src/passes/pass.cpp`
  - Public pass registration and scheduler ownership.
  - Confirms the pass is exposed as `llvm-memory-copy-fill-lowering` rather than as a mode of `memory-packing` or `multi-memory-lowering`.
- `version_129/src/passes/passes.h`
  - Public pass factory declaration.
- `main/src/passes/LLVMMemoryCopyFillLowering.cpp`, `main/src/passes/pass.cpp`, and `main/src/passes/passes.h`
  - Current-main spot check on 2026-04-26.
  - No teaching-relevant drift was found for the wiki contract: this remains a bulk-memory helper-call lowering pass, not a data-segment packing or many-memories layout pass.
- `version_129/test/lit/passes/` and `main/test/lit/passes/`
  - Directory scan for a pass-named lit file.
  - No dedicated `llvm-memory-copy-fill-lowering.wast` fixture was found in the checked official lit directories. The wiki therefore treats the source file and pass registration as the primary proof surface and recommends future Starshine tests be written from the source-backed transformed shapes.

## Durable conclusions

1. The pass's semantic surface is narrow: only `memory.copy` and `memory.fill` are the target instructions.
2. The transformation surface is compatibility lowering, not optimization: replace bulk-memory opcodes with helper calls while preserving operand order, side effects, traps, and memory writes.
3. The pass should not be merged in documentation with `memory-packing` or `multi-memory-lowering`:
   - `memory-packing` rewrites data segments and `memory.init` / `data.drop` users.
   - `multi-memory-lowering` combines memories and shifts addresses.
   - `llvm-memory-copy-fill-lowering` handles already-present `memory.copy` / `memory.fill` instructions by calling helper functions.
4. Starshine's current status is unknown-pass / no registry entry. The relevant local code is representation and validation infrastructure only, not a hidden pass implementation.

## Uncertainties and caveats

- The helper import names, exact helper signatures, and memory-index handling should be rechecked in the upstream owner file immediately before implementation. This manifest records the high-level source-backed contract and the official source locations, not a frozen ABI promise for a future Starshine port.
- No dedicated pass-named official lit fixture was found in the checked directories. That does not mean the pass is untested upstream; it means this dossier should not claim a standalone WAT proof file without a later source check finding one.
- Starshine has typed `MemIdx` on `MemoryCopy` / `MemoryFill`; a future local lowering must decide whether it supports only memory zero or also multi-memory helper variants. The upstream source should be treated as the authority for that decision.
