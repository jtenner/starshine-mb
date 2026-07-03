---
kind: concept
status: supported
last_reviewed: 2026-07-03
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

## Shape 3a: non-null `local.tee` assignments can validate as non-null

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(drop (local.tee $x (local.get $p)))
```

Possible after:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the `local.tee` is assignment evidence and also an expression use;
- local Binaryen v130 narrows this shape to a non-null child declaration;
- Starshine's representation does not yet expose a broad explicit retagging pass, but the focused optimized module validates after the declaration change.

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

## Shape 6: branch-free blocks can preserve domination

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(block
  (drop (local.get $x)))
```

Possible after, when the block has no direct branch/return/throw flow:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the assignment is non-null and dominates entry to the block;
- the block body is branch-free in the current Starshine subset;
- a get inside the block cannot observe the original nullable default.

## Shape 6a: branch-free block writes can dominate later outer gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p)))
(drop (local.get $x))
```

Possible after, when the block has no direct branch/return/throw flow:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows this shape under `--local-subtyping`;
- a branch-free block runs its write before the following outer get;
- Starshine now propagates initialized state out of branch-free blocks, while still keeping direct branch/return, throw, and `try_table` post-state flow conservative.

## Shape 6b: branch flow blocks non-null block post-state propagation

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p))
  (br 0))
(drop (local.get $x))
```

After, from local Binaryen v130 evidence:

```wat
(local $x (ref null $A))
```

Why it stays nullable:

- the assigned heap type still narrows from `$Parent` to `$A`;
- local Binaryen v130 does not use this branch-flow block post-state to prove non-nullability;
- Starshine keeps the same nullable fallback by bailing out of the non-null dominance scan on unconditional `br`, `br_table`, direct return/post-state, throw, and `try_table` flow.

## Shape 6c: `br_if` paths that can skip a write stay nullable

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block $exit
  (br_if $exit (i32.const 1))
  (local.set $x (local.get $p)))
(drop (local.get $x))
```

After, from local Binaryen v130 evidence:

```wat
(local $x (ref null $A))
```

Why it stays nullable:

- the true branch exits the block before the write, so the later outer get can still observe the default null;
- Starshine now treats `br_if` as a conditional-flow barrier for subsequent write initialization, rather than a full-function bailout, so earlier dominated gets can still narrow while branch-skipped writes do not prove non-null post-state.

## Shape 6d: conditional `return` paths can skip later dominance paths

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(if (i32.const 0)
  (then (return)))
(local.set $x (local.get $p))
(drop (local.get $x))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the returning branch cannot reach the later write or get;
- every path that reaches the later get has executed the non-null write;
- Starshine now treats `return` inside copied `if` arms as a path skip for this dominance proof, while keeping direct return/post-state cases conservative.

## Shape 6e: direct block `return` flow is a Starshine validator boundary

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p))
  (return))
(drop (local.get $x))
```

Binaryen v130 narrows this direct-return shape to non-null child and the Binaryen output validates with `wasm-tools`, but current Starshine keeps the local nullable:

```wat
(local $x (ref null $A))
```

Why Starshine stays nullable for now:

- the later get is syntactically after a direct `return`, so Binaryen can rely on unreachable-path reasoning;
- Starshine's current validation pass does not yet prove that unreachable post-return `local.get` uses of non-defaultable locals are initialized;
- this is a precise representation/tooling blocker, not an accepted semantic win: reopen when Starshine validation models Binaryen's unreachable non-defaultable-local proof or when the LS pass can safely repair/avoid those unreachable gets.

## Shape 7: loop bodies can preserve entry domination

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(loop
  (drop (local.get $x)))
```

Possible after, when the loop body has no direct branch/return/throw flow or only a tail `br_if` backedge after the dominated get:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the assignment is non-null and dominates the first loop entry;
- local Binaryen v130 narrows a loop whose body reads the local and then reaches a tail `br_if 0` backedge;
- Starshine admits that narrow backedge subset by preserving entry initialization for gets before the `br_if`, while refusing to let writes after a `br_if` prove non-null post-state;
- writes inside the loop are not propagated to later outer gets; a local Binaryen v130 probe for a branch-free loop write followed by an outside get kept the declaration nullable child, so Starshine keeps that source-backed fallback.

## Shape 8: branch-free `if` arms can preserve entry domination

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(if (i32.const 1)
  (then (drop (local.get $x)))
  (else (drop (local.get $x))))
```

Possible after, when the `if` arms have no direct branch/throw flow except the conditional-return skip subset:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the assignment is non-null and dominates entry to the `if`;
- each arm is scanned with a copy of the pre-`if` initialized state;
- current Starshine does not propagate writes inside either arm to later outer gets.

## Shape 8a: all-arm `if` writes do not currently prove non-null post-state

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(if (i32.const 1)
  (then (local.set $x (local.get $p)))
  (else (local.set $x (local.get $p))))
(drop (local.get $x))
```

After, from local Binaryen v130 evidence:

```wat
(local $x (ref null $A))
```

Why it stays nullable:

- the write-site LUB still narrows the heap from `$Parent` to `$A`;
- local Binaryen v130 keeps nullability for this post-`if` outside get even when both arms write;
- Starshine intentionally scans each arm with copied entry state and does not merge arm writes outward.

## Shape 9: dominated branch-free blocks can contain branch-free `if` arms

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(block
  (if (i32.const 1)
    (then (drop (local.get $x)))
    (else (drop (local.get $x)))))
```

Possible after, when no direct branch/return/throw flow is present:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the assignment dominates entry to both the block and the nested `if`;
- each nested `if` arm is scanned with a copy of the block-entry state;
- writes inside the nested `if` still do not propagate to later outer gets in the current Starshine subset;
- plain branch-free block writes do propagate to later outer gets as in Shape 6a.

## Shape 10: gets matter, but they do not choose the LUB

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

## Shape 11: repeated refinement after refinalization

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

## Shape 12: parameters are preserved

Before and after stay unchanged in the signature:

```wat
(func $f (param $p (ref null $Parent))
  (local.set $p
    (ref.as_non_null (ref.null $A)))
  (drop (local.get $p)))
```

After, from local Binaryen v130 evidence:

```wat
(func $f (param $p (ref null $Parent))
  ...)
```

Why:

- local Binaryen v130 keeps the parameter at its declared signature type even after a non-null child write;
- Starshine only rewrites body-local declarations;
- preserving params avoids changing the function ABI and matches the source-backed boundary.

## Shape 13: non-reference and tuple/nondefaultable locals are preserved

Before and after stay unchanged in the important part:

```wat
(local $pair (tuple i32 i64))
```

Why:

- the pass is about reference local declarations;
- nondefaultable or tuple-like shapes are not forced through the rewrite;
- the official lit surface includes preservation coverage for this boundary.

## Shape 14: neighborhood shapes matter

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

## What the current Starshine slice still needs

Starshine currently covers the basic write-site narrowing shapes, but it does not yet cover the full Binaryen contract. If the active slice grows toward parity, the reduced shape tests should cover:

1. body-local reference narrowing from assigned values;
2. sibling assignments that choose a common parent LUB;
3. `local.tee` assignment plus expression retagging;
4. dominated non-null positives, including the current branch-free `block`, branch-free `loop`, loop tail-`br_if`, nested branch-free block-`if`, and root-`if` subsets;
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
