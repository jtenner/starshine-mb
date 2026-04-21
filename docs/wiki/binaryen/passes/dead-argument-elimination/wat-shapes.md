---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0159-2026-04-21-dead-argument-elimination-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ../dae-optimizing/index.md
---

# `dead-argument-elimination` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's plain `dead-argument-elimination` / `dae` pass.

## Read this page with one mental model

Binaryen is not asking only:

- “is this parameter unused?”

It is asking a larger boundary question:

- “do we still own this direct-call boundary well enough to shrink or tighten it, and if not, which parts must stay exactly as they are?”

## Important note about the examples

The `after` snippets are **conceptual**.
In real Binaryen output:

- temp locals may appear,
- exact type names may differ,
- and some debris that `dae-optimizing` would immediately clean up may remain visible in plain `dae`.

So treat these as rewrite-family examples, not literal goldens.

## Quick glossary

- **closed boundary**: a function boundary whose relevant calls are still seen as direct calls
- **unseen call**: an export, `ref.func`, or other path that stops Binaryen from changing the signature here
- **constant actual**: a param position where every direct call provides the same constant value
- **localized operand**: an effectful call operand first hoisted to a temp so parameter removal can become legal

## Shape 1: plain unused direct-call parameter disappears

Before:

```wat
(func $f (param $x i32) (param $y i32)
  (drop (local.get $x))
)

(func $g
  (call $f
    (i32.const 1)
    (i32.const 2)
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
    (i32.const 1)
  )
)
```

Why it rewrites:

- `$y` is unused in the callee,
- the call boundary is still a known direct-call set,
- and Binaryen can shrink both the signature and the direct calls together.

## Shape 2: a recursive cycle can still lose the parameter

Before:

```wat
(func $f (param $x i32)
  (call $f
    (local.get $x)
  )
)
```

After, conceptually:

```wat
(func $f
  (local $x i32)
  (call $f)
)
```

Why it can rewrite:

- the param is only forwarded around the recursive cycle,
- but the incoming boundary value is never otherwise observed,
- so the whole cycle can stop accepting it.

Important caveat:

- if some function in the cycle truly uses the value, the whole relevant chain may have to keep it.

## Shape 3: all callers pass the same constant, so the boundary input becomes an internal local

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

- the param is still read,
- but the boundary value is constant across all known direct callers,
- so Binaryen internalizes the value first and then removes the incoming parameter.

## Shape 4: GC ref-typed params may narrow instead of disappearing

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

- the parameter is still live,
- but all known direct operands fit a narrower reference type,
- so DAE tightens the signature instead of deleting the slot.

This is one of the biggest “the name undersells the pass” shapes.

## Shape 5: result type may narrow too

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

- DAE computes a LUB of actual returned values,
- sees that a stricter result type is valid,
- then updates both the function and direct call expression types.

## Shape 6: all call results are dropped, so the return value disappears

Before:

```wat
(func $f (result i32)
  (i32.const 42)
)

(func $g
  (drop
    (call $f)
  )
)
```

After, conceptually:

```wat
(func $f
)

(func $g
  (call $f)
)
```

Why it rewrites:

- every known direct call drops the result,
- there are no unseen calls,
- and no tail-call rule blocks the change.

## Shape 7: dropped uninhabitable result becomes `call; unreachable`, not just plain `call`

Before, conceptually:

```wat
(func $f (result (ref $never))
  (unreachable)
)

(func $g
  (drop
    (call $f)
  )
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

Why it rewrites this way:

- the old result type carried useful knowledge that the call never really returns normally,
- removing the result must not lose that information,
- so Binaryen preserves it with an explicit `unreachable` in the caller repair.

## Shape 8: `call(unreachable)` must stay unreachable-looking after parameter removal

Before:

```wat
(func $target (param i32))

(func $caller
  (call $target
    (unreachable)
  )
)
```

After, conceptually:

```wat
(func $target)

