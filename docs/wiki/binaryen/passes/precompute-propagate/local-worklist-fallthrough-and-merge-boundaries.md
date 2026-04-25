---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md
  - ../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md
  - ../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../precompute/propagation-partial-precompute-and-gc-identity.md
---

# `precompute-propagate`: local worklist, fallthrough, and merge boundaries

This page is the middle layer of the `precompute-propagate` dossier. It cites the 2026-04-24 raw primary-source manifest for the tagged `version_129` contract and the 2026-04-25 current-main/code-map manifest for the fresh no-drift recheck.

The landing page and strategy page already explain the big idea:

- Binaryen runs the ordinary semantic `precompute` pass,
- then uses `LazyLocalGraph` to learn more local facts,
- then reruns the main evaluator once.

This page answers the harder question a future port actually needs:

- **what exact facts does Binaryen learn, from which nodes, and where does it deliberately stop?**

## Short version

The extra phase is **not** generic SCCP.
It is a small get/set worklist with these rules:

- prove some `local.set` values concrete
- prove some `local.get`s concrete only when **all** reaching sets agree
- let constant gets make more sets constant, and vice versa
- feed only the proven `local.get` constants into the second evaluator walk
- stop after that one extra walk

That is the real `version_129` contract.

## Where this logic lives

The key function is `propagateLocals(Function* func)` in Binaryen `version_129` and current-`main` `src/passes/Precompute.cpp`.

It depends most directly on:

- `LazyLocalGraph` from `src/ir/local-graph.h`
- `PrecomputingExpressionRunner`
- `Properties::getFallthrough(...)`
- the shared literal emitability checks in `canEmitConstantFor(...)`

## The actual pipeline inside `doWalkFunction(...)`

Binaryen's order is important:

1. run the ordinary bottom-up semantic precompute walk
2. run partial-select precompute once
3. if this is plain `precompute`, stop
4. if this is `precompute-propagate`, run `propagateLocals(...)`
5. if propagation learned any constant gets, rerun the main walk once
6. do **not** rerun partial-select precompute again here
7. refinalize the function

That means the extra phase is additive, but still deliberately bounded.

## What the propagation phase stores

Binaryen uses two internal maps:

- `setValues: LocalSet* -> Literals`
- `getValues: LocalGet* -> Literals`

Those maps do different jobs.

### `setValues`

This is an internal helper map.
It records which sets have already been proven to produce one concrete literal tuple.

### `getValues`

This is the visible payoff map.
The second full walk reads this map in `PrecomputingExpressionRunner::visitLocalGet(...)` and uses it to make more parent expressions evaluatable.

So the best mental model is:

- sets help solve the worklist,
- gets are what the second evaluator walk actually consumes.

## How Binaryen proves a set constant

`checkConstantSet(...)` does **not** ask whether the whole original set-value expression can be emitted directly as a replacement.
Instead it asks for the set value's **fallthrough value**:

- `precomputeValue(Properties::getFallthrough(set->value, ...))`

That is a subtle but important distinction.

## Why fallthrough matters

This lets Binaryen look through wrappers whose full expression might not be a simple constant replacement shape, while still learning the value that would flow out of the expression.

That is why propagation can work through some shapes like:

- `local.tee`
- wrappers whose fallthrough is still a concrete literal
- some value-preserving structured carriers

## The subtype filter on propagated set values

Binaryen does **not** propagate every concrete fallthrough value it sees.
It immediately checks:

- the value must be concrete, and
- `Type::isSubType(values.getType(), set->value->type)` must hold

This protects the pass from fallthrough facts that are valid only for an inner subexpression, not for the original full set value.

### Canonical warning case

Conceptually:

```wat
(local.set $x
  (ref.cast (ref struct)
    (ref.null any)))
```

The inner fallthrough null does **not** justify propagating `ref.null any` as if the whole cast expression had that type and behavior.

So the subtype filter is part of the real pass contract, not cleanup.

## How Binaryen proves a get constant

This is the heart of the phase.

For a `local.get` to become constant, Binaryen iterates all reaching sets from:

- `localGraph.getSets(get)`

and requires that every reaching source agree on the same concrete literal tuple.

If any incoming source disagrees or is unknown, propagation for that get stops.

## The exact consensus rule

A `local.get` is propagated only when all of the following are true:

- every relevant incoming set is proven constant
- all those constants are identical
- any function-entry value is also compatible with that same constant
- the final result is concrete

This explains the lit-test behavior much better than saying the pass “propagates through locals.”

### Positive merge case

Both paths write the same constant:

```wat
(local $x i32)
(if (local.get $cond)
  (then (local.set $x (i32.const 10)))
  (else (local.set $x (i32.const 10))))
(call $basic
  (i32.add (local.get $x) (local.get $x)))
```

