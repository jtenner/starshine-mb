# Binaryen `instrument-locals` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/instrument-locals/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `instrument-locals` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/instrument-locals/index.md`
- `docs/wiki/binaryen/passes/instrument-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/instrument-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/instrument-locals/unsupported-types-effects-and-import-roster.md`
- `docs/wiki/binaryen/passes/instrument-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/instrument-locals/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.

### Official source files consulted

- `InstrumentLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp>
  - Key reviewed locations in the tagged file:
    - file-level before/after comments for `local.get` and `local.set` wrapping around source lines 25-50.
    - helper-name constants and `addsEffects()` around source lines 51-78.
    - `visitLocalGet(...)` type selection, `i64` TODO bailout, and replacement call construction around source lines 79-134.
    - `visitLocalSet(...)` `Pop`, typed-function-reference, `i64`, and `unreachable` bailouts plus assigned-value wrapping around source lines 136-173.
    - `visitModule(...)` helper-import injection and feature-gated reference/SIMD helpers around source lines 175-202.
    - `addImport(...)` and `createInstrumentLocalsPass()` around source lines 204-208.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: public pass registration for `instrument-locals` and sibling `instrument-memory` around source lines 2707-2721.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - Key reviewed location: `createInstrumentLocalsPass()` declaration in the ordinary public pass-constructor roster.

### Official test files consulted

- `instrument-locals_all-features_disable-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
  - Key reviewed location: all-features run command and expected helper imports around source lines 1-30, followed by scalar/ref/SIMD rewrite checks and unchanged `i64` local traffic later in the file.
- `instrument-locals_effects.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_effects.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast>
  - Key reviewed location: comments and run lines around source lines 1-18 proving that `generate-global-effects -> instrument-locals -> vacuum` must be more conservative than a non-instrumenting lane.
- `instrument-locals-eh-legacy.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals-eh-legacy.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast>
  - Key reviewed location: legacy-EH `pop` payload checks proving that `local.set` values backed by `Pop` stay uninstrumented.

## Durable observations from the captured sources

- The reviewed official release surface anchored this dossier on Binaryen `version_129`; on 2026-04-24 the release page showed publish date **2026-04-01 14:31** and `Latest` status.
- `instrument-locals` remains a real public Binaryen pass in `pass.cpp`, but the public help text still says "loads and stores" even though the owner file's contract is local reads and writes. Keep this contradiction explicit rather than smoothing it over.
- The implementation is still a compact `PostWalker` pass plus import injection, not a hidden dataflow engine.
- The source-backed rewrite surface is narrower than the helper roster: scalar helper imports include `get_i64` / `set_i64`, but ordinary `i64` local gets and sets still return early in the visitors.
- Reference support remains limited to nullable `funcref` / `externref`; general reference types and typed function references are not fully supported.
- The pass explicitly adds effects by injecting imported calls; the dedicated effects lit file proves downstream cleanup implications with `generate-global-effects` and `vacuum`.
- A narrow 2026-04-24 current-`main` spot check on `InstrumentLocals.cpp` and the three dedicated lit files did not surface teaching-relevant contract drift beyond the existing `version_129` claims.
- The local Starshine recheck found no `instrument-locals` registry entry, owner file, tests, preset slot, or active backlog slice. Current local status is upstream-only documentation, not a boundary-only compatibility entry.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
