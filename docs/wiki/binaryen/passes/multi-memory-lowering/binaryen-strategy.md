---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md
  - ../../../raw/research/0393-2026-04-26-multi-memory-lowering-port-readiness.md
  - ../../../raw/research/0370-2026-04-25-multi-memory-lowering-source-dossier.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./memory-layout-bounds-and-growth.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `multi-memory-lowering`

## High-level algorithm

Binaryen's `version_129` `multi-memory-lowering` strategy is:

1. bail out when the module has zero or one memory;
2. validate that all memories can be represented as ranges inside one combined memory;
3. compute the combined initial/max page counts and a base byte offset for each original memory;
4. create mutable offset globals for original memories after the first;
5. retarget active data segments to the combined memory and add the right base offset to constant segment offsets;
6. create helper functions for each original memory's virtual `memory.size` and `memory.grow`;
7. replace the old memories with one combined memory;
8. repair memory exports for the first-memory-only case;
9. walk code and retarget memory operations to the combined memory;
10. disable the MultiMemory feature in Binaryen's module feature set.

The pass is therefore a module-layout and feature-lowering pass, not a local peephole.

## Source locations

The source-backed contract is concentrated in Binaryen `version_129`:

- `src/passes/MultiMemoryLowering.cpp`
  - file comments: pass goal, feature-disabling intent, and bounds-check overflow caveat;
  - `struct MultiMemoryLowering`: combined-memory state, pointer type, base-offset globals, helper names, and `checkBounds` mode;
  - nested `Replacer`: expression-level rewrites for memory instructions;
  - `prepCombinedMemory(...)`: module-shape validation, initial/max page aggregation, and import/export preservation rules;
  - `adjustActiveDataSegmentOffsets(...)`: active data retargeting and constant-offset shifting;
  - `memorySize(...)`: helper generation for virtual per-original-memory sizes;
  - `memoryGrow(...)`: helper generation for virtual growth plus byte movement and offset updates;
  - `run(...)`: orchestration, feature disabling, memory replacement, export repair, and code walk;
  - `createMultiMemoryLoweringPass()` / `createMultiMemoryLoweringWithBoundsChecksPass()`.
- `src/passes/pass.cpp`
  - public registration for both pass spellings.
- `src/passes/passes.h`
  - public constructor declarations.

See the raw manifests for exact URLs and reviewed surfaces: [`../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md) and the focused 2026-04-26 port-readiness recheck [`../../../raw/binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md).

## Combined memory layout

Binaryen preserves original memory `0` at byte offset `0`. Every later memory receives a mutable global storing its current base byte offset in bytes.

This representation matters because `memory.grow` can move later memories:

- if the last original memory grows, no later range needs movement;
- if an earlier original memory grows, later memory bytes must shift upward inside the combined memory;
- after that shift, each affected offset global must be updated.

The pass's correctness is therefore coupled to `memory.copy`, not just to address arithmetic.

## Instruction rewrites

For memory operations with an explicit original memory index, Binaryen retargets the operation to the combined memory. For nonzero memories, it adds that memory's base byte offset to the address operand before the retargeted access.

The reviewed source covers:

- scalar loads and stores;
- SIMD memory loads;
- atomic loads/stores/RMW/cmpxchg/wait/notify;
- `memory.init`;
- `memory.copy`;
- `memory.fill`;
- `memory.size`;
- `memory.grow`.

`memory.size` and `memory.grow` become calls to generated helpers because their semantics are about the original virtual memories, not a single address operand.

## Bounds-checking sibling

`multi-memory-lowering-with-bounds-checks` uses the same implementation with `checkBounds = true`.

The checked variant wraps accesses with runtime checks against the original memory's data length and traps when the access is outside that virtual memory. This is useful when the combined memory would otherwise make out-of-range original-memory accesses land in a neighboring memory's byte range.

The source comment still records an imprecision: the inserted checks do not perfectly model the spec's effective-address overflow behavior for every shifted-offset case. Keep that caveat explicit in future parity work.

## Important non-goals

- It is not a memory64-to-memory32 lowering pass. Use [`../memory64-lowering/index.md`](../memory64-lowering/index.md) for address-width lowering.
- It is not a memory-packing optimization. It preserves original memories as ranges inside one memory rather than trying to minimize data segment bytes for size.
- It is not a general linker. Imported memories after the first and exported memories after the first are not supported positive cases in the reviewed source.

## Current-main check

A focused 2026-04-26 current-`main` recheck on `MultiMemoryLowering.cpp`, `pass.cpp`, `passes.h`, and the paired lit filenames found no teaching-relevant drift from the `version_129` contract recorded here. The source-backed caveats are still part of the strategy: non-first imports/exports are not positive shapes, all memories must share address type/sharedness/page size, non-constant active data offsets remain behind a TODO/assertion path, and the checked sibling has a documented effective-address overflow imprecision.
