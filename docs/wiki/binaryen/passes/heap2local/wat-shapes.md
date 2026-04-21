---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./validation-fixups-and-special-cases.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `heap2local` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `heap2local` pass.

## Read this page with one mental model

Binaryen `heap2local` is trying to prove:

- this allocation never escapes the function
- and nobody can confuse it with some other possible value

If both are true, the pass can replace the object's fields with locals.
If either is false, the pass keeps the original heap traffic.

## Quick glossary

- **exclusive use**: every reachable use is definitely using the same allocation and not some competing value
- **escape**: the allocation can be observed outside the function or through some operation whose identity consequences the pass cannot model safely
- **flow-through**: the allocation value continues outward through a wrapper like a block or loop without mixing with another value
- **mixing**: some other possible value can reach the same use/result position, so the allocation is no longer exclusive there

## Positive family 1: direct struct owner in a local

Before:

```wat
(local.set $ref
  (struct.new_default $pair))
(struct.get $pair 0
  (local.get $ref))
```

After, conceptually:

```wat
(local.set $field0 (i32.const 0))
(local.set $field1 (i32.const 0))
(local.get $field0)
```

This is the basic happy path.

## Positive family 2: exclusive local-copy chains

Before:

```wat
(local.set $a (struct.new_default $pair))
(local.set $b (local.get $a))
(struct.get $pair 1
  (local.get $b))
```

Why this still works:

- both locals still carry the same exact allocation
- there is no competing write that could make the later get ambiguous

## Positive family 3: direct `local.tee` owner

Before:

```wat
(struct.get $pair 0
  (local.tee $ref
    (struct.new_default $pair)))
```

After, conceptually:

- initialize field locals
- drop the dead reference flow
- read from the field local directly

`local.tee` is okay when the value still stays exclusive.

## Positive family 4: safe flow through block or loop results

Binaryen allows some control-flow wrappers as long as the allocation remains the sole value flowing onward.

Example shape:

```wat
(struct.get $pair 1
  (block (result (ref null $pair))
    ...
    (local.get $ref)))
```

The key rule is not “block is always okay.”
The key rule is:

- block or loop flow is okay when the allocation is the only value that can reach that result position

## Positive family 5: sole branch-to-block value with no fallthrough competitor

This is more subtle.
A branch carrying the allocation to a block can still be okay when:

- that branch is the only branch carrying a value to the block
- and there is no competing final fallthrough value

That is one of the clearest examples of the pass's exclusivity reasoning.

## Negative family 1: call escape

Before:

```wat
(call $use-ref
  (local.get $ref))
```

Why this blocks the pass:

- the reference escapes into a call
- Binaryen can no longer pretend object identity is irrelevant

## Negative family 2: function-result escape

Before:

```wat
(return
  (local.get $ref))
```

or simply the allocation flowing out as the function body value.

Why this blocks the pass:

- the caller could observe the reference identity

## Negative family 3: mixed local provenance

Before:

```wat
(if (local.get $cond)
  (then
    (local.set $ref (ref.null $pair))))
(struct.get $pair 0
  (local.get $ref))
```

Why this blocks the pass:

- the later `local.get` might read either the optimized allocation or some other value
- the use is no longer exclusive

## Negative family 4: `select` / if-else value mixing

Before:

```wat
(local.set $ref
  (select
    (struct.new_default $pair)
    (ref.null $pair)
    (local.get $cond)))
```

Why this blocks the pass:

- even if one arm is the optimized allocation, the overall result mixes multiple possible values

## Negative family 5: branch mixing at a target block

A branch carrying the allocation is **not** enough by itself.
If the same target block can also receive:

- another branch-carried value
- or a competing fallthrough value

then the allocation is no longer exclusive there, so Binaryen gives up.

## Positive family 6: `ref.as_non_null` on the optimized allocation

Before:

```wat
(struct.get $pair 0
  (ref.as_non_null
    (local.get $ref)))
```

After, conceptually:

```wat
(local.get $field0)
```

Why this works:

- the pass knows the allocation is a fresh non-null object
- the `ref.as_non_null` cannot fail and does not need to remain

## Positive family 7: exact `ref.eq` / `ref.is_null` / `ref.test` / `ref.cast`

Important direct-ref families include:

- `ref.is_null allocation` -> always false
- `ref.eq allocation (ref.null ...)` -> always false
- `ref.eq allocation allocation` -> true when both sides are the same optimized flow
- `ref.test` -> static subtype answer
- `ref.cast` -> either disappears or becomes explicit `unreachable`

