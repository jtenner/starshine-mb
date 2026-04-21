---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./size-model-and-dependency-order.md
  - ../string-gathering/index.md
---

# `reorder-globals` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen’s `reorder-globals` pass.

## Read this page with one mental model

Binaryen is trying to make important globals cheaper to encode by giving them smaller indices.

It is not asking:

- “which global has the prettiest name?”
- “which global was created most recently?”
- “which global is constant?”
- “which global should come first in source order?”

It is asking:

- “how often is each global index encoded?”
- “which globals must stay before other globals because of initializer dependencies?”
- “which valid order looks cheapest overall?”

## Quick glossary

- **hot global**: a global with many counted uses (`global.get` and/or `global.set`)
- **dependent global**: a global whose initializer reads another global
- **independent global**: a global with no initializer dependency on another global
- **public pass**: ordinary `reorder-globals`
- **always variant**: `reorder-globals-always`, which still sorts tiny modules for tests/internal callers

## Shape 1: a hotter independent global can move earlier

Before:

```wat
(module
  (global $a i32 (i32.const 10))
  (global $b i32 (i32.const 20))
  (func
    (drop (global.get $b))))
```

After, conceptually:

```wat
(module
  (global $b i32 (i32.const 20))
  (global $a i32 (i32.const 10))
  (func
    (drop (global.get $b))))
```

Why it rewrites:

- `$a` and `$b` are independent
- `$b` is hotter
- there is no dependency reason to keep `$a` first

## Shape 2: `global.set` counts as heat too

Before:

```wat
(module
  (global $a (mut i32) (i32.const 10))
  (global $b (mut i32) (i32.const 20))
  (func
    (global.set $b (i32.const 30))
    (global.set $b (i32.const 40))
    (drop (global.get $a))))
```

After, conceptually:

```wat
(module
  (global $b (mut i32) (i32.const 20))
  (global $a (mut i32) (i32.const 10))
  (func
    (global.set $b (i32.const 30))
    (global.set $b (i32.const 40))
    (drop (global.get $a))))
```

Why it rewrites:

- Binaryen counts both reads and writes
- two `global.set $b` uses make `$b` hotter than `$a`

That is a real source rule, not just a test artifact.

## Shape 3: dependency beats popularity

Before:

```wat
(module
  (global $a i32 (i32.const 10))
  (global $b i32 (global.get $a))
  (func
    (drop (global.get $b))
    (drop (global.get $b))))
```

After stays dependency-first:

```wat
(module
  (global $a i32 (i32.const 10))
  (global $b i32 (global.get $a))
  (func
    (drop (global.get $b))
    (drop (global.get $b))))
```

Why Binaryen refuses to move `$b` up:

- `$b` depends on `$a` in its initializer
- declaration validity comes before profitability

## Shape 4: a whole dependency chain must stay in order

Before:

```wat
(module
  (global $a i32 (i32.const 10))
  (global $b i32 (global.get $a))
  (global $c i32 (global.get $b))
  (func
    (drop (global.get $c))
    (drop (global.get $c))))
```

After still keeps:

```wat
$a -> $b -> $c
```

Why:

- `$c` may be the hottest declaration in the module
- but `$c` cannot appear before `$b`
- and `$b` cannot appear before `$a`

This is why `reorder-globals` is a dependency-constrained layout pass, not a pure count sort.

## Shape 5: an independent hot global can still beat a dependent chain root

Before:

```wat
(module
  (global $a i32 (i32.const 10))
  (global $b i32 (global.get $a))
  (global $c i32 (i32.const 30))
  (func
    (drop (global.get $b))
    (drop (global.get $b))
    (drop (global.get $c))
    (drop (global.get $c))
    (drop (global.get $c))))
```

A valid reordered shape is:

```wat
(module
  (global $c i32 (i32.const 30))
  (global $a i32 (i32.const 10))
  (global $b i32 (global.get $a))
  ...)
```

