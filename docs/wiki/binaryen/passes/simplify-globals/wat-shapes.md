---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md
  - ../../../raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md
  - ../../../raw/research/0461-2026-05-05-simplify-globals-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./plain-vs-optimizing-and-safety.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals-optimizing/index.md
---

# `simplify-globals` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's plain `simplify-globals` pass.

## Read this page with one mental model

Binaryen is not asking only:

- “is this `global.get` constant?”

It is asking a broader question:

- “how much of this module's apparent global state is still real state, and which substitutions are still safe at startup or along the current simple runtime trace?”

## Important note about the examples

The `after` snippets are **conceptual**.
Real Binaryen output may still contain:

- `drop(...)` wrappers,
- unchanged local debris,
- or type-repair scaffolding.

That is especially important here because plain `simplify-globals` does **not** do the nested default-function cleanup rerun that `simplify-globals-optimizing` performs.
The 2026-05-05 current-main recheck did not change the shape families below.

## Quick glossary

- **startup propagation**: rewriting later global initializers and segment offsets while module instantiation order still gives stronger guarantees
- **runtime propagation**: rewriting function code using constant globals or cheap current-trace facts
- **read-only-to-write**: a global is only read to decide whether to write that same global
- **same-as-init write**: a write that stores the initializer value again rather than creating a new meaningful state

## Shape 1: one-time global-to-global initializer folding

Before:

```wat
(global $a (mut (ref null $S))
  (struct.new_default $S)
)
(global $b (mut (ref null $S))
  (global.get $a)
)
```

After, conceptually:

```wat
(global $b (mut (ref null $S))
  (struct.new_default $S)
)
```

Why it rewrites:

- `$a` has one relevant use,
- the use is in a later global initializer,
- startup still runs once,
- and copying the initializer preserves semantics there.

Important negative rule:

- the same source initializer is **not** copied into ordinary function code by this rule.

## Shape 2: same-as-init write becomes `drop(value)`

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (i32.const 0))
)
```

After, conceptually:

```wat
(global $g i32 (i32.const 0))
(func
  (drop (i32.const 0))
)
```

Why it rewrites:

- the write does not create a new state,
- so Binaryen can preserve evaluation but erase the mutation.

## Shape 3: unread private write becomes `drop(value)`

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (call $side_effect))
)
```

After, conceptually:

```wat
(global $g i32 (i32.const 0))
(func
  (drop (call $side_effect))
)
```

Why it rewrites:

- the global state is no longer needed,
- but the call's side effects must still happen.

## Shape 4: simple read-only-to-write self-guard disappears

Before:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (global.get $once)
    (then
      (global.set $once (i32.const 1))
    )
  )
)
```

After, conceptually:

```wat
(global $once i32 (i32.const 0))
(func
  (if
    (i32.const 0)
    (then
      (drop (i32.const 1))
    )
  )
)
```

What really matters:

- the exact printed cleanup afterward may vary,
- but the important semantic change is that the global write becomes unnecessary state.

## Shape 5: narrow whole-function early-return pattern

Before:

```wat
(func
  (block
    (if
      (global.get $once)
      (then (return))
    )
    (global.set $once (i32.const 1))
  )
)
```

After, conceptually:

```wat
(func
  (block
    (if
      (i32.const 0)
      (then (return))
    )
    (drop (i32.const 1))
  )
)
```

Why it matters:

- this family is source-backed,
- but it is an exact narrow body-shape matcher, not a general CFG theorem.

## Shape 6: startup propagation into a later global initializer

Before:

```wat
(global $a (mut i32) (i32.const 42))
(global $b i32
  (i32.add (global.get $a) (i32.const 1))
)
```

After, conceptually:

```wat
(global $b i32
  (i32.add (i32.const 42) (i32.const 1))
)
```

Why it rewrites:

- no runtime code has executed yet,
- so the earlier global still has its startup value while later globals are being initialized.

## Shape 7: startup propagation into a segment offset

Before:

```wat
(global $off (mut i32) (i32.const 8))
(data (memory 0) (global.get $off) "abc")
```

After, conceptually:

```wat
(data (memory 0) (i32.const 8) "abc")
```

Why it rewrites:

- segment offsets are part of module setup, not later runtime flow.

## Shape 8: cheap runtime trace propagation inside one simple path

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (i32.const 10))
  (drop (global.get $g))
)
```

