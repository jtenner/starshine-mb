# Binaryen `instrument-memory` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/instrument-memory/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `instrument-memory` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/instrument-memory/index.md`
- `docs/wiki/binaryen/passes/instrument-memory/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/instrument-memory/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/instrument-memory/helper-import-roster-filters-and-unsupported-types.md`
- `docs/wiki/binaryen/passes/instrument-memory/wat-shapes.md`
- `docs/wiki/binaryen/passes/instrument-memory/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.

### Official source files consulted

- `InstrumentMemory.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentMemory.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentMemory.cpp>
  - Key reviewed locations in the tagged file:
    - file-level before/after comments for load, store, and `memory.grow` wrapping near the top of the file.
    - helper-name constants for linear-memory, grow, struct, and array helpers near the helper-name block.
    - `InstructionFilter`, `CHECK_EXPRESSION(...)`, and the `id` counter near the rewriter setup.
    - `visitLoad(...)`, `visitStore(...)`, and `visitMemoryGrow(...)`, which own the linear-memory positive rewrite families.
    - GC visitors for `struct.get`, `struct.set`, `array.get`, and `array.set`, including scalar-type selection and unsupported-type bailouts.
    - `visitModule(...)`, which injects the broad helper-import roster and GC-conditional helpers.
    - `InstrumentMemory::addsEffects()` and pass-argument parsing in the public pass wrapper.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: public pass registration for sibling `instrument-locals` and `instrument-memory`.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - Key reviewed location: `createInstrumentMemoryPass()` declaration in the ordinary public pass-constructor roster.

### Official test files consulted

- `instrument-memory.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory.wast>
  - Key reviewed surface: scalar load/store helper imports, pointer hooks, value hooks, byte-width payloads, and static offset arguments.
- `instrument-memory-filter.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-filter.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory-filter.wast>
  - Key reviewed surface: comma-separated exact string filters, independent `load` and `memory.grow` positives, filtered-out `store` negatives, and helper imports that remain broader than the filtered rewrite subset.
- `instrument-memory-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory-gc.wast>
  - Key reviewed surface: GC `struct.get` / `struct.set` / `array.get` / `array.set` scalar payload hooks, array index hooks, and the GC-only import roster.
- `instrument-memory64.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory64.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory64.wast>
  - Key reviewed surface: memory64 address-side helper signatures and `i64.const` pointer / offset literals while scalar value hooks keep their payload types.

## Durable observations from the captured sources

- The reviewed official release surface anchored this dossier on Binaryen `version_129`; on 2026-04-24 the release page showed publish date **2026-04-01 14:31** and `Latest` status.
- `instrument-memory` remains a real public Binaryen pass in `pass.cpp`, but the public help text still says it intercepts loads and stores while the owner file and tests prove a broader surface: `memory.grow` and selected GC `struct.*` / `array.*` access families are also covered.
- The implementation is still a compact effect-adding `PostWalker` plus module-level helper import injection, not a hidden optimization or dataflow engine.
- Linear-memory loads and stores preserve the original memory op shape while rewriting pointer/value children and/or wrapping scalar results with helper calls.
- `memory.grow` uses a pre/post hook pair around the delta and result.
- The GC extension is scalar-only: `i32`, `i64`, `f32`, and `f64` payloads are instrumented, while general reference/SIMD/other payload types remain unsupported.
- The filter vocabulary is exact and source-backed: `load`, `store`, `memory.grow`, `struct.get`, `struct.set`, `array.get`, and `array.set`.
- The helper import roster is broader than the filtered rewrite subset: scalar memory/grow helpers are injected unconditionally, and GC helpers are injected whenever GC is enabled.
- A narrow 2026-04-24 current-`main` spot check on `InstrumentMemory.cpp` and the four dedicated lit files did not surface teaching-relevant contract drift beyond the existing `version_129` claims.
- The local Starshine recheck found no `instrument-memory` registry entry, owner file, tests, preset slot, or active backlog slice. Current local status is upstream-only documentation, not a boundary-only compatibility entry.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
