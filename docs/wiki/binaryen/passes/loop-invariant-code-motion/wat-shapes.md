---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./effects-loops-and-hoisting-rules.md
---

# WAT shape catalog for `loop-invariant-code-motion`

This page catalogs the main shape families beginners should look for when reading Binaryen LICM output.

## Positive family 1: simple invariant arithmetic

Before:

```wat
(func $f (param $x i32) (param $y i32)
  (loop $L
    (drop
      (i32.add
        (local.get $x)
        (local.get $y)))))
```

After the LICM-style rewrite shape:

```wat
(func $f (param $x i32) (param $y i32) (local $tmp i32)
  (local.set $tmp
    (i32.add
      (local.get $x)
      (local.get $y)))
  (loop $L
    (drop (local.get $tmp))))
```

Meaning:

- the value does not change across iterations
- Binaryen computes it once before the loop
- the loop reuses it through a temp local

## Positive family 2: staged child-then-parent hoisting

Before:

```wat
(loop $L
  (drop
    (i32.mul
      (i32.add (local.get $x) (i32.const 1))
      (local.get $y))))
```

Typical fixed-point story:

1. hoist `i32.add(x, 1)`
2. later hoist the enclosing `i32.mul(tmp, y)`

Meaning:

- LICM is iterative
- one round can expose a better second round

## Positive family 3: reused invariant subtree

Before:

```wat
(loop $L
  (drop (i32.add (local.get $x) (local.get $y)))
  (drop (i32.mul (i32.add (local.get $x) (local.get $y)) (i32.const 3))))
```

The exact emitted form may vary, but the beginner expectation is:

- Binaryen prefers one temp-localized pre-loop computation over recomputing the same invariant value each iteration

## Bailout family 1: loop-carried local dependency

```wat
(loop $L
  (local.set $x (i32.add (local.get $x) (i32.const 1)))
  (drop (i32.mul (local.get $x) (i32.const 2))))
```

Why it stays:

- `$x` changes inside the loop
- the value is not invariant for the loop

## Bailout family 2: memory-sensitive load

```wat
(loop $L
  (i32.store (local.get $p) (local.get $v))
  (drop (i32.load (local.get $p))))
```

Why it stays:

- the pointer may be invariant
- the memory contents are not proven invariant

## Bailout family 3: trap-capable expression

```wat
(loop $L
  (drop (i32.div_s (local.get $x) (local.get $y))))
```

Why it may stay:

- hoisting might change when the trap happens
- LICM is conservative about trap timing

## Bailout family 4: call inside the loop

```wat
(loop $L
  (drop (call $helper (local.get $x))))
```

Why it usually stays:

- calls are observable effects in the general case
- LICM is not a generic call-hoisting pass

## Bailout family 5: structural control node

```wat
(loop $L
  (br_if $L (local.get $cond)))
```

Why it stays:

- LICM is about reusable value expressions
- control nodes are not the normal rewrite surface

## Mixed family: some children move, some parents stay

Before:

```wat
(loop $L
  (drop
    (i32.add
      (i32.mul (local.get $x) (i32.const 4))
      (i32.load (local.get $p)))))
```

Possible outcome:

- `i32.mul(x, 4)` may move if `x` is invariant
- `i32.load(p)` may stay if loop memory effects block it
- the full parent add may then stay because not all children are hoistable

This mixed case is important because it shows LICM is not all-or-nothing.

## What the pass is not trying to do

LICM is not trying to:

- flatten control flow
- fold constants like `precompute`
- find equal nearby trees like `local-cse`
- sink code deeper like `code-pushing`
- rewrite whole local webs like `simplify-locals`

## Practical reading rule

When reading candidate LICM output, ask these questions in order:

1. does the value stay the same across loop iterations?
2. would computing it before the loop preserve effects and traps?
3. can every required child value also exist before the loop?
4. is the node a reusable value rather than a structural control form?

If the answer to any of those becomes “no,” expect a bailout.

## Sources

- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>
