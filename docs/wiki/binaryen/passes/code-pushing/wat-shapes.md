---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../../../../src/passes/code_pushing_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `code-pushing` WAT Shapes

This page catalogs the shapes future readers should keep in mind after the 2026-04-25 source correction.

## Mental model

Binaryen `code-pushing` moves work later in a structured block when it can prove the move preserves execution and ordering.

The two source-backed families to remember are:

1. one-unreachable-arm `if` sinking;
2. local sibling-root pushing before a later use.

Do **not** use the older “duplicate a pure expression into both reachable arms” example as a Binaryen fact. That was a stale dossier overread.

## Shape 1: one unreachable `if` arm lets work move into the reachable arm

Conceptual before:

```wat
(block
  (local.set $tmp (i32.const 7))
  (if
    (local.get $cond)
    (then
      (unreachable))
    (else
      (drop (local.get $tmp)))))
```

Conceptual after:

```wat
(block
  (if
    (local.get $cond)
    (then
      (unreachable))
    (else
      (local.set $tmp (i32.const 7))
      (drop (local.get $tmp)))))
```

Why it can move:

- only the `else` arm can continue,
- the moved work still executes exactly on the continuing path,
- and the moved roots pass the `canPushThrough(...)` safety check.

## Shape 2: local sibling-root movement before a later use

Conceptual before:

```wat
(block
  (local.set $tmp (i32.const 1))
  (drop (i32.const 0))
  (drop (local.get $tmp)))
```

Conceptual after, in spirit:

```wat
(block
  (drop (i32.const 0))
  (local.set $tmp (i32.const 1))
  (drop (local.get $tmp)))
```

Why it can move:

- the later root uses the earlier expression,
- every intervening root is safe to cross,
- and the move is local to the same block root list.

## Shape 3: both reachable `if` arms using a value is not a guaranteed Binaryen push

Before and after should be assumed unchanged unless a source/test proves the exact case:

```wat
(local.set $tmp (i32.const 7))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (drop (local.get $tmp))))
```

The stale page claimed Binaryen could generally duplicate the `local.set` into both arms.
The corrected source-backed rule is: the reviewed `optimizeIntoIf(...)` path is centered on the one-unreachable-arm case, not general two-live-arm duplication.

## Shape 4: value still used after the separator should not move into only one arm

```wat
(local.set $tmp (i32.const 7))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (nop)))
(drop (local.get $tmp))
```

Why this remains a bailout family:

- moving the set into one arm would strand the later use,
- and preserving execution requires reasoning about all uses, not just the first local arm use.

Current Starshine has a focused guard for this family in `src/passes/code_pushing_test.mbt`.

## Shape 5: trap-sensitive computations are barriers unless options say otherwise

```wat
(local.set $tmp
  (i32.div_s
    (i32.const 1)
    (i32.const 0)))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp))))
```

Why it is sensitive:

- moving the division can change when the trap occurs,
- Binaryen's `canPushThrough(...)` consults trap-related options,
- Starshine's current subset avoids this by only moving const-like values for the `local.set` sinking family.

## Shape 6: GC/reference expressions are not categorically excluded

The official `code-pushing-gc.wast` test remains part of the source-backed proof surface.
The important rule is not “GC never moves” or “GC always moves.”
It is:

- reference-typed expressions participate only when the same movement predicate proves safety,
- and ref-specific cases such as `ref.func`, casts, and `ref.as_non_null` can matter.

## Shape 7: EH shapes are bailout-rich

Exception-handling shapes can make movement observable through exceptional control and value availability.
Use `code-pushing-eh.wast` as the official upstream proof surface for this family.

A future Starshine port should add focused fixtures before widening motion around:

- `try`,
- `catch`,
- `throw`,
- and any moved root whose value crosses an exceptional boundary.

## Shape 8: current Starshine positive single-consuming-arm sink

Current Starshine implements a narrower HOT subset than Binaryen.
A local positive shape is:

```wat
(func (param i32) (local i32)
  i32.const 7
  local.set 1
  local.get 0
  if
    local.get 1
    drop
  end)
```

Current local HOT result shape:

- the original root `local.set` becomes `nop`,
- a cloned `local.set 1` is inserted at the beginning of the consuming arm,
- the arm's existing `local.get 1` remains.

This is useful and safe, but narrower than Binaryen's upstream predicate-driven motion.

## Shape 9: current Starshine keeps both-arm uses

Current Starshine intentionally does not duplicate into both live arms:

```wat
(func (param i32) (local i32)
  i32.const 7
  local.set 1
  local.get 0
  if
    local.get 1
    drop
  else
    local.get 1
    drop
  end)
```

The focused test keeps the original set because both arms read the local.
This now aligns with the corrected wiki warning that two-live-arm duplication is not the source-backed baseline teaching shape.

## Shape 10: current Starshine local dead-block flattening helper

Current Starshine also has a local cleanup shape around a typed block next to unreachable context.

Conceptual family:

```wat
(func (result i32)
  i32.const 0
  (block (result i32)
    f64.const 0
    unreachable)
  unreachable)
```

The local pass can flatten the inner block roots around the unreachable context when its branch/multivalue guards allow it.

Caveat:

- this is a Starshine-local helper family in `src/passes/code_pushing.mbt`,
- not a claim about upstream Binaryen `CodePushing.cpp`.

## Reader checklist

Before expecting a `code-pushing` rewrite, ask:

1. Is this a one-unreachable-arm `if` family or ordinary sibling-root movement?
2. Is the source expression local to the same block root list?
3. Does moving it preserve whether it executes?
4. Can it cross every intervening expression under `canPushThrough(...)`?
5. Does trap policy matter?
6. Are GC/EH/reference details involved?
7. Is the example actually current Starshine-local rather than upstream Binaryen?

## Sources

- [`../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- Binaryen `version_129` tests linked in the raw manifest.
