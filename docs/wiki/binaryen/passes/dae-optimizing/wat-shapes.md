---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./signature-updates-and-nested-reruns.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/wat-shapes.md
  - ../local-cse/index.md
  - ../simplify-locals/index.md
---

# `dae-optimizing` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `dae-optimizing` pass.
The 2026-04-25 follow-up added a current-main implementation/test-map bridge and a dedicated owner/test page. Use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for upstream file/test provenance and [`./starshine-strategy.md`](./starshine-strategy.md) for the local code-map and naming caveat before turning any shape here into local tests.

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

Why it rewrites:

- all returned values prove a narrower result type
- direct call expression typing must update too
- surrounding expressions may need refinalization afterward

So DAE edits results as well as params.

## Shape 7: if every direct caller drops the result, the result may disappear entirely

Before:

```wat
(func $f (result i32)
  (i32.const 42)
)

(func $g
  (drop (call $f))
)

(func $h
  (drop (call $f))
)
```

After, conceptually:

```wat
(func $f
  (drop (i32.const 42))
)

(func $g
  (call $f)
)

(func $h
  (call $f)
)
```

Why it rewrites:

- every observed direct caller already throws the result away
- DAE removes the result from the callee and the surrounding `drop` from callers

This is a second major family, not just a minor afterthought.

## Shape 8: dropped uninhabitable results may become `call; unreachable`

Before, conceptually:

```wat
(func $f (result none)
  (unreachable)
)

(func $g
  (drop (call $f))
)
```

After, conceptually:

```wat
(func $f
  (unreachable)
)

(func $g
  (call $f)
  (unreachable)
)
```

Why Binaryen does this:

- the old call site carried a strong “normal execution does not continue” fact
- blindly deleting the `drop` could weaken the caller’s control-flow meaning
- so DAE repairs the caller with an explicit `unreachable`

This is one of the most important easy-to-miss correctness details.

## Shape 9: an exported function is a negative case even if the param looks dead

Before and after stay the same in the important part:

```wat
(func $f (export "f") (param $x i32) (param $y i32)
  (drop (local.get $x))
)
```

Why Binaryen keeps the old boundary:

- exports are treated as unseen calls
- external callers may still use the old ABI
- so DAE refuses signature-changing rewrites

This is a core closed-world rule.

## Shape 10: `ref.func` escape is also a negative case

Before and after stay the same in the important part:

```wat
(func $f (param $x i32) (param $y i32)
  (drop (local.get $x))
)

(func $g (result funcref)
  (ref.func $f)
)
```

Why Binaryen keeps the old boundary:

- the function now escapes as a reference
- DAE no longer owns the whole call surface through direct calls alone

So escape analysis matters here, not just callee body liveness.

## Shape 11: imports stay fixed

Before and after stay the same:

```wat
(import "env" "f" (func $f (param i32 i32)))

(func $g
  (call $f (i32.const 1) (i32.const 2))
)
```

Why Binaryen leaves it alone:

- imported boundaries are out of scope for signature-changing DAE

## Shape 12: `call_ref` and `call_indirect` do not get the easy direct-call rewrite story

Before and after stay the same in the important part, conceptually:

```wat
(func $g (param $fp (ref null func))
  (call_ref (local.get $fp) (i32.const 1) (i32.const 2))
)
```

Why this matters:

- DAE is mainly designed around known direct callees
- indirect-style calls are conservatism signals here, not the main rewrite surface

## Shape 13: effectful or nested unused operands may need localization before removal

Before, conceptually:

```wat
(func $f (param $x i32) (param $y i32)
  (drop (local.get $x))
)

(func $g
  (call $f
    (i32.const 10)
    (call $side_effect)
  )
)
```

A possible intermediate shape is:

```wat
(func $g
  (local $tmp i32)
  (local.set $tmp (call $side_effect))
  (call $f
    (i32.const 10)
    (local.get $tmp)
  )
)
```

And only later can the dead boundary slot disappear entirely.

Why this family matters:

- parameter removal is not always safe in one step
- Binaryen has a specific repair path through call localization first

Important honesty note:

- this page treats that intermediate localization shape conceptually from the source design and helper API
- the exact localized WAT form can vary depending on caller structure and later cleanup

## Shape 14: all callers dropped is not enough when tail calls interfere

Before and after may stay the same in the important part, conceptually:

```wat
(func $f (result i32)
  ...
)

(func $g (result i32)
  (return_call $f)
)
```

Why Binaryen can bail out:

- tail-call relationships are tracked separately
- complete result removal is more conservative than ordinary result-type refinement

So a good rule is:

- dropped-result removal has its own extra safety gate

## Shape 15: optimizing cleanup can remove new casts after type refinement

Before, conceptually:

```wat
(func $f (param $x (ref null eq))
  (drop (ref.cast (ref null func) (local.get $x)))
)
```

After DAE boundary refinement, the function may conceptually become:

```wat
(func $f (param $x (ref null func))
  (drop (ref.cast (ref null func) (local.get $x)))
)
```

And after the optimizing nested rerun, the cast can disappear:

```wat
(func $f (param $x (ref null func))
  (drop (local.get $x))
)
```

Why this matters:

- `dae-optimizing` is not just the boundary rewrite itself
- later nested cleanup is often where the visible simplification payoff appears

The dedicated `dae-refine-params-and-optimize` test exists for exactly this kind of interaction.

## Shape 16: low-payoff one-caller chains are intentionally not chased forever

Conceptually, imagine:

```wat
(func $a (param $x i32) ...)
(func $b ... (call $a ...))
(func $c ... (call $b ...))
(func $d ... (call $c ...))
```

Even if each boundary might improve step by step, Binaryen does not insist on walking the whole chain greedily in one DAE invocation.

Why this matters:

- the pass contains a practical “not worth it right now” heuristic
- inlining or a later DAE run may clean the next link more profitably

This is less a single WAT rewrite than a scheduling shape, but it is still part of the real behavior contract.

## Important interaction families

## Interaction 1: DAE can create local-cleanup work

When DAE materializes constants or localizes call operands, it often creates new local traffic.

That is one reason the optimizing helper reruns cleanup passes afterward.

## Interaction 2: DAE can unlock cast cleanup

When DAE narrows a ref-typed param or result, later passes may remove casts, tests, or dead subtype plumbing that used to be necessary.

## Interaction 3: DAE precedes `inlining-optimizing`

Because it runs first in the late global optimizing cluster, DAE can simplify boundaries before the inliner makes later cost and usefulness decisions.

That ordering is part of the real pipeline story.

## One good rule of thumb

A good beginner summary is:

> `dae-optimizing` rewrites function boundaries only when Binaryen still owns the direct-call surface, then reruns cleanup so the rewritten boundary actually pays off.

That is the real shape story Binaryen `version_129` implements.
