---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0402-2026-04-26-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-ssa-primary-sources.md
  - ../../../raw/research/0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0207-2026-04-21-ssa-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/gtest/local-graph.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./merge-locals-entry-prepends-and-default-values.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../ssa-nomerge/wat-shapes.md
---

# `ssa` WAT shapes

This page is the beginner-friendly shape catalog for full Binaryen `ssa`. It is anchored by the committed primary-source manifest [`../../../raw/binaryen/2026-04-24-ssa-primary-sources.md`](../../../raw/binaryen/2026-04-24-ssa-primary-sources.md).

The most important rule to remember is:

- `ssa` and `ssa-nomerge` share the same analysis,
- but full `ssa` handles merged reads by creating a fresh merge local.

## Directly shipped `ssa.wast` shapes

These are the small families the official `test/lit/passes/ssa.wast` file proves directly.

## Shape 1: repeated parameter overwrites split into one-assignment locals

Before:

```wat
(func $bar (param $x (ref func))
  (local.set $x (ref.func $foo))
  (drop (local.get $x))
  (local.set $x (ref.func $bar))
  (drop (local.get $x)))
```

After, conceptually:

```wat
(func $bar (param $x (ref func))
  (local $1 (ref func))
  (local $2 (ref func))
  (local.set $1 (ref.func $foo))
  (drop (local.get $1))
  (local.set $2 (ref.func $bar))
  (drop (local.get $2)))
```

What this teaches:

- full `ssa` renames non-SSA writes into fresh locals
- later gets follow the exact rewritten source local
- each fresh local is assigned once

## Shape 2: default ref local becomes an explicit refined null/default

Before:

```wat
(func $refine-to-null (result (ref $A))
  (local $0 (ref null $A))
  (block $label (result (ref $A))
    (drop
      (br_on_cast $label (ref null $A) (ref $A)
        (local.get $0)))
    (unreachable)))
```

After, conceptually:

- the `local.get $0` is replaced by an explicit null/default value
- the parent `br_on_cast` sees a more refined child type
- the function needs `ReFinalize`

What this teaches:

- `ssa` is not only about fresh locals
- it also materializes implicit entry/default values when they are the only reaching source
- reference-typed default replacement can have typing consequences higher in the tree

## Shape 3: default tuple local becomes an explicit tuple default

Before:

```wat
(func $null-tuple (result funcref)
  (local $tuple (tuple i32 funcref))
  (tuple.extract 2 1
    (local.get $tuple)))
```

After, conceptually:

```wat
(func $null-tuple (result funcref)
  (tuple.extract 2 1
    (tuple.make 2
      (i32.const 0)
      (ref.null nofunc))))
```

What this teaches:

- entry/default replacement also applies to tuple locals
- the pass can materialize default values directly instead of leaving a `local.get`

## Source-derived full-merge shapes

These shapes are explicit in `SSAify.cpp`, but the tiny shipped lit file does not isolate them directly.
So they should be taught as source-derived from the owner file plus LocalGraph helper contracts.

## Shape 4: two explicit predecessor writes feed one merge local

Before:

```wat
(local $x i32)
(if
  (i32.const 1)
  (then
    (local.set $x (i32.const 10)))
  (else
    (local.set $x (i32.const 20))))
(drop (local.get $x))
```

After, conceptually:

- create a fresh merge local
- rewrite both explicit incoming values to `local.tee` into that merge local
- retarget the later get to the merge local

What this teaches:

- full `ssa` does not leave merged reads on the canonical slot
- it materializes a phi-like join with ordinary AST nodes

## Shape 5: one-arm param overwrite needs an entry prepend

Before:

```wat
(func (param $p i32)
  (if
    (i32.const 1)
    (then
      (local.set $p (i32.const 7))))
  (drop (local.get $p)))
```

After, conceptually:

- create a merge local
- prepend `local.set $merge (local.get $p)` at function entry
- tee the explicit incoming overwrite into the merge local
- retarget the later get to the merge local

What this teaches:

- parameter entry is a real incoming source
- params need prepended copies when they participate in a full-`ssa` merge

## Shape 6: one-arm ordinary local overwrite does not need an entry prepend

Before:

```wat
(local $x i32)
(if
  (i32.const 1)
  (then
    (local.set $x (i32.const 7))))
(drop (local.get $x))
```

After, conceptually:

- create a merge local
- tee the explicit overwrite into it
- do **not** prepend an `i32.const 0` store, because the merge local already defaults to zero

What this teaches:

- ordinary defaultable locals and params behave differently at merge entry
- that difference is part of correctness, not a stylistic choice

## Shape 7: unreachable reads are not precise proof targets

If LocalGraph sees a `local.get` in unreachable code, the helper may conservatively overestimate the entry/default source.
So the pass is not a perfect unreachable-code debugger.

What this teaches:

- `ssa` is optimization-grade analysis
- not exact symbolic provenance for impossible paths

## Shape 8: nondefaultable locals keep their weird entry cases

If the only source is a nondefaultable local's implicit entry and Binaryen cannot soundly materialize a default literal:

- it leaves the get alone

What this teaches:

- default replacement is not universal
- the pass still respects wasm type constraints

## The central contrast with `ssa-nomerge`

Before:

```wat
(if
  ...
  (then (local.set $x ...))
  (else (local.set $x ...)))
(local.get $x)
```

Full `ssa`, conceptually:

- create a merge local
- feed it from all incoming sources
- read the merge local

`ssa-nomerge`, conceptually:

- leave the later read on canonical `$x`
- do not materialize the join

That is the main sibling difference this folder exists to keep visible.

## Starshine shape caveat

Current Starshine does not expose full `ssa`, so these are Binaryen shapes, not local output guarantees. Starshine's active sibling uses HOT SSA destruction and predecessor copies; see [`./starshine-strategy.md`](./starshine-strategy.md) and [`../ssa-nomerge/starshine-hot-ir-strategy.md`](../ssa-nomerge/starshine-hot-ir-strategy.md).

## Practical rules a future reader should keep

- direct `ssa.wast` coverage is small but real
- merge-local families are source-derived from `SSAify.cpp`
- parameter-entry and ordinary-default entry are different cases
- full `ssa` uses `local.tee` and prepends instead of phi instructions
- full `ssa` is a public upstream pass, but not the default early no-DWARF sibling used in this repo's main optimize-path page
