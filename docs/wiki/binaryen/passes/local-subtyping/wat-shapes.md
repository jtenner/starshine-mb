---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
---

# `local-subtyping` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `local-subtyping` pass.

## Read this page with the corrected mental model

Binaryen asks:

- which reference-typed body locals are assigned values narrower than their declarations?
- what is the best common type of those assignments?
- can all relevant gets safely use a non-null declaration?
- after changing the declaration, which gets and tees need retagging?
- does refinalization expose another refinement round?

The examples below are conceptual. They show the important local declaration and expression-type behavior, not exact pretty-printer output.

## Shape 1: assigned values narrow a wide local

Before:

```wat
(local $x anyref)
(local.set $x
  (struct.new $A ...))
(drop (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $A))
(local.set $x
  (struct.new $A ...))
(drop (local.get $x))
```

Why it rewrites:

- `$x` is reference-typed;
- assigned values prove a narrower common type;
- the declaration and safe get type can be retagged.

## Shape 2: sibling writes narrow only to a common parent

Before:

```wat
(local $x anyref)
(if
  (then (local.set $x (struct.new $Left ...)))
  (else (local.set $x (struct.new $Right ...))))
(drop (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $Parent))
```

Why it rewrites that way:

- Binaryen computes a LUB;
- it does not pick `$Left` or `$Right` arbitrarily;
- the best common parent can still be narrower than `anyref`.

## Shape 3: `local.tee` is an assignment and a typed expression

Before:

```wat
(local $x anyref)
(drop
  (local.tee $x
    (struct.new $A ...)))
```

After, conceptually:

```wat
(local $x (ref null $A))
(drop
  (local.tee $x
    (struct.new $A ...)))
```

Why it matters:

- the tee contributes assigned-value evidence;
- the tee expression type must also be repaired after declaration narrowing.

## Shape 4: non-null narrowing needs dominated gets

Before:

```wat
(local $x (ref null $A))
(local.set $x
  (struct.new $A ...))
(drop (local.get $x))
```

Possible after, when all relevant gets are dominated:

```wat
(local $x (ref $A))
(local.set $x
  (struct.new $A ...))
(drop (local.get $x))
```

Why it rewrites:

- the assigned value is non-null;
- the relevant get cannot observe the original null/default state;
- Binaryen keeps the non-null declaration and retags the get.

## Shape 5: an undominated get keeps nullability

Before:

```wat
(local $x (ref null $A))
(drop (local.get $x)) ;; may happen before a non-null assignment
(local.set $x
  (struct.new $A ...))
```

After, conceptually:

```wat
(local $x (ref null $A))
```

Why it does not become non-null:

- some get can observe the older nullable state;
- structural dominance fails;
- Binaryen falls back to a nullable declaration and preserves nullable get typing.

## Shape 6: gets matter, but they do not choose the LUB

Before and after may stay the same in the important part:

```wat
(local $x anyref)
(call $needs_a
  (local.get $x))
```

Why this alone does not narrow:

- a consumer that wants `$A` does not prove `$x` always contains `$A`;
- assigned values drive the LUB;
- gets are used for dominance and repair once a candidate exists.

## Shape 7: repeated refinement after refinalization

Before, conceptually:

```wat
(local $a anyref)
(local $b anyref)
(local.set $a (struct.new $A ...))
(local.set $b (local.get $a))
(drop (local.get $b))
```

After, conceptually:

```wat
(local $a (ref null $A))
(local $b (ref null $A))
```

Why iteration matters:

- narrowing `$a` can make the type assigned to `$b` more precise;
- Binaryen refinalizes and reruns until stable;
- a single declaration-only pass may miss this family.

## Shape 8: parameters are preserved

Before and after stay unchanged in the signature:

```wat
(func $f (param $p anyref)
  (drop (local.get $p)))
```

Why:

- the scanner can see params today;
- the rewrite loop starts at the body-local base;
- the function ABI remains unchanged.

## Shape 9: non-reference and tuple/nondefaultable locals are preserved

Before and after stay unchanged in the important part:

```wat
(local $pair (tuple i32 i64))
```

Why:

- the pass is about reference local declarations;
- nondefaultable or tuple-like shapes are not forced through the rewrite;
- the official lit surface includes preservation coverage for this boundary.

## Shape 10: neighborhood shapes matter

`local-subtyping` is not an isolated cleanup.

Useful combined shapes include:

```wat
;; optimize-casts may expose a cleaner assignment first
(local.set $x (ref.cast (ref null $A) ...))

;; coalesce-locals benefits after local-subtyping creates exact-equal local types
(local.set $y (local.get $x))

;; local-cse and simplify-locals later consume cleaner local traffic
(drop (local.get $y))
```

The important scheduler lesson:

`optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`

## What a future Starshine port must preserve

If Starshine ports `local-subtyping`, the reduced shape tests should cover:

1. body-local reference narrowing from assigned values;
2. sibling assignments that choose a common parent LUB;
3. `local.tee` assignment plus expression retagging;
4. dominated non-null positives;
5. undominated nullable fallbacks;
6. gets not acting as standalone LUB evidence;
7. repeated refinement after refinalization;
8. parameter preservation;
9. non-reference and tuple/nondefaultable preservation;
10. interaction tests with `optimize-casts`, `coalesce-locals`, and `local-cse`.

## Sources

- [`../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen current-main pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalSubtyping.cpp>
- Binaryen current-main lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-subtyping.wast>
