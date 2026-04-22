---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md
  - ../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md
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

## Why this page exists

Earlier DFE notes in this repo tended to blur together two different things:

- **upstream Binaryen DFE proper**
- **broader local Starshine cleanup currently bundled into the local DFE pass**

This page keeps that split explicit and practical.

## Source-backed correction

Official Binaryen `version_129` DFE does **not** itself do a second phase of:

- duplicate function-type compaction
- wide type-index rewriting across unrelated instructions
- name-section stripping
- element-kind canonicalization back to compact function lists
- function-annotation-section rewrite bookkeeping

The owning upstream file still does only these DFE-core steps:

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

Key code locations:

- `src/passes/duplicate_function_elimination.mbt:142-183`
  - `dfe_duplicate_simple_type_canonical_map(...)`
- `src/passes/duplicate_function_elimination.mbt:3172-3243`
  - `dfe_canonicalize_duplicate_simple_type_indices(...)`

That is a real local feature.
It is not something the official DFE source performs itself.

### Local shape: duplicate typed block signatures collapse after a merge

Before, conceptually:

```wat
(type (func (result i32))) ;; type 0
(type (func (result i32))) ;; type 1
(func
  (block (type 1)
    i32.const 7)
  drop)
(func
  (block (type 1)
    i32.const 7)
  drop)
```

After local Starshine DFE, conceptually:

```wat
(type (func (result i32))) ;; only one kept
(func
  (block (type 0)
    i32.const 7)
  drop)
```

The focused local proof lane is `src/passes/duplicate_function_elimination_test.mbt:254-317`.

## 2. Wide type-index rewriting

Because the local implementation compacts types, it also rewrites many type-index-bearing surfaces across instructions and types.

Key code locations:

- `src/passes/duplicate_function_elimination.mbt:1088-1116`
  - `dfe_scan_rewrite_func_type_idxs(...)`
- `src/passes/duplicate_function_elimination.mbt:2394-2521`
  - `dfe_rewrite_module_type_idxs(...)`
- the underlying scan/rewrite helpers span `:185-2394`

Again, this is a local extension required by local type compaction, not part of upstream DFE proper.

### Local shape: typed select and concrete-ref block types retag

Before, conceptually:

```wat
(type (func (result i32))) ;; duplicate type family
(type (func (param i32) (result i64))) ;; concrete ref type 2
(func
  (block (result (ref null 2))
    (ref.null 2))
  (ref.null 2)
  (ref.null 2)
  i32.const 1
  (select (result (ref null 2)))
  drop
  drop)
```

After local Starshine DFE, conceptually:

```wat
(type (func (param i32) (result i64))) ;; remapped concrete ref type 1
(func
  (block (result (ref null 1))
    (ref.null 1))
  (ref.null 1)
  (ref.null 1)
  i32.const 1
  (select (result (ref null 1)))
  drop
  drop)
```

The focused proof lane is `src/passes/duplicate_function_elimination_test.mbt:511-654`.

## 3. Element-kind canonicalization

Local code can rewrite compactable `ref.func` element-expression forms back into compact function-list element forms.

Key code locations:

- `src/passes/duplicate_function_elimination.mbt:54-90`
  - compactable-expression detection and `funcs`-kind rebuilding
- `src/passes/duplicate_function_elimination.mbt:92-114`
  - whole-element-section canonicalization

Useful locally, but not a direct part of the official DFE file.

### Local shape: passive `ref.func` element expressions become `funcs`

Before, conceptually:

```wat
(elem func (ref.func 0))
```

After local Starshine DFE, conceptually:

```wat
(elem func 0)
```

The local proof lane is `src/passes/duplicate_function_elimination_test.mbt:700-764`.

## 4. Name-section stripping

Local code explicitly strips the `name` section.

Key code location:

- `src/passes/duplicate_function_elimination.mbt:116-118`
  - `dfe_strip_name_sec(...)`

That may still be a valid local cleanup decision, but it should not be mistaken for a source-backed DFE requirement from Binaryen `DuplicateFunctionElimination.cpp`.

## 5. Function-annotation-section rewrite bookkeeping

Local code also rewrites a dedicated function-annotation section after merges.

Key code locations:

- `src/passes/duplicate_function_elimination.mbt:2663-2711`
  - annotation-section rewrite helpers
- `src/passes/duplicate_function_elimination.mbt:2712-2827`
  - module-wide function-index rewrite path that feeds survivor remapping into that metadata

That is another example of local serialized-format bookkeeping layered around DFE.

### Local shape: duplicate annotation entries collapse to the survivor

Before, conceptually:

```wat
(func $middle ...)
(func $right ...)
(@func_annotation 1 "binaryen.idempotent")
(@func_annotation 2 "binaryen.idempotent")
```

After local Starshine DFE, conceptually:

```wat
(func $middle ...)
(@func_annotation 1 "binaryen.idempotent")
```

The local proof lane is `src/passes/duplicate_function_elimination_test.mbt:766-848`.

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
