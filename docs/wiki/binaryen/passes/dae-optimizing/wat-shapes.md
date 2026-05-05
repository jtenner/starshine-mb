---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./signature-updates-and-nested-reruns.md
  - ./starshine-port-readiness-and-validation.md
  - ../dead-argument-elimination/wat-shapes.md
  - ../dae2/wat-shapes.md
---

# `dae-optimizing` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `dae-optimizing` pass.
The 2026-05-05 current-main recheck keeps these families current. Use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for upstream file/test provenance and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the first-slice bridge before turning any shape here into local tests.

## Read this page with one mental model

Binaryen is not asking only:

- “does this function have an unused parameter?”

It is asking a bigger boundary question:

- “do we still own this direct-call boundary strongly enough to rewrite it, and if so, what is the best smaller or more precise boundary to leave behind?”

## Important note about the examples

The `after` snippets below are often **conceptual**.

In real Binaryen output, exact local indices, type names, and cleanup details may differ because:

- the pass may insert new locals before later cleanup runs
- the optimizing helper may immediately simplify some intermediate shapes away
- GC reference types may print with more exact subtype syntax than the short examples here

So read these as “rewrite family” examples, not as byte-for-byte goldens.

## Quick glossary

- **closed boundary**: a function boundary whose callers are still known through the collected direct-call set
- **unseen call**: a call path Binaryen cannot safely rewrite here, such as export or `ref.func` escape
- **localized operand**: a hard call argument first hoisted into a temp local before boundary deletion
- **touched function**: a function whose body changed enough to be scheduled for nested cleanup replay

## Shape 1: plain unused direct-call parameter disappears

Before:

```wat
(func $f (param $x i32) (param $y i32)
  (drop (local.get $x))
)

(func $g
  (call $f
    (i32.const 10)
    (i32.const 20)
  )
)
```

After, conceptually:

```wat
(func $f (param $x i32)
  (drop (local.get $x))
)

(func $g
  (call $f
    (i32.const 10)
  )
)
```

Why it rewrites:

- `$y` is unused in the callee
- the function boundary is direct-call-only and still owned
- Binaryen can remove the param from both callee and caller

This is the easiest DAE family, but it is not the whole pass.

## Shape 2: a read parameter can still disappear if every caller passes the same constant

Before:

```wat
(func $f (param $x i32) (result i32)
  (i32.add (local.get $x) (i32.const 1))
)

(func $a (result i32)
  (call $f (i32.const 7))
)

(func $b (result i32)
  (call $f (i32.const 7))
)
```

After, conceptually:

```wat
(func $f (result i32)
  (local $x i32)
  (local.set $x (i32.const 7))
  (i32.add (local.get $x) (i32.const 1))
)

(func $a (result i32)
  (call $f)
)

(func $b (result i32)
  (call $f)
)
```

Why it rewrites:

- the incoming slot is still used in the body
- but every direct caller supplies the same constant
- Binaryen materializes that constant into the callee body, then removes the old incoming param

This is the clearest proof that the pass is more than “remove params never read.”

## Shape 3: GC and string constants also count as constant actuals

Before, conceptually:

```wat
(func $f (param $x (ref null string)) (result i32)
  (drop (local.get $x))
  (i32.const 0)
)

(func $g (result i32)
  (call $f (string.const 0))
)
```

After, conceptually:

```wat
(func $f (result i32)
  (local $x (ref null string))
  (local.set $x (string.const 0))
  (drop (local.get $x))
  (i32.const 0)
)

(func $g (result i32)
  (call $f)
)
```

Why this matters:

- the Binaryen tests cover constant actual families beyond numeric literals
- a future Starshine port must preserve that wider modern scope when GC and strings are enabled

## Shape 4: a used ref-typed parameter may narrow instead of disappearing

Before, conceptually:

```wat
(func $f (param $x (ref null eq))
  (drop (local.get $x))
)

(func $a
  (call $f (ref.func $h))
)

(func $b
  (call $f (ref.null func))
)
```

After, conceptually:

```wat
(func $f (param $x (ref null func))
  (drop (local.get $x))
)

(func $a
  (call $f (ref.func $h))
)

(func $b
  (call $f (ref.null func))
)
```

Why it rewrites:

- all direct callers already supply a narrower ref family
- the parameter is still semantically needed
- Binaryen refines the boundary instead of deleting it

This is a “sounds unlike DAE, but is really in DAE” family.

## Shape 5: refining a param type can also require body repair

