---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md
  - ../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../reorder-functions/index.md
---

# Exact lexical-order proof and declaration-only boundaries for `reorder-functions-by-name`

## Why this page exists

This compact page joins the exact pieces that define the pass:

- the exact comparator,
- the declaration-only boundary,
- the dedicated official lit proof surface,
- the current-main no-drift result,
- and the split from count-based `reorder-functions`.

## Exact algorithm

In Binaryen `version_129`, `ReorderFunctionsByName::run(Module* module)` does one thing:

- sort `module->functions`.

The comparator is:

- `a->name < b->name`.

That means the pass's real contract is:

- sort the module's function declaration vector by ascending internal function name.

## Exact declaration-only boundary

The same pass overrides:

- `requiresNonNullableLocalFixups() = false`.

That is consistent with the mutation surface:

- bodies are not rewritten,
- locals are not rewritten,
- types are not rewritten,
- only declaration order changes.

So this sibling should be taught as a declaration-order pass, not as a function-body optimizer.

## Public-pass identity

`pass.cpp` registers `reorder-functions-by-name` as a separate public pass and describes it as useful for debugging.

That keeps the purpose honest and keeps the sibling split honest:

- `reorder-functions-by-name` = lexical debugging-oriented order,
- `reorder-functions` = static-use-count order.

## Direct lit-backed proof surface

The dedicated official lit file `reorder-functions-by-name.wast` checks four concrete declaration permutations. All of them normalize to the same final order:

- `$a`,
- `$b`,
- `$c`.

### Proof family 1: reverse order

Input order:

- `$c`, `$b`, `$a`

Checked output order:

- `$a`, `$b`, `$c`

### Proof family 2: already sorted

Input order:

- `$a`, `$b`, `$c`

Checked output order:

- `$a`, `$b`, `$c`

### Proof family 3: middle swap

Input order:

- `$b`, `$a`, `$c`

Checked output order:

- `$a`, `$b`, `$c`

### Proof family 4: front/back mix

Input order:

- `$c`, `$a`, `$b`

Checked output order:

- `$a`, `$b`, `$c`

## What the direct proof teaches

The dedicated lit file directly proves these beginner-important facts:

1. the intended order is ascending lexical name order;
2. already sorted modules are no-ops;
3. the pass is about declaration order, not body rewriting.

## Important non-goals

The reviewed source and tests make the pass's non-goals clear. This pass does **not**:

- count direct calls,
- count `start`,
- count exports,
- count element-segment references,
- inspect `ref.func`,
- inspect body complexity,
- run a legality-repair phase after sorting.

Those are all boundaries that belong to the sibling `reorder-functions` dossier or to downstream Binaryen infrastructure, not to this pass itself.

## Current-main drift result

A 2026-04-24 current-main spot check of `ReorderFunctions.cpp` found no teaching-relevant drift on the reviewed surface.

So for this pass, the safe maintenance rule is:

- treat `version_129` as the release oracle;
- keep the no-drift note explicit until a later thread records a real change.

## Starshine-specific boundary

The Binaryen proof is tiny because Binaryen already owns its module-function vector and writer machinery. In Starshine, a future module pass must also update numeric `FuncIdx` users and metadata after changing declaration order. That local porting boundary is tracked in [`./starshine-strategy.md`](./starshine-strategy.md).

## Condensed durable summary

The exact source-confirmed contract is:

- Binaryen exposes `reorder-functions-by-name` as a separate public debugging-oriented pass.
- It sorts `module->functions` by ascending internal function name.
- It changes declaration order only.
- The dedicated lit file proves the core positive families directly.
- Current Starshine has only a boundary-only tracking entry today.

## Sources

- [`../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md)
- [`../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md`](../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md`](../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md)
