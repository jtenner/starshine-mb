---
kind: concept
status: strong
last_reviewed: 2026-07-26
sources:
  - ./index.md
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
---

# `local-subtyping`: LUBs, dominance, and iteration

## Assignment LUBs

A local declaration must accept every value written by `local.set` and `local.tee`. Starshine now folds assignment types pairwise and chooses the narrowest common supertype that remains below the declared type.

Important cases:

- child plus child -> child;
- sibling concrete types -> nearest declared concrete parent;
- i31 plus struct -> `eq`;
- unrelated concrete function types -> `func`;
- exact function plus `nofunc` null bottom -> nullable exact function;
- any nullable input makes the result nullable.

Typed nulls use their bottom heap families for LUB reasoning: internal nulls use `none`, function nulls `nofunc`, continuation nulls `nocont`, extern nulls `noextern`, and exception nulls `noexn`.

## Gets and structural dominance

Gets do not contribute candidate types. They determine whether a nullable declaration may become non-null.

A non-null rewrite is admitted only when every relevant get is structurally dominated by a write under the pass's represented block/loop/if/branch/return/tail-call/throw/try-table analysis. Unsupported or ref-catch flow falls back to nullable.

## Iteration

Narrowing one local can sharpen a later assignment through:

- `local.get`;
- an adjacent select LUB;
- a call-ref target and result;
- a refinalized i31-valued if or block.

The module pass therefore rebuilds and reanalyzes until stable, bounded by the number of reference body locals plus one.

## Exactness and bottoms

Exact reference targets accept their matching exact value and the compatible bottom family. This is essential for Binaryen's unreachable incompatible-set test: `ref.func $f` plus `ref.null func` has nullable exact `$f` as its LUB, not broad `funcref`.

## Safety

- parameters stay signature-owned;
- tuples and numeric/vector locals are outside the pass;
- legacy `try` fails closed;
- control-result refinalization is shape-gated;
- historical validator-rejected Binaryen non-null outputs remain nullable in Starshine.
