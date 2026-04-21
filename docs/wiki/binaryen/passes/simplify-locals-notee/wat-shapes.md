---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0166-2026-04-21-simplify-locals-notee-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.txt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ../simplify-locals/wat-shapes.md
  - ../simplify-locals-notee-nostructure/wat-shapes.md
---

# `simplify-locals-notee` WAT shapes

This page focuses on the shapes beginners are most likely to misread.

## Reading rule

When you inspect a `simplify-locals-notee` rewrite, always ask two questions separately:

1. would this require creating a new `local.tee`?
2. would this require creating or improving structured control-flow results?

For this pass:

- question 1 must stay **no**
- question 2 may still be **yes**

## Positive shapes

## 1. Single-use sink

Before:

```wat
(local.set $x EXPR)
(drop (local.get $x))
```

After, when safe:

```wat
(drop EXPR)
```

Why it works:

- only one later use
- no tee needed
- ordinary direct sinking is still allowed

## 2. Structured `if` result formation without tees

Before:

```wat
(if COND
  (then
    (local.set $a A))
  (else
    (local.set $a B)))
(drop (local.get $a))
```

After, conceptually:

```wat
(drop
  (if (result t) COND
    (then A)
    (else B)))
```

Why it matters:

- this is the main shape that proves `-notee` is not `-nostructure`
- the dedicated upstream `simplify-locals-notee` fixture exists largely to show this contrast

## 3. Named block branch-payload formation

Before:

```wat
(block $out
  ...
  (local.set $b V1)
  (br $out)
  ...
  (local.set $b V2))
(drop (local.get $b))
```

After, conceptually:

```wat
(drop
  (block $out (result t)
    ...
    (br $out V1)
    ...
    V2))
```

Again, no tee is needed here.
The pass is using structure, not multi-use tee sinking.

## 4. Plain block-result simplification

Before:

```wat
(local.set $z
  (block (result i32)
    (i32.const 5)))
(drop (local.get $z))
```

After, conceptually:

```wat
(drop
  (block (result i32)
    (i32.const 5)))
```

## Negative and bailout shapes

## 1. Multi-use sink that would need a tee

Before:

```wat
(local.set $x EXPR)
(use-1 (local.get $x))
(use-2 (local.get $x))
```

Full `simplify-locals` may eventually consider:

```wat
(use-1 (local.tee $x EXPR))
(use-2 (local.get $x))
```

`-notee` will not.
That is its signature no-rewrite family.

## 2. Effect-order barriers

Before:

```wat
(local.set $x EXPR)
(call $impure)
(drop (local.get $x))
```

Usually preserved if moving `EXPR` past the call would change effect ordering.

## 3. Throw / try-region barriers

Before:

```wat
(local.set $x EXPR_THAT_MAY_THROW)
(try
  (do
    ...
    (drop (local.get $x))))
```

The pass is conservative here because motion into a `try` can change what gets caught.

## 4. Non-linear control-flow poison

Before:

```wat
(block $b
  ...
  (br_if $b COND)
  ...
  (drop (local.get $x)))
```

Once the linear trace model loses confidence, pending sink facts are dropped instead of guessed through.

## Close-but-different sibling shapes

## `-notee` versus `-nostructure`

If the interesting rewrite is a new result-typed `if` or block, then:

- `-notee` may still do it
- `-nostructure` may not

## `-notee` versus `-notee-nostructure`

If the interesting rewrite depends on structure at all, then:

- `-notee` may still do it
- `-notee-nostructure` may not

## `-notee` versus `-nonesting`

If the sink is structurally legal but would create new nesting, then:

- `-notee` may still do it
- `-nonesting` may not

## Quick checklist for future port reviews

When evaluating a candidate `simplify-locals-notee` port, confirm all of these:

- single-use direct sinks still work
- structured `if` and block result formation still works
- multi-use tee creation does not happen
- effect and EH barriers still block unsafe movement
- late copy cleanup and dead-set cleanup still run

If a candidate implementation fails any of those, it is probably implementing the wrong sibling variant.
