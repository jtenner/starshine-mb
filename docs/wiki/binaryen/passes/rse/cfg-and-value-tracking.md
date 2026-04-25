---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `rse` Value Tracking And Barrier Rules

This page corrects the easiest `rse` mistake in the older dossier.
Binaryen `version_129` does **not** run a CFG predecessor-merge analysis for this pass.
It keeps one straight-line value-number fact per local and forgets that fact at conservative barriers.

## The real tracking model

For each local, Binaryen remembers:

- no trusted value, or
- one value-numbering result for the expression currently believed to be in that local.

That is all.

There is no pass-local state for:

- predecessor sets;
- merged value alternatives;
- LocalGraph incoming values;
- liveness-backed use sets;
- copied-local provenance chains.

The result is deliberately simple and cheap.

## Why value numbering matters

The remembered value is not a textual WAT snippet.
It is a value-numbering result.
That lets the pass answer “does this RHS equal the current local value?” in Binaryen's semantic value-numbering domain rather than by string comparison.

This enables the important positive case:

```wat
(local.set $x VALUE)
(local.set $x VALUE)
```

where the second write can be removed if both `VALUE` expressions number the same way and no barrier cleared `$x` in between.

## Why `local.get` still matters

`visitLocalGet` does not directly rewrite the get expression.
Instead, when the remembered expression's type is a subtype of the `local.get` type, it refines the value-numbering result for the get.

That matters for two reasons:

- later same-value checks can succeed because the get carries the known value number;
- GC/reference tests can preserve narrower type facts without an unsafe syntactic substitution.

## Barrier rule: forget rather than merge

When a construct makes the straight-line fact unsafe, Binaryen clears remembered values.
The corrected source-backed rule is:

- use precise single-local clearing when a construct invalidates one target local;
- use all-local clearing when control/effect boundaries make every remembered local fact suspect.

This is simpler and more conservative than predecessor dataflow.

## Examples of barriers

The source's clear-all and clear-local cases cover broad families, including:

- non-linear control transfer such as breaks and throws;
- loops and conditional structures where one linear current value is not enough;
- calls and other operations that may interact with local or global state;
- memory/table/atomic/GC forms where the pass chooses not to preserve facts;
- continuation/pop forms and newer feature surfaces that should not inherit stale local facts accidentally.

The important teaching point is not the exhaustive list.
The important point is the policy: when unsure, forget.

## What this means for shapes

### Same-value repeated writes can fold

```wat
(local.set $x (i32.const 1))
(local.set $x (i32.const 1))
```

The second set can fold because `$x` still has the same remembered value.

### Different overwritten writes are not enough

```wat
(local.set $x (i32.const 1))
(local.set $x (i32.const 2))
```

This is not an `rse` proof by itself.
Binaryen remembers the newer value, but the older different-value set is not deleted merely because it is overwritten.

### Branch joins do not become exact facts

```wat
(if
  (then (local.set $x (i32.const 1)))
  (else (local.set $x (i32.const 1))))
(local.set $x (i32.const 1))
```

A more ambitious dataflow pass might prove the post-if value.
`version_129` `rse` does not rely on such a join proof; barriers clear facts conservatively.

## Relationship to Starshine infrastructure

Starshine already has useful local-analysis infrastructure in files such as `src/ir/use_def.mbt`, `src/ir/liveness.mbt`, and `src/ir/ssa_local.mbt`.
Those may be useful for a deliberate future extension, but they are not required to match the reviewed Binaryen `rse` baseline.

The source-faithful Starshine port should begin with:

- per-local current-value identity;
- same-value set/tee shell removal;
- local-get type/value refinement if the HOT representation supports it cleanly;
- conservative invalidation boundaries.

Only after direct Binaryen parity is green should a wider liveness/dataflow variant be considered.
