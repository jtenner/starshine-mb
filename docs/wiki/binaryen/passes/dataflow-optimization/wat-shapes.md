---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md
  - ../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md
  - ../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast
related:
  - ./binaryen-strategy.md
  - ./flat-ir-dataflow-ir-and-boundaries.md
  - ./starshine-port-readiness-and-validation.md
---

# WAT shapes for `dataflow-optimization` / `dfo`

This page is deliberately beginner-friendly.
The goal is not exact prettyprinted oracle output.
The goal is to teach which kinds of shapes `dfo` likes, which ones it ignores, and why. The 2026-04-25 and 2026-04-27 current-main rechecks found no teaching-relevant shape drift from the earlier `version_129` dossier. For how these shapes become Starshine tests, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Reading rule

For `dfo`, always read these shapes with one hidden prefix in mind:

- **assume `flatten` has already run**

So the interesting shapes are usually about explicit `local.set` / `local.get` traffic, not about pretty nested expression trees.

## Positive family 1: same constant from both sides of a merge

### Before flat-era graph simplification

```wat
(func (result i32)
  (local $x i32)
  (if
    (i32.const 1)
    (local.set $x (i32.const 7))
    (local.set $x (i32.const 7))
  )
  (local.get $x)
)
```

### What `dfo` conceptually sees

- one merged local value
- both incoming paths carry the same constant
- synthetic phi is redundant

### Why it is a positive

This is the cleanest phi-collapse family.
If the merged value is recognized as the same constant on every incoming path, `dfo` can replace later uses with that constant.

## Positive family 2: supported arithmetic chain becomes all-constant

### Before

```wat
(func (result i32)
  (local $a i32)
  (local $b i32)
  (local $c i32)
  (local.set $a (i32.const 4))
  (local.set $b (i32.const 5))
  (local.set $c
    (i32.mul
      (local.get $a)
      (local.get $b)
    )
  )
  (local.get $c)
)
```

### Why it is a positive

- the values are flat locals already
- the op is in the supported binary subset
- both inputs are constant in DataFlow IR
- nested `precompute` can turn the multiplication into one literal constant

## Positive family 3: `eqz` or comparison normalization on constant input

### Before

```wat
(func (result i32)
  (local $x i32)
  (local.set $x (i32.const 0))
  (i32.eqz (local.get $x))
)
```

### Why it is a positive

`eqz` is one of the explicitly supported unary families.
If the child becomes constant, the node can reach the all-constant-expression rule and then nested `precompute` can decide the final literal constant.

## Positive family 4: `select` with constant arms and constant condition

### Before

```wat
(func (result i32)
  (select
    (i32.const 11)
    (i32.const 22)
    (i32.const 0)
  )
)
```

### Why it is a positive

`select` is a first-class supported node in the graph.
If all three inputs are constant and the result type is concrete, it is a strong candidate for the nested-`precompute` fold path.

## Positive family 5: aggressive flatten-era combo pipeline

The official combo lit file proves that `dfo` belongs in shapes like:

```text
flatten -> simplify-locals-nonesting -> dfo -> -O3
```

A good mental model is:

- earlier flatten-era cleanup creates explicit local traffic
- `dfo` squeezes constant facts out of that flat local graph
- later ordinary cleanup removes the leftover flatten scaffolding

## Bailout family 1: non-flat nested value trees

### Example

```wat
(func (result i32)
  (i32.add
    (if (result i32)
      (i32.const 1)
      (i32.const 2)
    )
    (i32.const 3)
  )
)
```

### Why it is a bailout for `dfo` itself

This is a good shape for `flatten`, not for raw `dfo`.
Until flattening has happened, the pass's hard precondition is not met.

## Bailout family 2: unsupported opcode becomes unknown `Var`

### Example intuition

If the flat code uses an instruction outside the pass's supported unary/binary/select subset, the graph often records:

- child traffic was visited
- but the result itself is just an unknown `Var`

### Why that matters

The pass may still learn something about surrounding constants, but precision stops at the unsupported node.
So this is often a partial-information family, not a total failure family.

## Bailout family 3: loop-carried changing value

### Example intuition

```wat
(func (param $n i32) (result i32)
  (local $x i32)
  (local.set $x (i32.const 0))
  (loop $L
    ;; $x really changes across iterations
    ...
  )
  (local.get $x)
)
```

### Why it is a bailout

The reviewed source deliberately avoids rich loop phis.
A truly loop-varying value usually becomes an unknown loop-entry `Var` in the graph, which cuts off precise constant reasoning.

## Bailout family 4: EH

### Example intuition

```wat
(func
  (try
    (do
      ...)
    (catch_all
      ...)
  )
)
```

### Why it is a bailout

The reviewed graph builder explicitly says DataFlow does not support EH instructions yet.
This is an implementation boundary, not just a missing test.

## Bailout family 5: all inputs constant, but nested `precompute` still refuses

### Example intuition

Some trap-sensitive expressions can have constant children without reducing to a harmless literal constant.

### Why it is a bailout

`dfo` only commits the rewrite if nested `precompute` actually returns a `Const`.
If the temp function body is not a literal constant afterwards, the pass leaves the node alone.

## Preserved family: non-integer-centered traffic

Because the reviewed graph focuses on integer relevance, shapes centered on other value kinds are not where this pass shines.
That does not always mean hard failure.
It often means:

- no useful graph fact
- no rewrite
- let neighboring passes handle it instead

## What this pass is not trying to do

When looking at a shape, do **not** expect `dfo` to behave like:

- general copy propagation
- full constant propagation across all wasm types
- generic loop optimization
- late cleanup of flatten-created locals and structure

Those jobs belong elsewhere.

## Porting checklist from shapes

A future Starshine port should preserve these shape-level rules:

- require flatten-era shapes first
- optimize mainly integer-local graph traffic
- keep loops conservative
- treat unsupported nodes as precision barriers
- use nested `precompute` as the final constantization gate
- rely on later cleanup for leftover flat scaffolding

## Sources

- [`../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md)
- [`../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md`](../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md)
- [`../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md`](../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
