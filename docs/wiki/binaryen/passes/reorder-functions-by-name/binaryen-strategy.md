---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md
  - ../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md
  - ../../../raw/binaryen/2026-05-05-reorder-functions-current-main-recheck.md
  - ../../../raw/research/0475-2026-05-05-reorder-functions-current-main-recheck.md
  - ../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md
  - ../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./lexical-order-proof-and-boundaries.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../reorder-functions/index.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
  - ../reorder-types/index.md
---

# Binaryen `reorder-functions-by-name` strategy

## The pass in one sentence

Binaryen `reorder-functions-by-name` sorts the module's function declaration list by ascending internal function name and leaves the function bodies themselves alone.

## Why this pass is easy to misread

The pass is tiny enough that it can disappear into the shadow of [`../reorder-functions/index.md`](../reorder-functions/index.md). But upstream gives it:

- its own public pass name,
- its own registration string,
- its own constructor in `ReorderFunctions.cpp`,
- and its own dedicated lit file.

So the first teaching rule is:

- do not collapse it into the frequency-based sibling.

## Public surface

`pass.cpp` exposes two public passes from the same source file:

- `reorder-functions-by-name`
- `reorder-functions`

The descriptions tell the honest story:

- `reorder-functions-by-name` is useful for debugging;
- `reorder-functions` sorts by access frequency.

That means the family split is intentional, not an incidental implementation detail.

## The algorithm is one sort

In Binaryen `version_129`, the entire implementation of `reorder-functions-by-name` is one sort over `module->functions`.

The comparator is:

- `a->name < b->name`

So the pass orders function declarations by **ascending internal name**.

The same pass also reports:

- `requiresNonNullableLocalFixups() = false`

That matches the real mutation surface: declaration order only, with no local/body/type repair work.

There is no preliminary analysis phase. There is no call-counting phase. There is no post-sort repair phase inside this pass.

## What the pass depends on

The real dependency surface is tiny:

- pass infrastructure to run a module pass,
- the module's `functions` vector,
- Binaryen `Name` ordering,
- ordinary vector sorting.

Notably absent from the source contract:

- CFG reasoning,
- effect analysis,
- liveness,
- dominance,
- SSA,
- type refinalization,
- local repair,
- label repair,
- export/start/element scanning.

That absence is part of the contract. This is a declaration-order pass, not a body-transform pass.

## Why upstream says it exists

The registration text frames the pass as useful for debugging. That keeps the beginner mental model honest.

This pass is not trying to:

- shrink raw binary size,
- improve gzip size,
- estimate runtime hotness,
- or expose new body-level simplification opportunities.

Instead, it gives Binaryen a deterministic lexical function order that is easier for humans to inspect and compare.

## The sibling split matters

Because both passes live in `ReorderFunctions.cpp`, the cleanest teaching split is:

- shared substrate: reorder the module's function list;
- `reorder-functions-by-name`: ascending lexical name order;
- `reorder-functions`: descending static-use counts with descending-name tie breaks.

That distinction matters for future parity work. A port that fuses them into one vague reorderer would lose public CLI behavior.

## Positive family 1: scrambled names normalize lexically

If the module function list is in a surprising order like:

- `$zebra`
- `$apple`
- `$mid`

then `reorder-functions-by-name` wants:

- `$apple`
- `$mid`
- `$zebra`

That is the main real rewrite family.

## Positive family 2: already sorted modules become no-ops

If the function list is already in ascending lexical name order, this pass does nothing.

That is useful for debugging because it gives a stable normalization target.

## Positive family 3: body content is irrelevant

Unlike the sibling pass, function bodies do not affect the order at all. A function with many callers or table mentions still stays wherever its **name** puts it.

That is the biggest conceptual contrast with `reorder-functions`.

## Important negative families

### No count model

The pass does not inspect:

- direct calls,
- start function,
- exports,
- element segments,
- `ref.func`.

If a reader starts talking about hot helpers or static reference surfaces, they have shifted into the sibling pass's logic.

### No body mutation

The pass only reorders declarations. It does not rewrite function contents.

### No legality/repair phase

There is no type or control-flow repair logic in the pass because the implementation does not touch those surfaces.

## Interactions with nearby passes

### With `reorder-functions`

This is the most important comparison. Both passes reorder the same declaration list, but they optimize for different things:

- by-name: debugger readability and deterministic lexical order;
- plain reorder: static-use-count-based layout.

### With `reorder-globals`, `reorder-locals`, and `reorder-types`

Those neighbors sound similar, but they are algorithmically heavier:

- `reorder-globals` has dependency and size-threshold logic;
- `reorder-locals` must repair uses and metadata;
- `reorder-types` has legality and graph-order concerns.

`reorder-functions-by-name` has none of that.

## What a future Starshine port must preserve

At minimum:

1. separate public pass identity from `reorder-functions`;
2. ascending-name comparator;
3. no body-driven ordering;
4. no call/export/start/element counting;
5. debugging-oriented framing;
6. coherent function-index remapping in Starshine, even though that remapping is not visible as complex logic in Binaryen's tiny source file.

## Common beginner mistakes to avoid

- **Mistake:** "This is just a mode of `reorder-functions`."
  - No. It is a separate public pass.
- **Mistake:** "This one also uses call counts."
  - No. It ignores call counts entirely.
- **Mistake:** "This is a size optimization."
  - No. Upstream frames it as useful for debugging.
- **Mistake:** "The pass must repair locals or labels after sorting."
  - Not in Binaryen's pass; it only reorders declarations.
- **Mistake:** "The pass is too trivial to document."
  - The dedicated public registration and dedicated lit file show that the behavior is still a real upstream contract.

## Condensed mental model

A faithful beginner summary is:

- Binaryen alphabetizes the module's function declarations by internal name.
- It leaves bodies alone.
- It needs no nonnullable-local fixups because it never mutates body contents.
- It keeps this as a separate public pass because lexical debugging order is a different goal from static-use-count layout.

The dedicated lit file proves the core positive family directly through four declaration permutations that all normalize to `$a`, `$b`, `$c`, and a narrow 2026-05-05 current-main recheck found no teaching-relevant drift on the reviewed surface.

## Sources

- [`../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md)
- [`../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md`](../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md`](../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md)
- [`../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md`](../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md)
