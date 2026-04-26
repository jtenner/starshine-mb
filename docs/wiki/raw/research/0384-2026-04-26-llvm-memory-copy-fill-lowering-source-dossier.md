---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../binaryen/passes/llvm-memory-copy-fill-lowering/index.md
  - ../../binaryen/passes/llvm-memory-copy-fill-lowering/binaryen-strategy.md
  - ../../binaryen/passes/llvm-memory-copy-fill-lowering/wat-shapes.md
  - ../../binaryen/passes/llvm-memory-copy-fill-lowering/starshine-strategy.md
  - ../../../../src/wast/types.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
  - ../../../../src/passes/optimize.mbt
---

# `llvm-memory-copy-fill-lowering` source dossier

## Question

Does Starshine's pass wiki need a durable page for Binaryen `llvm-memory-copy-fill-lowering`, even though it is not part of the current no-DWARF parity queue or Starshine registry?

## Answer

Yes. The pass is a real upstream Binaryen transformation pass, and Starshine already has enough bulk-memory representation and validation surfaces that future readers could reasonably ask whether it is implemented locally. The new dossier records that the current answer is no: Starshine parses, encodes, validates, lifts, lowers, and effect-tracks `memory.copy` / `memory.fill`, but it has no pass that lowers those instructions into helper imports.

## Sources checked

- Official Binaryen `version_129` and current-main owner/registration/factory files for `LLVMMemoryCopyFillLowering`.
- Official Binaryen `version_129` and current-main `test/lit/passes` directories for a pass-named lit fixture; none was found during this focused check.
- Starshine local surfaces for bulk-memory instructions:
  - WAST opcode tags and lowering to lib IR.
  - Binary encoding for `memory.copy` and `memory.fill`.
  - Typechecking for `memory.copy` and `memory.fill`.
  - Data-count validation for `memory.init` / `data.drop` only, which is a useful distinction because `memory.copy` / `memory.fill` do not need data-count validation.
  - HOT lift/lower and effect summaries.
  - Public pass registry arrays, where the upstream pass name is absent.

## Durable findings

1. Binaryen's pass is compatibility lowering for bulk-memory copy/fill instructions, not a size optimizer.
2. The important transformed shapes are:
   - `memory.copy` with destination/source/length operands.
   - `memory.fill` with destination/value/length operands.
   - no-op around `memory.init` / `data.drop`, passive segment layout, and many-memory layout.
3. The main local caveat is not parsing support. Starshine already has representation support. The missing piece is a module/function rewrite pass that would add or reference helper imports and replace instructions with calls.
4. Future implementation must preserve memory-write effects and trap behavior. A helper-call rewrite changes call/effect shape, so downstream passes and validation must see the helper declarations and call signatures consistently.

## Wiki changes made

- Added `docs/wiki/binaryen/passes/llvm-memory-copy-fill-lowering/` with:
  - `index.md`
  - `binaryen-strategy.md`
  - `implementation-structure-and-tests.md`
  - `wat-shapes.md`
  - `helper-call-lowering-and-boundaries.md`
  - `starshine-strategy.md`
- Updated the pass catalog and tracker so this upstream-only pass is findable without implying active Starshine support.
- Updated the global wiki index and log.

## Uncertainties

- The exact helper import ABI should be rechecked in Binaryen's owner file before coding. This note deliberately avoids freezing helper signatures beyond the source-backed “bulk-memory helper-call lowering” contract.
- The absence of a dedicated pass-named lit file is a focused check result, not a claim that no upstream tests exercise the owner file indirectly.
