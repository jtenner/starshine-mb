---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
---

# `duplicate-import-elimination`: identity key and rewrite surface

This page focuses on the two most important implementation questions for Binaryen `duplicate-import-elimination`:

1. **when are two imports considered duplicates?**
2. **which uses must be retargeted before the later alias import can be removed?**

Those are the two places a future port is most likely to drift.

## Identity key: what must match

The pass uses `ImportInfo` as the duplicate key.

At a high level, two imports match only if all of these match:

- import kind
- import module string
- import field/base string
- kind-specific import type metadata

## Per-kind key summary

| Kind | Helper key Binaryen uses | Beginner translation | Important caveat |
| --- | --- | --- | --- |
| Function | full stored `Function::type` | same imported function type, not just same module/base strings | current `wasm.h` still notes a TODO around imported-function exactness semantics |
| Global | `Type(curr.type, curr.mutable_)` | same value type **and** same mutability | this is stricter than just same visible WAT type name |
| Table | `HeapType`, `initial`, `max`, `addressType` | same table reference kind + same limits/addressing | helper source does **not** visibly include full table element nullability/exactness |
| Memory | `initial`, `max`, `shared`, `addressType`, `pageSize` | same limits, sharedness, addressing width, and page-size metadata | stricter than a casual min/max-only description |

## First-import-wins canonicalization

Binaryen does not create a fresh merged import.

Instead:

- the first import seen for a key becomes canonical
- each later matching import is retargeted to that first name
- the later import declaration is then removed

That means a future port should preserve:

- deterministic canonical choice
- stable behavior under repeated runs
- export/start/user rewrites to an existing name rather than to a synthetic one

## Rewrite surface: what actually changes

## Functions

Binaryen retargets these function-name users:

- direct `call`
- `ref.func`
- function exports
- module start name
- module-code expressions walked by `runOnModuleCode(...)`

### Why `ref.func` matters

This is the easiest function-family edge to forget.

If the module contains:

- table element payloads like `(ref.func $dup)`
- global initializers with `ref.func`
- other function-reference expressions

then a correct port must retarget those too, not just direct calls.

## Globals

Binaryen retargets:

- `global.get`
- `global.set`
- global exports
- module-code expressions walked by `runOnModuleCode(...)`

That means duplicate imported globals matter in:

- function bodies
- later global initializers
- active segment offsets that use `global.get`

## Tables

Binaryen retargets these table-name users:

- `table.get`
- `table.set`
- `table.size`
- `table.grow`
- `table.fill`
- `table.copy` destination and source
- `table.init`
- table exports
- module-code expressions walked by `runOnModuleCode(...)`

### Beginner warning

A table duplicate is not “just a `table.get` rename.”

If the port forgets bulk table ops, it will silently mis-handle real modules.

## Memories

Binaryen retargets these memory-name users:

- `load`
- `store`
- atomic memory ops
- SIMD memory ops
- `memory.size`
- `memory.grow`
- `memory.init`
- `memory.copy` destination and source
- `memory.fill`
- memory exports
- `array.new_data`
- `array.init_data`
- module-code expressions walked by `runOnModuleCode(...)`

### Beginner warning

A memory duplicate is not “just a memory export rename.”

It touches many instruction families.

## What `runOnModuleCode(...)` actually covers

`runOnModuleCode(...)` walks expression trees inside:

- global initializers
- element segment offsets
- element segment payload expressions
- data segment offsets

So module-level expression users are part of the rewrite contract.

That is an important positive fact.

## What the inspected helper surface does **not** explicitly cover

From the helper surfaces traced for this dossier, I did **not** find an equally explicit rewrite for non-expression top-level target-name fields such as:

- `ElementSegment.table`
- `DataSegment.memory`

I want to be precise here:

- I **did** verify expression-tree rewrites through `runOnModuleCode(...)`
- I **did** verify export/start rewrites
- I **did not** verify a direct explicit rewrite for those two non-expression fields in the same helper path

So treat this as an uncertainty ledger item, not a confident claim that Binaryen gets those wrong.

Possible explanations include:

- another code path handles those names
- the current tested surface simply does not exercise those fields for this pass

## Negative surface: what the pass does not try to do

The pass does not try to:

- merge different import kinds
- merge imports with different module strings
- merge imports with different field/base strings
- merge same-named imports with different helper-defined type metadata
- analyze effects to justify extra rewrites
- preserve later alias names as separate declarations after retargeting users
- handle imported tags in `version_129`

That last point is especially important.

## Imported tags: nearby helper support, but no pass support

`ImportInfo` already has tag support.
But `DuplicateImportElimination.cpp` never scans imported tags and never builds a tag replacement map.

So the current source story is:

- helper support exists nearby
- pass support does not

That is exactly the kind of thing future documentation tends to smooth over incorrectly, so it should stay explicit.

## Table-key caveat in plain English

A beginner-friendly way to phrase the table nuance is:

- Binaryen’s helper definitely compares table size/address/heap-shape information,
- but the helper source I traced does **not** visibly compare the full Binaryen table `Type` object the way globals and functions use full type objects.

So avoid saying “full table type equality” without a footnote.

## Practical porting checklist

When implementing this pass in Starshine, verify all of these are true:

1. Duplicate detection is per handled import kind, not one shared string map.
2. The canonical import is the first seen, not a fresh synthesized import.
3. Function duplicates rewrite:
   - direct `call`
   - `ref.func`
   - exports
   - start
   - module-code expressions
4. Global duplicates rewrite:
   - `global.get`
   - `global.set`
   - exports
   - module-code expressions
5. Table duplicates rewrite:
   - ordinary table ops
   - bulk table ops
   - exports
   - module-code expressions
6. Memory duplicates rewrite:
   - ordinary memory ops
   - atomic/SIMD memory ops
   - bulk memory ops
   - array-data helpers
   - exports
   - module-code expressions
7. Redundant import declarations are actually removed after retargeting.
8. Any unsupported or uncertain segment-target-name behavior is documented, not silently guessed.

That checklist is the shortest faithful implementation summary of the `version_129` source.