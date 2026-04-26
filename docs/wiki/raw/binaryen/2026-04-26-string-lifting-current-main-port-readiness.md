# Binaryen `string-lifting` current-main port-readiness recheck

_Capture date:_ 2026-04-26  
_Status:_ immutable primary-source recheck and Starshine-port bridge for the `docs/wiki/binaryen/passes/string-lifting/` dossier

## Scope

This file captures a focused current-main recheck of Binaryen `string-lifting` after the living dossier already had `version_129` coverage and a 2026-04-25 wrong-signature correction. The goal was not to replace the tagged oracle; it was to make the local Starshine port-readiness page safer by checking whether current upstream had drifted in a way that changes first-slice planning.

Use this file together with:

- `docs/wiki/raw/binaryen/2026-04-24-string-lifting-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md`
- `docs/wiki/raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`
- `docs/wiki/raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md`

## Primary sources rechecked

- Binaryen current-main `StringLifting.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp>
  - raw source opened 2026-04-26: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/StringLifting.cpp>
  - focused surfaces: pass comment and `string-constants-module` argument; imported string-global scan; `string.consts` custom-section JSON parse and erase; exact helper-import signature checks; unknown-helper warning; `StringApplier::visitGlobalGet(...)`; `StringApplier::visitCall(...)`; function refinalization; module-code walk; cast-repair TODO; `FeatureSet::Strings` enablement.
- Binaryen current-main `string-lifting.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lifting.wast>
  - raw source opened 2026-04-26: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/string-lifting.wast>
  - focused surfaces: `wasm-opt -all --string-lifting -S`; magic imports; helper imports; wrong-base and wrong-module negatives; expected output for `string.const`, `string.new_wtf16_array`, `string.from_code_point`, `string.concat`, `string.encode_wtf16_array`, `string.eq`, `string.compare`, `string.test`, `string.measure_wtf16`, `stringview_wtf16.get_codeunit`, and `stringview_wtf16.slice`.
- Binaryen current-main `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - focused surface: public pass registration remains in the string pass family beside `string-gathering` and `string-lowering*`.

## Recheck result

No teaching-relevant drift was found on the checked surfaces. Current `main` still matches the tagged `version_129` dossier on the important planning contract:

- `string-lifting` is still a module pass that lifts JavaScript-string imports into wasm string instructions.
- It still supports configurable magic string-constant imports plus the `string.consts` JSON custom-section path.
- It still removes the consumed `string.consts` custom section after parsing.
- It still treats recognized `wasm:js-string` helper names with wrong signatures as fatal errors, while unknown helper bases in that module are warnings and wrong modules are ignored.
- It still rewrites both global gets and helper calls, refinalizes changed functions, walks module code, enables the Strings feature, and leaves the explicit cast-repair TODO in place.
- The direct lit file still proves the major magic-import and helper-call output families, plus wrong-base / wrong-module non-rewrites.

## Starshine-port impact

This recheck strengthens the future-port ordering rather than changing it:

1. Treat `string-lifting` as an upstream-only unknown-pass gap in Starshine today.
2. Before any rewrite pass, add local representation, parser, printer, validator, and binary support for every lifted output opcode that Starshine would emit.
3. Implement magic-import `global.get -> string.const` as the safest first semantic slice.
4. Keep `string.consts` JSON custom-section support separate because Starshine's binary layer currently recognizes custom sections generically, but has no pass-facing `string.consts` parser/removal utility.
5. Add helper-call rewrites only after exact signature checking and fatal/error behavior are tested.
6. Decide whether to preserve Binaryen's cast TODO or intentionally repair casts with explicit divergence notes.

## Evidence caveats

- The current-main check is focused, not a full upstream audit. It should not be used to claim all future trunk behavior is stable.
- The raw GitHub rendering opened by the web tool compressed the source into long lines, so durable living pages should cite the official GitHub blob URLs and the semantic source regions rather than pretending line anchors were freshly verified.
- The direct lit file remains much stronger for magic imports and helper calls than for the JSON `string.consts` path, which is source-confirmed from `StringLifting.cpp`.