Why this can happen:

- `$c` is independent and hottest
- `$b` still depends on `$a`
- so Binaryen can move `$c` first while still keeping the `$a -> $b` chain valid

## Shape 6: a low-use prerequisite can move earlier because it unlocks a very hot dependent

Before, conceptually:

```wat
(module
  (global $a i32 (i32.const 0))
  (global $b i32 (global.get $a))
  (global $c i32 (global.get $b))
  (global $other i32 (i32.const 1))
  (func
    ;; many uses of $c
    ;; a few uses of $other
  ))
```

A non-greedy best order can be:

```wat
$a, $b, $c, $other
```

instead of:

```wat
$other, $a, $b, $c
```

Why:

- raw greed sees `$other` as hotter than `$a`
- but putting `$a` first unlocks `$b`, which unlocks very hot `$c`
- Binaryen therefore tries non-greedy candidate models such as summed-dependent counts

This family is one of the clearest reasons the pass does not rely on just one greedy sort.

## Shape 7: imports stay first even if defined globals are hotter

Before:

```wat
(module
  (import "a" "b" (global $imp i32))
  (global $def i32 (i32.const 10))
  (func
    (drop (global.get $def))
    (drop (global.get $def))))
```

After still keeps the import first:

```wat
(module
  (import "a" "b" (global $imp i32))
  (global $def i32 (i32.const 10))
  ...)
```

Why:

- imported globals are always ordered before defined globals
- Binaryen enforces that in the comparator even before heat is considered

## Shape 8: names do not matter

These two modules behave the same way for sorting purposes:

```wat
(global $a i32 ...)
(global $b i32 ...)
```

and

```wat
(global $z i32 ...)
(global $q i32 ...)
```

if their import status, dependencies, and counted uses are the same.

Why:

- Binaryen sorts by import status, count model, and original order
- not by symbolic name spelling

The lit suite has an explicit import-name flip check for this.

## Shape 9: public `reorder-globals` can deliberately do nothing on a small module

Before:

```wat
(module
  ;; fewer than 128 globals total
  (global $a i32 (i32.const 10))
  (global $b i32 (i32.const 20))
  (func
    (drop (global.get $b))))
```

After with the public pass may stay exactly the same.

Why:

- with fewer than `128` globals, Binaryen’s public production pass returns early
- the real encoded index cost has not changed yet

This is the single most important negative shape in the dossier.

## Shape 10: the `always` variant can still reorder the same small module

Using the same small module as above, `reorder-globals-always` may reorder it to:

```wat
(module
  (global $b i32 (i32.const 20))
  (global $a i32 (i32.const 10))
  ...)
```

Why:

- `reorder-globals-always` removes the public under-`128` cutoff
- it uses a synthetic smooth cost model so tests and internal callers can still observe meaningful reordering

That is why most shipped behavior examples for this pass live in `reorder-globals.wast`, not only in the “real” production test.

## Shape 11: `string-gathering` and `reorder-globals` are different kinds of reorder

After `string-gathering`, a module might look conceptually like this:

```wat
(module
  (global $string (ref string) (string.const "foo"))
  (global $user ... (global.get $string))
  ...)
```

The key idea is:

- `string-gathering` moved `$string` early enough so `$user` validates
- `reorder-globals` later decides the *best final* declaration order for size, still respecting that dependency

So if you see a string-global move, do not assume `reorder-globals` created it.
Often `string-gathering` did the validity-first move first.

## What this pass deliberately does not do

- It does not delete unused globals.
- It does not analyze CFGs or effects.
- It does not rewrite `global.get` / `global.set` sites one by one in Binaryen IR.
- It does not sort by names.
- It does not ignore imports or initializer dependencies.
- It does not always reorder small modules in public mode.

If you see one of those behaviors, you are probably looking at a different pass or at the `always` helper variant rather than the public production pass.

## Sources

- [`../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md`](../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
