---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
---

# Cast insertion, exactness, and boundaries in `gufa-cast-all`

## Why this page exists

The easiest beginner mistake is saying:

- “`gufa-cast-all` just makes GUFA more aggressive.”

That is not precise enough.
The real teaching question is:

- **when does Binaryen insert a brand-new cast, and when does it still refuse?**

## The short answer

`gufa-cast-all` inserts a new `ref.cast` only after plain GUFA has already run and only when the oracle knows a narrower castable reference type than the expression's current static type.

That new cast is still filtered by:

- castability
- legality
- exactness support
- emitability / feature limits

So the pass is **not** “cast everything to the narrowest inferred type.”

## Why Binaryen needs a separate sibling at all

Plain GUFA can know more than it can directly encode with simple replacement.
For example:

- it may know a value always belongs to one subtype cone,
- but it may not have one exact replacement expression to substitute.

`gufa-cast-all` is the sibling that turns some of that extra knowledge into explicit IR using `ref.cast`.

That is why this is a separate public pass instead of an invisible detail inside plain `gufa`.

## The core positive pattern

Conceptually, before:

```wat
(local.get $x) ;; broad static type
```

The oracle may know that `$x`'s possible contents are always inside a narrower subtype cone.
Then `gufa-cast-all` can produce, conceptually:

```wat
(ref.cast (ref $Narrower)
  (local.get $x)
)
```

Teaching point:

- the cast expresses preexisting proof,
- it does not create the proof.

## Why exactness is tricky

The reviewed GUFA-family sources and the dedicated `gufa-cast-all.wast` file show that exactness is feature-sensitive.
When custom descriptors are unavailable, Binaryen may need to relax an exact inferred target to a non-exact one.

So a better beginner rule is:

- **insert the narrowest valid cast**, not
- **always insert the narrowest mathematically known cast**.

## Important distinction: refine old cast vs insert new cast

Two nearby rewrite families are easy to blur together.

### Existing-cast refinement

Plain shared GUFA logic can already sharpen a cast that is already present.

### New-cast insertion

`gufa-cast-all` adds a second family:

- there was no cast here before,
- but the oracle now justifies making one explicit.

This dossier exists largely to keep those two families separate in future teaching and porting work.

## Preserved no-op cases matter

The dedicated lit file is important not only for its positive examples, but also for the no-op cases it preserves.
Those preserved cases teach that some expressions remain untouched even when the oracle appears to know more.

That can happen because:

- the expression is not a legal cast target,
- exactness cannot be represented under the active feature set,
- the inferred type is not a valid improvement to materialize this way,
- or the family simply keeps a conservative boundary on what it will rewrite.

Those no-op cases are part of the public contract.

## Why this is not the cleanup-owning sibling

If `gufa-cast-all` adds a new cast and that cast later makes more simplifications possible, that later cleanup does not belong to this pass itself.
`gufa-cast-all` still keeps `optimizing = false`.
So it does **not** own the changed-functions-only nested `dce` + `vacuum` rerun that `gufa-optimizing` owns.

That means future ports should not silently merge these siblings just because both are “more visible” than plain `gufa`.

## Future-port checklist for this exact surface

Keep these rules explicit:

1. shared `ContentOracle` analysis first
2. shared plain-GUFA rewrites first
3. `ReFinalize()` before new-cast insertion
4. only insert casts for valid castable reference-typed sites
5. preserve feature-sensitive exactness downgrades
6. keep preserved no-op cases preserved
7. do not silently add `gufa-optimizing`'s cleanup rerun here

## One-sentence memory aid

If you only remember one sentence, remember this:

- `gufa-cast-all` is the GUFA sibling that turns proven narrower reference cones into explicit `ref.cast` instructions when Binaryen can express them legally.
