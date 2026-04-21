---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./effect-pruning-and-traps-never-happen.md
  - ./starshine-hot-ir-strategy.md
---

# `vacuum` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `vacuum`.

## Read this page with one mental model

`vacuum` is not mainly looking for `nop`.

It is mainly looking for:

- wrappers whose result is unused
- arms or blocks whose structure became empty
- trap-only residue that can be cleaned up conservatively under options

So the real shape question is usually:

- `what effects must survive, and what structure is now unnecessary?`

## Important note about the examples

Most `after` snippets below are **conceptual**.

In real Binaryen output:

- later passes may clean more up
- exact pretty-printing can differ
- some intermediate zero literals or wrapper blocks may remain until later cleanup

So read these as rewrite families, not exact final byte-for-byte output templates.

## Shape 1: dropped pure wrapper disappears entirely

Before:

```wat
(drop
  (i32.add
    (i32.const 1)
    (i32.const 2)))
```

After, conceptually:

```wat
(nop)
```

Why:

- result unused
- parent removable
- children have no unremovable side effects

This is the simplest positive case.

## Shape 2: dropped pure wrapper collapses to the one effectful child

Before:

```wat
(drop
  (i32.eqz
    (call $impure)))
```

After, conceptually:

```wat
(drop
  (call $impure))
```

Why:

- `i32.eqz` itself is removable here
- the call still matters
- only one effectful child survives

This is the main “unused-result effect pruning” family.

## Shape 3: multiple effectful children survive, parent wrapper goes away

Before, conceptually:

```wat
(drop
  (i32.add
    (call $left)
    (call $right)))
```

After, conceptually:

```wat
(block
  (drop (call $left))
  (drop (call $right))
)
```

Why:

- the arithmetic result is unused
- both child calls still matter
- the wrapper goes away, but the effectful children remain

This family depends on `getDroppedChildrenAndAppend(...)` and type/default-value handling.

## Shape 4: defaultable arm results can collapse to zeros when the outer result is dropped

Before, conceptually:

```wat
(drop
  (if (result i32)
    (local.get $cond)
    (then
      (call $nop)
      (call $call.without.effects (ref.func $i)))
    (else
      (call $nop)
      (call $call.without.effects (ref.func $i)))))
```

After, conceptually:

```wat
(drop
  (if (result i32)
    (local.get $cond)
    (then
      (call $nop)
      (i32.const 0))
    (else
      (call $nop)
      (i32.const 0))))
```

Why:

- the outer `drop` means the arm results are unused
- `i32` is defaultable
- Binaryen can replace the removed arm values with zeros

This family is locked by `vacuum-intrinsics.wast`.

## Shape 5: non-defaultable or awkward reference result types block that same rewrite

Before, conceptually:

```wat
(drop
  (if (result anyref)
    (call $cond_i32)
    (then
      (call $call.without.effects-ref (ref.func $ref)))
    (else
      (call $call.without.effects-ref (ref.func $ref)))))
```

After, conceptually:

```wat
(drop
  (if (result anyref)
    (call $cond_i32)
    (then
      (call $call.without.effects-ref (ref.func $ref)))
    (else
      (call $call.without.effects-ref (ref.func $ref)))))
```

Why it stays larger:

- Binaryen cannot safely synthesize the needed dummy value here
- so it gives up on that particular collapse

This is the main negative type-shape family.

## Shape 6: constant-condition `if` collapses to the chosen arm

Before:

```wat
(if
  (i32.const 1)
  (then (call $a))
  (else (call $b)))
```

After:

```wat
(call $a)
```

Why:

- constant condition
- ordinary dead arm removal

## Shape 7: unreachable condition collapses to the condition itself

Before:

```wat
(if
  (unreachable)
  (then (call $a))
  (else (call $b)))
```

After:

```wat
(unreachable)
```

Why:

- the condition already determines the whole outcome

## Shape 8: no-`else` `if` with empty `then` becomes `drop(condition)`

Before:

```wat
(if
  (local.get $cond)
  (then (nop)))
```

