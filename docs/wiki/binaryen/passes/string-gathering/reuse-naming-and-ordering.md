---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md
  - ../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals-optimizing/index.md
  - ../../../strings/string-const-surface.md
---

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md) and the local status/code-map bridge in [`./starshine-strategy.md`](./starshine-strategy.md).

# `string-gathering`: reuse, naming, and ordering

This page focuses on the easiest part of `string-gathering` to misunderstand:

- which existing globals count as reusable,
- how Binaryen names fresh ones,
- and why the pass reorders globals even though `reorder-globals` still runs right after it.

## One mental model

Binaryen wants each literal to end up with exactly one **defining** immutable `(ref string)` global.

Everything else becomes either:

- a `global.get` of that defining global, or
- an untouched existing user that already was a `global.get`.

## Reusable global checklist

An existing global is reusable only if all of these are true:

| Requirement | Why it matters |
| --- | --- |
| defined, not imported | imported globals do not define a local string literal body |
| immutable | Binaryen wants the canonical string source to be stable |
| exact non-null string type `(ref string)` | matches the defining shape it would emit itself |
| initializer is directly `string.const ...` | nested or alias forms are not treated as defining storage |

If any one of those fails, Binaryen does **not** reuse the global as the canonical storage site.

## Three common non-reusable families

### Nullable string globals

Example input shape:

```wat
(global $g (ref null string) (string.const "foo"))
```

Why Binaryen refuses to reuse it:

- it is not the exact defining type the pass emits
- the pass wants canonical defining globals to be non-null stringref

So Binaryen creates or reuses a separate canonical `(ref string)` global and rewrites `$g` to read from it.

### Mutable string globals

Example input shape:

```wat
(global $g (mut (ref string)) (string.const "foo"))
```

Why Binaryen refuses to reuse it:

- a mutable global is not a safe “defining constant source” shape

So again, the mutable global becomes an alias, not the defining home of the literal.

### Nested string users inside another initializer

Example input shape:

```wat
(global $struct (ref $struct)
  (struct.new $struct
    (string.const "")))
```

Why Binaryen refuses to reuse it:

- the initializer is not directly a `StringConst`
- the pass only reuses the exact defining shape it knows how to preserve

This is why the later direct string global in the shipped test becomes the defining global instead.

## First reusable global wins

If several globals already match the reusable defining shape for the same literal, Binaryen keeps the first one it sees in current module order.

That means the rule is:

- not “shortest name wins”
- not “alphabetically earliest name wins”
- not “new fresh canonical name wins”
- simply “first matching reusable global encountered while scanning globals wins”

Later matching globals become aliases via `global.get`.

## Why Binaryen preserves some exact initializer pointers

Once the pass decides an existing global is the canonical defining one, it stores the pointer to that initializer in a `stringPtrsToPreserve` set.

That matters because the final replacement phase otherwise rewrites every `StringConst` slot it recorded.

Without the preserve set, Binaryen could accidentally turn:

```wat
(global $g (ref string) (string.const "foo"))
```

into:

```wat
(global $g (ref string) (global.get $g))
```

which would destroy the defining global instead of reusing it.

## Fresh names are about readability, not identity

When Binaryen must invent a new defining global, it derives the name from the string contents.

The pipeline is:

1. convert stored literal data from WTF-16 to WTF-8
2. escape it for printing
3. prefix with `string.const_`
4. ask `Names::getValidGlobalName(...)` for a collision-safe valid global name

So a literal like `"bar"` leads to a readable generated name such as:

- `$"string.const_\"bar\""`

Important practical rule:

- the literal payload is the semantic key
- the printed global name is just a convenient stable label

## Why the pass reorders globals at all

After gathering, other global initializers may now read from the canonical defining globals.

That can create an invalid order.
For example:

```wat
(global $struct (ref $struct)
  (struct.new $struct
    (global.get $string)))
(global $string (ref string) (string.const ""))
```

If `$struct` stays before `$string`, the module can be invalid because the initializer reads a global defined later.

So `string-gathering` performs a stable reorder that moves all defining string globals before non-defining globals.

## Why this reorder is intentionally weak

Binaryen does **not** try to compute a final global cost model here.

It only guarantees:

- defining string globals earlier than things that might use them

That is why the scheduler immediately follows this pass with `reorder-globals`.

A useful beginner summary is:

- `string-gathering` fixes validity and canonicalization
- `reorder-globals` fixes final layout quality

## Stability across repeated runs

The pass is designed not to grow more and more globals when rerun.

That stability comes from three choices working together:

- reusable defining globals are detected up front
- the first reusable match is reused instead of always creating a fresh global
- preserved initializer pointers are skipped during final replacement

So after one run:

- canonical defining globals remain defining globals
- aliases remain aliases
- ordinary string uses remain `global.get`s

A second run therefore has little or nothing new to do.

## Relation to `string-lowering`

This same reuse/naming/order logic matters beyond the standalone late optimize pass.

`StringLowering` subclasses `StringGathering`, so its first phase relies on exactly the same canonical global structure.

That means these rules are not “just cleanup aesthetics.”
They are also the foundation of the later full string-lowering path.

## Porting checklist for this specific subtopic

A future Starshine port should preserve all of these source-level details:

- reuse only direct immutable defined `(ref string)` globals
- keep first-match module-order selection for reusable globals
- keep a preserved-slot mechanism so reused defining initializers stay intact
- derive fresh names from literal contents in a readable collision-safe way
- move defining globals earlier stably for validity
- keep the reorder narrow and leave final global layout work to `reorder-globals`

## Sources

- [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md)
- [`../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`](../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md)
- [`../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md`](../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
