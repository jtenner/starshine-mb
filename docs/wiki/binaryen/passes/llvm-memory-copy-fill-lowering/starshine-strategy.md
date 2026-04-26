---
kind: starshine-strategy
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../raw/research/0384-2026-04-26-llvm-memory-copy-fill-lowering-source-dossier.md
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./helper-call-lowering-and-boundaries.md
---

# Starshine strategy: `llvm-memory-copy-fill-lowering`

## Current status

Starshine currently has no `llvm-memory-copy-fill-lowering` pass.

This is stronger than “not implemented yet but tracked”: the public pass registry arrays do not include the upstream name in `src/passes/optimize.mbt:107-129`. A user request for this exact pass should therefore be treated as unknown unless a future registry-honesty change adds it as `BoundaryOnly`, `Removed`, or implemented.

## Existing reusable infrastructure

Starshine already has the raw instruction surface:

- `src/wast/types.mbt:309-310` defines WAST opcode variants for `MemoryFill` and `MemoryCopy`.
- `src/wast/lower_to_lib.mbt:2295-2301` lowers text-format `memory.fill` and `memory.copy` into lib IR.
- `src/lib/types.mbt:780-781` represents `MemoryCopy(MemIdx, MemIdx)` and `MemoryFill(MemIdx)`.
- `src/binary/encode.mbt:3055-3074` writes the binary bulk-memory encodings.
- `src/validate/typecheck.mbt:3137-3138` routes typechecking to the memory copy/fill rules.
- `src/validate/validate.mbt:2086-2118` keeps data-count validation scoped to `MemoryInit` / `DataDrop`, which helps future tests avoid over-validating `memory.copy` / `memory.fill`.
- `src/ir/hot_lift.mbt:717-718` and `src/ir/hot_lower.mbt:970-977` can roundtrip `MemoryCopy` and `MemoryFill` through HOT.

These are prerequisites only. None of them add helper imports or replace instructions with calls.

## Likely port shape

A faithful Starshine port should probably be a module-aware pass:

1. Add a registry entry with an honest initial category.
2. Decide whether the pass owns helper import creation directly or shares an import/helper utility with other compatibility-lowering passes.
3. Scan functions for `MemoryCopy` and `MemoryFill`.
4. Insert or reuse source-confirmed helper declarations.
5. Replace each instruction with a call while preserving operand order.
6. Validate and binary roundtrip the result.

A HOT-only implementation would be risky unless the module-level helper declaration work is already complete, because the replacement instruction is a call to a function that must exist in the module.

## First slice recommendation

The safest first slice is narrow:

- memory zero only;
- imported helper declarations only;
- `memory.copy` and `memory.fill` in simple function bodies;
- no multi-memory support until Binaryen helper behavior is rechecked and mirrored;
- no attempt to lower `memory.init` or `data.drop`.

This yields useful tests while keeping the pass distinct from [`../multi-memory-lowering/index.md`](../multi-memory-lowering/index.md) and [`../memory-packing/index.md`](../memory-packing/index.md).

## Validation ladder

1. Registry-honesty test: exact upstream spelling is reported with the chosen local category.
2. Reduced WAT tests for one `memory.copy` and one `memory.fill`.
3. Helper declaration tests for import/type/index consistency.
4. Operand-order tests with trapping operands before the memory operation.
5. Negative tests for `memory.init` / `data.drop` no-op behavior.
6. Direct Binaryen oracle comparison using `wasm-opt --llvm-memory-copy-fill-lowering` on reduced fixtures.
7. `moon info`, `moon fmt`, `moon test` before commit.

## Open design questions

- Should Starshine expose the pass as upstream-only unknown until implemented, or add a boundary-only registry entry now for discoverability?
- Should helper imports be named exactly like Binaryen's current owner file, or should Starshine normalize helper names and compare semantically in oracle tests?
- How should multi-memory `MemoryCopy(dst, src)` and `MemoryFill(mem)` be handled in a first port?
- Should helper calls carry any local effect metadata, or should downstream passes treat them as ordinary effectful calls?