After:

```wat
(drop
  (local.get $cond))
```

Why:

- the condition still executes
- the body no longer matters

## Shape 9: empty `then`, live `else` flips the condition and the branch hint

Before, conceptually:

```wat
(@metadata.code.branch_hint "\00")
(if
  (i32.eqz
    (local.get $x))
  (then (nop))
  (else
    (call $work
      (local.get $x))))
```

After, conceptually:

```wat
(@metadata.code.branch_hint "\01")
(if
  (i32.eqz
    (i32.eqz
      (local.get $x)))
  (then
    (call $work
      (local.get $x))))
```

Why:

- Binaryen flips the condition instead of keeping a useless `then`
- the branch hint must flip too

This family is locked by `vacuum-branch-hints.wast`.

## Shape 10: `drop(local.tee(...))` becomes `local.set`

Before:

```wat
(drop
  (local.tee $x
    (i32.const 1)))
```

After:

```wat
(local.set $x
  (i32.const 1))
```

Why:

- the tee's produced value is unused
- only the write matters

This is one of the clearest concrete rewrites a future Starshine parity port must preserve.

## Shape 11: empty loop body disappears

Before:

```wat
(loop $L
  (nop))
```

After:

```wat
(nop)
```

Why:

- `visitLoop(...)` removes exactly this trivial loop family

## Shape 12: nontrivial or potentially infinite loops stay

Before and after stay the same in the important part:

```wat
(drop
  (loop $L (result i32)
    (br_if $L
      (i32.const 1))
    (i32.const 10)))
```

Why it stays:

- the loop may not terminate
- `vacuum` does not pretend such a loop is ordinary dead residue

This stays true even under TNH.

## Shape 13: block cleanup removes inner `nop` and trivial block shells

Before:

```wat
(block
  (nop)
  (drop
    (local.get $x))
  (nop))
```

After, conceptually:

```wat
(drop
  (local.get $x))
```

Why:

- child pruning removes the `nop`
- `BlockUtils::simplifyToContents(...)` collapses the trivial block

## Shape 14: dropped result block can lose its final value when no branch depends on it

Before, conceptually:

```wat
(drop
  (block (result i32)
    (call $side)
    (i32.const 7)))
```

After, conceptually:

```wat
(call $side)
```

Why:

- final block value only existed to feed the dropped result
- no branch payload needs that value

Important caveat:

- if named branches still target the block result, Binaryen must keep more structure

## Shape 15: non-throwing `try` / `try_table` collapses to the body

Before:

```wat
(try
  (do
    (drop (i32.const 0)))
  (catch_all
    (call $handler)))
```

After, conceptually:

```wat
(drop
  (i32.const 0))
```

Likewise, a `try_table` whose body cannot throw can collapse to its body.

Why:

- the exception wrapper is doing nothing observable any more

## Shape 16: `try` catch-all with no remaining effects can become `nop`

Before, conceptually:

```wat
(try
  (do
    (throw $e (i32.const 0)))
  (catch_all
    (nop)))
```

After, conceptually:

```wat
(nop)
```

But only for the `try` family with the source's specific conditions:

- type `none`
- has `catch_all`
- no unremovable side effects remain

## Shape 17: `try_table` is deliberately less aggressive than `try`

Before and after stay structurally similar in the important part:

```wat
(block $catch
  (try_table (catch_all $catch)
    (throw $e (i32.const 0))))
```

Why it stays:

- Binaryen intentionally leaves this family to `remove-unused-brs`
- `vacuum` does not normalize every obviously caught `try_table`

This is an important negative shape.

## Shape 18: return-before-throw makes a caught `try_table` removable

Before:

```wat
(block $catch
  (try_table (catch_all $catch)
    (return_call $throw)))
```

After:

```wat
(return_call $throw)
```

Why:

- the body returns before any throw would matter to the surrounding catch

The shipped EH tests lock this in for:

- `return_call`
- `return_call_indirect`
- `return_call_ref`

## Shape 19: void function body can disappear entirely

Before, conceptually:

```wat
(func
  (local.set $x (i32.const 1))
  (local.set $y (i32.const 2))
  (drop (local.get $x))
  (return))
```

After:

```wat
(func
  (nop))
```

Why:

- the whole body has no observable effect for callers to notice
- local traffic and `return` itself are not externally visible in a void function

This family is locked by `vacuum-func.wast`.

## Shape 20: result-returning function does **not** get that whole-body wipe

Before and after stay similar in the important part:

```wat
(func (result i32)
  (local.set $x (i32.const 1))
  (return (local.get $x)))
```

Why it stays:

- the returned value still matters

## Shape 21: explicit `unreachable` is preserved at function scope

Before:

```wat
(func
  (unreachable))
```

After:

```wat
(func
  (unreachable))
```

Why it stays even in TNH:

- Binaryen wants that explicit unreachability to keep propagating outward
- the whole-function nop logic has a direct `FindAll<Unreachable>` safeguard

This is a critical future-port invariant.

## Shape 22: TNH can remove trap-only residue before an explicit `unreachable`

Before, conceptually:

```wat
(block
  (i32.store (i32.const 0) (i32.const 1))
  (i32.store (i32.const 2) (i32.const 3))
  (unreachable))
```

After in TNH mode, conceptually:

```wat
(block
  (i32.store (i32.const 0) (i32.const 1))
  (unreachable))
```

Why:

- the second store is definitely on the path into the explicit trap
- but only until a barrier appears

## Shape 23: TNH barriers stop that cleanup

These keep more structure in TNH mode than beginners often expect:

- calls before an explicit `unreachable`
- may-not-return code
- control transfers
- dangling `pop`
- loops that may never reach the trap

So a shape like this stays conservative:

```wat
(call $maybe_weird)
(i32.store (i32.const 2) (i32.const 3))
(unreachable)
```

The call blocks the earlier trap-path deletion.

## Shape 24: string comparisons are a great positive/negative contrast

### `string.compare`

Dropped `string.compare` often stays because it may trap.

### `string.eq`

Dropped `string.eq` can disappear because it does not trap.

This is a very beginner-friendly reminder that `vacuum` is effect-semantic, not opcode-name-semantic.

## Shape 25: GC atomic operations also show the effect model clearly

From `vacuum-gc-atomics.wast`:

- dropped unordered or unshared cases can disappear
- dropped shared mutable atomic gets stay

So the pass is not just checking “was this result dropped?”

It is also checking whether the operation is still observably synchronizing.

## Shape 26: descriptor and cast cases are option-sensitive

From `vacuum-desc.wast` and `vacuum-gc.wast`:

- some dropped descriptor and cast forms stay in ordinary mode because they may trap
- some disappear under `--ignore-implicit-traps`
- some disappear under TNH

Those are good reminder shapes for two rules:

- trap sensitivity matters
- option sensitivity mostly arrives through the effect analyzers

## One-sentence summary for each family

- **dropped pure wrapper**: delete it entirely
- **one effectful child**: keep just that child
- **multiple effectful children**: keep the children, lose the wrapper if type rules allow
- **defaultable dropped arm values**: use zeros
- **non-defaultable results**: stay conservative
- **constant `if`**: pick the arm
- **unreachable condition**: keep the condition
- **empty `if` arm**: remove or flip it, and flip branch hints too if needed
- **drop of tee**: turn into set
- **empty loop body**: delete the loop
- **real loop**: keep it
- **trivial block residue**: collapse it
- **dropped block result**: pop it only if branches do not still need it
- **non-throwing `try` / `try_table`**: keep just the body
- **trivial `try_table` catch-all throw**: leave it for `remove-unused-brs`
- **void function with no observable effects**: maybe whole-body `nop`
- **explicit `unreachable` at function scope**: preserve it
- **TNH trap path**: prune only until a real barrier

## Bottom line

The most useful beginner question is not:

- `is this dead?`

It is:

- `if the result is unused, what structure is still needed to keep effects, types, and unreachability honest?`

That is the real `vacuum` shape logic.
