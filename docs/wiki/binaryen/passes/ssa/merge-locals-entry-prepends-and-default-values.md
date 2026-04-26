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
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../ssa-nomerge/merge-shapes-and-canonical-slots.md
---

# `ssa`: merge locals, entry prepends, and default values

This page explains the single easiest thing to miss when moving from `ssa-nomerge` to full `ssa`:

- **full `ssa` does not leave merge reads on the canonical slot.**
- it creates a fresh merge local and rewrites incoming values to feed that local.

## Quick glossary

- **canonical slot**: the original local index from the input function
- **fresh set slot**: a new local index created for one rewritten `local.set`
- **merge local**: a fresh local allocated for one `local.get` with more than one reaching source
- **entry value**: the implicit incoming value represented as `nullptr` in LocalGraph
  - parameter entry for params
  - zero/null default entry for ordinary locals

## The source-backed core rule

In `SSAify.cpp`, when a `local.get` has more than one reaching set and `allowMerges` is true, Binaryen does the source-backed work captured in [`../../../raw/binaryen/2026-04-24-ssa-primary-sources.md`](../../../raw/binaryen/2026-04-24-ssa-primary-sources.md):

1. allocates a fresh merge local
2. retargets that get to the merge local
3. rewrites each explicit incoming set value to a `local.tee` into the merge local
4. prepends an entry `local.set` only when a parameter entry value is one of the incoming sources

So the pass is not simply "renaming locals until things look SSA-ish."
It is actively **materializing phi-like joins using ordinary AST nodes**.

## Why there is no phi instruction

The source comment says the AST has no phi instruction here.
So Binaryen models joins with:

- a fresh local for the merged value
- explicit writes into that local on all incoming paths

That is the practical meaning of the pass name.

## Explicit incoming sets become `local.tee`s

Suppose a read can be reached from two explicit sets.
Conceptually before:

```wat
(if
  (i32.const 1)
  (then
    (local.set $x (i32.const 4)))
  (else
    (local.set $x (i32.const 5))))
(drop (local.get $x))
```

Conceptually after full `ssa`:

```wat
(local $merge i32)
(if
  (i32.const 1)
  (then
    (local.set $x1
      (local.tee $merge
        (i32.const 4))))
  (else
    (local.set $x2
      (local.tee $merge
        (i32.const 5)))))
(drop (local.get $merge))
```

That is not verbatim shipped golden output.
It is the source-backed shape implied by `SSAify.cpp`:

- each explicit incoming value is rewritten to a tee of the merge local
- the later get reads the merge local

## Parameter-entry merges need prepends

If one incoming source is the original parameter entry value, Binaryen cannot rely on the new merge local already containing it.
So it prepends a function-entry copy.

Conceptually before:

```wat
(func (param $p i32)
  (if
    (i32.const 1)
    (then
      (local.set $p (i32.const 7))))
  (drop (local.get $p)))
```

Conceptually after full `ssa`:

```wat
(func (param $p i32)
  (local $merge i32)
  (local.set $merge (local.get $p))
  (if
    (i32.const 1)
    (then
      (local.set $p1
        (local.tee $merge
          (i32.const 7)))))
  (drop (local.get $merge)))
```

That function-entry `local.set` is the important full-`ssa`-only behavior.
`ssa-nomerge` does not do this because it leaves the merged read on the canonical slot instead.

## Default-entry merges for ordinary locals do **not** need prepends

Now compare an ordinary defaultable local:

```wat
(local $x i32)
(if
  (i32.const 1)
  (then
    (local.set $x (i32.const 7))))
(drop (local.get $x))
```

A tempting but wrong model is:

- prepend `local.set $merge (i32.const 0)`

That is not necessary.
The fresh merge local already starts at the default value.
So Binaryen can simply:

- create the merge local
- rewrite explicit incoming sets to tee into it
- leave the implicit default-entry path alone

This param-vs-default split is one of the easiest details to lose.

## Single-source entry values use a different path

If a get has exactly one reaching source and that source is the implicit entry value:

- params keep using the parameter slot
- defaultable locals may be replaced directly with an explicit default literal
- nondefaultable locals are left alone

So there are really two different entry-value stories:

- single-source entry handling for ordinary direct rewrites
- multi-source entry handling for full-`ssa` merge-local creation

## Reference defaults can trigger narrow refinalization

The dedicated `ssa.wast` file directly proves the easiest visible typed example here:

- replacing a reference-typed default local read with a more refined null/default can sharpen the parent expression's observed type

That is why `SSAify.cpp` sets a `refinalize` flag in those cases and runs `ReFinalize` afterward.

This is a narrow but real correctness rule.

## What the shipped `ssa.wast` file directly proves

Directly golden-locked:

- repeated param overwrites create fresh locals
- ref/null default replacement can require `ReFinalize`
- tuple default replacement works

## What this page teaches from source-derived behavior

Source-derived from `SSAify.cpp` plus LocalGraph helper contracts:

- merge-local creation
- explicit incoming `local.tee` insertion
- parameter-entry prepends
- ordinary-default-entry no-prepend behavior

That distinction should stay visible so the dossier is confident without pretending the tiny lit file covers every interesting merge case directly.

## Starshine status caveat

Current Starshine's active `ssa-nomerge` path can lower HOT overlay phis through predecessor copies, but that is not this Binaryen full-`ssa` merge-local contract. Local follow-along lives in [`./starshine-strategy.md`](./starshine-strategy.md); future-port sequencing and validation live in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Why `ssa-nomerge` is smaller

This page is also the cleanest answer to:

- what does `ssa` do that `ssa-nomerge` deliberately refuses?

Answer:

- `ssa` materializes the join
- `ssa-nomerge` leaves merged reads on the original slot and only untangles single-source regions

That is the central sibling split.
