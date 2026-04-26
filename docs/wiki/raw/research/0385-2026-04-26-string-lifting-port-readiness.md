# `string-lifting` port-readiness bridge

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages

## Question

The existing `string-lifting` dossier was source-correct after the 2026-04-25 wrong-signature fix, but future Starshine implementers still had to infer the first safe implementation slice from the overview and Starshine status page. This run asked:

- has Binaryen current `main` drifted in any port-planning-relevant way?
- what exact local Starshine surfaces are prerequisites rather than an implementation?
- what first-slice / validation ladder keeps `string-lifting` honest if Starshine later tracks it?

## Sources read

- Existing living pages under `docs/wiki/binaryen/passes/string-lifting/`.
- Existing raw manifests:
  - `docs/wiki/raw/binaryen/2026-04-24-string-lifting-primary-sources.md`
  - `docs/wiki/raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md`
  - `docs/wiki/raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`
  - `docs/wiki/raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md`
- New raw current-main bridge: `docs/wiki/raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`.
- Official Binaryen current-main primary sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lifting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Local Starshine code surfaces:
  - `src/passes/optimize.mbt`
  - `src/lib/types.mbt`
  - `src/wast/types.mbt`
  - `src/wast/keywords.mbt`
  - `src/wast/parser.mbt`
  - `src/wast/lower_to_lib.mbt`
  - `src/wast/module_wast.mbt`
  - `src/validate/typecheck.mbt`
  - `src/validate/validate.mbt`
  - `src/binary/encode.mbt`
  - `src/binary/decode.mbt`
  - `src/ir/hot_lift.mbt`
  - `src/ir/hot_lower.mbt`
  - `src/ir/hot_side_tables.mbt`

## Findings

- No port-planning-relevant current-main drift was found for `StringLifting.cpp`, `string-lifting.wast`, or pass registration.
- The pass remains a module-level import/helper recognizer and rewriter, not a HOT peephole and not a synonym for `string-gathering` or `string-lowering`.
- The safest future Starshine first slice is still magic-import `global.get -> string.const`, preceded by honest registry tracking and full output-opcode surface work.
- The JSON `string.consts` path is a second slice because it needs pass-facing custom-section parse/remove behavior.
- Helper-call rewrites must wait for exact signature checking, fatal recognized-helper mismatch tests, and the missing lifted output opcodes such as `string.from_code_point`, `string.concat`, `string.eq`, `string.compare`, `string.test`, `string.measure_wtf16`, and string-view get/slice.
- Starshine's existing string support is real but narrow: `StringConst`, string new/encode array opcodes, parser/lowerer/printer entries, validator surface facts, and binary string pool handling are prerequisites, not a `string-lifting` implementation.

## Living-page updates

- Added `docs/wiki/binaryen/passes/string-lifting/starshine-port-readiness-and-validation.md`.
- Refreshed `docs/wiki/binaryen/passes/string-lifting/index.md`, `binaryen-strategy.md`, `implementation-structure-and-tests.md`, `import-and-call-shapes.md`, and `starshine-strategy.md` to link the new bridge and current-main raw source.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md` for discoverability.

## Follow-up questions

- If Starshine tracks `string-lifting` before implementation, should the pass be boundary-only or removed? It is currently unknown, and the wiki intentionally does not change that code status.
- Should Starshine preserve Binaryen's current cast TODO for parity, or should a future local port intentionally add casts and document the divergence?
- Should generic custom-section storage grow a pass-facing JSON helper for `string.consts`, or should `string-lifting` own its own small parser?
