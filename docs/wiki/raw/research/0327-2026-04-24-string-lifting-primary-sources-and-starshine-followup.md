---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-string-lifting-primary-sources.md
  - ../../binaryen/passes/string-lifting/index.md
  - ../../binaryen/passes/string-lifting/binaryen-strategy.md
  - ../../binaryen/passes/string-lifting/import-and-call-shapes.md
  - ../../binaryen/passes/string-lifting/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/decode.mbt
related:
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/string-lowering/index.md
  - ../../strings/string-const-surface.md
---

# `string-lifting` primary sources and Starshine follow-up

## Question

The wiki already had strong dossiers for `string-gathering` and `string-lowering`, but both kept mentioning `string-lifting` as a sibling without giving it a canonical pass page.
This follow-up asks:

- what does upstream Binaryen `string-lifting` actually transform?
- how does it relate to `string-lowering`?
- what exact Starshine surfaces exist today, and where is the pass absent?

## Source review

Reviewed primary online sources:

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `StringLifting.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `string-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- `string-lifting.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lifting.wast>
- current-main spot checks for `StringLifting.cpp` and `string-lifting.wast`.

The immutable manifest is [`../binaryen/2026-04-24-string-lifting-primary-sources.md`](../binaryen/2026-04-24-string-lifting-primary-sources.md).

## Findings

- `string-lifting` is the reverse-side sibling of [`string-lowering`](../../binaryen/passes/string-lowering/index.md): it lifts imported JavaScript-string constants and helper calls back into wasm-string instructions so Binaryen can optimize them.
- It handles two constant sources:
  - magic imports from the configured string-constants module;
  - numbered imports from module `string.const` plus a JSON `string.consts` custom section.
- It source-checks exact helper signatures before lifting `wasm:js-string` calls. The supported helper roster is `fromCharCodeArray`, `fromCodePoint`, `concat`, `intoCharCodeArray`, `equals`, `test`, `compare`, `length`, `charCodeAt`, and `substring`.
- The concrete transformation shapes are:
  - `global.get` of an imported string constant -> `string.const`;
  - matching helper calls -> `string.new_wtf16_array`, `string.from_code_point`, `string.concat`, `string.encode_wtf16_array`, `string.eq`, `string.test`, `string.compare`, `string.measure_wtf16`, `stringview_wtf16.get_codeunit`, or `stringview_wtf16.slice`.
- The pass is whole-module: it scans functions in parallel and then walks module code.
- It refinalizes changed functions and enables the Strings feature.
- It contains an explicit source TODO for cast insertion on string inputs, so future docs and ports must not overstate validation-perfect string-typed repair.
- The dedicated lit test is strongest for magic imports and helper calls. The JSON `string.consts` path is source-confirmed but less isolated in that direct test file.

## Starshine status

Current Starshine does **not** implement or track `string-lifting`:

- `src/passes/optimize.mbt` omits `string-lifting` from active, boundary-only, and removed registries, so explicit requests are unknown-pass requests rather than honest boundary-only rejections.
- There is no `src/passes/string_lifting.mbt` owner file.
- There is no active backlog slice for the pass in `agent-todo.md`.

Reusable prerequisites exist, but they are not a pass:

- `src/lib/types.mbt` defines `StringConst` and several string new/encode instructions.
- `src/wast/types.mbt`, `src/wast/keywords.mbt`, `src/wast/parser.mbt`, and `src/wast/lower_to_lib.mbt` parse and lower part of the string instruction surface.
- `src/validate/typecheck.mbt` validates the supported local string instructions.
- `src/binary/encode.mbt` and `src/binary/decode.mbt` round-trip `string.const` literals through the stringrefs section.
- `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt`, and `src/ir/hot_side_tables.mbt` preserve `string.const` payloads through HOT lowering/lifting.

## Wiki updates made

Added a full living dossier under `docs/wiki/binaryen/passes/string-lifting/`:

- overview page
- Binaryen strategy page
- implementation/test-map page
- transformed-shape page
- Starshine status/port-strategy page

Also updated the pass catalogs and the existing string-family pages so `string-lifting` is no longer a dangling sibling mention.

## Follow-up questions

- Should Starshine add `string-lifting` as a boundary-only registry name, or keep it unknown until a real string module-pass campaign exists?
- If it is eventually ported, should it be paired directly with `string-lowering` and share a string import/helper module utility layer?
- Should the local string instruction model add the full Binaryen `string-lifting` output surface, including `string.from_code_point`, `string.concat`, equality/compare/test, measuring, views, and slices, before any pass work starts?