These are not separate passes here.
They are part of `heap2local`'s own rewrite surface.

## Positive family 8: descriptor-bearing struct allocations

Source-visible special family:

```wat
(ref.get_desc $node
  (struct.new_default_desc $node ...))
```

Binaryen can store the descriptor in its own local and later replace the `ref.get_desc` with that saved descriptor value.

Important honesty note:

- this family is much clearer in the source than in the dedicated `version_129` lit file

## Positive family 9: small fixed-size arrays

Before:

```wat
(local.set $arr
  (array.new_default $array
    (i32.const 3)))
(array.set $array
  (local.get $arr)
  (i32.const 1)
  (i32.const 9))
(array.get $array
  (local.get $arr)
  (i32.const 1))
```

After, conceptually:

```wat
(local.set $slot0 (i32.const 0))
(local.set $slot1 (i32.const 0))
(local.set $slot2 (i32.const 0))
(local.set $slot1 (i32.const 9))
(local.get $slot1)
```

The crucial rule is:

- Binaryen is only doing this for small, fixed, struct-like arrays

## Negative family 6: nonconstant array size

Before:

```wat
(array.new $array
  (i32.const 42)
  (local.get $n))
```

Why this blocks the pass:

- the array is no longer a fixed struct-like shape

## Negative family 7: nonconstant array index

Before:

```wat
(array.get $array
  (local.get $arr)
  (local.get $i))
```

Why this blocks the main array optimization path:

- Binaryen cannot map that access to one known synthetic field slot safely

Important freshness note:

- current `main` is a little more precise about which operand positions need that const-index barrier
- but the beginner rule for `version_129` remains: dynamic indexing is a bailout for the main accessed-array path

## Negative family 8: arrays of size `>= 20`

Before:

```wat
(array.new $array
  (call $get-init)
  (i32.const 20))
```

Why this blocks the pass:

- Binaryen intentionally caps the scalarized size below `20`

## Positive family 10: out-of-bounds array access becomes explicit trap

This is a subtle but important one.
If Binaryen has already converted a fixed array to synthetic struct form and later sees a constant out-of-bounds access, it can rewrite that access into:

- preserved side effects
- followed by explicit `unreachable`

So OOB is not merely “bail out and keep the array.”
Once the synthetic-struct conversion has happened, some OOB cases become explicit trap rewrites.

## Positive family 11: packed field and packed array reads

Packed access is still valid after scalarization.
Binaryen preserves:

- zero-extension for unsigned reads
- sign-extension for signed reads

So a packed `struct.get_u`, `struct.get_s`, `array.get_u`, or `array.get_s` does not simply become a plain local.get with no extra work.

## Positive family 12: atomic object traffic on nonescaping objects

The dedicated lit surface shows that Binaryen can still optimize some shared struct/array atomic get/set families when the object never escapes.

The key reasoning is:

- no other thread can observe or synchronize through that nonescaping object identity

This is a non-obvious but important part of the real pass surface.

## Source-visible special family: RMW and cmpxchg

`Heap2Local.cpp` also handles:

- `struct.rmw`
- `struct.cmpxchg`
- `array.rmw`
- `array.cmpxchg`

These families are easier to see in the source than in the dedicated lit file.
So the safest mental model is:

- they are part of the source-level contract even if they are not the first examples most people encounter

## Positive family 13: nested allocations only one layer at a time

Example idea:

```wat
(struct.new $outer
  (struct.new_default $inner))
```

If optimizing the outer allocation would expose the inner one as newly nonescaping, Binaryen still does not iterate to a fixpoint inside one invocation.

Important lesson:

- `heap2local` is intentionally single-iteration
- later cleanup plus later reruns are expected to do more work

## Positive family 14: EH `pop` shapes are repaired after rewrite

The dedicated lit surface includes `pop` examples because `heap2local` can create new blocks while scalarizing.
Those blocks may invalidate nested-pop structure until `EHUtils::handleBlockNestedPops(...)` repairs it.

Beginner lesson:

- the pass's shape story includes EH fixup, not just field-local rewrites

## What this pass does **not** mean

These are useful non-goals to keep explicit:

- generic whole-program escape analysis
- generic stack allocation for all GC objects
- arbitrary dynamic-array optimization
- full fixpoint nested allocation cleanup in one invocation
- ignoring packed/atomic/cast/nullability corner cases just because the happy path is easy to describe

## Scheduler interaction to remember

`heap2local` does not try to be the entire GC/local cleanup story by itself.
It is placed before:

- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

because those later passes are expected to profit from the scalarized traffic it exposes.
