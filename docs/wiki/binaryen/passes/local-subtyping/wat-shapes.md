---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./lubs-and-dominance.md
  - ../optimize-casts/index.md
---

# `local-subtyping` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `local-subtyping` pass.

## Read this page with one mental model

Binaryen is not asking:

- “where can I infer every possible local subtype?”

It is asking a much smaller question:

- “given the concrete local traffic I can already see, what one narrower local type would still satisfy all of it, and can the helper layer realize that safely?”

That is why many examples below are about:

- common-parent narrowing
- non-null hints
- helper-induced conservatism
- explicit non-rewrites

## Important note about the examples

The `after` snippets below are **conceptual**.

In real Binaryen output, the pass may realize the change by:

- directly changing the local declaration type
- or introducing a copy local in the dominated region

So read the examples as “what kind of local-type tightening is intended,” not “the exact final printed WAT in every case.”

## Quick glossary

- **wide local**: the original local declaration type is broader than the uses really need
- **narrow local**: the tighter type Binaryen wants after collecting the subtype facts
- **LUB**: the least upper bound of all observed concrete subtype facts
- **dominance-safe region**: the structured-control region where the helper knows the narrow local value is valid
- **copy local**: an extra helper-created local that carries the narrower type when changing the original local uniformly would be unsafe

## Shape 1: all concrete gets/sets already agree on one narrower type

Before:

```wat
(local $x anyref)
(local.set $x
  (struct.new $A ...))
(drop
  (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $A))
(local.set $x
  (struct.new $A ...))
(drop
  (local.get $x))
```

Why it rewrites:

- the declaration is wider than the concrete local traffic
- the observed set/get facts all agree on the narrower type
- the helper layer can realize that change safely

This is the simplest positive family.

## Shape 2: sibling subtypes narrow only to the common parent

Before:

```wat
(local $x anyref)
(if (result i32)
  (i32.const 1)
  (then
    (local.set $x
      (struct.new $Left ...)))
  (else
    (local.set $x
      (struct.new $Right ...))))
(drop
  (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $Parent))
```

Why it rewrites that way:

- Binaryen computes a LUB, not the narrowest individual leaf type
- both child structs fit under `$Parent`
- the declaration can still get narrower than `anyref`, just not all the way to either child leaf

This is the most important “LUB, not smallest leaf” shape.

## Shape 3: `ref.as_non_null(local.get ...)` can contribute a non-null fact

Before:

```wat
(local $x (ref null $A))
(local.set $x
  (struct.new $A ...))
(drop
  (ref.as_non_null
    (local.get $x)))
```

After, conceptually:

```wat
(local $x (ref $A))
```

Why it can rewrite:

- `ref.as_non_null(local.get $x)` is one of the very few direct refinement hooks this pass understands
- the local traffic may now all agree on the non-null form
- if the helper can apply that safely, the local can narrow to the non-null type

Important nuance:

- one `ref.as_non_null` does not guarantee narrowing by itself
- any remaining concrete nullable get/set facts can keep the LUB nullable

## Shape 4: `local.tee` contributes the tee result type

Before:

```wat
(local $x anyref)
(drop
  (local.tee $x
    (struct.new $A ...)))
(drop
  (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $A))
```

Why it matters:

- Binaryen records the tee result type for `local.tee`
- that is slightly more precise than pretending every set is only a plain `local.set`
- later local users can benefit from the narrower declaration

This is a small source detail that changes real behavior.

## Shape 5: dead or trapping paths do not automatically force a wider local

Before, conceptually:

```wat
(local $x anyref)
(local.set $x
  (struct.new $A ...))
(drop
  (call_ref ...)) ;; can make later traffic unreachable
(drop
  (local.get $x))
```

Why narrowing can still happen:

- the pass only records **concrete** types
- non-concrete `unreachable`-typed traffic does not automatically widen the result
- the shipped tests include `call_ref` and throwing families to keep this honest

This is why dead-code and exceptional-path tests are part of the official surface.

## Shape 6: params are intentionally unchanged

Before and after stay the same in the important part:

```wat
(func $f (param $p anyref)
  (drop
    (local.get $p)))
```

Why Binaryen keeps it:

- the pass only optimizes vars, not params, in `version_129`
- the source comment explicitly calls params out as future work and ties them to harder dominance / named-block questions

A future port should preserve that conservatism first.

## Shape 7: tuple locals are intentionally unchanged

Before and after stay the same in the important part:

```wat
(local $pair (tuple i32 i64))
```

Why Binaryen keeps it:

- `TypeUpdating::canHandleAsLocal(...)` rejects tuple types
- this pass only updates helper-supported single-value locals

That is a real current contract, not an accidental omission.

## Shape 8: `ref.cast` alone is not a direct positive shape here

Before and after stay the same in the important part:

```wat
(local $x anyref)
(drop
  (ref.cast (ref $A)
    (local.get $x)))
```

Why Binaryen may keep it:

- `local-subtyping` itself does not directly inspect `ref.cast`
- the pass only has a specialized direct hook for `ref.as_non_null(local.get ...)`
- if `ref.cast` information matters, Binaryen expects neighboring passes like `optimize-casts` to expose better local traffic first

This is one of the easiest places to overestimate the pass.

## Shape 9: one narrower use does not override wider concrete uses

Before:

```wat
(local $x anyref)
(local.set $x
  (struct.new $A ...))
(drop
  (local.get $x))
(call $needs_anyref
  (local.get $x))
```

After, conceptually:

```wat
(local $x anyref)
```

Why Binaryen can keep it wide:

- the local's observed concrete traffic still includes a wider use requirement
- the LUB must satisfy *all* those facts together
- one narrow use site does not force a globally narrow declaration

## Shape 10: named blocks and `try_table` are helper-sensitive regions

Before, conceptually:

```wat
(local $x anyref)
(block $b
  ...
  (try_table ...)
  ...
  (drop (local.get $x)))
```

What matters here:

- the collector may still decide the local wants a narrower type
- but the actual rewrite safety depends on `LocalStructuralDominance`
- named blocks, loops, and catches are real structure for the updater

So the important lesson is not “these shapes never rewrite.”
The important lesson is:

- these are the shapes where the dominance-aware helper contract matters most

That is why the shipped tests exercise named-block and `try_table` families directly.

## Shape 11: sometimes the real `after` shape is a copy local

Conceptual before:

```wat
(local $x anyref)
(local.set $x
  (struct.new $A ...))
;; some dominated region uses only need ref $A
;; some other region still needs the older view
```

Conceptual after:

```wat
(local $x anyref)
(local $x.narrow (ref $A))
(local.set $x
  (struct.new $A ...))
(local.set $x.narrow
  (local.get $x))
;; dominated users switch to $x.narrow
```

Why this can happen:

- the type updater may not be able to change the original local uniformly
- but it can still introduce a copy local that carries the narrower type where dominance makes that valid

This is the single most important “the pass is more than a declaration edit” shape.

## What a future Starshine port must preserve

If Starshine ports `local-subtyping`, these are the shape truths worth preserving first:

1. narrow only non-parameter locals
2. skip tuple locals unless the helper layer grows
3. use LUB-style common narrowing, not aggressive leaf picking
4. treat `ref.as_non_null(local.get ...)` as special
5. do not pretend `ref.cast` is directly in scope here
6. keep dead-code / non-concrete traffic from widening the result spuriously
7. preserve dominance-sensitive rewriting around named blocks and catches
8. allow copy-local insertion when a uniform type change is unsafe

## Sources

- [`../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`](../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