The get can become `10`, so the parent add can become `20`.

### Negative merge case

Different incoming constants:

```wat
(local $x i32)
(if (local.get $cond)
  (then (local.set $x (i32.const 10)))
  (else (local.set $x (i32.const 20))))
(call $basic
  (i32.add (local.get $x) (local.get $x)))
```

The get does **not** become constant, because Binaryen requires exact agreement.

## Function-entry values: vars, params, and nondefaultable locals

The `nullptr` reaching-set case in `localGraph.getSets(get)` means “this read can see the function-entry value.”

Binaryen treats that case in three different ways.

### 1. Param entry values

If the local is a parameter, Binaryen gives up.

Reason:

- params are not compile-time constants here.

### 2. Defaultable local vars

If the local is a normal defaultable var, Binaryen uses the zero/default literal for that type.

That is why tests like `split-but-join-init0` can fold even when one path relies on the implicit entry value.

### 3. Nondefaultable local vars

If the local is nondefaultable and the graph still suggests a function-entry read, Binaryen gives up.

The source comment says this is either:

- an internal error, or
- unreachable-code imprecision in `LocalGraph`

Either way, the pass refuses to invent a value.

That conservative bailout is worth preserving exactly.

## The worklist edges

After the initial scan, Binaryen pushes newly proven constants onto a small worklist.

It then follows only two kinds of influence edges:

### Constant set -> influenced gets

If a `local.set` became constant, Binaryen checks the gets influenced by that set:

- `localGraph.getSetInfluences(set)`

### Constant get -> influenced sets

If a `local.get` became constant, Binaryen checks the sets whose values depend on that get:

- `localGraph.getGetInfluences(get)`

This is why the phase can discover chains like:

```wat
(local.set $x (i32.const 10))
(local.set $y (i32.add (local.get $x) (i32.const 1)))
(local.get $y)
```

The constant get for `$x` can make the later set to `$y` constant, which can then make later gets of `$y` constant.

## What the phase does **not** do

The easiest documentation mistake is to describe this as a general constant-propagation engine.

It is not.

### Not generic SCCP

It does not reason with full branch feasibility lattices.

### Not repeated convergence inside one pass run

It does one local worklist solve and one extra evaluator walk.
Anything beyond that is left to later pass executions or `--converge`.

### Not direct set rewriting as the public surface

The user-visible benefit is mainly that more `local.get`s read as concrete during the second walk.

### Not a bypass around emitability rules

Even if the evaluator learns a value semantically, it still must be re-emittable honestly.

## Why `local.tee` still appears in the test surface

Because set propagation uses **fallthrough values**, it can learn from some tee-like shapes.

That is why the all-features test contains a `through-tee` family instead of treating tees as automatically opaque.

But this is still not a license for arbitrary wrapper-insensitive propagation.
The subtype check and later emitability checks still apply.

## Why loops remain conservative

The propagation phase itself is local-graph-based, but the values it asks for still come from the bounded semantic evaluator.

That means loop-carried values are still conservative.
The phase does not magically turn into an open-ended symbolic executor for loop induction.

So examples like `deadloop` are teaching-important negatives:

- a loop may contain constants,
- but that does not mean a loop-carried get reaches one stable propagated literal under this pass.

## Why partial-select precompute needs a temporary heap cache

This point is easy to miss because it lives adjacent to propagation rather than inside `propagateLocals(...)` itself.

During speculative parent-into-select-arm evaluation, Binaryen uses a temporary `HeapValues` cache and clears it between arm trials.

Why:

- speculative arm evaluation must not pollute the real heap-value cache,
- especially in cases where one speculative arm no longer traps or no longer observes the same heap identity.

The dedicated `precompute-propagate-partial.wast` file locks exactly that boundary.

This matters here because propagation can unlock the extra walk that later exposes the bug if the speculative cache discipline is wrong.

## Practical WAT families to remember

### Positive families

- local-carried arithmetic constants
- identical-merge constants after `if` joins
- default-zero entry-value consensus for defaultable vars
- fallthrough propagation through `local.tee`
- chained local-derived constants (`x` makes `y` constant)

### Negative or bailout families

- differing incoming constants
- one constant arm plus one unknown arm
- param-dependent entry values
- nondefaultable-local entry reads
- loop-carried non-consensus values
- values known semantically but not safely emittable

## Best beginner summary

If plain `precompute` means:

- “evaluate what is already provable here,”

then `precompute-propagate` means:

- “solve a small local get/set consensus problem, feed the proven `local.get`s back into the same evaluator, and try one more full walk.”

That is the real Binaryen `version_129` contract future Starshine work should preserve. Current Starshine has no implementation of this local-flow phase yet; see [`./starshine-strategy.md`](./starshine-strategy.md) before treating any local `precompute` code as sibling coverage.
