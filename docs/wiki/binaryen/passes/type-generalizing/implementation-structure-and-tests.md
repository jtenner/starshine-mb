---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./local-flow-type-floor-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
supersedes:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
---

# Upstream implementation structure and test map for `type-generalizing`

## Why this page exists

The landing page explains what the corrected pass does.
This page answers a narrower question:

- which official Binaryen files actually define that contract?

For the corrected dossier, the answer is smaller than the old page claimed.
There is one owner file, one registration surface, and one dedicated lit file.

## Main upstream files

### 1. `src/passes/TypeGeneralizing.cpp`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeGeneralizing.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeGeneralizing.cpp>

This is the core implementation.
It defines:

- the `TypeGeneralizing` function pass
- the local-index type-evidence map
- the local-set/local-tee evidence collection
- candidate-expression checks for unreachable, concrete, and nondefaultable types
- subtype and LUB based compatible-type selection
- direct expression retagging
- the `local.get` drop-plus-zero replacement
- the single exported constructor `createTypeGeneralizingPass()`

If you only read one source file for this pass, read this one.

### 2. `src/passes/pass.cpp`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>

This file proves the upstream registration identity.
It registers:

- `experimental-type-generalizing`

through `registerTestPass(...)`.

This is the source-backed reason the corrected wiki treats upstream `experimental-type-generalizing` as a hidden/test pass and treats the Starshine name `type-generalizing` as a local boundary-only alias rather than an exact upstream public pass name.

### 3. `src/wasm/wasm-type.h`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-type.h>

This file owns the `Type` lattice operations that the pass relies on, including subtype and least-upper-bound helpers. You do not need every detail from the header to understand the pass, but you do need to know that the pass is type-lattice-driven.

## Dedicated lit test

### `test/lit/passes/type-generalizing.wast`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-generalizing.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing.wast>

This is the dedicated proof surface.
It proves that upstream considers the following families part of the real contract:

- retagging expression result types when local-flow evidence permits it
- preserving or introducing default values where the chosen type is defaultable
- handling `local.get` through the special drop-plus-zero sequence
- keeping no-op cases when the proof is weak or the candidate is unsafe

## Negative file/test map

The 2026-04-24 source correction also matters because several previously cited surfaces were not found for the reviewed release.

| Previously claimed surface | Corrected status |
| --- | --- |
| `experimental-type-generalizing-with-optimizing-casts` registration | Not found in reviewed `version_129` `pass.cpp` |
| `type-generalizing-with-optimizing-casts.wast` | Not found in reviewed release |
| `ContentOracle` dependency | Not present in `TypeGeneralizing.cpp` |
| `possible-contents.h` ownership | Not used by this pass in the reviewed source |
| `lubs.h` helper dependency | The pass uses `Type` LUB operations, not the previously claimed oracle/LUB visitor family |
| `struct.get` / `struct.set` / `call_ref` / `ref.cast` visitors | Not present in `TypeGeneralizing.cpp` |

This table is intentionally explicit so future maintenance does not silently reintroduce the stale 0191 story.

## What each real file proves

| File | What it proves |
| --- | --- |
| `TypeGeneralizing.cpp` | algorithm, local evidence map, candidate gates, `local.get` fallback, single constructor |
| `pass.cpp` | exact hidden/test pass registration name |
| `wasm-type.h` | subtype and LUB helper ownership |
| `type-generalizing.wast` | official positive and no-op shape expectations |

## Implementation structure in one outline

The corrected `version_129` source is small enough to summarize almost linearly:

1. define a function-local pass
2. maintain a map from local index to observed value type
3. collect evidence from `local.set` and `local.tee`
4. skip unreachable, concrete, and nondefaultable expression candidates
5. compute a compatible type using subtype/LUB operations
6. retag ordinary expression candidates in place
7. rewrite `local.get` candidates to drop-plus-zero sequences
8. rescan/clear evidence as the walk requires
9. export one pass constructor

That compactness is itself part of the teaching story.
This family is small and specialized.

## Test map by rewrite family

### Ordinary expression retagging

Best source:
- `type-generalizing.wast`

Teaches:
- local-flow evidence can justify changing a candidate expression's visible type
- the pass changes types, not the surrounding function signature or module type section

### `local.get` replacement

Best source:
- `type-generalizing.wast`

Teaches:
- direct type mutation of a `local.get` is not valid when it would disagree with the local declaration
- Binaryen preserves the original get as a dropped expression and emits a default/zero value of the chosen type

### No-op and boundary families

Best source:
- `type-generalizing.wast` plus `TypeGeneralizing.cpp`

Teaches:
- no rewrite for unsafe type evidence
- no rewrite for nondefaultable targets
- no broad GC oracle rewrites

## Relationship to nearby dossiers

This file/test map also clarifies the neighboring split:

- compared with `type-refining`, this pass is much smaller and does not rewrite struct field declarations or field operations
- compared with `gufa`, this pass does not build or consume a `ContentOracle`
- compared with `gufa-cast-all`, this pass does not insert new casts
- compared with `type-merging`, this pass retags expressions rather than merging type declarations

## Porting checklist derived from the official file map

A future Starshine port should not be considered faithful unless it has equivalents for:

- local-flow evidence keyed by local index
- subtype and least-upper-bound type comparisons
- candidate gates for unreachable, concrete, and nondefaultable types
- direct expression retagging
- `local.get` drop-plus-zero materialization
- tests that lock both positive and no-op cases
- continued honest registry behavior until the pass becomes active

## Practical reading order

For future follow-up work, the best reading order is:

1. `pass.cpp` to see the hidden/test registration name
2. `TypeGeneralizing.cpp` to see the full implementation shape
3. `type-generalizing.wast` for official before/after examples
4. `wasm-type.h` only when the subtype/LUB mechanics need deeper confirmation
