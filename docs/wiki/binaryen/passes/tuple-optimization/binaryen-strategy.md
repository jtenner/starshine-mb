---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md
  - ../../../raw/research/0254-2026-04-22-tuple-optimization-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./scheduler-and-gates.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `tuple-optimization` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.
The reviewed official Binaryen release page on 2026-04-22 showed publish date **2026-04-01**, and the raw primary-source capture for this pass now records that provenance explicitly.

Core upstream files:

- `src/passes/TupleOptimization.cpp`
- `src/passes/pass.cpp`
- `src/passes/OptimizeInstructions.cpp`
- `src/wasm/wasm.cpp`
- `src/wasm/wasm-validator.cpp`
- `test/lit/passes/tuple-optimization.wast`

A narrow 2026-05-04 freshness check found no drift in the core tuple-opt pass file or dedicated lit file on current `main`, and no relevant drift in the tuple-specific scheduler / peephole sections that frame this pass.

## High-level intent

Binaryen is not trying to optimize “tuples everywhere.”
It is trying to remove a very specific obstacle to later local optimization:

- tuple locals can hide the fact that only one or two tuple lanes are still useful
- local-cleanup passes work much better on ordinary scalar locals than on one bundled tuple local

So upstream tuple-opt does this instead:

1. identify tuple locals that behave like scratch storage
2. reject any copy-connected component that escapes that role
3. split the remaining tuple locals into scalar locals
4. let later local passes finish the cleanup

That design is why the pass is both:

- tiny in code size
- important in scheduler placement

## The pass in one sentence

`tuple-optimization` is a conservative tuple-local scalarization pass whose real job is to expose dead lanes and dead copies to later local-cleanup passes.

## What the pass is not

It is important to say explicitly what upstream does **not** do here.

Binaryen tuple-opt does **not**:

- optimize arbitrary multivalue control-flow structure
- lower every tuple-producing expression in the function
- analyze CFG, dominance, effects, or liveness
- refinalize types globally after the rewrite
- fold direct `tuple.extract(tuple.make(...))`
- claim that every block / if / loop tuple shape is profitable to lower

That last point is directly supported by the source comment: Binaryen deliberately avoids broad lowering of blocks and similar constructs because multivalue can sometimes be better for code size.

## Phase 1: `doWalkFunction` cheap gates

The pass starts with two early exits:

- multivalue must be enabled
- the function must actually contain at least one tuple local

Those gates are easy to under-document, but they matter for both correctness and performance.

### Correctness meaning

If multivalue is disabled, tuple IR is simply out of scope.

### Performance meaning

Binaryen does not pay any body-walk or rewrite cost unless a tuple local is present.
So the pass is intentionally cheap on scalar-only functions.

## Phase 2: collect `uses`, `validUses`, and `copiedIndexes`

During the post-walk, Binaryen fills three per-local structures:

- `uses`
- `validUses`
- `copiedIndexes`

This is the entire analysis core.
There is no hidden heavy dataflow stage after it.

## `uses`: what Binaryen counts as tuple-local traffic

For tuple locals:

- `local.get` counts as one use
- `local.set` counts as one use
- `local.tee` counts as two uses

The tee rule matters because Binaryen wants to prove both halves are safe:

- the write into the tuple local
- the yielded tuple value read by the surrounding expression

If only one half were counted, the pass could accidentally treat an escaping tee as safe.

## `validUses`: the narrow approved writer and reader surface

A tuple-local use is considered valid only in a small set of cases.

### Approved writers

Binaryen accepts tuple-local writes only when the value is:

- `tuple.make`
- `local.get` of another tuple local
- reachable `local.tee` of another tuple local

### Approved readers

Binaryen accepts tuple-local reads only when `tuple.extract` reads from:

- `local.get` of a tuple local
- `local.tee` of a tuple local

This is the part beginners most often overgeneralize.
Upstream is **not** saying “this tuple is okay because its uses look mostly nice.”
It is saying “this tuple local is okay only if every observed use belongs to a known approved writer or reader family.”

## Why unreachable tees are treated specially

The source comment in `visitLocalSet` calls out an important corner case:

- if the inner tee is `unreachable`, Binaryen refuses to count that as a valid tuple-local copy

Why?

Because unreachable code can make the apparent tuple type unreliable.
In that state, the inner tee and outer tee may not even have the same tuple type, or the inner one may not be a real tuple in any useful semantic sense.

So the pass leaves that cleanup to earlier / neighboring cleanup passes instead of trying to be clever inside unreachable code.

## `copiedIndexes`: symmetric copy-connected components

When one tuple local copies another, Binaryen records the relation in both directions.
That is what `copiedIndexes` stores.

This means the pass reasons in terms of connected components, not isolated locals.

If local `x` copies local `y` and either side later escapes the approved surface, both are poisoned.
That conservative rule is the pass's central safety invariant.

## Phase 3: mark bad tuple components

After the walk, `optimize` seeds a work queue with every tuple local where:

- `uses > 0`
- `validUses < uses`

Those locals are immediately bad.
Binaryen then propagates badness across the symmetric copy graph using `UniqueDeferredQueue<Index>`.

This is a very small implementation detail with a big conceptual consequence:

- a tuple local that looks safe in isolation still fails if it is copy-connected to an escaping tuple local

## Phase 4: choose good tuple locals

A tuple local is good only if:

- it has at least one use
- it was not marked bad after propagation

