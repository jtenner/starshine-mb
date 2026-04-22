# Binaryen `heap2local` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/heap2local/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `heap2local` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/heap2local/index.md`
- `docs/wiki/binaryen/passes/heap2local/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/heap2local/validation-fixups-and-special-cases.md`
- `docs/wiki/binaryen/passes/heap2local/wat-shapes.md`
- `docs/wiki/binaryen/passes/heap2local/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/heap2local/parity.md`

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

- `Heap2Local.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Heap2Local.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Heap2Local.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>

### Official test files consulted

- `heap2local.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap2local.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap2local.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centers on the same teaching-relevant mechanics already described by the living dossier: `EscapeAnalyzer` nonescape-plus-exclusivity proof, array-to-synthetic-struct lowering, struct-local scalarization, direct ref-op folding, and mandatory `ReFinalize` / EH / nondefaultable-local repair.
- The checked current-`main` `Heap2Local.cpp` still differs only in a narrow source-level way on the surfaces reviewed for this run: slightly tighter array interaction checks, refined `array.cmpxchg` / `struct.cmpxchg` expected-vs-ref handling, and an explicit unreachable-code skip in `visitRefTest`.
- The checked current-`main` dedicated `heap2local.wast` file still showed only the already-known typo cleanup (`vaccum` -> `vacuum`), so the visible source drift remains larger than the visible dedicated-lit drift for this dossier.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