Before, conceptually:

```wat
(func $f (param $x (ref null eq))
  (local $tmp (ref null eq))
  (local.set $tmp (local.get $x))
  (drop (local.get $tmp))
)
```

After, conceptually:

```wat
(func $f (param $x (ref null func))
  (local $tmp (ref null func))
  (local.set $tmp (local.get $x))
  (drop (local.get $tmp))
)
```

Why this shape matters:

- DAE cannot only change the function signature
- it may also need to update local traffic inside the body so validation still holds

That is why `type-updating.h` matters.

## Shape 6: a function result may become more precise

Before, conceptually:

```wat
(func $f (result (ref null eq))
  (ref.null func)
)

(func $g (result (ref null eq))
  (call $f)
)
```

After, conceptually:

```wat
(func $f (result (ref null func))
  (ref.null func)
)

(func $g (result (ref null func))
  (call $f)
)
```

Why this matters:

- the pass can refine the outgoing boundary too
- nested cleanup then removes any debris left by the boundary rewrite

## Shape 7: dropped results can disappear when every caller drops them

Before, conceptually:

```wat
(func $f (result i32)
  (i32.const 9)
)

(func $g
  (drop (call $f))
)
```

After, conceptually:

```wat
(func $f
  (nop)
)

(func $g
  (call $f)
)
```

Why this rewrites:

- all owned direct callers drop the result
- the function result is removable
- the caller and callee boundaries can shrink together

## Shape 8: `call; unreachable` repair keeps uninhabited-result facts alive

Before, conceptually:

```wat
(func $f (result (ref null nofunc))
  (unreachable)
)

(func $g
  (drop (call $f))
)
```

After, conceptually:

```wat
(func $g
  (call $f)
  (unreachable)
)
```

Why it matters:

- the old dropped call encoded a stronger control-flow fact than “ignore the value”
- Binaryen preserves that fact after removing the result

## Shape 9: export and escape surfaces block signature rewrites

Before:

```wat
(func $f (param $x i32)
  (drop (local.get $x))
)
(export "f" (func $f))
```

After:

```wat
;; preserved
```

Why it stays:

- the function is still externally visible
- Binaryen treats it as having unseen calls

The same basic bailout family applies to `ref.func` escapes.

## Shape 10: tail calls limit result removal

Before, conceptually:

```wat
(func $f (result i32)
  (i32.const 0)
)

(func $g
  (return_call $f)
)
```

After:

```wat
;; may stay unchanged if tail-call constraints block full result removal
```

Why it stays:

- the optimizing pass keeps tail-call legality conservative
- “all direct callers drop the result” is necessary, not always sufficient

## Shape 11: operand localization keeps effects alive

Before, conceptually:

```wat
(func $f (param $x i32)
  (nop)
)

(func $g
  (call $f
    (call $side_effect)
  )
)
```

After, conceptually:

```wat
(func $g
  (local.set $tmp (call $side_effect))
  (call $f)
)
```

Why it rewrites this way:

- the argument must still be evaluated
- but the call boundary can shrink only after localization

This is the path that makes hard operands safe.

## Shape 12: the optimizing replay can remove the debris the boundary rewrite created

Before, conceptually:

```wat
(func $f (param $x i32)
  (local $tmp i32)
  (local.set $tmp (i32.const 7))
  (drop (local.get $x))
)
```

After, conceptually:

```wat
(func $f
  (nop)
)
```

Why it matters:

- boundary changes can introduce temporaries or obvious cleanup opportunities
- `dae-optimizing` does not stop at the boundary rewrite
- the nested cleanup replay is part of the visible contract

## Shape 13: recursive forwarding cycles can still disappear

Before:

```wat
(func $f (param $x i32)
  (call $f
    (local.get $x)))
```

After, conceptually:

```wat
(func $f
  (local $x i32)
  (call $f))
```

Why it rewrites:

- the param is only forwarded around a cycle
- nothing outside the cycle gives it a real use
- so the backward fixed point leaves it unused

## Shape 14: mutual recursion can optimize the same way

Before, conceptually:

```wat
(func $a (param $x i32)
  (call $b (local.get $x)))
(func $b (param $y i32)
  (call $a (local.get $y)))
```

After, conceptually:

```wat
(func $a
  (local $x i32)
  (call $b))
(func $b
  (local $y i32)
  (call $a))
```

Why it rewrites:

- the whole cycle is only forwarding,
- so all the relevant params stay dead together.
