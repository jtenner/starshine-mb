# Binaryen `instrument-memory` current-main port-readiness capture

_Capture date:_ 2026-04-26  
_Status:_ immutable source manifest and port-readiness bridge for the `docs/wiki/binaryen/passes/instrument-memory/` dossier

## Scope

This file records a focused current-main primary-source recheck for Binaryen `instrument-memory` and connects the upstream contract to the Starshine port-readiness questions that were still implicit in the earlier 2026-04-24 manifest.

Use this file as provenance. Use the living pages for explanation:

- `docs/wiki/binaryen/passes/instrument-memory/index.md`
- `docs/wiki/binaryen/passes/instrument-memory/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/instrument-memory/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/instrument-memory/helper-import-roster-filters-and-unsupported-types.md`
- `docs/wiki/binaryen/passes/instrument-memory/wat-shapes.md`
- `docs/wiki/binaryen/passes/instrument-memory/starshine-strategy.md`
- `docs/wiki/binaryen/passes/instrument-memory/starshine-port-readiness-and-validation.md`

## Official primary sources rechecked

### Owner and registration files

- `src/passes/InstrumentMemory.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentMemory.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentMemory.cpp>
  - Focus: helper-name roster, `InstructionFilter`, postwalk `AddInstrumentation`, `visitLoad`, `visitStore`, `visitMemoryGrow`, GC `struct.*` / `array.*` visitors, module-level helper-import injection, pass-argument parsing, and `addsEffects()`.
- `src/passes/pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Focus: public `instrument-memory` registration and unchanged help-text caveat that still under-describes the owner-file surface as loads/stores.
- `src/passes/passes.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - Focus: `createInstrumentMemoryPass()` factory declaration remains in the ordinary public pass roster.

### Dedicated lit files

- `test/lit/passes/instrument-memory.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory.wast>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory.wast>
  - Focus: scalar load/store pointer hooks, scalar value hooks, byte-width arguments, offset arguments, and helper imports.
- `test/lit/passes/instrument-memory-filter.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory-filter.wast>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-filter.wast>
  - Focus: exact comma-separated filter vocabulary, filtered no-op stores, and broader-than-filter helper imports.
- `test/lit/passes/instrument-memory-gc.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory-gc.wast>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-gc.wast>
  - Focus: GC `struct.get`, `struct.set`, `array.get`, and `array.set` scalar hooks plus array-index hooks.
- `test/lit/passes/instrument-memory64.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory64.wast>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory64.wast>
  - Focus: memory64 address-side `i64` helper signatures and `i64.const` offset/address literals while scalar value hooks remain payload-typed.

## Current-main finding

The current-main recheck found no teaching-relevant drift from the earlier tagged `version_129` contract:

- `instrument-memory` remains a compact public instrumentation pass, not a default optimizer pass.
- The owner-file strategy remains module-level helper import injection plus a postwalk wrapper over supported operation families.
- The public help text still sounds like a load/store-only pass, but owner and test files still prove `memory.grow` and selected GC `struct.*` / `array.*` coverage.
- The exact filter keys remain `load`, `store`, `memory.grow`, `struct.get`, `struct.set`, `array.get`, and `array.set`.
- Helper imports remain broader than the filtered rewrite subset.
- The pass still reports that it adds effects.
- Unsupported boundaries remain important: no bulk-memory instrumentation, no atomic RMW/cmpxchg support, no general reference payload hooks, and no SIMD payload hooks.

## Starshine port-readiness observations

The local repository recheck for this capture found the same high-level status as the 2026-04-24 dossier, but the exact implementation sequence is now clearer:

- There is no `instrument-memory` registry entry in `src/passes/optimize.mbt`; requests still fail at the unknown-name path rather than at the boundary-only or removed guards.
- Existing local memory and GC instruction representations are preservation infrastructure, not instrumentation support.
- A faithful local implementation should land as module-level work because Binaryen's observable output includes helper imports and helper-call ABI choices.
- The first safe slice should be registry-status honesty plus helper-import synthesis and scalar linear-memory load/store/grow rewrites. GC payload hooks, memory64 address widening, filters, and effect-composition tests should follow deliberately rather than being implied by the first slice.
- A local port must choose whether the pass belongs in the public optimizer surface at all. If Starshine keeps it absent, the wiki should keep documenting the absence as intentional upstream-only coverage.

## Uncertainties and caveats

- The recheck was focused on owner/registration/lit surfaces, not a whole-Binaryen history audit.
- The helper ABI should be treated as source-owned by Binaryen until a Starshine port deliberately documents a local divergence.
- Starshine's effect-summary story is still local architecture work: documenting Binaryen's `addsEffects()` is not enough to define how a future Starshine module pass invalidates or recomputes any local effect cache.
- No Starshine implementation backlog slice exists as of this capture; adding one would be a planning change, not a documentation correction.

## Consumability rule

Cite this capture when explaining the 2026-04-26 current-main no-drift result, the first-slice port order, or the exact distinction between local instruction support and actual `instrument-memory` instrumentation support.
