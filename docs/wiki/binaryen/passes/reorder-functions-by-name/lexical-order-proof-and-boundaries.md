---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderFunctions.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-functions-by-name.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderFunctions.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./module-shapes.md
  - ../reorder-functions/index.md
---

# Exact lexical-order proof and declaration-only boundaries for `reorder-functions-by-name`

## Why this page exists

The existing dossier already had the right big idea.
What it still lacked was one compact source-confirmed place that joined together:

- the exact comparator
- the declaration-only boundary
- the dedicated official lit proof surface
- the current-`main` no-drift result

This page closes that gap.

## Exact algorithm

In Binaryen `version_129`, `ReorderFunctionsByName::run(Module* module)` does one thing:

- `std::sort(module->functions.begin(), module->functions.end(), ...)`

with the comparator:

- `a->name < b->name`

That means the pass's real contract is:

- sort the module's function declaration vector by ascending internal function name

## Exact declaration-only boundary

The same pass overrides:

- `requiresNonNullableLocalFixups() = false`

That is consistent with the mutation surface:

- bodies are not rewritten
- locals are not rewritten
- types are not rewritten
- only declaration order changes

So this sibling should be taught as a declaration-order pass, not as a function-body optimizer.

## Public-pass identity

`pass.cpp` registers `reorder-functions-by-name` as a separate public pass and describes it as:

- useful for debugging

That keeps the purpose honest.
It also keeps the sibling split honest:

- `reorder-functions-by-name` = lexical debugging-oriented order
- `reorder-functions` = static-use-count order

## Direct lit-backed proof surface

The dedicated official lit file `reorder-functions-by-name.wast` checks four concrete declaration permutations.
All of them normalize to the same final order:

- `$a`
- `$b`
- `$c`

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

1. the intended order is ascending lexical name order
2. already sorted modules are no-ops
3. the pass is about declaration order, not body rewriting

## Important non-goals

The reviewed source and tests also make the pass's non-goals very clear.
This pass does **not**:

- count direct calls
- count `start`
- count exports
- count element-segment references
- inspect `ref.func`
- inspect body complexity
- run a legality-repair phase after sorting

Those are all boundaries that belong to the sibling `reorder-functions` dossier or to downstream Binaryen infrastructure, not to this pass itself.

## Current-main drift result

A narrow current-`main` check of `ReorderFunctions.cpp` found no drift on the reviewed surface.

So for this pass, the safe maintenance rule is:

- treat `version_129` as the release oracle
- keep the no-drift note explicit until a later thread records a real change

## Condensed durable summary

The exact source-confirmed contract is:

- Binaryen exposes `reorder-functions-by-name` as a separate public debugging-oriented pass.
- It sorts `module->functions` by ascending internal function name.
- It changes declaration order only.
- The dedicated lit file proves the core positive families directly.
