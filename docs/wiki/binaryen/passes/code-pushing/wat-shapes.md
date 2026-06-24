---
kind: concept
status: supported
last_reviewed: 2026-06-24
sources:
  - ../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md
  - ../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md
  - ../../../raw/research/0823-2026-06-21-code-pushing-atomics-gc-boundary.md
  - ../../../raw/research/0821-2026-06-21-code-pushing-global-get-window-multi-set-movement.md
  - ../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md
  - ../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md
  - ../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md
  - ../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md
  - ../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md
  - ../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md
  - ../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md
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

This page catalogs the source-backed shapes future readers should keep in mind after the 2026-06-20 `version_130` source/lit refresh, the post-use, ordinary-`if`, dropped-`if`, no-branch-value `br_if`, branch-value `br_if`, ordered multi-set, local-copy, `nop`-window, loop-target `br_if`, `drop(const)`-window, `drop(local.get)`-window, bounded `drop(global.get)`-window, and atomics/GC segment-movement Starshine slices, and the earlier source corrections.

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

## Shape 4: segment movement after a narrow `br_if` before later same-block use

Binaryen-backed before:

```wat
(block $exit
  (local.set $tmp (i32.const 7))
  (br_if $exit (local.get $cond))
  (drop (local.get $tmp)))
```

Binaryen-backed after:

```wat
(block $exit
  (br_if $exit (local.get $cond))
  (local.set $tmp (i32.const 7))
  (drop (local.get $tmp)))
```

Starshine now implements this single-set `br_if` subset for no-branch-value branches to a void block or loop label, when the branch does not read the local and every read is a same-block / same-loop-body suffix read after the branch.

## Shape 4b: segment movement after a branch-value `br_if` before later same-block use

Binaryen-backed before:

```wat
(block $exit (result i32)
  (local.set $tmp (i32.const 7))
  (drop
    (br_if $exit
      (i32.const 42)
      (local.get $cond)))
  (local.get $tmp))
```

Binaryen-backed after:

```wat
(block $exit (result i32)
  (drop
    (br_if $exit
      (i32.const 42)
      (local.get $cond)))
  (local.set $tmp (i32.const 7))
  (local.get $tmp))
```

Starshine implements this branch-value `br_if` subset for one branch payload to a value block label. The branch payload and condition must not read the moved local; a payload such as `(local.get $tmp)` keeps the set stationary.

The adjacent local-independent multi-set variant is also source-backed:

```wat
(block $exit (result i32)
  (local.set $a (i32.const 2))
  (local.set $b (i32.const 3))
  (drop
    (br_if $exit
      (i32.const 7)
      (local.get $cond)))
  (drop (local.get $a))
  (drop (local.get $b))
  (i32.const 0))
```

Binaryen moves both sets after the value-carrying branch while preserving `$a` before `$b`; Starshine now matches that bounded ordered family. A payload-read variant keeps the read local's set before the branch; broader partial-window branch-value splitting remains outside this slice.

## Shape 5: ordered multi-set movement after a void `if`

Binaryen-backed before:

```wat
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

Binaryen-backed after:

```wat
(if
  (local.get $cond)
  (then
    nop))
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(drop (local.get $a))
(drop (local.get $b))
```

Starshine now implements this first ordered multi-set subset only for adjacent local-independent values before an ordinary void `if`, preserving source order.

## Shape 6: ordered multi-set movement after a dropped value `if`

Binaryen-backed before:

```wat
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(drop
  (if (result i32)
    (local.get $cond)
    (then (i32.const 1))
    (else (i32.const 2))))
(drop (local.get $a))
(drop (local.get $b))
```

Binaryen-backed after:

```wat
(drop
  (if (result i32)
    (local.get $cond)
    (then (i32.const 1))
    (else (i32.const 2))))
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(drop (local.get $a))
(drop (local.get $b))
```

Starshine now implements this ordered multi-set subset only for adjacent local-independent values before a dropped value `if`, preserving source order.

## Shape 6b: ordered multi-set movement after a narrow `br_if`

Binaryen-backed before:

```wat
(block $exit
  (local.set $a (i32.const 7))
  (local.set $b (i32.const 9))
  (br_if $exit (local.get $cond))
  (drop (local.get $a))
  (drop (local.get $b)))
```

Binaryen-backed after:

```wat
(block $exit
  (br_if $exit (local.get $cond))
  (local.set $a (i32.const 7))
  (local.set $b (i32.const 9))
  (drop (local.get $a))
  (drop (local.get $b)))
```

Starshine now implements this ordered multi-set subset for adjacent local-independent values before a no-branch-value `br_if` to a void block or loop label, preserving source order.

## Shape 6c: ordered local-copy multi-set movement

Binaryen-backed before:

```wat
(local.set $a (local.get $src_a))
(local.set $b (local.get $src_b))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

Binaryen-backed after:

```wat
(if
  (local.get $cond)
  (then
    nop))
(local.set $a (local.get $src_a))
(local.set $b (local.get $src_b))
(drop (local.get $a))
(drop (local.get $b))
```

Starshine now implements direct local-copy multi-set movement for ordinary void `if`, dropped value-`if`, and narrow no-branch-value `br_if` push points, preserving source order and rejecting cases where the crossed push point writes a copied source local.

## Shape 6d: `nop`-separated ordered multi-set movement

Binaryen-backed before:

```wat
(local.set $a (i32.const 7))
nop
(local.set $b (i32.const 9))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

Binaryen-backed after:

```wat
nop
(if
  (local.get $cond)
  (then
    nop))
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(drop (local.get $a))
(drop (local.get $b))
```

Starshine implements this only for `nop` separators before ordinary void `if`, dropped value-`if`, and narrow no-branch-value `br_if` push points.

## Shape 6e: `drop(const)`-separated ordered multi-set movement

Binaryen-backed before:

```wat
(local.set $a (i32.const 7))
(drop (i32.const 99))
(local.set $b (i32.const 9))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

