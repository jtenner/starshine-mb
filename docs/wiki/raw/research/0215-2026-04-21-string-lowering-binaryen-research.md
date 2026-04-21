# Binaryen `string-lowering` research

Date: 2026-04-21
Status: supported

## Scope

This note expands the Binaryen pass wiki beyond the current no-DWARF / saved-`-O4z` queue because the tracker no longer exposed an obvious `wiki status = none` candidate among the usual parity passes, while the existing `string-gathering` dossier still depended on an underdocumented upstream sibling: full `string-lowering`.

`string-lowering` is a real public Binaryen pass in `version_129`, but this repo did not yet have a dedicated living folder for it.
That left a real teaching gap around:

- where `string-gathering` stops and `string-lowering` begins,
- how Binaryen lowers string heap types to `externref`,
- why the pass emits either JSON-backed `string.const` imports or magic imports,
- which string ops are actually lowered in `version_129`,
- and which surfaces are still explicit TODOs in upstream source.

## Candidate selection and tracker rule

I consulted these local pages first, as required:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`

The tracker already shows dedicated dossiers for nearly all usual campaign targets, including the recently refreshed `reorder-functions-by-name` and `reorder-globals-always` entries.
So this note intentionally expands the tracker with another justified upstream-only pass instead of reopening a recently completed folder.

## Backlog status in `agent-todo.md`

There is **no dedicated `string-lowering` slice** in the current `agent-todo.md`.
That is worth stating explicitly because this pass is upstream-only for now and sits outside the repo's current local registry / preset implementation queue.

## Primary official sources used

### Tagged `version_129`

- `src/passes/StringLowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/string-utils.h`
- `test/lit/passes/string-gathering.wast`
- `test/lit/passes/string-lowering.wast`
- `test/lit/passes/string-lowering.js`
- Binaryen `CHANGELOG.md`

### Current `main` drift check

- `main/src/passes/StringLowering.cpp`
- `main/src/passes/pass.cpp`

## High-level answer

Binaryen `string-lowering` in `version_129` is **not** a generic string optimizer and **not** just `string-gathering` with a different CLI spelling.
It is a shared-family lowering pass that:

1. runs the full `StringGathering` logic first,
2. rewrites string-related heap types from `stringref` to `externref`,
3. turns canonical defining string globals into imports,
4. optionally emits well-formed literals as magic imports instead of JSON-backed numbered imports,
5. rewrites a narrow current set of string instructions into imported helper calls,
6. refinalizes the module,
7. and then disables the Strings feature flag.

That means the pass changes both:

- **code shape**
- **ABI / type shape**

It is therefore much broader than `string-gathering`, but still much narrower than “lower every possible string proposal instruction.”

## Actual implementation structure

`src/passes/StringLowering.cpp` contains both public passes:

- `struct StringGathering : public Pass`
- `struct StringLowering : public StringGathering`

That file layout matters.
The gathering pass is literally the first phase of lowering, not just a neighboring concept.

The public constructors at the bottom of the file are:

- `createStringGatheringPass()`
- `createStringLoweringPass()`
- `createStringLoweringMagicImportPass()`
- `createStringLoweringMagicImportAssertPass()`

`pass.cpp` registers the public CLI pass names:

- `string-gathering`
- `string-lifting`
- `string-lowering`
- `string-lowering-magic-imports`
- `string-lowering-magic-imports-assert`

## Main algorithmic phases

## Phase 1: gather all `string.const`s first

`StringLowering::run()` starts by calling `StringGathering::run(module)`.
So all of the earlier gathering mechanics apply first:

- parallel defined-function scan,
- separate `walkModuleCode(module)` scan,
- one canonical immutable non-null defining global per literal,
- direct AST-slot replacement of non-defining `StringConst` sites,
- validity-first stable move of defining globals to the front.

This is the strongest reason not to blur the two passes together:
`string-lowering` strictly contains `string-gathering`, then continues.

## Phase 2: rewrite heap types away from `string`

`updateTypes(module)` does the type migration.
The crucial rules are:

- `HeapType::string` becomes `HeapType::ext`.
- String refs keep their original nullability.
- Public function types in singleton rec groups are fixed manually before `TypeMapper` runs.
- The file has an explicit upstream TODO saying broader public-type cases would need more work.

That means `version_129` lowering is not a completely general public-type lowering engine.
It handles the function-signature cases Binaryen expects here, then relies on `TypeMapper` for the ordinary private/internal remap.

This is one of the most important beginner-facing facts because it shows the pass mutates the module ABI, not just instruction bodies.

## Phase 3: turn defining globals into imports

After type rewriting, `makeImports(module)` visits globals whose initializers are still `StringConst`.
For each one, Binaryen clears `global->init` and assigns import metadata instead.

There are two lowering modes.

### Default mode: numbered `"string.const"` imports plus JSON custom section

If magic imports are not used, or the literal is not accepted as a well-formed UTF-8 import name, Binaryen emits imports like:

- module: `"string.const"`
- base: `"0"`, `"1"`, ...

It also appends a `string.consts` custom section containing a JSON array of the original literal payloads.
The manual `string-lowering.wast` test and `string-lowering.js` prove both:

- the exact custom-section name,
- the JSON escaping behavior,
- duplicate-literal deduplication,
- and that the section roundtrips through `JSON.parse` in Node.

### Magic-import mode

When `useMagicImports` is enabled and the literal can be converted by `String::convertUTF16ToUTF8(...)`, Binaryen instead emits imports under the pass-argument-selected string-constants module name, with the UTF-8 literal itself as the import base.

That is what the CLI surface documents as:

- `string-lowering-magic-imports`
- `string-lowering-magic-imports-assert`

The assert variant rejects strings that cannot use the magic-import path.
The manual test proves that unpaired-surrogate families remain JSON-backed in plain magic-import mode, and become fatal errors in assert mode.

## Phase 4: replace a narrow set of string instructions with imported helper calls

`replaceInstructions(module)` adds imported helper functions first, then runs a parallel post-walk replacer.
The imported helper surface in `version_129` is:

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

The current concrete instruction rewrites are narrow and explicit:

- `StringNewWTF16Array` -> `fromCharCodeArray`
- `StringNewFromCodePoint` -> `fromCodePoint`
- `StringConcat` -> `concat`
- `StringEncodeWTF16Array` -> `intoCharCodeArray`
- `StringEqEqual` -> `equals`
- `StringEqCompare` -> `compare`
- `StringTest` -> `test`
- `StringMeasure` -> `length`
- `StringWTF16Get` -> `charCodeAt`
- `StringSliceWTF` -> `substring`

The source also makes the negative boundary explicit.
For unsupported string.new* and string.encode* variants, Binaryen still has `WASM_UNREACHABLE("TODO: ...")` fallthroughs.
So `string-lowering` is a real shipped pass, but not a universal string-proposal lowering catch-all.

## Phase 5: refinalize and disable the feature

After the code and type rewrites, the pass runs `ReFinalize()` and then disables `FeatureSet::Strings`.
That is the semantic end-state:

- string heap types are gone,
- string instructions are gone on the supported surface,
- and the lowered module now advertises itself without the Strings feature.

## Important safety / correctness boundaries

## Whole-module, not function-local

The pass changes globals, imports, custom sections, function signatures, instruction bodies, and feature flags.
So this is a whole-module boundary pass, not a hot/function-local transform.

## Defined-function parallelism plus separate module-code walk

Like `string-gathering`, the instruction-replacement phase is function-parallel, but the family also explicitly visits module code.
That matters for:

- global initializers,
- defining-string globals,
- and other non-function expression slots reached through module-level traversal.

## Public-type limitation is real

The explicit singleton-rec-group manual repair plus TODO comment means a port cannot honestly claim “Binaryen lowers all public string-bearing type shapes” on the basis of `version_129`.
The file itself says broader public-type cases would require more work.

## Preset placement fact

`pass.cpp` registers `string-lowering`, but the normal no-DWARF optimize pipeline in `version_129` only auto-schedules:

- `string-gathering`

near `reorder-globals`.
`string-lowering` is therefore a public pass surface, not part of the ordinary top-level optimize tail covered by the local parity tracker.
That is why tracker expansion needed explicit justification.

## Test surface

Two test files matter most.

### `test/lit/passes/string-gathering.wast`

This file checks both:

- `--string-gathering`
- `--string-lowering`

It is the main proof for:

- literal deduplication,
- reusable-global rules,
- nullable-global non-reuse,
- generated defining-global naming,
- externref type replacement in lowered output,
- helper import creation,
- and rewritten function/global users.

### `test/lit/passes/string-lowering.wast`

This file is manual and focuses on the part the auto-updated gathering file does not cover well:

- the `string.consts` custom section,
- JSON escaping,
- duplicate literal coalescing,
- magic-import mode,
- invalid-string fallback,
- and assert-mode fatal failure.

### `test/lit/passes/string-lowering.js`

This Node script proves the custom section is not just pretty-printed text:
Binaryen expects the bytes to decode as UTF-8 JSON and roundtrip through `JSON.parse`.

## Drift check against current `main`

A direct source diff check between `version_129` and current `main` for `src/passes/StringLowering.cpp` produced no visible diff on the checked file.
`main/src/passes/pass.cpp` still registers the same pass names.

So the working conclusion for this dossier is:

- the `version_129` `string-lowering` contract described here is still current on checked surfaces,
- and there is no obvious drift yet that would force a split between tagged-oracle behavior and present upstream behavior.

## Practical porting lessons for Starshine

If Starshine ever ports this pass, the minimal honest contract is not just “replace `string.const` with imports.”
A real parity-minded port would need to preserve:

1. the whole `string-gathering` prefix,
2. nullability-preserving `string` -> `extern` type remap,
3. singleton-public-function-type special handling,
4. default JSON-backed numbered import lowering,
5. magic-import and assert variants,
6. the narrow current helper-import surface,
7. refinalization after type/op rewrites,
8. and feature-flag removal after successful lowering.

## Living wiki follow-up created from this note

This note is filed back into a new living folder:

- `docs/wiki/binaryen/passes/string-lowering/`

with:

- `index.md`
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `wat-shapes.md`
- `json-and-magic-imports.md`

## Sources

- Binaryen `version_129` `StringLowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen `version_129` `string-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- Binaryen `version_129` `string-gathering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- Binaryen `version_129` `string-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.wast>
- Binaryen `version_129` `string-lowering.js`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.js>
- Binaryen `version_129` `CHANGELOG.md`: <https://github.com/WebAssembly/binaryen/blob/version_129/CHANGELOG.md>
- Binaryen current `main` `StringLowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
- Binaryen current `main` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Local tracker: `docs/wiki/binaryen/passes/tracker.md`
- Local pass namespace map: `docs/wiki/binaryen/passes/index.md`
- Local no-DWARF path page: `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- Local neighboring dossier: `docs/wiki/binaryen/passes/string-gathering/index.md`
- Local backlog: `agent-todo.md`
