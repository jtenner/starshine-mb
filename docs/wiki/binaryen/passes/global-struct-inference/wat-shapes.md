---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-analysis-and-unnesting.md
  - ./starshine-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `global-struct-inference` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `global-struct-inference` pass. It is backed by the primary-source manifest in [`../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md`](../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md) and the 2026-05-06 current-main recheck in [`../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md), and should be read with the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## Read this page with one mental model

Binaryen `gsi` is trying to prove:

- this read can only come from one or two immutable global-created instances that I understand well enough to substitute.

If that proof fails, the pass leaves the read alone.

## Quick glossary

- **candidate global**: an immutable global whose top-level initializer is a trusted `struct.new` source for this pass
- **poisoned type**: a type Binaryen no longer trusts because allocation happened in a function or nested global position
- **singleton group**: among two unique values, the one associated with exactly one global, so a single `ref.eq` can distinguish it
- **un-nesting**: splitting a non-constant nested field operand out into its own immutable global

## Positive family 1: open-world direct immutable-global read

Before:

```wat
(global $g (ref $S)
  (struct.new $S
    (i32.const 7)))
(func (result i32)
  (struct.get $S 0
    (global.get $g)))
```

After, conceptually:

```wat
(func (result i32)
  (block (result i32)
    (drop
      (ref.as_non_null
        (global.get $g)))
    (i32.const 7)))
```

Why this matters:

- this optimization does **not** need closed world
- the exact immutable global source is already visible at the read site
- the null trap is preserved with `ref.as_non_null`

## Positive family 2: one candidate global in closed world

Before:

```wat
(global $g (ref $S)
  (struct.new $S
    (global.get $imported-i32)))
(func (param $x (ref null $S)) (result i32)
  (struct.get $S 0
    (local.get $x)))
```

After, conceptually:

```wat
(func (param $x (ref null $S)) (result i32)
  (struct.get $S 0
    (block (result (ref $S))
      (drop
        (ref.as_non_null
          (local.get $x)))
      (global.get $g))))
```

Why this happens:

- Binaryen proves `$x` can only be that one trusted global instance
- but the field value itself is not a literal constant
- so it rewrites the **origin**, not necessarily the final value

## Positive family 3: two unique values => `select`

Before:

```wat
(global $g1 (ref $S) (struct.new $S (i32.const 42)))
(global $g2 (ref $S) (struct.new $S (i32.const 1337)))
(func (param $x (ref null $S)) (result i32)
  (struct.get $S 0
    (local.get $x)))
```

After, conceptually:

```wat
(func (param $x (ref null $S)) (result i32)
  (select
    (i32.const 42)
    (i32.const 1337)
    (ref.eq
      (ref.as_non_null
        (local.get $x))
      (global.get $g1))))
```

Why this works:

- there are exactly two unique values
- one compare against one singleton global is enough

## Positive family 4: three globals but only two unique values

Before:

```wat
(global $g1 (ref $S) (struct.new $S (i32.const 42)))
(global $g2 (ref $S) (struct.new $S (i32.const 1337)))
(global $g3 (ref $S) (struct.new $S (i32.const 1337)))
```

Result:

- still optimizable

Why this matters:

- the pass is not limited to “two globals total”
- it is limited to two **unique values** with one singleton-tested group

## Positive family 5: many globals, one shared value

Before:

```wat
(global $g1 (ref $S) (struct.new $S (i32.const 42)))
(global $g2 (ref $S) (struct.new $S (i32.const 42)))
(global $g3 (ref $S) (struct.new $S (i32.const 42)))
```

After, conceptually:

```wat
(block (result i32)
  (drop
    (ref.as_non_null ...))
  (i32.const 42))
```

Why this matters:

- many globals are fine when they all collapse to one value
- no `select` is needed at all

## Positive family 6: subtype-origin parent read

Before:

```wat
(type $Parent (sub (struct (field i32))))
(type $Child1 (sub $Parent (struct (field i32))))
(type $Child2 (sub $Parent (struct (field i32))))
(global $g1 (ref $Child1) (struct.new $Child1 (i32.const 42)))
(global $g2 (ref $Child2) (struct.new $Child2 (i32.const 1337)))
(func (param $x (ref null $Parent)) (result i32)
  (struct.get $Parent 0
    (local.get $x)))
```

After, conceptually:

```wat
(select
  (i32.const 42)
  (i32.const 1337)
  (ref.eq
    (ref.as_non_null
      (local.get $x))
    (global.get $g1)))
```

Why this happens:

- child candidate globals propagate upward to the parent type
- the parent read is still small enough to explain with one compare

## Positive family 7: non-constant operand un-nesting

Before:

```wat
(global $g1 (ref $S)
  (struct.new $S
    (i32.add (i32.const 41) (i32.const 1))))
(global $g2 (ref $S)
  (struct.new $S
    (i32.const 1337)))
```

After, conceptually:

```wat
(global $g1.unnested.0 i32
  (i32.add (i32.const 41) (i32.const 1)))
(global $g1 (ref $S)
  (struct.new $S
    (global.get $g1.unnested.0)))
```

and the read can then use either:

- `global.get $g1.unnested.0`
- or `i32.const 1337`

inside the final select.

Why this matters:

- non-constant fields are not automatically disqualified
- Binaryen can manufacture a fresh immutable global to make the origin proof usable
- Starshine's guarded local subset currently handles small-module arithmetic operands, integer bitwise operands such as `i32.and` / `i64.xor`, and integer shift/rotate operands such as `i32.shl` / `i64.rotl`, but still avoids arbitrary expression equivalence and large-module unbounded un-nesting

## Positive family 8: immutable global-get field operands count as constant enough

Before:

```wat
(global $one i32 (i32.const 1))
(global $two i32 (i32.const 2))
(global $g1 (ref $S) (struct.new $S (global.get $one)))
(global $g2 (ref $S) (struct.new $S (global.get $two)))
```

After, conceptually:

```wat
(select
  (global.get $one)
  (global.get $two)
  (ref.eq ...))
```

Why this matters:

- `PossibleConstantValues` treats immutable `global.get`s as constant materializable values
- the pass is not limited to plain literals

## Positive family 9: packed-field signedness is preserved

Before:

```wat
(type $S (struct (field i8)))
(global $A (ref $S) (struct.new $S (i32.const 257)))
(global $B (ref $S) (struct.new $S (i32.const 258)))
(func (param $x (ref $S)) (result i32)
  (struct.get_u $S 0
    (local.get $x)))
```

After, conceptually:

```wat
(select
  (i32.and (i32.const 257) (i32.const 255))
  (i32.and (i32.const 258) (i32.const 255))
  (ref.eq ...))
```

Why this matters:

- the pass recreates the same signed/unsigned packed-load behavior
- it does not just reuse the raw stored operands blindly

## Positive family 10: atomic gets can still optimize

Before:

```wat
(type $S (shared (struct (field i32))))
(global $a (ref $S) (struct.new $S (i32.const 42)))
(global $b (ref $S) (struct.new $S (i32.const 1337)))
(func (param $x (ref $S))
  (drop
    (struct.atomic.get acqrel $S 0
      (local.get $x))))
```

After, conceptually:

- still a `select` or a constant block

Why this is safe:

- the field is immutable
- there are no writes that the atomic read could synchronize with

This is one of the easiest Binaryen rules to underestimate.

## Positive family 11: null-result refinement

Before:

```wat
(type $A (struct (field (ref null $A))))
(global $g1 (ref (exact $A)) (struct.new_default $A))
(global $g2 (ref (exact $A)) (struct.new_default $A))
(func (param $x (ref $A)) (result (ref $A))
  (block (result (ref $A))
    (ref.as_non_null
      (struct.get $A 0
        (local.get $x)))))
```

After, conceptually:

- the inner read refines to `null`
- the enclosing block and outer non-null cast are refinalized accordingly

Why this matters:

- `gsi` is a typed rewrite, not just text substitution
- refinalization is part of the pass contract

## Negative family 1: mutable field

Before:

```wat
(type $S (struct (field (mut i32))))
```

Why this blocks optimization:

- `gsi` only reasons about immutable field contents

## Negative family 2: function-local allocation poisons the type

Before:

```wat
(func
  (drop
    (struct.new $S ...)))
```

Why this blocks optimization for `$S` reads:

- values of `$S` are no longer provably restricted to trusted immutable globals

## Negative family 3: nested `struct.new` inside a global initializer poisons the nested type

Before:

```wat
(global $tuple (ref $Tuple)
  (struct.new $Tuple
    (struct.new $S ...)
    (ref.null any)))
```

Why this blocks optimization for `$S` reads:

- `$S` is created in a non-top-level global position
- the simple type-to-global candidate model is no longer trusted

## Negative family 4: more than two unique values

Before:

```wat
(global $g1 ... 42)
(global $g2 ... 1337)
(global $g3 ... 99999)
```

Why this blocks optimization:

- Binaryen refuses to synthesize larger decision trees here
- one compare is the practical limit

## Negative family 5: two equal pairs still bail

Before:

```wat
(global $g1 ... 42)
(global $g2 ... 42)
(global $g3 ... 1337)
(global $g4 ... 1337)
```

Why this blocks optimization:

- there are only two unique values
- but neither value-group is singleton
- one compare is not enough

## Negative family 6: declared `anyref` globals

Before:

```wat
(global $g1 anyref (struct.new $S ...))
(global $g2 anyref (struct.new $S ...))
```

Why this blocks optimization:

- the declared global type is too broad for the `ref.eq`-based select strategy used here

## Negative family 7: one global of too-broad declared type still does not help

Before:

```wat
(global $g anyref (struct.new $S ...))
(func (param $x (ref null $S))
  (struct.get $S 0
    (local.get $x)))
```

Why this still blocks optimization:

- even the one-global case would need a cast back to a struct type
- Binaryen deliberately leaves that to other passes instead of doing it here

## Negative family 8: poisoned subtype poisons the parent read

Before:

```wat
(type $Parent ...)
(type $Child ...)
(func
  (drop
    (struct.new $Child ...)))
(func (param $x (ref null $Parent))
  (struct.get $Parent 0
    (local.get $x)))
```

Why this blocks optimization:

- a parent read could still observe the poisoned child values
- unoptimizability spreads upward

## Negative family 9: not arbitrary expression equivalence

Before:

```wat
(global $g1 (ref $S)
  (struct.new $S
    (i32.add (i32.const 41) (i32.const 1))))
(global $g2 (ref $S)
  (struct.new $S
    (i32.add (i32.const 41) (i32.const 1))))
```

Why this does **not** automatically become a grouped same-value constant case:

- `gsi` is not doing deep symbolic equivalence over non-constant expression trees
- at that stage they are still non-constant values

## Negative family 10: not a generic devirtualizing whole-program field analysis

Before:

```wat
(func (param $x (ref null $S))
  ;; many control-flow and local-flow facts suggest what $x probably is
  (struct.get $S 0
    (local.get $x)))
```

Why this often stays unchanged:

- `gsi` only uses its narrow trusted-global-origin machinery
- it is not a general dataflow or probabilistic reasoning pass

## What this pass does **not** mean

These are useful non-goals to keep explicit:

- generic object escape analysis
- arbitrary many-way dispatch on many candidate globals
- mutable-field propagation
- deep equivalence over non-constant field expressions
- “closed world means all parent reads optimize”
- “atomic gets are always off limits”

## Scheduler interaction to remember

In the repo's canonical no-DWARF open-world path, `gsi` sits after:

- `global-refining`
- second `remove-unused-module-elements`

That is not accidental.
Those earlier module passes make the global-origin picture smaller and more precise before `gsi` tries to exploit it.

## Local Starshine shape caveat

Current Starshine implements only a subset of this catalog:

- open-world direct `global.get` + `struct.get*` pairs
- top-level immutable `struct.new*`, default, and descriptor-constructor globals
- simple materializable field values plus local packed-field repair
- nullable-global and nullable-local trap preservation with `ref.as_non_null` + `drop`
- narrow closed-world exact and subtype-propagated single-candidate local/param origin rewrites, guarded so broad `eqref` global declarations do not produce invalid replacements
- exact and subtype-propagated multi-candidate local/param one-value folds when all safe direct candidates expose the same materializable field value
- exact and subtype-propagated multi-candidate local/param two-value `select(ref.eq(...))` rewrites when exactly two materializable values exist and one value group has a singleton candidate global

It now implements subtype-propagated parent origin rewrites, one-value folds, singleton-tested two-value selects, small-module arithmetic/bitwise/shift-rotate fresh-global un-nesting, and direct/closed-world `ref.get_desc` folds/selects. It still does **not** implement the sibling descriptor-cast pass or atomic-get coverage because Starshine has no in-tree struct atomic-get instruction form yet; large modules also keep the materializable-only GSI subset to preserve pass-local artifact budget. Keep that distinction visible when adding examples or parity claims.
