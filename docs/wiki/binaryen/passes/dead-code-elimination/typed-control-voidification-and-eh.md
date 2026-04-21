---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# `dead-code-elimination`: typed-control voidification, type repair, and EH cleanup

This page exists because the easiest wrong summary of DCE is:

- “it deletes dead code”

The real non-obvious behavior is often:

- “it keeps the control structure, removes the dead **result**, and then repairs the function”

## Why DCE does not just delete typed control

Consider a value-typed control wrapper whose result is immediately dropped:

```wat
(drop
  (block (result i32)
    (call $side)
    (i32.const 1)))
```

If that block still matters structurally, DCE cannot always erase it outright.
It may need to keep the sequencing and control shape but remove the now-pointless result type.

That is the core idea behind **voidification**.

## The basic voidification mental model

Before:

```wat
(drop
  (if (result i32)
    COND
    (then THEN-VALUE)
    (else ELSE-VALUE)))
```

After, conceptually:

```wat
(if
  COND
  (then THEN-EFFECTS-ONLY)
  (else ELSE-EFFECTS-ONLY))
```

or:

```wat
(block
  SIDE-EFFECTS-ONLY)
```

The exact rewritten shape depends on the original structure.
But the key point is the same:

- the result disappears
- the still-observable control/effect behavior stays

## Which control structures this affects

Binaryen's DCE source and test surface make this relevant for:

- `block`
- `if`
- `loop`
- `try`
- `try_table`

That does **not** mean every one of those nodes is always freely voidifiable.
The pass only does it when the surrounding branch and effect conditions allow it.

## Why incoming branches matter so much

A result-typed block is harder to simplify if branches still target it expecting a value or depending on the label as structured control.

That is why DCE starts with helper walkers that check whether blocks are really unneeded.
If the label is still live, the block may need to stay much closer to its original form.

Beginner rule:

- **dead final value** does not automatically mean **dead block**

## Why explicit `unreachable` can still be necessary

Sometimes DCE removes or voidifies the final result-producing wrapper around a control shape that no longer falls through.
When that happens, the function may still need an explicit trailing `unreachable` to remain structurally well-typed.

This is a big source of confusion.
The optimizer is making code *smaller* and *simpler*, but it may still need to insert an explicit `unreachable` node because the type/control contract after simplification still demands it.

So a good beginner mental model is:

- DCE often deletes dead `unreachable` suffixes
- but sometimes it must also **materialize** an explicit `unreachable` after voidifying non-fallthrough final control

Those are not contradictory.
They happen in different structural situations.

## Why local type repair is part of DCE

When a value-producing wrapper stops producing a value, some locals may no longer need or justify their previous precise type assumptions.
Binaryen handles that with:

- `TypeUpdater::handleNonDefaultableLocals(...)`

That means the pass is not done when it finishes structural simplification.
Removing dead result traffic can force later local-type cleanup.

A future port that copies only the “delete dead nodes” half and forgets this repair half will be incomplete.

## Why EH repair is part of DCE

Exception handling makes the same point even more strongly.
After DCE simplifies dead typed wrappers, Binaryen still calls:

- `EHUtils::handleBlockNestedPops(...)`

The dedicated `dce-eh*` test files exist because dead-result cleanup can expose or invalidate nested-pop structure.
So DCE's real contract includes:

- simplify dead EH result structure
- then repair EH details before the function is considered done

## Why flattening follows immediately

DCE can leave behind simpler semantics but still slightly awkward nesting.
That is why it also runs:

- `Flatten::flatten(...)`

This is not the aggressive standalone `flatten` pass from the `-O4z` prelude.
It is the small IR helper that cleans up extra block nesting created or exposed by DCE's own rewrites.

## Practical shape families to keep straight

## Positive family: dead result wrapper becomes void

Before:

```wat
(drop
  (block (result i32)
    (call $side)
    (i32.const 1)))
```

After, conceptually:

```wat
(call $side)
```

or:

```wat
(block
  (call $side))
```

depending on what structural wrapper still needs to remain.

## Positive family: dead typed `if` keeps control but loses value type

Before:

```wat
(drop
  (if (result i32)
    COND
    (then (call $a) (i32.const 1))
    (else (call $b) (i32.const 2))))
```

After, conceptually:

```wat
(if
  COND
  (then (call $a))
  (else (call $b)))
```

## Positive family: non-fallthrough final wrapper may need explicit `unreachable`

Before:

```wat
(drop
  (block (result i32)
    (return (i32.const 7))))
```

After, conceptually:

```wat
(block
  (return (i32.const 7)))
unreachable
```

The exact final shape varies, but the important rule is:

- DCE may need a real explicit `unreachable` after the simplified final control.

## Negative family: branch-targeted typed wrapper must stay

Before:

```wat
(block $out (result i32)
  ...
  (br $out (i32.const 1))
  ...)
```

If that label is still live, DCE cannot treat this like a plain dead wrapper just because one surrounding `drop` or tail value disappeared.

## Negative family: EH shape still requires repair

Before:

```wat
(try (result i32)
  ...
  (catch ...))
```

When the result becomes dead, DCE may voidify or simplify the typed wrapper.
But that does **not** mean the EH structure is automatically fine afterward.
That is why the pass explicitly runs EH repair before it finishes.

## What a future Starshine port must preserve

- Do not confuse dead-result cleanup with simple node deletion.
- Preserve the distinction between:
  - removing a dead value
  - voidifying a typed control wrapper
  - and repairing the function afterward
- Keep explicit-`unreachable` insertion honest.
- Keep branch-target safety honest.
- Keep type and EH repair as part of the pass boundary, not optional follow-up polish.
