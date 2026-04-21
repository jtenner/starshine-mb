---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `pick-load-signs` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `pick-load-signs` pass.

## Read this page with one mental model

Binaryen `pick-load-signs` is trying to prove:

- this local was written by an exact narrow load,
- and every later read is immediately used in a specific sign- or zero-extension pattern,
- so it is cheaper to change the load opcode than to keep re-extending or masking the loaded value.

If any use does not fit that story, the pass keeps the original load.

## Quick glossary

- **candidate producer**: an exact non-tee `local.set(load ...)`
- **recognized use**: a `local.get` used in one of the allowed sign/zero-extension shapes
- **unknown use**: any other use, which blocks the rewrite
- **signed evidence**: a use that proves sign extension is wanted
- **unsigned evidence**: a use that proves zero extension is wanted

## Positive family 1: direct sign extension

Before:

```wat
(local.set $x
  (i32.load8_u
    (i32.const 0)))
(drop
  (i32.extend8_s
    (local.get $x)))
```

After:

```wat
(local.set $x
  (i32.load8_s
    (i32.const 0)))
(drop
  (i32.extend8_s
    (local.get $x)))
```

Important nuance:

- `pick-load-signs` itself only flips the load opcode
- a later pass may remove the now-redundant extend

## Positive family 2: direct zero-extension mask

Before:

```wat
(local.set $x
  (i32.load8_s
    (i32.const 0)))
(drop
  (i32.and
    (local.get $x)
    (i32.const 255)))
```

After:

```wat
(local.set $x
  (i32.load8_u
    (i32.const 0)))
(drop
  (i32.and
    (local.get $x)
    (i32.const 255)))
```

The key rule is:

- the mask must be a low-bit mask like `255`, `65535`, and so on

## Positive family 3: signed shift pair

Before:

```wat
(local.set $x
  (i32.load16_u
    (i32.const 0)))
(drop
  (i32.shr_s
    (i32.shl
      (local.get $x)
      (i32.const 16))
    (i32.const 16)))
```

After, conceptually:

```wat
(local.set $x
  (i32.load16_s
    (i32.const 0)))
...
```

This is why the pass inspects both parent and grandparent context:

- `local.get` is the child of `i32.shl`
- the actual signed-extension meaning appears at the `i32.shr_s` grandparent

## Positive family 4: unsigned shift pair

Before:

```wat
(local.set $x
  (i32.load16_s
    (i32.const 0)))
(drop
  (i32.shr_u
    (i32.shl
      (local.get $x)
      (i32.const 16))
    (i32.const 16)))
```

After, conceptually:

```wat
(local.set $x
  (i32.load16_u
    (i32.const 0)))
...
```

Again, the pass is not proving this with general dataflow.
It is matching one exact parent/grandparent tree family.

## Positive family 5: multiple same-width producers for one local

Before:

```wat
(local.set $x (i32.load8_u (i32.const 0)))
(drop (i32.extend8_s (local.get $x)))
(local.set $x (i32.load8_u (i32.const 4)))
(drop (i32.extend8_s (local.get $x)))
```

After, conceptually:

- both `i32.load8_u` producers can flip to `i32.load8_s`

The evidence is collected per local, so same-width candidate loads feeding the same local can move together.

## Decision-shape note: signed wins ties

If the evidence is split, Binaryen weights the signed side more heavily.

Beginner reason:

- a signed shift-pair can remove two instructions
- so one signed use can compete with two unsigned uses

This is not a dominance proof.
It is a tiny cost heuristic.

## Negative family 1: `local.tee` producer

Before:

```wat
(drop
  (i32.extend8_s
    (local.tee $x
      (i32.load8_u
        (i32.const 0)))))
```

Why this blocks the pass:

- upstream `visitLocalSet(...)` explicitly skips tees
- only plain `local.set(load ...)` producers are candidates

## Negative family 2: unknown use blocks everything

Before:

