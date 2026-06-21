---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md
  - ../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md
  - ../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md
  - ../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md
  - ../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../../../src/passes/code_pushing_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `code-pushing` WAT Shapes

This page catalogs the source-backed shapes future readers should keep in mind after the 2026-06-20 `version_130` source/lit refresh, the 2026-06-20 post-use, ordinary-`if`, and dropped-`if` segment-movement Starshine slices, and the earlier source corrections.

## Mental model

Binaryen `code-pushing` moves SFA-like `local.set` roots later in a structured block segment when the value can safely cross intervening effects.

The main families are:

1. block-local segment pushing toward a push point;
2. `if` arm sinking when exactly one arm consumes the local;
3. post-if-read allowances when the non-consuming arm cannot fall through.

Do **not** use arbitrary “duplicate pure expression into both reachable arms” examples as a Binaryen fact.

## Shape 1: local-set segment pushes toward a later control point

Conceptual before:

```wat
(block
  (local.set $tmp (i32.const 1))
  (drop (i32.const 0))
  (if
    (local.get $cond)
    (then (drop (local.get $tmp)))))
```

Conceptual after, if the intervening roots are safe to cross:

```wat
(block
  (drop (i32.const 0))
  (local.set $tmp (i32.const 1))
  (if
    (local.get $cond)
    (then (drop (local.get $tmp)))))
```

Why it can move:

- `$tmp` is SFA-like;
- the set's value is movable;
- the intervening roots do not invalidate the value effects or violate `version_130` ordered-before constraints;
- the destination is a recognized push point.

## Shape 2: segment movement after a void `if` before later suffix use

Binaryen-backed before:

```wat
(local.set $tmp (i32.const 7))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $tmp))
```

Binaryen-backed after:

```wat
(if
  (local.get $cond)
  (then
    nop))
(local.set $tmp (i32.const 7))
(drop (local.get $tmp))
```

Starshine now implements this single-set ordinary-void-`if` subset when the segment-window diagnostic reports `candidate:if`, neither arm reads the local, and every read is a same-region suffix read after the `if`.

## Shape 3: segment movement after a dropped value `if` before later suffix use

Binaryen-backed before:

```wat
(local.set $tmp (i32.const 7))
(drop
  (if (result i32)
    (local.get $cond)
    (then (i32.const 1))
    (else (i32.const 2))))
(drop (local.get $tmp))
```

Binaryen-backed after:

```wat
(drop
  (if (result i32)
    (local.get $cond)
    (then (i32.const 1))
    (else (i32.const 2))))
(local.set $tmp (i32.const 7))
(drop (local.get $tmp))
```

Starshine now implements this single-set dropped-`if` subset when the segment-window diagnostic reports `candidate:dropped-if`, the dropped push point does not read the local, and every read is a same-region suffix read after the dropped wrapper.

## Shape 4: `if` arm sinking into the only consuming arm

Conceptual before:

```wat
(local.set $tmp (i32.const 7))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (nop)))
```

Conceptual after:

```wat
(if
  (local.get $cond)
  (then
    (local.set $tmp (i32.const 7))
    (drop (local.get $tmp)))
  (else
    (nop)))
```

This is close to Starshine's current positive subset when the value passes the strict movable-value gate and all local reads are in one arm.

## Shape 5: post-if use can be safe when the other arm is unreachable

Conceptual family:

```wat
(local.set $tmp (i32.const 7))
(if
  (local.get $cond)
  (then
    (unreachable))
  (else
    (drop (local.get $tmp))))
(drop (local.get $tmp))
```

The post-if read is not automatically fatal if the non-consuming path cannot continue. This nuance belongs to Binaryen's `optimizeIntoIf(...)` family. Starshine's first conservative slice now supports the same-region suffix-read subset when the opposite arm cannot fall through.

## Shape 6: both reachable arms using a value is not the baseline push

Assume unchanged unless a source/test proves a more specific case:

```wat
(local.set $tmp (i32.const 7))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (drop (local.get $tmp))))
```

The pass is not a generic “duplicate the set into both arms” transform.

## Shape 7: post-if read with fallthrough from the other arm should not sink into one arm

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

- moving the set into the `then` arm would leave the later read uninitialized on the `else` fallthrough path;
- Starshine has a focused guard for this family in `src/passes/code_pushing_test.mbt`.

## Shape 8: trap-sensitive computations are option-sensitive

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

- moving the division can change when the trap occurs;
- Binaryen has tests for ignore-implicit-traps and TNH modes;
- Starshine's current subset avoids this with an explicit nontrapping gate for movable values.

## Shape 9: `switch` and conditional branch push points

Binaryen's push-point concept is broader than plain `if`. Future Starshine work should add no-rewrite shape recognition before mutation for:

```wat
(local.set $tmp (i32.const 1))
(br_if $label (local.get $cond))
```

and switch/br-table-like shapes where the local's later consumption and effect barriers can be proved.

## Shape 10: GC/reference and atomics expressions are not categorically excluded

The official `version_130` `code-pushing-gc.wast` and `code-pushing-atomics.wast` tests are part of the proof surface.

Safe rule:

- reference-typed expressions may participate only when the same SFA, use, and effect proof succeeds;
- `code-pushing-atomics.wast` shows a GC `struct.get` may move past a shared atomic load, but not past a shared atomic store;
- `ref.func`, casts, null checks, descriptor-shaped operations, and atomics need explicit tests before Starshine widens.

## Shape 11: EH shapes are bailout-rich

Exception-handling shapes can make movement observable through exceptional control and value availability. Future Starshine fixtures should cover `try`, `catch`, `throw`, and any moved root whose value crosses an exceptional boundary.

## Shape 12: current Starshine positive single-consuming-arm sink

Current Starshine implements this narrower HOT subset:

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

- the original root `local.set` becomes `nop`;
- a cloned `local.set 1` is inserted at the beginning of the consuming arm;
- the arm's existing `local.get 1` remains.

## Shape 13: current Starshine local dead-block flattening helper

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

Caveat:

- this is a Starshine-local helper family in `src/passes/code_pushing.mbt`;
- it is not a claim about upstream Binaryen `CodePushing.cpp`.

## Reader checklist

Before expecting a `code-pushing` rewrite, ask:

1. Is the source a suitable SFA `local.set` root?
2. Is there a recognized push point?
3. Are all local gets accounted for at or after the destination?
4. Can the value cross every intervening effect?
5. Does trap policy matter?
6. Are GC/atomics/EH/reference details involved?
7. Is the example actually current Starshine-local rather than upstream Binaryen?

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md)
- [`../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md)
- [`../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md)
- [`../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md`](../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md)
- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- Binaryen `version_130` tests linked in the raw manifest.
