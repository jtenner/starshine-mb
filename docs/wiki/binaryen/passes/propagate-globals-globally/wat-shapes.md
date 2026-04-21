---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
  - ../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-and-startup-boundaries.md
  - ../simplify-globals/index.md
---

# `propagate-globals-globally` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `propagate-globals-globally` pass.

## Read this page with one mental model

Binaryen is not asking:

- "can I replace this global everywhere?"

It is asking a smaller, more precise question:

- "is this a startup-safe global expression, and do all of its `global.get` inputs already have known startup replacements?"

## Important note about the examples

The `after` snippets are **conceptual**.
Real Binaryen output may preserve surrounding declaration structure or leave later folding to other utilities.
What matters here is the value-flow boundary and rewrite scope.

## Quick glossary

- **startup-safe expression**: one of the curated expression families the pass accepts in startup/global positions
- **known startup expression**: a startup-safe expression whose global inputs are already known and can therefore be substituted away
- **active offset**: the offset of an active data or active element segment
- **code use**: a `global.get` inside ordinary executable function code; this pass does not own that surface

## Shape 1: direct global-to-global propagation

Before:

```wat
(global $a i32 (i32.const 10))
(global $b i32 (global.get $a))
```

After, conceptually:

```wat
(global $a i32 (i32.const 10))
(global $b i32 (i32.const 10))
```

Why it rewrites:

- the initializer is startup-safe
- the `global.get` input is already known

## Shape 2: startup arithmetic over a known global

Before:

```wat
(global $base i32 (i32.const 8))
(global $off i32 (i32.add (global.get $base) (i32.const 4)))
```

After, conceptually:

```wat
(global $base i32 (i32.const 8))
(global $off i32 (i32.const 12))
```

or equivalently a rewritten startup expression with the `global.get` removed.

Why it matters:

- the pass is not limited to direct aliasing
- unary/binary startup expressions are part of the real contract

## Shape 3: startup `select` over known inputs

Before:

```wat
(global $cond i32 (i32.const 1))
(global $x i32 (i32.const 11))
(global $y i32 (i32.const 22))
(global $z i32 (select (global.get $x) (global.get $y) (global.get $cond)))
```

After, conceptually:

```wat
(global $z i32 (i32.const 11))
```

or at least a rebuilt `select` with known operands substituted.

Why it matters:

- `Select` is explicitly in the accepted startup-safe subset
- this is a good example of the pass owning expression chains, not just aliases

## Shape 4: active data offset propagation

Before:

```wat
(global $off i32 (i32.const 8))
(data (global.get $off) "abc")
```

After, conceptually:

```wat
(global $off i32 (i32.const 8))
(data (i32.const 8) "abc")
```

This is one of the most important shapes in the whole folder because it proves the pass is about startup expressions broadly, not only global declarations.

## Shape 5: active element offset propagation

Before:

```wat
(table $t 4 funcref)
(func $f)
(global $off i32 (i32.const 1))
(elem (table $t) (global.get $off) func $f)
```

After, conceptually:

```wat
(table $t 4 funcref)
(func $f)
(global $off i32 (i32.const 1))
(elem (table $t) (i32.const 1) func $f)
```

Why it rewrites:

- active elem offsets are a first-class module-level rewrite target in the real implementation

## Shape 6: startup string-expression propagation

Before:

```wat
(global $lhs (ref null string) (string.const "a"))
(global $rhs (ref null string) (string.const "b"))
(global $both (ref null string)
  (string.concat (global.get $lhs) (global.get $rhs)))
```

After, conceptually:

```wat
(global $both (ref null string)
  (string.concat (string.const "a") (string.const "b")))
```

and possibly later to an even simpler form.

Why it matters:

- the pass's startup-safe subset explicitly includes several `string.*` nodes
- this explains why the pass is a meaningful neighbor of `string-gathering`

## Shape 7: ordinary function-body use is preserved

Before:

```wat
(global $a i32 (i32.const 10))

(func $use (result i32)
  (global.get $a)
)
```

After, conceptually:

```wat
(global $a i32 (i32.const 10))

(func $use (result i32)
  (global.get $a)
)
```

Why it stays:

- this public pass stops before function-body propagation
- that broader work belongs to `simplify-globals*`

## Shape 8: non-startup-safe expressions bail out

Before:

```wat
(global $g i32
  ;; pretend the initializer uses a form outside the pass's startup-safe subset
  (...complex non-global-safe expression...)
)
```

After, conceptually:

```wat
;; preserved
```

Why it matters:

- this pass owns a curated startup subset, not all possible initializer IR

## Shape 9: runtime-write-sensitive families are out of scope

Before:

```wat
(global $a (mut i32) (i32.const 10))
(func $set
  (global.set $a (i32.const 20))
)
(func $use (result i32)
  (global.get $a)
)
```

After, conceptually:

```wat
;; function-body use preserved for this pass
```

Why it matters:

- runtime current-value reasoning is not this pass's job
- broader simplify-globals-family analysis owns that surface

## Positive summary

The pass is strongest on:

- startup-safe global initializer chains
- startup arithmetic / select / string expressions whose global inputs are known
- active data offsets
- active elem offsets

## Negative summary

The pass deliberately stops short of:

- ordinary function-body `global.get` propagation
- broad runtime dataflow
- read-only-to-write cleanup
- dead `global.set` cleanup
- optimizing-family reruns

## Beginner rule of thumb

If the rewrite can be explained as:

- "during module startup, this global initializer or active offset can already substitute known global expressions"

then it is a good candidate for `propagate-globals-globally`.

If you need to say:

- "during ordinary execution, this function body can now treat the global as constant"

you are probably talking about `simplify-globals*`, not this pass.