```wat
(local.set $x
  (i32.load8_u
    (i32.const 0)))
(drop
  (i32.eq
    (local.get $x)
    (i32.const 1)))
```

Why this blocks the pass:

- `i32.eq` is not one of the recognized sign/zero-extension shapes
- the use counts toward `totalUsages`
- but it contributes no signed or unsigned evidence
- so the candidate is rejected

## Negative family 3: official `br_if` value-use bailout

This is the dedicated upstream negative test.

Before:

```wat
(block $label (result i32)
  (local.set $temp
    (i32.load8_u
      (i32.const 22)))
  (drop
    (i32.extend8_s
      (br_if $label
        (local.get $temp)
        (i32.const 1))))
  (unreachable))
```

Why this blocks the pass:

- the `local.get` is being used as the value carried by `br_if`
- that use is not a recognized sign/zero-extension shape
- wrapping the `br_if` inside `i32.extend8_s` does not rescue it

This is one of the clearest examples of what the pass really means by “based on their uses.”

## Negative family 4: mixed-width evidence

Before:

```wat
(local.set $x
  (i32.load8_u
    (i32.const 0)))
(drop
  (i32.extend8_s
    (local.get $x)))
(drop
  (i32.extend16_s
    (local.get $x)))
```

Why this blocks the pass:

- the same sign family appears with conflicting widths
- Binaryen intentionally poisons that width record and rejects the rewrite

## Negative family 5: width mismatch with the load

Before:

```wat
(local.set $x
  (i32.load16_u
    (i32.const 0)))
(drop
  (i32.extend8_s
    (local.get $x)))
```

Why this blocks the pass:

- the recognized sign-extension width is `8`
- the load width is `16`
- so changing the load would not preserve the intended meaning

## Negative family 6: atomic loads

Conceptually:

```wat
(local.set $x
  (i32.atomic.load8_u ...))
(drop
  (i32.extend8_s
    (local.get $x)))
```

Why this blocks the pass:

- upstream explicitly skips atomic loads
- the pass treats them as always unsigned here

## Negative family 7: dead local with no informative uses

Before:

```wat
(local.set $x
  (i32.load8_u
    (i32.const 0)))
```

Why this blocks the pass:

- `totalUsages == 0`
- Binaryen has no evidence for what signedness would be better

This pass is not trying to guess.

## Negative family 8: i64 lookalikes are not upstream `pick-load-signs` shapes

A beginner might expect this to be in scope:

```wat
(local.set $x
  (i64.load8_u
    (i32.const 0)))
(drop
  (i64.extend8_s
    (local.get $x)))
```

But in upstream `version_129`, this is **not** really a `pick-load-signs` recognition family.

Why:

- the pass delegates recognition to `Properties::getSignExt*` and `getZeroExt*`
- those helpers here only recognize i32 forms

Important nuance:

- Binaryen still has broader i64 sign-extension cleanup elsewhere
- the official neighboring home for that is mainly `optimize-instructions`, not `pick-load-signs`

## Negative family 9: mixed-width producers for one local are not all guaranteed to flip together

If one local is written by both:

- a load8 candidate
- and a load16 candidate

then the usage evidence is shared per local, but the final width check is still per load.

So the right mental model is:

- same local means shared evidence
- not guaranteed shared rewrite outcome

## What this pass does **not** mean

These are useful non-goals to keep explicit:

- generic integer dataflow simplification
- generic all-width load canonicalization
- proof through arbitrary arithmetic or CFG merges
- partial rewrites when some uses are known and others are not
- i64 sign-extension cleanup in upstream `version_129` `pick-load-signs`

## Scheduler interaction to remember

`pick-load-signs` is intentionally tiny.
It sits before `precompute` and can rerun after inlining-related optimization helpers.

So its job is not to solve the whole sign-extension story by itself.
Its job is to make one cheap local opcode choice so that nearby passes can do better cleanup afterward.
