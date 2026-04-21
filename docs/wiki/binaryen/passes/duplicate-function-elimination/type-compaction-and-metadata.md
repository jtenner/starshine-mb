---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
---

# `duplicate-function-elimination` type compaction and metadata

## Why this page changed meaning

Earlier DFE notes in this repo tended to treat type compaction, name stripping, and metadata cleanup as if they were part of official Binaryen DFE itself.

The 2026-04-20 source refresh corrected that.

This page now exists to keep one crucial distinction explicit:

- **upstream Binaryen DFE proper**
- versus
- **broader local Starshine cleanup currently bundled into the local DFE pass**

## Source-backed correction

Official Binaryen `version_129` DFE does **not** itself do a second phase of:

- duplicate function-type compaction
- wide type-index rewriting across unrelated instructions
- name-section stripping
- element-kind canonicalization back to compact function lists
- function-annotation-section rewrite bookkeeping

The owning upstream file does only these DFE-core steps:

- choose an iteration budget
- hash functions
- exact-compare candidates
- remove duplicates
- rewrite function references
- repeat if needed

That is the official DFE contract.

## What official Binaryen *does* do about metadata

The real upstream metadata story is much smaller.

`FunctionUtils::equal(...)` in `function-utils.h`:

- **ignores** non-semantic metadata for merge blocking
- **compares** semantics-altering function annotations

So in official DFE, metadata mainly affects equality like this:

- branch hints and debug/source location do not block merging
- `js.called`, `removable.if.unused`, and `idempotent` do block merging unless they match

After a merge, Binaryen simply keeps the survivor function and therefore keeps that survivor's metadata surface.
It is not running a separate metadata-normalization pass.

## Current Starshine-local extras

The local MoonBit implementation in `src/passes/duplicate_function_elimination.mbt` currently goes beyond upstream DFE in several ways.

## 1. Duplicate simple-type compaction

Local code builds a canonical map of duplicate simple function types and may compact the type section after a function merge.

That is a real local feature.
It is not something the official DFE source performs itself.

## 2. Wide type-index rewriting

Because the local implementation compacts types, it also rewrites many type-index-bearing surfaces across instructions and types.

Again, this is a local extension required by local type compaction, not part of upstream DFE proper.

## 3. Element-kind canonicalization

Local code can rewrite compactable `ref.func` element-expression forms back into compact function-list element forms.

Useful locally, but not a direct part of the official DFE file.

## 4. Name-section stripping

Local code explicitly strips the `name` section.

That may still be a valid local cleanup decision, but it should not be mistaken for a source-backed DFE requirement from Binaryen `DuplicateFunctionElimination.cpp`.

## 5. Function-annotation-section rewrite bookkeeping

Local code also rewrites a dedicated function-annotation section after merges.

That is another example of local serialized-format bookkeeping layered around DFE.

## Why this distinction matters for parity

If you do not separate upstream DFE from local extras, several bad parity conclusions follow.

You can easily misread a difference like:

- type section size
- name section presence or absence
- element-kind print form
- annotation section shape

as if it proved the **core duplicate-function-elimination algorithm** was wrong.

But some of those differences may actually come from local extra cleanup that upstream DFE does not perform at all.

So the practical parity rule is:

- first compare the core upstream DFE contract
- only then compare the extra local normalization layers

## Practical rule for future docs and code reviews

When future work touches local DFE behavior, classify it honestly.

### Upstream DFE proper

Examples:

- iteration budget
- candidate hashing
- equality contract
- defined-only candidate set
- function-reference rewrite surface

### Local extra cleanup around DFE

Examples:

- type compaction
- type-index rewrites
- element-kind canonicalization
- name stripping
- annotation-section rewrite bookkeeping

Keeping those buckets separate will make future Binaryen parity work much easier to reason about.