After, conceptually:

```wat
(func
  (drop (i32.const 10))
)
```

Why it rewrites:

- along the current simple trace, Binaryen knows the current value of `$g`.

Important note:

- plain `simplify-globals` may still leave follow-up debris that the optimizing variant would clean further.

## Shape 9: adjacent dominated block positive

Before:

```wat
(func
  (global.set $g (i32.const 10))
  (block
    (drop (global.get $g))
  )
)
```

After, conceptually:

```wat
(func
  (block
    (drop (i32.const 10))
  )
)
```

Why it can rewrite:

- Binaryen's runtime propagation walker can connect some adjacent block cases cheaply.

## Shape 10: call barrier blocks runtime propagation

Before:

```wat
(func
  (global.set $g (i32.const 10))
  (call $unknown)
  (drop (global.get $g))
)
```

After:

```wat
(func
  (global.set $g (i32.const 10))
  (call $unknown)
  (drop (global.get $g))
)
```

Why it stays:

- the call clears the current-value map,
- so Binaryen stops pretending it still knows `$g` here.

## Shape 11: extra body effects block read-only-to-write

Before:

```wat
(func
  (if
    (global.get $g)
    (then
      (call $side_effect)
      (global.set $g (i32.const 1))
    )
  )
)
```

After:

```wat
(func
  (if
    (global.get $g)
    (then
      (call $side_effect)
      (global.set $g (i32.const 1))
    )
  )
)
```

Why it stays:

- the body is no longer “just write this global,”
- so the self-guard proof does not apply.

## Shape 12: effect-summary-only helper calls do not count as owned syntax

Before:

```wat
(func
  (if
    (call $reads_g)
    (then
      (call $writes_g)
    )
  )
)
```

After:

```wat
(func
  (if
    (call $reads_g)
    (then
      (call $writes_g)
    )
  )
)
```

Why it stays:

- the pass wants actual `global.get` / `global.set` nodes for this pattern,
- not just summarized knowledge that some helper call touches the same global.

## Shape 13: immutable copy chain prefers the earliest compatible ancestor

Before:

```wat
(global $a i32 (i32.const 7))
(global $b i32 (global.get $a))
(global $c i32 (global.get $b))
(func
  (drop (global.get $c))
)
```

After, conceptually:

```wat
(func
  (drop (global.get $a))
)
```

Why it rewrites:

- the chain is immutable,
- and the ancestor type matches exactly.

## Shape 14: type mismatch blocks earlier-ancestor replacement

Before:

```wat
(global $a (ref null $Parent) ...)
(global $b (ref null $Child) (global.get $a))
(func
  (drop (global.get $b))
)
```

After:

```wat
(func
  (drop (global.get $b))
)
```

Why it stays:

- the earlier ancestor type is not an exact replacement for this use in `version_129`.

## Shape 15: plain-pass leftovers are expected

Before:

```wat
(func
  (drop
    (i32.eqz
      (global.get $g)
    )
  )
)
```

After, conceptually in the plain pass:

```wat
(func
  (drop
    (i32.eqz
      (i32.const 0)
    )
  )
)
```

Why this page calls it out:

- plain `simplify-globals` may stop at this stage,
- while `simplify-globals-optimizing` would immediately let the nested function pipeline simplify the new local debris further.

## Best beginner checklist

When deciding whether a `simplify-globals` shape should rewrite, ask:

1. is this startup-time reasoning or runtime reasoning?
2. if runtime, did a call or nonlinear control already break the cheap trace?
3. if this is a self-guard, does the body really do nothing but write that same global?
4. is Binaryen looking at actual `global.get` / `global.set` nodes, not just summary facts?
5. if the write disappears, should the value still be evaluated as `drop(value)`?
6. would a more refined replacement force later type repair?

If you keep those six questions in mind, most of the source-backed positive and bailout families become much easier to predict.