Unused tuple locals are not interesting here.
The pass is trying to expose meaningful later cleanup opportunities, not to perform generic tuple-local bookkeeping for its own sake.

## Phase 5: allocate contiguous scalar locals

For every good tuple local, Binaryen allocates:

- one fresh scalar local per tuple lane
- contiguously

The mapping stored by the pass is:

- tuple-local index -> base scalar-local index

Everything else is computed by offset from that base.

That contiguous-local contract is part of the real implementation structure.
It keeps the rewrite simple and ensures later local passes see an ordinary cluster of scalar locals.

## Phase 6: `MapApplier` rewrites tuple writers

The rewrite phase is another post-walk over the function.

When a good tuple local is written from `tuple.make`:

- the pass emits one scalar `local.set` per lane

When a good tuple local is written from another tuple local:

- the pass emits one scalar `local.get` plus `local.set` per lane

### Important subtype detail

When rewriting a tuple-local copy, Binaryen uses the **source tuple's lane types** when building the scalar gets.
It does not blindly assume the destination lane types are identical.

That matters because tuple-local copies can be valid under subtyping.
The lit suite's `tuple.element.subtyping` test is the clearest example.

## Phase 7: `MapApplier` rewrites tuple readers

When Binaryen sees:

```wat
(tuple.extract i
  (local.get $tuple))
```

and `$tuple` is good, it becomes:

- a direct scalar `local.get` of the split lane local

That is the simplest visible payoff from the pass.
Later local passes can now see one lane at a time.

## The `replacedTees` contract

The most important internal detail to preserve conceptually is `replacedTees`.

Why it exists:

- a tuple `local.tee` is both a write and an expression result
- after scalarization, that original tuple-valued expression no longer exists as one node
- outer users still need the correct yielded lane value, in the correct order

So Binaryen records which replacement expressions came from tuple tees and later lowers tee users as:

- the scalarized side-effect work
- followed by a `local.get` of the selected lane

This is how upstream preserves tee semantics without keeping the tuple local itself alive.

## Why `OptimizeInstructions` is a separate neighbor

The tuple-specific `visitTupleExtract` peephole in `OptimizeInstructions.cpp` handles:

- direct `tuple.extract(tuple.make(...))`

That happens earlier than tuple-opt by design.

So the division of labor is:

- `optimize-instructions`: direct tuple peepholes on expression structure
- `tuple-optimization`: tuple-local scalarization
- later local passes: dead-lane / dead-copy cleanup after scalarization

A future port that merges those responsibilities into one pass may still be correct, but it would be departing from the way Binaryen currently structures the optimization story.

## Scheduler meaning

`pass.cpp` places tuple-opt:

- after `code-pushing`
- before `simplify-locals-nostructure`
- behind a multivalue feature gate

The comment in `pass.cpp` also makes two motivations explicit:

- run before local opts because splitting tuples helps them
- but not too early, because `optimize-instructions` can already remove tuple-related things first

That means the pass's meaning is partly defined by its neighborhood.
It is not just a bag-of-rewrites entry.

## The practical no-DWARF neighborhood

In the canonical no-DWARF function path, the relevant slice is:

- `precompute`
- `code-pushing`
- `tuple-optimization`
- `simplify-locals-nostructure`
- `vacuum`

The saved generated-artifact optimize log also shows repeated later nested reruns of the same core neighborhood, using `precompute-propagate` in place of the top-level `precompute`.

So tuple-opt matters in both:

- top-level preset reconstruction
- nested optimize-after-other-pass reasoning

## Shipped-test reading guide

The dedicated lit file teaches a few especially durable lessons.

### Positive lessons

- write-only tuple locals still split (`just-set`)
- tuple-local copies are transitive (`tee`, `set-after-set`, `chain-3`)
- tuple tees preserve yielded scalar values (`just-tee`, `tee-chain`)
- subtyping across tuple-local copies must stay valid (`tuple.element.subtyping`)

### Negative lessons

- whole-tuple escapes poison the whole copy component (`just-get-bad`, `corruption-*`, `chain-3-corruption`)
- calls returning tuples are not handled here (`set-call`)
- tuple ops with no tuple local are left alone (`make-extract-no-local*`)
- `block`-produced tuple values are not currently lowered here (`set-of-block`)
- unreachable tuple-like traffic should not crash or over-optimize (`unreachability`, `unreachable.tuple.extract`)

## Most important beginner correction

A safe beginner summary is:

- Binaryen tuple-opt is a conservative tuple-local splitter whose main customer is later local-cleanup passes.

An unsafe beginner summary is:

- Binaryen tuple-opt lowers tuple or multivalue structure generally.

The second reading is not what the code or tests show today.

## Porting contract

A future implementation should preserve these invariants even if the host IR is very different:

1. multivalue gate
2. tuple-local existence gate
3. `uses` versus `validUses` safety model
4. copy-connected component poisoning
5. reachable-tee conservatism in unreachable code
6. per-lane scalar replacement
7. tee result identity and ordering
8. source-lane type preservation across copied tuple locals
9. division of labor with earlier tuple peepholes
10. scheduler placement before local-cleanup passes

## Sources

- [`../../../raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md)
- [`../../../raw/research/0254-2026-04-22-tuple-optimization-primary-sources-and-code-map-followup.md`](../../../raw/research/0254-2026-04-22-tuple-optimization-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md`](../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast>
