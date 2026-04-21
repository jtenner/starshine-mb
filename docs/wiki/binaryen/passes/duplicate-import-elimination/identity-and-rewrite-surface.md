---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
  - ../../../raw/research/0205-2026-04-21-duplicate-import-elimination-source-confirmation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# `duplicate-import-elimination`: identity key and rewrite surface

This page focuses on the two most important implementation questions for Binaryen `version_129` `duplicate-import-elimination`:

1. **when are two imports considered duplicates?**
2. **which uses must be retargeted before the later import can be removed?**

The source-confirmed answer is smaller than the earlier dossier taught.
Current Binaryen `version_129` answers both questions only for imported **functions**.

## Identity key: what must match

The real pass does **not** use a broad cross-kind `ImportInfo(kind,module,base,type)` key.

Instead it uses a two-step rule:

1. first bucket imported functions by:
   - import module string
   - import base/field string
2. then, within that bucket, merge only when:
   - the earlier and later imported functions have equal `Function::type`

So the practical identity key is:

- same imported function kind,
- same module string,
- same base string,
- same function type.

But the implementation reaches that result through a small `(module, base)` map plus an explicit type check, not through the older folder's broader helper-key story.

## First-import-wins canonicalization

Binaryen does not create a fresh merged import.

Instead:

- the first imported function seen for a `(module, base)` bucket becomes canonical,
- each later matching imported function is retargeted to that first name,
- the later declaration is then removed.

That means a future port should preserve:

- deterministic canonical choice,
- stable repeated runs,
- rewrites to an existing function name rather than to a synthetic one.

## Positive identity cases

## Same module/base, same function type

Conceptual shape:

```wat
(import "env" "waka" (func $foo))
(import "env" "waka" (func $bar))
```

These are duplicates because:

- module matches,
- base matches,
- function type matches.

`$foo` wins because it is first.

## Same module/base, same parameter/result shape under an explicit type

Conceptual shape:

```wat
(type $t (func (param i32)))
(import "env" "waka" (func $a (type $t)))
(import "env" "waka" (func $b (type $t)))
```

Again, these merge because the effective `Function::type` is equal.

## Negative identity cases

## Same module/base, different function type

Conceptual shape:

```wat
(import "env" "waka" (func $foo))
(import "env" "waka" (func $wrong (param i32)))
```

These do **not** merge because the function types differ.

This negative family is explicitly covered by the shipped test.

## Different module string

Conceptual shape:

```wat
(import "env1" "waka" (func $a))
(import "env2" "waka" (func $b))
```

These do not share a bucket.

## Different base/field string

Conceptual shape:

```wat
(import "env" "waka" (func $a))
(import "env" "woka" (func $b))
```

These do not share a bucket either.

## What the pass does not currently compare because it does not handle those kinds

For Binaryen `version_129`, do **not** teach this page in terms of current merge rules for:

- imported globals,
- imported tables,
- imported memories,
- imported tags.

Those kinds are not part of this pass's current implementation.

## Rewrite surface: what actually changes

The pass uses only:

- `OptUtils::replaceFunctions(...)`

So the real rewrite surface is exactly the function-name rewrite surface that helper covers.

## Direct `call`

Binaryen rewrites:

- `Call.target`

So if a function body calls the later duplicate import, the call target is retargeted to the first imported function name.

## `ref.func`

Binaryen rewrites:

- `RefFunc.func`

This is an important edge because it keeps function-reference users aligned with the direct-call rewrite.

## Module-code `call` / `ref.func`

The helper also runs on module-code expression trees through `runOnModuleCode(...)`.

Because the walker only visits `Call` and `RefFunc`, this matters only where module-level expressions can contain function references.

The practical positive example is:

- element segment payload expressions that contain `ref.func`

That exact family is visible in the shipped test through the table element update from `$foo $bar` to `$foo $foo`.

## Start function

Binaryen explicitly rewrites:

- `module.start`

So if the start function was the later duplicate import, it is retargeted to the canonical first import.

## Function exports

Binaryen explicitly rewrites function exports:

- `export "name" (func $dup)` becomes `export "name" (func $canonical)`

The external export name stays the same; only the internal target changes.

## What the rewrite surface does **not** include here

Because the pass uses only `replaceFunctions(...)`, it does **not** currently rewrite by name here:

- `GlobalGet` / `GlobalSet`
- table instructions
- memory instructions
- global exports
- table exports
- memory exports
- segment target-name fields as non-function declarations

Those broader surfaces belonged to the earlier overgeneralized dossier, not to the real `version_129` pass.

## Imported tags are not a caveat here; they are outside the implemented scope

The older dossier treated tags as a nearby caveat.
The more accurate source-confirmed phrasing is simpler:

- imported tags are just not handled by this pass today.

The same is true for imported globals, tables, and memories.

## Practical porting checklist

When implementing Binaryen `version_129` parity for this pass in Starshine, verify all of these are true:

1. Only imported functions are considered.
2. Duplicate buckets are keyed by `(module, base)`.
3. Same-bucket functions merge only when `Function::type` is equal.
4. The canonical import is the first one seen.
5. The rewrite surface includes:
   - direct `call`
   - `ref.func`
   - module-code `call` / `ref.func`
   - start
   - function exports
6. Duplicate imported functions are actually removed after retargeting.
7. Globals/tables/memories/tags are left untouched unless a future deliberate divergence is documented.

That checklist is the shortest faithful implementation summary of the real `version_129` pass.
