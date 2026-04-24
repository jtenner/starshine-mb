---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-string-lowering-primary-sources.md
  - ../../../raw/research/0284-2026-04-24-string-lowering-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./json-and-magic-imports.md
  - ./starshine-strategy.md
  - ../string-gathering/index.md
---

# Binaryen `string-lowering` strategy

## Upstream source rule

Use Binaryen `version_129` as the current tagged oracle for this folder, with the 2026-04-24 raw manifest as the provenance anchor.
On 2026-04-24 the official GitHub `version_129` release page showed publish date **2026-04-01 14:31**.
The main sources are:

- `src/passes/StringLowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/string-utils.h`
- `test/lit/passes/string-gathering.wast`
- `test/lit/passes/string-lowering.wast`
- `test/lit/passes/string-lowering.js`

Primary URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.js>

## High-level intent

Binaryen `string-lowering` is a whole-module pass that removes the supported wasm string surface in favor of imports and `externref`-shaped types.

The shortest accurate summary is:

- gather first,
- then rewrite types,
- then rewrite defining globals,
- then rewrite instructions,
- then refinalize,
- then disable the Strings feature.

So this pass is broader than `string-gathering`, but narrower than "lower every string-proposal opcode".

## Public pass names and family split

`pass.cpp` registers these public siblings:

- `string-gathering`
- `string-lifting`
- `string-lowering`
- `string-lowering-magic-imports`
- `string-lowering-magic-imports-assert`

That matters because this family has three distinct teaching surfaces:

- **gathering** = canonicalize literals into globals
- **lowering** = replace the supported wasm-string surface with imports / externrefs
- **lifting** = go the other direction for imported string operations

## Important ownership fact

`StringLowering.cpp` contains both:

- `struct StringGathering : public Pass`
- `struct StringLowering : public StringGathering`

So `string-lowering` literally inherits the gathering algorithm and runs it first.
That is stronger than merely "these passes are related".

## Phase 1: run `StringGathering`

`StringLowering::run()` starts with:

- `StringGathering::run(module)`

That means the exact gathering behavior comes first:

- scan defined functions in parallel for `StringConst`
- scan module code separately with `walkModuleCode(module)`
- deduplicate literals globally
- reuse immutable defined non-null string globals when possible
- create fresh defining globals otherwise
- replace non-defining literal sites with `global.get`
- stable-move defining globals earlier for validation

This prefix is not optional and is not merely conceptual.
It is actual inherited code.

## Phase 2: rewrite types from `string` to `extern`

`updateTypes(module)` is the ABI-changing step.

### The core remap

The central type update is simple:

- `HeapType::string` -> `HeapType::ext`

Nullability is preserved.
So nullable `stringref` becomes nullable `externref`, and non-null string refs become non-null `(ref extern)`.

### The non-obvious public-type rule

The implementation comments explain a subtle limitation:

- `TypeMapper` will not handle public types the way this pass needs.
- Binaryen therefore manually fixes singleton-rec-group function types that still mention strings.
- The file has an explicit TODO saying broader public-type cases would need more work.

That means the real `version_129` contract is not "general public type lowering".
It is a narrower, source-confirmed special case.

For porting, that is a major safety rule: do not silently overstate the supported public-type surface.

## Phase 3: lower defining globals into imports

After gathering, the defining string globals still have `StringConst` initializers.
`makeImports(module)` converts those globals into imports.

The important behaviors are:

- look only at globals whose initializer is still `StringConst`
- assign `global->module` and `global->base`
- clear `global->init`
- optionally append JSON metadata for the lowered literals

This is how Binaryen preserves the literal payload after removing the original string initializer.

## Phase 4: choose JSON imports vs magic imports

There are two public lowering modes.

### Default mode

Binaryen imports each defining string global from:

- module `"string.const"`
- base `"0"`, `"1"`, ...

and stores the original literal payloads in a custom section named:

- `string.consts`

whose bytes are a JSON array.

### Magic-import mode

