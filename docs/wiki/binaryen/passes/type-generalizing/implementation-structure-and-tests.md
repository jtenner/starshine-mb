---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./call-ref-casts-and-boundaries.md
  - ./wat-shapes.md
---

# Upstream implementation structure and test map for `type-generalizing`

## Why this page exists

The landing page explains what the family does.
This page answers a different question:

- which official Binaryen files actually define that contract?

For this dossier, the answer is pleasantly small.
The family is mostly one implementation file, one registration file, and two lit tests.

## Main upstream files

### 1. `src/passes/TypeGeneralizing.cpp`

Source:
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeGeneralizing.cpp>

This is the core family implementation.
It defines:

- the `TypeGeneralizing` walker pass class
- the `optimizeCasts` flag split
- the `ClosedWorld` + `optimizeLevel = 3` pass options
- the module-wide `ContentOracle`
- the four visitors:
  - `visitStructGet`
  - `visitStructSet`
  - `visitCallRef`
  - `visitRefCast`
- the post-change `ReFinalize` step
- the two exported pass constructors

If you only read one source file for this family, read this one.

### 2. `src/passes/pass.cpp`

Source:
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>

This file proves the public CLI identity of the family.
It registers two separate experimental pass names:

- `experimental-type-generalizing`
- `experimental-type-generalizing-with-optimizing-casts`

This is the official source-backed reason the wiki treats the local registry name `type-generalizing` as a family alias rather than as the exact upstream name.

### 3. `src/ir/possible-contents.h`

Source:
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>

This is the oracle dependency.
It matters because the pass is not doing ad hoc local inference.
It is consuming whole-program possible-contents facts.

You do not need every detail from this header to understand the family, but you do need to know that the family's precision comes from this analysis layer.

### 4. `src/ir/lubs.h`

Source:
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>

This helper matters because the family repeatedly computes a least upper bound over possible receiver or target heap types.
That is the step that turns many possible concrete contents into one safe narrower visible type.

## Dedicated lit tests

### 1. `test/lit/passes/type-generalizing.wast`

Source:
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing.wast>

This is the plain sibling's teaching surface.
It proves that upstream considers the following part of the real contract:

- `struct.get` result narrowing
- `struct.set` field-type narrowing
- `call_ref` target/result sharpening when the target signature becomes unique
- preserved no-op cases when the proof is not strong enough

### 2. `test/lit/passes/type-generalizing-with-optimizing-casts.wast`

Source:
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing-with-optimizing-casts.wast>

This file proves the sibling split is not just a registration detail.
It exists specifically to teach and lock the extra `ref.cast`-tightening behavior.

If this file did not exist, it would be easier to mistake the second public name for a hidden mode.
The test file shows it is a real separate public surface.

## What each file proves

| File | What it proves |
| --- | --- |
| `TypeGeneralizing.cpp` | algorithm, visitor surface, closed-world gate, oracle dependency, refinalization, sibling flag split |
| `pass.cpp` | exact public pass names and constructor split |
| `possible-contents.h` | family depends on module-wide possible-contents facts |
| `lubs.h` | family computes safe narrowed types through LUB reasoning |
| `type-generalizing.wast` | plain-sibling positive and preserved shapes |
| `type-generalizing-with-optimizing-casts.wast` | optimizing-casts sibling really exists and really differs |

## Implementation structure in one outline

The core `version_129` source is small enough to summarize almost linearly:

1. define a post-order walker pass with a stored `ContentOracle`
2. store `optimizeCasts` in the constructor
3. request `ClosedWorld` and `optimizeLevel = 3`
4. refine nullable `struct.get` result types from receiver contents
5. refine `struct.set` field types from receiver contents
6. refine `call_ref` target/result types from possible target signatures
7. optionally refine `ref.cast` targets from operand contents
8. build the oracle once per module in `doWalkModule`
9. refinalize changed functions when GC is enabled
10. export two pass constructors for the two public experimental names

That compactness is itself part of the teaching story.
This family is small and specialized.

## Test map by rewrite family

### `struct.get`

Best source:
- `type-generalizing.wast`

Teaches:
- broad parent-typed receiver becomes effectively narrower in the closed world
- result type can become more precise without changing the basic operation kind

### `struct.set`

Best source:
- `type-generalizing.wast`

Teaches:
- the pass can narrow the expected field type on writes
- the family is not only about result expressions

### `call_ref`

Best source:
- `type-generalizing.wast`

Teaches:
- one-signature-only rule
- target type sharpening
- result type sharpening
- impossible-target rewrite to `unreachable`

### `ref.cast`

Best source:
- `type-generalizing-with-optimizing-casts.wast`

Teaches:
- cast optimization is sibling-gated
- the family tightens existing cast targets rather than inserting new casts

## What the tests do not claim

The files are also useful because of what they do **not** claim.
They do not present this as:

- a broad whole-IR type optimizer
- a general cast insertion pass
- a default scheduler pass
- a replacement for `type-refining`, `gufa`, or `type-merging`

That absence helps keep the dossier honest.

## Relationship to nearby dossiers

This file/test map also clarifies the neighboring split:

- compared with `type-refining`, this family is much smaller and more expression-local
- compared with `gufa`, this family is a consumer of the same oracle style rather than a broader rewrite engine
- compared with `gufa-cast-all`, this family tightens existing casts instead of adding new ones
- compared with `type-merging`, this family retags uses instead of merging declarations

## Porting checklist derived from the official file map

A future Starshine port should not be considered faithful unless it has equivalents for:

- a module-wide possible-contents oracle
- a four-visitor rewrite surface
- two pass-entry names or one clearly documented local alias with a flag split
- one-signature-only `call_ref` narrowing
- impossible-target `call_ref -> unreachable`
- optional cast-target tightening
- post-change refinalization
- tests that separately lock the plain and optimizing-casts variants

## Practical reading order

For future follow-up work, the best reading order is:

1. `pass.cpp` to see the real public names
2. `TypeGeneralizing.cpp` to see the whole implementation shape
3. `type-generalizing.wast` for the plain family examples
4. `type-generalizing-with-optimizing-casts.wast` for the sibling split
5. `possible-contents.h` and `lubs.h` only when the oracle/LUB mechanics need deeper confirmation
