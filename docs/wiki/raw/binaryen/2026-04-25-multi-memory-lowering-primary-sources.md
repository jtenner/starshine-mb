# Binaryen `multi-memory-lowering` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for `docs/wiki/binaryen/passes/multi-memory-lowering/`

## Scope

This file captures the primary online sources consulted while adding the `multi-memory-lowering` / `multi-memory-lowering-with-bounds-checks` dossier.
It is provenance-heavy by design. Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/multi-memory-lowering/index.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/memory-layout-bounds-and-growth.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - Earlier same-repo captures observed the release page as published **2026-04-01 14:31** and marked `Latest`; this capture reuses `version_129` as the tagged source oracle.

### Official Binaryen source files consulted

- `MultiMemoryLowering.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MultiMemoryLowering.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MultiMemoryLowering.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MultiMemoryLowering.cpp>
  - Key reviewed locations in the tagged file:
    - file-level comments explaining the goal: condense multiple memories into one memory for engines without multi-memory support; disable the MultiMemory feature in the emitted module; and acknowledge the optional bounds-check imprecision around spec-style offset overflow.
    - `struct MultiMemoryLowering`, storing `combinedMemory`, pointer type, import/export state, total initial/max pages, per-memory byte-offset globals, memory-index map, generated `memory.size` and `memory.grow` function names, and the `checkBounds` mode.
    - nested `Replacer` walker: skips generated helper functions, rewrites `memory.size` / `memory.grow` to helper calls, adds byte-offset globals to memory addresses, optionally emits bounds-check blocks, and retargets `MemoryInit`, `MemoryCopy`, `MemoryFill`, scalar loads/stores, SIMD loads, atomic RMW/cmpxchg/wait/notify to the combined memory.
    - `run(...)`: disables the MultiMemory feature, skips modules with zero or one memory, prepares combined-memory state, creates offset globals, adjusts active data segments, creates helper functions, removes old memories, adds the combined memory, repairs memory exports, and finally runs `Replacer`.
    - `prepCombinedMemory(...)`: requires matching sharedness, address type, and page size; rejects imported memories after the first; rejects exported memories other than the first; sums initial/max page counts; preserves first-memory import/export identity on the combined memory.
    - `adjustActiveDataSegmentOffsets(...)`: moves active data segments to the combined memory and adds the original memory's byte offset to constant segment offsets; non-constant segment offsets remain a source TODO/assertion.
    - `memoryGrow(...)`: creates one helper per original memory, calls `memory.grow` on the combined memory, moves later memory ranges with `memory.copy` when a non-last memory grows, and updates offset globals for later memories.
    - `memorySize(...)`: creates one helper per original memory that computes a virtual per-memory size from adjacent byte-offset globals or the combined memory size.
    - factory functions `createMultiMemoryLoweringPass()` and `createMultiMemoryLoweringWithBoundsChecksPass()`.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - Key reviewed location: public registrations for `multi-memory-lowering` and `multi-memory-lowering-with-bounds-checks`, with descriptions `combines multiple memories into a single memory` and the bounds-checking variant that traps when reads or writes exceed the original memory's data length.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: constructor declarations for `createMultiMemoryLoweringPass()` and `createMultiMemoryLoweringWithBoundsChecksPass()`.

### Official Binaryen test files consulted

- `multi-memory-lowering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/multi-memory-lowering.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/multi-memory-lowering.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/multi-memory-lowering.wast>
  - Key reviewed surface: combined-memory output, offset-global creation, load/store address rewriting, memory operation retargeting, helper functions for `memory.size` / `memory.grow`, export repair, and feature removal.
- `multi-memory-lowering-with-bounds-checks.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/multi-memory-lowering-with-bounds-checks.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/multi-memory-lowering-with-bounds-checks.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/multi-memory-lowering-with-bounds-checks.wast>
  - Key reviewed surface: optional bounds-check wrapper shapes around ordinary memory accesses and bulk-memory operations.

### Related primary-source context

- Binaryen README `wasm-merge` section
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
  - Key reviewed surface: `wasm-merge` can produce multi-memory output when multiple input modules contain memories, and the README names `wasm-opt --multi-memory-lowering` as a workaround for older VMs.
- WebAssembly multi-memory proposal overview
  - URL: <https://github.com/WebAssembly/multi-memory/blob/main/proposals/multi-memory/Overview.md>
  - Key reviewed surface: the proposal adds multiple memories in one module, memory indexes on memory-related instructions, memory indexes for `memory.copy`, data segment / memory export indexing, and validation against the selected memory index.

## Durable observations from the captured sources

- `multi-memory-lowering` is a real public Binaryen pass in `version_129`; `multi-memory-lowering-with-bounds-checks` is a public sibling using the same owner file with `checkBounds = true`.
- The pass is a whole-module feature-lowering transform, not a local memory peephole: it rewrites the memory section, active data segment offsets, memory exports, and every surviving instruction that names an original memory.
- The output contains one combined memory plus mutable byte-offset globals for every original memory after the first.
- Loads, stores, SIMD memory ops, atomics, `memory.init`, `memory.copy`, and `memory.fill` are retargeted to the combined memory after their address operands are shifted by the selected original memory's byte-offset global.
- `memory.size` and `memory.grow` cannot be retargeted by simple operand rewriting; Binaryen creates helper functions that preserve the illusion of separate original memories.
- Non-last `memory.grow` is especially invasive: after growing the combined memory, Binaryen copies later memory ranges upward and updates offset globals.
- The pass preserves only a constrained module shape: same memory address type and sharedness across all memories, same page size, at most the first memory imported, and at most the first memory exported.
- Active data segment offsets are source-confirmed only for constant offsets; the owner file still has a TODO/assertion around non-constant segment offsets and a TODO for stronger runtime traps in one shifted-offset case.
- The optional bounds-check variant deliberately adds local temporaries and explicit traps before retargeted memory accesses; the owner file comments record an imprecision around offset overflow versus the spec's effective-address arithmetic.
- A focused current-`main` spot check on `MultiMemoryLowering.cpp` and the paired lit filenames found no teaching-relevant drift from the `version_129` contract on 2026-04-25.
- Starshine currently has no registry entry, owner file, tests, preset slot, or backlog slice for `multi-memory-lowering` or the bounds-checking sibling. Current local status is upstream-only documentation, not boundary-only compatibility.

## Uncertainty and caveats

- The current source makes several fatal/assertion assumptions rather than polished user-facing diagnostics: imported memories after the first, non-first exported memories, mismatched page sizes, mismatched sharedness/address types, and non-constant active data offsets are not documented here as supported positive cases.
- The pass deliberately disables the MultiMemory feature in Binaryen's feature set; Starshine's current feature/custom-section model has no equivalent public metadata cleanup contract for this pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