If `useMagicImports` is enabled and `String::convertUTF16ToUTF8(...)` succeeds for the literal, Binaryen instead uses the pass-argument-selected constants module and the literal text itself as the import base.

This is the meaning of:

- `string-lowering-magic-imports`

### Assert mode

If `assertUTF8` is enabled, invalid strings are fatal instead of falling back to JSON.
That is the meaning of:

- `string-lowering-magic-imports-assert`

The manual lit file proves the distinction with valid strings, unpaired surrogates, and the fatal-error branch.

## Phase 5: add imported helper functions for lowered string ops

Before instruction rewriting, Binaryen creates all helper imports up front.
That avoids mutating import state during parallel rewriting.

The helper import surface in `version_129` is:

- `fromCharCodeArray`
- `fromCodePoint`
- `concat`
- `intoCharCodeArray`
- `equals`
- `test`
- `compare`
- `length`
- `charCodeAt`
- `substring`

These imports live under module:

- `wasm:js-string`

The signatures are rewritten to use `externref`-shaped types and the mutable i16 array helper type expected by the file.

## Phase 6: rewrite supported instructions

The replacer pass is function-parallel and postorder.
Its concrete rewrite families are:

- `StringNewWTF16Array` -> `fromCharCodeArray(...)`
- `StringNewFromCodePoint` -> `fromCodePoint(...)`
- `StringConcat` -> `concat(...)`
- `StringEncodeWTF16Array` -> `intoCharCodeArray(...)`
- `StringEqEqual` -> `equals(...)`
- `StringEqCompare` -> `compare(...)`
- `StringTest` -> `test(...)`
- `StringMeasure` -> `length(...)`
- `StringWTF16Get` -> `charCodeAt(...)`
- `StringSliceWTF` -> `substring(...)`

After the function-parallel run, the pass also does:

- `replacer.walkModuleCode(module)`

so the module-level expression surface is rewritten too.

## Negative boundary: unsupported ops are explicit upstream TODOs

The source has `WASM_UNREACHABLE("TODO: all of string.new*")` and similar unreachable defaults for unsupported instruction families.

So the honest teaching rule is:

- Binaryen `version_129` lowers a **specific current subset** of string instructions,
- not the entire proposal surface.

## Phase 7: refinalize and remove the feature

After type and instruction mutation, the pass runs:

- `ReFinalize().run(getPassRunner(), module)`

and then:

- `module->features.disable(FeatureSet::Strings)`

That is the final proof that this pass is meant to fully leave the lowered module outside the Strings feature set on the supported surface.

## What this pass is not

It is not:

- a normal no-DWARF optimize-tail pass
- a function-local hot pass
- a generic string optimizer
- a pure literal-hoisting pass
- a full lowering for every future string opcode
- a general public-rec-group lowering framework

## Interactions with nearby passes

## With `string-gathering`

`string-lowering` contains it.
So any port or explanation that skips gathering first is incomplete.

## With `reorder-globals`

`pass.cpp` explicitly schedules `string-gathering` before `reorder-globals` in the ordinary optimize tail.
That same division of labor matters conceptually here too:

- gathering / lowering create canonical defining globals
- global layout work can happen later

## With `string-lifting`

The changelog and public pass names make these sibling surfaces explicit:

- `string-lifting` raises imported string operations and values back into wasm strings
- `string-lowering` lowers them down again

So `string-lowering` should be taught as one half of a bidirectional public family, not as an isolated curiosity.

## Current-main drift check

A 2026-04-24 checked source diff found no visible difference between `version_129` and current `main` for `src/passes/StringLowering.cpp` on the inspected teaching-relevant surfaces.
`main/src/passes/pass.cpp` still exposes the same pass names.

The durable conclusion is:

- the `version_129` strategy described here is still current on the checked surfaces.

## Sources

- [`../../../raw/binaryen/2026-04-24-string-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-string-lowering-primary-sources.md)
- [`../../../raw/research/0284-2026-04-24-string-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0284-2026-04-24-string-lowering-primary-sources-and-starshine-followup.md)
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
