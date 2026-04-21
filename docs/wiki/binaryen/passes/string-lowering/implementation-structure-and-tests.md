---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./json-and-magic-imports.md
  - ../string-gathering/index.md
---

# `string-lowering`: implementation structure and tests

This page is the compact source-confirmed map of which Binaryen files own `string-lowering` and which shipped tests prove the important contract surfaces.

## Official owner files

| File | Why it matters |
| --- | --- |
| `src/passes/StringLowering.cpp` | Main owner file for both `StringGathering` and `StringLowering`, including type rewrites, import lowering, helper-import setup, instruction replacement, refinalization, and feature disable |
| `src/passes/pass.cpp` | Registers `string-lowering`, `string-lowering-magic-imports`, and `string-lowering-magic-imports-assert`; also registers sibling `string-gathering` and `string-lifting` |
| `src/passes/passes.h` | Declares the public pass constructors |
| `src/passes/string-utils.h` | Supplies shared family constants like the string-constants module name |
| `test/lit/passes/string-gathering.wast` | Main auto-updated proof file for both gathering and lowering shapes |
| `test/lit/passes/string-lowering.wast` | Manual proof file for custom-section JSON, magic imports, invalid-string fallback, and assert failure |
| `test/lit/passes/string-lowering.js` | Confirms the emitted `string.consts` custom section decodes and parses as JSON |

## Real implementation phases in `StringLowering.cpp`

## 1. `run(Module* module)`

This top-level method defines the real phase order:

1. bail out immediately if the module does not have the Strings feature
2. run `StringGathering::run(module)`
3. `updateTypes(module)`
4. `makeImports(module)`
5. `replaceInstructions(module)`
6. `ReFinalize()`
7. disable `FeatureSet::Strings`

That single list is the cleanest source-confirmed summary of the pass.

## 2. `updateTypes(module)`

This is the ABI-changing step.
It proves the pass is not just a code rewrite.

Important subfacts:

- `HeapType::string` is remapped to `HeapType::ext`
- nullability is preserved
- public singleton-rec-group function types are manually rewritten first
- `TypeMapper` then handles the ordinary remap work
- the file has an explicit TODO for broader public-type cases

## 3. `makeImports(module)`

This step lowers defining string globals into imports.
The key behaviors are:

- keep numbered `"string.const"` imports in the default mode
- append JSON text for those literals into custom section `string.consts`
- optionally switch well-formed strings to magic imports instead
- clear the original initializer afterward

## 4. `replaceInstructions(module)`

This step adds the helper imports up front, then runs the parallel replacer.
The file proves the exact helper import surface and therefore the exact op-lowering surface.

## Exact helper import surface in `version_129`

| Import base | Purpose |
| --- | --- |
| `fromCharCodeArray` | lower `StringNewWTF16Array` |
| `fromCodePoint` | lower `StringNewFromCodePoint` |
| `concat` | lower `StringConcat` |
| `intoCharCodeArray` | lower `StringEncodeWTF16Array` |
| `equals` | lower `StringEqEqual` |
| `test` | lower `StringTest` |
| `compare` | lower `StringEqCompare` |
| `length` | lower `StringMeasure` |
| `charCodeAt` | lower `StringWTF16Get` |
| `substring` | lower `StringSliceWTF` |

All are imported from module:

- `wasm:js-string`

## Exact op families Binaryen lowers here

| IR family | `version_129` behavior |
| --- | --- |
| `StringConst` | already handled by inherited gathering phase |
| `StringNewWTF16Array` | lowered |
| `StringNewFromCodePoint` | lowered |
| other `StringNew*` variants | explicit upstream TODO / unreachable |
| `StringConcat` | lowered |
| `StringEncodeWTF16Array` | lowered |
| other `StringEncode*` variants | explicit upstream TODO / unreachable |
| `StringEqEqual` | lowered |
| `StringEqCompare` | lowered |
| `StringTest` | lowered |
| `StringMeasure` | lowered to `length` |
| `StringWTF16Get` | lowered |
| `StringSliceWTF` | lowered |

That table is the best compact answer to "what does this pass really lower today?"

## Shipped proof surface

## `test/lit/passes/string-gathering.wast`

This file is the strongest broad proof for everyday lowering shape.
It directly checks:

- gathered literal reuse
- reusable-global detection
- non-reuse of the wrong global shape
- generated defining-global naming
- externref replacement in globals and signatures
- helper import declarations
- rewritten function users
- rewritten global-initializer users

It is also important that the file checks both prefixes:

- `CHECK` for `--string-gathering`
- `LOWER` for `--string-lowering`

That makes it the best compact sibling-comparison proof.

## `test/lit/passes/string-lowering.wast`

This file exists because the auto-updated gathering file does not fully explain the custom-section half of lowering.
It proves:

- the exact `string.consts` custom-section name
- JSON array contents
- escaping of tabs, NUL, quotes, backslashes, CR/LF, and non-ASCII text
- deduplication of repeated literals
- magic-import mode behavior
- invalid-string fallback in magic-import mode
- assert-mode fatal failure for invalid strings

## `test/lit/passes/string-lowering.js`

This helper script proves the custom section is intended as real machine-readable JSON, not just a debugging artifact.
It:

- reads the `string.consts` custom section from the emitted wasm
- decodes it as UTF-8
- parses it with `JSON.parse`
- prints the normalized result

That is the strongest proof that the JSON surface is part of the intended contract.

## Best beginner proof split

If teaching this pass to a new contributor, the cleanest proof split is:

- `string-gathering.wast` for code-shape and type-shape rewrites
- `string-lowering.wast` plus `string-lowering.js` for metadata / import-mode behavior

## Current-main drift check

A checked diff against current `main` found no visible changes in `src/passes/StringLowering.cpp` on the inspected file, and `main/src/passes/pass.cpp` still exposes the same public pass names.

So the working conclusion is:

- the tagged `version_129` implementation and test map here still matches current upstream on the checked surfaces.

## Sources

- [`../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md`](../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.js>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
