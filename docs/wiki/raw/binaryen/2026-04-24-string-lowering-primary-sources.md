# Binaryen `string-lowering` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/string-lowering/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `string-lowering` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/string-lowering/index.md`
- `docs/wiki/binaryen/passes/string-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/string-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/string-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/string-lowering/json-and-magic-imports.md`
- `docs/wiki/binaryen/passes/string-lowering/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.

### Official source files consulted

- `StringLowering.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
  - Key reviewed locations in the tagged file:
    - `StringGathering::run(...)` / scan-and-rewrite prefix around lines 1341-1350.
    - `StringLowering::run(...)` phase order around lines 1600-1628.
    - `makeImports(...)` JSON / magic-import handling around lines 1632-1717.
    - `updateTypes(...)` public singleton function-type handling plus `HeapType::string -> HeapType::ext` mapping around lines 1729-1815.
    - helper-import setup around lines 1818-1916.
    - supported opcode replacements and explicit TODO/unreachable families around lines 1933-2075.
    - public pass constructors around lines 2080-2088.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: public pass registration for `string-gathering`, `string-lifting`, `string-lowering`, `string-lowering-magic-imports`, and `string-lowering-magic-imports-assert` around lines 3190-3221.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `string-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>

### Official test files consulted

- `string-gathering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
  - Reviewed because it is the broad auto-updated proof surface for the inherited gathering prefix plus ordinary lowering shapes.
- `string-lowering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.wast>
  - Key reviewed location: manual custom-section / magic-import / assert-mode checks around lines 366-459.
- `string-lowering.js`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.js>
  - Key reviewed location: decoding and `JSON.parse(...)` of the emitted `string.consts` custom section around lines 277-302.

## Durable observations from the captured sources

- The reviewed official release surface anchored this dossier on Binaryen `version_129`; on 2026-04-24 the release page showed publish date **2026-04-01 14:31**.
- The reviewed upstream implementation still matched the existing dossier's core teaching story: `StringLowering` subclasses `StringGathering`, runs the gathering prefix first, rewrites string heap types to extern heap types, lowers defining string globals into imports, replaces a narrow supported string-op surface with helper calls, refinalizes, and disables the Strings feature.
- The public pass family is source-confirmed in `pass.cpp`: `string-gathering`, `string-lifting`, `string-lowering`, `string-lowering-magic-imports`, and `string-lowering-magic-imports-assert` are distinct public names.
- The JSON-vs-magic-import behavior is supported by both source and tests: default mode uses numbered `"string.const"` imports plus a `string.consts` JSON custom section; magic-import mode uses well-formed strings as import names; assert mode treats invalid strings as fatal.
- The unsupported-op boundary is source-confirmed: some `string.new*` and `string.encode*` variants still hit explicit upstream TODO / unreachable paths in `version_129`.
- A narrow 2026-04-24 current-`main` spot check on `StringLowering.cpp` did not surface teaching-relevant contract drift beyond the dossier's existing `version_129` claims.
- The local Starshine recheck found no `string-lowering` pass registry entry, no dedicated owner file, and no active backlog slice; current local support is limited to wasm-string parsing/lowering/validation and `string.const` binary plumbing.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
