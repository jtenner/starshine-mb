# Binaryen `multi-memory-lowering` port-readiness primary-source capture

_Capture date:_ 2026-04-26  
_Status:_ additive source manifest for the Starshine port-readiness bridge in `docs/wiki/binaryen/passes/multi-memory-lowering/`

## Scope

This file extends the 2026-04-25 source dossier with a focused port-readiness recheck. It does not replace the original manifest; cite both when teaching the full pass contract.

Living pages updated from this capture:

- `docs/wiki/binaryen/passes/multi-memory-lowering/index.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/multi-memory-lowering/starshine-port-readiness-and-validation.md`

## Primary online sources consulted

### Official Binaryen sources

- `src/passes/MultiMemoryLowering.cpp`
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MultiMemoryLowering.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MultiMemoryLowering.cpp>
  - reviewed surfaces: public file comments, `MultiMemoryLowering` state, nested `Replacer`, module legality preparation, active data offset adjustment, helper generation for virtual `memory.size` / `memory.grow`, old-memory removal, combined-memory insertion, export repair, code walk, MultiMemory feature disablement, and checked-sibling bounds checks.
- `src/passes/pass.cpp`
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - reviewed surfaces: registrations for `multi-memory-lowering` and `multi-memory-lowering-with-bounds-checks`.
- `src/passes/passes.h`
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - reviewed surfaces: factory declarations for both pass names.

### Official Binaryen tests

- `test/lit/passes/multi-memory-lowering.wast`
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/multi-memory-lowering.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/multi-memory-lowering.wast>
  - reviewed surfaces: unchecked lowering examples for one combined memory, offset globals, scalar address repair, active data retargeting, `memory.copy` / `memory.fill` / `memory.init`, helper calls, grow behavior, export repair, and feature cleanup.
- `test/lit/passes/multi-memory-lowering-with-bounds-checks.wast`
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/multi-memory-lowering-with-bounds-checks.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/multi-memory-lowering-with-bounds-checks.wast>
  - reviewed surfaces: checked-sibling trapping wrappers for out-of-virtual-memory accesses.

### Official proposal context

- WebAssembly multi-memory proposal overview: <https://github.com/WebAssembly/multi-memory/blob/main/proposals/multi-memory/Overview.md>
  - reviewed surfaces: memory indexes on memory instructions, indexed data segments and exports, and validation against the selected memory.

## Current-main drift result

A focused 2026-04-26 current-`main` recheck found no teaching-relevant drift from the 2026-04-25 / `version_129` contract for the pass family. The important caveats remain active: only constant active data offsets are documented as a positive rewrite family, imported/exported memories after the first are not positive shapes, all memories must share address type/sharedness/page size, and the checked sibling still needs the source-commented effective-address overflow caveat preserved in Starshine parity notes.

## Port-readiness conclusions

- A faithful Starshine port must be a module pass, not a HOT-only rewrite, because it mutates memory declarations, data segments, memory exports, helper globals, helper functions, function bodies, and feature metadata together.
- The safe local first slice is **unchecked structural lowering** for two unimported, unexported, memory32, unshared memories with constant active data offsets and scalar load/store plus simple bulk-memory retargeting.
- `memory.size` and last-memory `memory.grow` should follow only after the declaration/data/body rewrite is stable, because helper generation introduces new functions and typed call sites.
- Non-last `memory.grow` is the first hard correctness cliff: later memory ranges must be moved with `memory.copy`, and later base-offset globals must be updated atomically with the virtual grow result.
- The checked sibling should be implemented after the unchecked pass is oracle-stable; otherwise bounds-check insertion can obscure ordinary address-repair bugs.
- Starshine already has useful prerequisites: `MemIdx`-carrying `MemArg`, binary decode/encode for multi-memory bulk ops, typechecking keyed by selected memory, memory effects, and module-pass infrastructure. The visible gaps are WAT multi-memory fixture ergonomics, memory-section mutation helpers, helper global/function creation policy, and feature/custom-section cleanup.

## Uncertainty and caveats

- Binaryen has source assertions/fatal assumptions rather than friendly user diagnostics for several unsupported shapes. A Starshine port must choose whether to match failure behavior, reject the pass request with a clear diagnostic, or deliberately support more shapes.
- The exact local feature-metadata cleanup contract is still unresolved. Starshine can encode custom sections, but no `multi-memory-lowering` page should promise Binaryen-style feature-set removal until code exists.
- The multi-memory proposal is context, not Binaryen implementation evidence. Use Binaryen source and lit files as the oracle for pass behavior.
