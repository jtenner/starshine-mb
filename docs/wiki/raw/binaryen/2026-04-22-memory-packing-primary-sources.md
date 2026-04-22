# Binaryen `memory-packing` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/memory-packing/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `memory-packing` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/memory-packing/index.md`
- `docs/wiki/binaryen/passes/memory-packing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/memory-packing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/memory-packing/segment-op-rewrites-and-traps.md`
- `docs/wiki/binaryen/passes/memory-packing/wat-shapes.md`
- `docs/wiki/binaryen/passes/memory-packing/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/memory-packing/parity.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that the `version_129` release page was still the reviewed official release surface for this dossier on this run.

### Official source files consulted

- `MemoryPacking.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MemoryPacking.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MemoryPacking.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Representative helper-visible surfaces reviewed through the pass source
  - `ReFinalize`, `Builder`, `UnifiedExpressionVisitor`, `ModuleUtils::ParallelFunctionAnalysis`, `DisjointSpans`, `Names::getValidGlobalName(...)`, `std::ckd_add`, and `WebLimitations::MaxDataSegments`

### Official test files consulted

- `memory-packing_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_all-features.wast>
- `memory-packing_traps.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_traps.wast>
- `memory-packing_zero-filled-memory.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_zero-filled-memory.wast>
- `memory-packing_zero-filled-memory64.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_zero-filled-memory64.wast>
- `memory-packing_memory64-high-addr.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_memory64-high-addr.wast>
- `memory-packing-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing-gc.wast>
- Representative current-`main` spot checks
  - `MemoryPacking.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MemoryPacking.cpp>
  - `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centered on the same teaching-relevant mechanics already described by the living dossier: whole-module legality gating, early active-segment op cleanup, generic segment-referrer discovery, active-vs-passive profitability splits, top-byte trap retention, passive replacement planning, lazy drop-state globals, and segment-count limiting.
- The reviewed source layout still makes the owner split visible: `MemoryPacking.cpp` is the core algorithm file, while `pass.cpp` explains the public pass identity and scheduler role, and the dedicated lit files pin down the real trap/imported-memory/GC/high-address boundaries.
- A narrow 2026-04-22 current-`main` spot check on `MemoryPacking.cpp` and `pass.cpp` did not surface a new teaching-relevant contract drift beyond the dossier's existing statement that current `main` still matches the released `version_129` semantics on the reviewed surfaces.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
