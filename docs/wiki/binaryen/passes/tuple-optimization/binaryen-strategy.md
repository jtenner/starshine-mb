---
kind: concept
status: supported
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./scheduler-and-gates.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `tuple-optimization` Strategy

## Upstream Source Rule

- The living upstream oracle is Binaryen `version_129`.
- The core implementation is `src/passes/TupleOptimization.cpp`.
- The scheduler slot is confirmed in `src/passes/pass.cpp`.
- The earlier tuple peephole that folds `tuple.extract(tuple.make(...))` lives in `src/passes/OptimizeInstructions.cpp`, not in `TupleOptimization.cpp`.

## High-Level Intent

- Binaryen is not trying to "optimize multivalue in general."
- It is targeting a very specific bottleneck in Binaryen's own internal IR: tuple locals obscure per-lane local optimizations.
- The pass therefore lowers only those tuple locals that are clearly scratch storage and clearly do not escape.

The exact mental model is:

1. find tuple locals that only ever come from `tuple.make` or from copying another equally-safe tuple local
2. prove they are only ever consumed by `tuple.extract` or by copying into another equally-safe tuple local
3. split the tuple local into one scalar local per lane
4. leave the real dead-lane elimination and local simplification to later passes

## Phase 1: Gather Raw Use Counts

Binaryen tracks three per-local structures:

- `uses`
  Counts tuple-local uses conservatively.
  `local.get` counts as one use.
  `local.set` counts as one use.
  `local.tee` counts as two uses because it both writes and reads.
- `validUses`
  Counts only those uses that fit the tuple-scratch contract.
- `copiedIndexes`
  Records the undirected graph of tuple-local copies.

This design matters because the pass is not trying to prove full semantic equivalence from scratch. It is using a much cheaper rule:

- if every observed use is one of the approved tuple patterns, the local is safe
- if any use is outside the approved set, the local is poisoned

## Phase 2: Recognize Approved Writers

Binaryen approves tuple-local writes only when the tuple local is assigned from:

- `tuple.make`
- `local.get` of another tuple local
- `local.tee` of another tuple local, but only when the tee is reachable

Important detail:

- An unreachable inner tee is ignored rather than optimized through.
- That is not just a cleanup detail. In unreachable code, the apparent tuple type can be untrustworthy, so Binaryen refuses to count that as a valid tuple copy.

What Binaryen records for approved copies:

- increments `validUses` for both source and destination locals
- inserts each local into the other's `copiedIndexes` set

Why the copy graph is symmetric:

- If local `x` copies from local `y`, then a future invalid use of either one proves the whole connected component is unsafe.
- Binaryen therefore models copy-connected tuple locals as one safety component, not as isolated nodes.

## Phase 3: Recognize Approved Readers

Binaryen approves tuple-local reads only when they feed `tuple.extract` through:

- `local.get`
- reachable `local.tee`

That is the only consumer family the pass is willing to scalarize directly.

What Binaryen is explicitly not doing here:

- It is not optimizing arbitrary users of tuple values.
- It is not trying to forward tuple values through calls, returns, branches, or other general multivalue constructs.
- It is not rewriting blocks and returns just because they happen to carry multiple results.

## Phase 4: Mark Bad Components

Once raw and valid counts are collected:

- a tuple local with `uses > validUses` is immediately seeded as bad
- badness then propagates through the symmetric `copiedIndexes` graph

Why this propagation rule is the core safety invariant:

- A tuple local that looks safe on its own may still be copying from a tuple local that escapes elsewhere.
- Binaryen wants all tuple locals in the same copy-connected component to succeed or fail together.

This is the pass's defining conservative move.

## Phase 5: Select Good Locals

A tuple local is considered good when:

- it has at least one use
- it is not marked bad after propagation

Two consequences:

- unused tuple locals are not interesting here
- safety is component-wide, but rewriting is still local-based once the component is known good

## Phase 6: Allocate Fresh Scalar Locals

For every good tuple local:

- Binaryen allocates one fresh scalar local per lane
- those new locals are contiguous
- the pass stores a base index for the tuple local, from which the lane locals can be computed

The contiguous-local detail is not incidental.

- It keeps the rewrite simple.
- It lets later local passes treat the new scalar locals as an ordinary adjacent cluster.
- The pass asserts this contiguity while allocating.

## Phase 7: Rewrite Tuple Writers

Binaryen then walks the function again with a mapping applier.

When it sees a rewritten tuple `local.set` or `local.tee`:

- if the value is `tuple.make`, it emits one scalar `local.set` per tuple lane
- if the value is another tuple local, it emits one scalar `local.get` plus `local.set` per lane

Important detail for tuple-local copies:

- Binaryen uses the source tuple lane types, not blindly the target tuple type
- that preserves legal subtype relationships across the copied tuple as long as arity matches

## Phase 8: Rewrite Tuple Reads

When Binaryen sees:

```wat
(tuple.extract i
  (local.get $tuple))
```

or the tee equivalent, it replaces that with:

- a direct scalar `local.get` of the split lane local, or
- a `sequence(extra-tee-replacement, local.get lane)` when the source expression was a rewritten tee

This is how Binaryen preserves tee semantics without keeping the tuple local alive.

## The `replacedTees` Mechanism

The most specific implementation detail worth preserving in Starshine thinking is Binaryen's `replacedTees` map.

Why it exists:

- A rewritten tee no longer exists as one tuple-valued expression.
- But outer users may still conceptually read from that tee.
- Binaryen therefore remembers which replacement expression came from which original tee so it can append the correct scalar `local.get` later.

What this proves about upstream intent:

- tee handling is not a small corner case
- preserving the scalar value identity of the tee is part of the main transform contract

## What Binaryen Deliberately Leaves To Other Passes

This pass does not:

- delete dead scalar locals after splitting
- delete dead scalar sets created by the split
- fold `tuple.extract(tuple.make(...))`
- restructure arbitrary multivalue control flow
- optimize all tuple-typed expressions everywhere

That division of labor is intentional:

- `optimize-instructions` handles the direct `tuple.extract(tuple.make(...))` peephole first
- later local passes such as local simplification and cleanup realize the payoff from the scalar split

## The Most Important Porting Lesson

The upstream algorithm is simple because Binaryen starts from explicit tuple locals.

The actual transferable invariants are:

- do not optimize escaping tuple components
- treat copy-connected tuple traffic as one safety component
- preserve tee value ordering exactly
- expose scalar locals early enough that later local passes can finish the cleanup

Those invariants are the part Starshine must mimic exactly, even when its HOT-native implementation discovers the same family through different lifted shapes.

## Sources

- Archived project research note: [`../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md`](../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` earlier tuple peephole in `optimize-instructions`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>

