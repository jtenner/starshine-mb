---
kind: concept
status: strong
last_reviewed: 2026-09-11
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

## Tee assignment type and result type

A `local.tee` contributes its operand type to the written local's assignment
LUB. Its stack result has the local's declared storage type. Those types differ
when another assignment keeps the local wider than this operand. A following
tee or set must use the declared result, or it can narrow its destination to a
type that the emitted stack value does not satisfy. A later iteration can refine
that result after the carrier's declaration has itself narrowed.

`src/passes/local_subtyping_dew_tee_type_test.mbt` covers a struct passed through
two tees while a later array assignment keeps the first local at `eqref`. Both
locals retain a compatible common type, the pass still narrows their declarations,
and the output validates. The old transform emitted an invalid second tee.

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
