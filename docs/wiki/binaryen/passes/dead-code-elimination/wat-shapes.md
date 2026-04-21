---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./typed-control-voidification-and-eh.md
  - ../../no-dwarf-default-optimize-path.md
---

# `dead-code-elimination` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `dead-code-elimination` pass.

## Read this page with one mental model

Binaryen DCE is usually trying to do one of two things:

- remove work that is unreachable after a non-fallthrough point
- remove a value that is dead while keeping any still-visible side effects and structure valid

Everything else on this page is about why that sometimes means deletion, sometimes means simplification, and sometimes means “keep the wrapper but make it void.”

## Quick glossary

- **dead result**: the program computes a value, but nobody needs that value anymore
- **non-fallthrough**: control does not continue to the next expression on that path (`return`, `throw`, `unreachable`, and similar families)
- **voidify**: keep a control structure but remove its result type
- **live label**: a block/loop label that branches still target

## Shape family 1: dead pure `drop` disappears entirely

Before:

```wat
(drop
  (i32.add
    (i32.const 1)
    (i32.const 2)))
```

After:

```wat
;; nothing remains
```

Why this works:

- the child is pure
- its result is dead
- erasing it does not erase observable behavior

## Shape family 2: dead impure `drop` keeps the side effect

Before:

```wat
(drop
  (call $log_and_return_i32))
```

After, conceptually:

```wat
(call $log_and_return_i32)
```

Why this works:

- the value is dead
- but the call itself is still observable
- DCE removes only the dead-result wrapper, not the effectful work

## Shape family 3: unreachable suffix after `return` is removed

Before:

```wat
(i32.const 5)
(return)
(i32.const 9)
(drop)
```

After:

```wat
(i32.const 5)
(return)
```

This is the easy DCE case.
It is real, but it is not the whole pass.

## Shape family 4: dead pure tail inside a block disappears

Before:

```wat
(block
  (call $side)
  (drop (i32.const 1)))
```

After:

```wat
(block
  (call $side))
```

Important lesson:

- DCE keeps the side-effectful prefix in order
- and only removes the dead pure tail

## Shape family 5: dead typed block may simplify to contents

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

Which exact form you see depends on whether the wrapper is still needed structurally.

## Shape family 6: dead typed `if` may become a void `if`

Before:

```wat
(drop
  (if (result i32)
    (local.get $cond)
    (then
      (call $a)
      (i32.const 1))
    (else
      (call $b)
      (i32.const 2))))
```

After, conceptually:

```wat
(if
  (local.get $cond)
  (then
    (call $a))
  (else
    (call $b)))
```

Important lesson:

- DCE often keeps the control shell
- it removes the dead result, not necessarily the whole node

## Shape family 7: explicit `unreachable` may need to remain or be inserted

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

This looks strange until you remember the real goal:

- keep the simplified function structurally well-typed after a non-fallthrough final control rewrite

## Shape family 8: live labels block aggressive block removal

Before:

```wat
(block $out (result i32)
  (br $out (i32.const 1))
  (i32.const 2))
```

After:

```wat
;; wrapper is not freely removable
```

Why this matters:

- a block with a live incoming branch is not just dead syntax around a value
- its label is still part of the function's control-flow contract

## Shape family 9: DCE keeps effect order even when values die

Before:

```wat
(drop
  (block (result i32)
    (call $a)
    (call $b)
    (i32.const 1)))
```

After, conceptually:

```wat
(call $a)
(call $b)
```

Important lesson:

- DCE is not trying to be clever about reordering effects
- it keeps still-visible work in program order

## Shape family 10: EH wrappers can simplify, but not by magic

Before:

```wat
(drop
  (try (result i32)
    ...
    (catch ...)))
```

After, conceptually:

```wat
(try
  ...
  (catch ...))
```

with later EH repair as needed.

Important lesson:

- DCE can remove the dead result
- but EH shape still needs explicit repair afterward

## Shape family 11: stack-switching families are part of the real surface

The dedicated `dce-stack-switching.wast` file exists for a reason.
DCE's effect and structure rules are not only for MVP-era blocks, `if`, and calls.
The pass still has to behave correctly when newer control/effect surfaces are present.

Beginner lesson:

- do not assume “simple dead code cleanup” means “MVP-only syntax.”

## Shape family 12: pass interactions are part of the shape story

The dedicated `dce_vacuum_remove-unused-names.wast` file shows that some shapes are intentionally left in a partially cleaned state until later passes run.

That means a shape can be:

- already meaningfully simplified by DCE,
- but still not in the final prettiest form until `vacuum` and `remove-unused-names` finish the neighborhood cleanup.

## Negative families and non-goals

These are outside the real `version_129` DCE contract:

- dead-store elimination for memory stores
- dead-store elimination for `global.set`
- full local-liveness cleanup of arbitrary local traffic
- branch retargeting or branch-value normalization as a main goal
- whole-module reachability cleanup
- final `nop` / empty-wrapper janitor work as a complete fixpoint by itself

Those jobs belong to other passes or pass combinations.

## Scheduler interaction to remember

DCE runs early because it is supposed to make later cleanup passes easier.
A shape that looks “not fully cleaned” after DCE alone may still be perfectly normal in the full pipeline if:

- `remove-unused-names`
- `remove-unused-brs`
- `vacuum`

are expected to finish the job.
