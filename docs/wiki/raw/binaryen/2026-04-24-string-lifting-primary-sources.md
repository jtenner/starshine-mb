# Binaryen `string-lifting` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/string-lifting/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `string-lifting` dossier.
It is provenance-heavy by design; use the living pages for explanation:

- `docs/wiki/binaryen/passes/string-lifting/index.md`
- `docs/wiki/binaryen/passes/string-lifting/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/string-lifting/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/string-lifting/import-and-call-shapes.md`
- `docs/wiki/binaryen/passes/string-lifting/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.

### Official source files consulted

- `StringLifting.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp>
  - Key reviewed locations in the tagged file:
    - file-level purpose and `string-constants-module` pass argument near the header comments and `StringLifting` struct start.
    - `StringLifting::run(...)` imported-global discovery for magic string constants from the chosen string-constants module.
    - custom-section discovery and JSON array parsing for `string.consts`.
    - imported helper-function roster and exact-signature checks for `fromCharCodeArray`, `fromCodePoint`, `concat`, `intoCharCodeArray`, `equals`, `test`, `compare`, `length`, `charCodeAt`, and `substring`.
    - `StringApplier::visitGlobalGet(...)` rewrite from imported string globals to `StringConst`.
    - `StringApplier::visitCall(...)` rewrites from `wasm:js-string` helper calls to wasm string instructions.
    - function-local refinalization after modified function bodies.
    - module-code walk, open TODO for missing casts on generated string inputs, final `FeatureSet::Strings` enable, and `createStringLiftingPass()`.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: public registration for `string-gathering`, `string-lifting`, `string-lowering`, `string-lowering-magic-imports`, and `string-lowering-magic-imports-assert` around the pass-registration cluster.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `string-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>

### Official test files consulted

- `string-lifting.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lifting.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lifting.wast>
  - Key reviewed surfaces:
    - pass invocation `--string-lifting` with all features enabled.
    - magic string-constant imports from module `'` and multiple uses of an imported constant.
    - helper imports under `wasm:js-string` for the full supported roster.
    - positive rewrites to `string.const`, `string.new_wtf16_array`, `string.from_code_point`, `string.concat`, `string.encode_wtf16_array`, `string.eq`, `string.compare`, `string.test`, `string.measure_wtf16`, `stringview_wtf16.get_codeunit`, and `stringview_wtf16.slice` printed by Binaryen.
    - negative imports with the wrong helper base or wrong module staying as calls.

## Durable observations from the captured sources

- `string-lifting` is a public Binaryen pass in `version_129`; `pass.cpp` registers it between `string-gathering` and `string-lowering`.
- The file-level source comment states the intended direction: lift JS string imports into wasm strings so they can be optimized, with `StringLowering` typically run later to lower them again.
- The pass can discover string constants in two ways:
  - magic imports from the configurable string-constants module, using the import base as the string payload;
  - numbered imports from module `string.const` plus a `string.consts` JSON custom section, which the pass parses and then removes after lifting.
- The source checks exact helper signatures before treating `wasm:js-string` imports as liftable helper calls. Unknown helper names produce a warning, while wrong modules are ignored.
- The concrete rewrite surface is source-backed and lit-backed for the core family: `global.get` of an imported string constant becomes `string.const`, and supported helper calls become wasm string instructions.
- The pass is function-parallel for function bodies but also calls `walkModuleCode(module)` after the function walk, so module expressions are in scope too.
- It refinalizes modified functions because lifted instructions narrow externref-shaped operands/results to stringref-shaped values.
- It explicitly leaves an open cast-repair TODO: the pass generates `string.*` instructions whose string inputs should be `stringref`, but not all externrefs are converted to strings. The source notes that validation currently accepts the situation and that later lowering usually removes the need for casts.
- It enables `FeatureSet::Strings` at the end so the lifted module validates with wasm string instructions.
- A narrow 2026-04-24 current-`main` spot check on `StringLifting.cpp` and `string-lifting.wast` did not reveal teaching-relevant drift from the tagged `version_129` surfaces reviewed here.
- The local Starshine recheck found no `string-lifting` pass registry entry, no dedicated owner file, and no active backlog slice. Starshine has partial prerequisite string instruction / `string.const` parser, validator, binary, and HOT plumbing, but not this import-lifting module pass.

## Uncertainties and boundaries

- The direct lit test is strongest for magic-import constants and `wasm:js-string` helper calls. The JSON `string.consts` lifting path is source-confirmed in `StringLifting.cpp` and conceptually paired with `string-lowering`, but it is less visibly isolated in the dedicated `string-lifting.wast` output than the magic-import path.
- The open cast TODO is not a local interpretation; it is part of the reviewed upstream source contract and must remain visible in living pages until upstream or Starshine repairs that boundary.

## Consumability rule

When restating these conclusions, cite this raw capture together with the living dossier pages. Do not treat this manifest as the beginner-facing explanation.
