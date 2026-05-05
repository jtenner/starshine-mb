---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md
  - ../../../raw/research/0463-2026-05-05-rse-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../../../src/passes/rse.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `rse` CFG And Value Tracking

This page corrects the easiest current `rse` mistake.
Binaryen `version_129` **does** run a pass-local CFG value-flow analysis for `rse`, but that analysis is still much narrower than LocalGraph/liveness dead-store elimination.

## The real tracking model

For every basic block, Binaryen stores:

- a `start` local-value array;
- an `end` local-value array;
- the block's collected `local.get` sites;
- the block's collected `local.set` / `local.tee` sites.

For each local, the value is one of:

- unknown/no useful value;
- a value-numbered expression/local fact;
- a block merge value number created when incoming predecessor values disagree.

That is enough to answer the pass's two real questions:

1. Does this write assign the same value number the target local already has?
2. Does this get have an equivalent local with a stricter static reference type?

## CFG flow, not LocalGraph/liveness

The implementation builds a CFG and flows facts through blocks.
The 2026-05-05 current-main recheck stayed aligned with that shape.
It does **not** use Binaryen `LocalGraph` or liveness to prove arbitrary writes dead.

The distinction matters:

- CFG value flow can prove that both paths into a block agree on the value currently in `$x`.
- Liveness dead-store elimination would prove that an older different-value write is never read before being overwritten.
- `rse` does the first kind of reasoning for value equality; it does not do the second kind of deletion.

## How block start values are derived

At the entry block, Binaryen initializes facts from function parameters and defaultable/nondefaultable local entries.
For later blocks:

- one predecessor: copy the predecessor `end` facts;
- many predecessors with the same real value: keep that value;
- many predecessors with different real values: synthesize a block-specific merge value;
- still-unseen predecessors during fixed-point convergence: treat them carefully so the work queue can converge.

The merge value is not a runtime value.
It is a value-numbering sentinel meaning “all paths reach here with some value represented by this merge slot.”

## How block end values are computed

Within a block, Binaryen processes collected local writes in order.
For a write RHS:

- if the RHS is a `local.get`, reuse the current value number of the referenced local;
- otherwise use ordinary `ValueNumbering` on the expression;
- first ask `Properties::getFallthrough(...)` for the fallthrough value when the RHS is wrapped in a shape whose visible value is not the outer expression itself.

Then the target local's current value becomes that RHS value.
The resulting per-local array becomes the block's `end` state.

## Why local-get retargeting needs the value map

During optimization, Binaryen also builds a map from value number to locals that currently hold that value.
When it visits a `local.get`, it can choose a different local with the same value number if that local's declared type is a strict subtype of the original local's type.

This is not expression substitution.
It is a local-index retarget:

```wat
(local.get $wide)
```

can become:

```wat
(local.get $narrow)
```

when `$wide` and `$narrow` hold the same value number and `$narrow`'s type validates where `$wide` was used.

## Examples of what the CFG flow enables

### Same value through a diamond

```wat
(if
  (then (local.set $x (i32.const 1)))
  (else (local.set $x (i32.const 1))))
(local.set $x (i32.const 1))
```

A straight-line-only pass would lose the fact at the join.
Binaryen `rse` can carry the agreed value through the block-start state, so the final same-value set is eligible.

### Different values through a diamond

```wat
(if
  (then (local.set $x (i32.const 1)))
  (else (local.set $x (i32.const 2))))
(local.set $x (i32.const 1))
```

The incoming values differ.
Binaryen must not pretend `$x` definitely holds `1`; the later write is not a same-value deletion.

### Copied locals

```wat
(local.set $a (ref.as_non_null (local.get $maybe)))
(local.set $b (local.get $a))
(local.get $b)
```

If `$a` and `$b` carry the same value number but `$a` has a narrower type, a later get may be retargeted to `$a`.
This is the kind of behavior the GC test surface protects.

## Relationship to Starshine infrastructure

Starshine already has useful local-analysis infrastructure in files such as `src/ir/use_def.mbt`, `src/ir/liveness.mbt`, and `src/ir/ssa_local.mbt`.
For a source-faithful first `rse` port, those files should be treated as optional substrates, not as permission to widen the semantics.

The pass needs:

- a HOT/basic-block view that can model predecessor joins;
- per-local value identity at block starts and ends;
- ordered local-get/local-set site scanning;
- reference-type comparison for refined local retargeting;
- type/writeback validation after rewrites.

Only after direct Binaryen parity is green should a wider liveness/dead-store variant be considered.
