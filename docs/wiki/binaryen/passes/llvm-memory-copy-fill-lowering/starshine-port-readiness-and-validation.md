---
kind: starshine-port-readiness
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0414-2026-04-26-llvm-memory-copy-fill-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/validate/validate.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./helper-call-lowering-and-boundaries.md
  - ./starshine-strategy.md
  - ../memory64-lowering/index.md
  - ../multi-memory-lowering/index.md
---

# Starshine port readiness and validation: `llvm-memory-copy-fill-lowering`

## Current hold point

Starshine should still treat `llvm-memory-copy-fill-lowering` as **unknown** today. The public registry arrays in `src/passes/optimize.mbt:118-129` do not list the spelling as boundary-only, removed, or implemented.

The local codebase already models the source opcodes, but a faithful port needs module-level helper-function synthesis and feature/validation policy, not just a single HOT rewrite.

## Source-confirmed Binaryen target

A Starshine port should match these upstream facts unless it explicitly documents a deliberate divergence:

- Create module-local helpers named from `__memory_copy` and `__memory_fill`; do not model them as imports unless the port intentionally chooses a different ABI.
- Use `(i32, i32, i32) -> none` helper signatures.
- Replace `memory.copy` with `call __memory_copy(dst, src, size)` and `memory.fill` with `call __memory_fill(dst, value, size)`.
- Support memory32 and single-memory only in the Binaryen-compatible first port.
- Reject or skip memory64, multi-memory, passive data/element/table surfaces, `table.copy`, and `table.fill` until a separate policy exists.
- Preserve Binaryen's bulk-memory feature cleanup if Starshine models the feature section in the chosen test surface.
- Do not assert stronger LLVM pointer-overflow behavior than Binaryen promises; the upstream pass explicitly does not implement that undefined-behavior edge.

## First safe implementation slice

1. **Registry honesty**: either keep the spelling unknown until the mutating pass lands, or add a boundary-only entry with tests proving it does not silently rewrite.
2. **Analyzer/no-op slice**: scan functions and report whether eligible `MemoryCopy` / `MemoryFill` instructions exist, while rejecting memory64, multi-memory, passive segment, and table-bulk blockers.
3. **Helper declaration slice**: add empty or generated module-local helper functions with stable internal names and `(i32, i32, i32) -> none` signatures.
4. **Instruction rewrite slice**: replace memory32 single-memory `MemoryCopy(0, 0)` and `MemoryFill(0)` with calls while preserving operand order.
5. **Helper body slice**: generate or share the actual bounds-checking byte-loop helper bodies, including overlap-sensitive copy behavior.
6. **Feature cleanup slice**: clear bulk-memory feature metadata only after all bulk-memory uses covered by this pass are gone and validation still succeeds.

## Required reduced tests

- Registry/CLI behavior for the exact upstream spelling.
- Simple `memory.copy` lowering to `__memory_copy` with three `i32` operands.
- Simple `memory.fill` lowering to `__memory_fill` with three `i32` operands.
- Operand-order fixture where an address/length operand can trap before the helper call.
- Overlap-oriented copy fixture that demonstrates why the helper body must choose copy direction.
- Multi-memory fixture proving the first port rejects or preserves nonzero `MemoryCopy(dst, src)` shapes rather than dropping memory indices.
- Memory64 fixture proving the first port rejects or preserves 64-bit-address modules.
- Passive `memory.init` / `data.drop` fixture proving this pass does not steal `memory-packing` responsibilities.
- Table bulk fixture proving `table.copy` / `table.fill` are outside this pass.
- Validation test proving generated helper function types, function indices, and call sites are consistent.

## Oracle lanes

Use official Binaryen as the oracle only for the source-supported subset:

```text
wasm-opt --llvm-memory-copy-fill-lowering input.wasm -o expected.wasm
```

Normalize helper-name suffixes if Binaryen's `Names::getValidFunctionName` chooses conflict-avoiding variants. Do not compare unsupported memory64, multi-memory, passive-segment, or table-bulk cases as if Binaryen should produce a valid lowered module; upstream currently treats those as fatal boundaries.

## Local surfaces to reuse

- `src/ir/effects.mbt:140-143` already records `MemoryCopy` as read+write and `MemoryFill` as write-only.
- `src/validate/validate.mbt:2086-2118` already keeps data-count validation scoped to `MemoryInit` / `DataDrop`, which is a useful negative-test anchor.
- `src/wast/lower_to_lib.mbt:2295-2301`, `src/lib/types.mbt:780-781`, `src/binary/encode.mbt:3055-3074`, and `src/ir/hot_lift.mbt` / `src/ir/hot_lower.mbt` provide opcode representation and roundtrip support, not helper synthesis.

## Open Starshine decisions

- Unknown vs boundary-only registry policy before implementation.
- Whether helper bodies should be generated exactly like Binaryen or expressed through a shared local runtime/helper abstraction.
- How to expose feature cleanup, since Starshine preserves opaque custom sections differently from Binaryen's internal `FeatureSet` flag.
- Whether to implement memory64/multi-memory compatibility later or leave those to `memory64-lowering` and `multi-memory-lowering` sequencing before this pass.