Binaryen-backed after:

```wat
(drop (i32.const 99))
(if
  (local.get $cond)
  (then
    nop))
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(drop (local.get $a))
(drop (local.get $b))
```

Starshine implements this only for `drop` roots with exactly one pure `const` child before ordinary void `if`, dropped value-`if`, and narrow no-branch-value `br_if` push points.

## Shape 6f: `drop(local.get)`-separated ordered multi-set movement

Binaryen-backed before:

```wat
(local.set $a (i32.const 7))
(drop (local.get $param))
(local.set $b (i32.const 9))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

Binaryen-backed after:

```wat
(drop (local.get $param))
(if
  (local.get $cond)
  (then
    nop))
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(drop (local.get $a))
(drop (local.get $b))
```

Starshine implements this only for `drop` roots with exactly one `local.get` child before ordinary void `if`, dropped value-`if`, and narrow no-branch-value `br_if` push points.

## Shape 6g: bounded `drop(global.get)`-separated ordered multi-set movement

Binaryen-backed positive before ordinary void `if` / dropped value-`if` push points:

```wat
(global $g i32 (i32.const 42))
(local.set $a (i32.const 7))
(drop (global.get $g))
(local.set $b (i32.const 9))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

Binaryen-backed positive after:

```wat
(drop (global.get $g))
(if
  (local.get $cond)
  (then
    nop))
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(drop (local.get $a))
(drop (local.get $b))
```

Starshine implements this only for `drop` roots with exactly one `global.get` child before ordinary void `if` and dropped value-`if` push points. Binaryen v130 did not move the same separator window before no-branch-value block-/loop-target `br_if`; Starshine keeps that as an explicit boundary. Other non-adjacent windows still need source-backed `orderedBefore` / effect tests. The current ordered multi-set slices intentionally do not cover switch/`br_table`, branch values, `br_on_*`, arbitrary non-adjacent windows beyond `nop` / `drop(const)` / `drop(local.get)` / bounded ordinary-/dropped-`if` `drop(global.get)`, local-copy dependency chains, or general local-read-dependent value expressions.

## Shape 6h: loop-target `br_if` movement

Binaryen-backed before:

```wat
(loop $top
  (local.set $a (i32.const 7))
  (local.set $b (i32.const 9))
  (br_if $top (local.get $cond))
  (drop (local.get $a))
  (drop (local.get $b)))
```

Binaryen-backed after:

```wat
(loop $top
  (br_if $top (local.get $cond))
  (local.set $a (i32.const 7))
  (local.set $b (i32.const 9))
  (drop (local.get $a))
  (drop (local.get $b)))
```

Starshine now treats void loop labels like void block labels for the existing no-branch-value `br_if` movement proof. The same SFA, push-point-read, source-local-write, source-order, and suffix-read boundaries apply.

## Shape 7: `if` arm sinking into the only consuming arm

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

## Shape 8: post-if use can be safe when the other arm is unreachable

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

## Shape 9: both reachable arms using a value is not the baseline push

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

## Shape 10: post-if read with fallthrough from the other arm should not sink into one arm

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

## Shape 11: trap-sensitive computations are option-sensitive

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

## Shape 12: `switch` and broader conditional branch push points

Binaryen's push-point concept is broader than plain `if`. Starshine has one narrow `br_if` mutation slice; future work should widen or keep no-rewrite shape recognition for:

```wat
(local.set $tmp (i32.const 1))
(br_if $label (local.get $cond))
```

and switch/br-table-like shapes, `br_on_*`, loop-target branches, and branch-value conditional branches beyond the current single-/adjacent-multi-set `br_if` subset where the local's later consumption and effect barriers can be proved.

The 2026-06-21 `br_table` boundary slice records a narrower fact: local Binaryen `version_130` did **not** move either a single pure SFA set or two adjacent pure SFA sets before a no-branch-value `br_table $exit $exit` to the enclosing void block label. Starshine keeps `BrTable` as diagnostic switch recognition only for that shape and protects the no-mutation boundary in `src/passes/code_pushing_test.mbt`. Future switch work must start from a different source-backed positive probe or a Binaryen source/lit change.

## Shape 13: GC/reference and atomics expressions are not categorically excluded

The official `version_130` `code-pushing-gc.wast` and `code-pushing-atomics.wast` tests are part of the proof surface.

Safe rule:

- reference-typed expressions may participate only when the same SFA, use, and effect proof succeeds;
- `code-pushing-atomics.wast` shows a non-null GC `struct.get` may move past a shared atomic load, but not past a shared atomic store;
- Starshine implements only this narrow `struct.get`/atomic load-store family today, through HOT fixtures because the WAT parser/lowerer cannot yet consume the official shared-GC syntax;
- `ref.func`, casts, null checks, descriptor-shaped operations, broader heap expressions, and other atomics need explicit tests before Starshine widens.

## Shape 14: EH shapes are bailout-rich

Exception-handling shapes can make movement observable through exceptional control and value availability. Future Starshine fixtures should cover `try`, `catch`, `throw`, and any moved root whose value crosses an exceptional boundary.

## Shape 15: current Starshine positive single-consuming-arm sink

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

## Shape 16: current Starshine local dead-block flattening helper

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

- [`../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md`](../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md)
- [`../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md`](../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md)
- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md`](../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md)
- [`../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md`](../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md)
- [`../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md`](../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md)
- [`../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md)
- [`../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md)
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