(func $caller
  (unreachable)
)
```

Why this matters:

- removing the parameter must not silently turn an unreachable-typed call site into an ordinary none-typed call,
- so Binaryen repairs the caller to preserve validation and the original “never continues” meaning.

The reviewed TNH lit file makes this especially explicit.

## Shape 9: tail-call families are preserved for dropped-return removal

Before, conceptually:

```wat
(func $caller (result i32)
  (return_call $callee)
)

(func $callee (result i32)
  (i32.const 0)
)
```

After:

```wat
;; preserved in plain DAE for dropped-return purposes
```

Why it bails out:

- tail callers and tail callees must keep compatible result types,
- so DAE refuses to strip the result in these families even when ordinary non-tail dropped-call logic might seem tempting.

## Shape 10: export visibility is a hard signature-change bailout

Before:

```wat
(func $public (export "public") (param $x i32)
  (nop)
)
```

After:

```wat
;; preserved
```

Why it bails out:

- the exported function boundary is externally visible,
- so Binaryen treats it as having unseen calls and will not change the signature here.

## Shape 11: `ref.func` escape is also a hard signature-change bailout

Before:

```wat
(func $f (param $x i32)
  (nop)
)

(func $g
  (drop (ref.func $f))
)
```

After:

```wat
;; preserved for signature-changing purposes
```

Why it bails out:

- `ref.func` means the function boundary can escape,
- so DAE no longer owns the full direct-call surface.

## Shape 12: indirect-call style boundaries are not the easy positive surface

Before, conceptually:

```wat
(type $t (func (param i32)))

(func $caller (param $f (ref null $t))
  (call_ref $t
    (i32.const 1)
    (local.get $f)
  )
)
```

After:

```wat
;; generally preserved as a plain-DAE boundary rewrite target
```

Why it usually stays unchanged:

- plain DAE's main rewrite surface is known direct calls,
- while indirect or escaping reference-based calls weaken the signature ownership story.

## Shape 13: effectful operands may force a localization round before removal

Before, conceptually:

```wat
(func $f (param $dead i32)
  (nop)
)

(func $g
  (call $f
    (i32.add
      (call $side)
      (i32.const 1)
    )
  )
)
```

Intermediate shape after localization, conceptually:

```wat
(func $g
  (local $tmp i32)
  (local.set $tmp
    (i32.add
      (call $side)
      (i32.const 1)
    )
  )
  (call $f
    (local.get $tmp)
  )
)
```

Later after another DAE iteration, conceptually:

```wat
(func $g
  (local $tmp i32)
  (local.set $tmp
    (i32.add
      (call $side)
      (i32.const 1)
    )
  )
  (call $f)
)
```

Why this matters:

- plain DAE is iterative,
- and one pass round may exist only to make the next removal legal.

## Shape 14: plain DAE may leave cleanup debris that `dae-optimizing` would remove

Before:

```wat
(func $f (param $x i32)
  (drop (local.get $x))
)

(func $g
  (call $f (i32.const 7))
)
```

Possible plain-DAE-style after, conceptually:

```wat
(func $f
  (local $x i32)
  (local.set $x (i32.const 7))
  (drop (local.get $x))
)

(func $g
  (call $f)
)
```

What to remember:

- plain DAE is still correct here,
- even if a later cleanup pass could now simplify the body further.

That “unfinished-looking but intentional” outcome is one of the clearest differences from `dae-optimizing`.

## Fast checklist for reading a candidate shape

When you see a possible DAE opportunity, ask:

1. Is the boundary still a known direct-call set?
2. Is the function imported, exported, or `ref.func`-escaped?
3. Is the parameter actually unused, or only constant across callers?
4. Are there GC ref-typed params or results that can narrow?
5. Are all known results dropped?
6. Do tail-call rules block return removal?
7. Are nested effects forcing localization first?
8. Would the visible payoff require later cleanup that only `dae-optimizing` guarantees?

## Bottom line

The most important beginner correction is:

> Plain `dead-argument-elimination` is not just a delete-parameter pass. It is a direct-call boundary optimizer with refinement, constantization, dropped-return cleanup, and iterative legality repair, but without the extra nested polish pass that `dae-optimizing` adds.
