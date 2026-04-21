---
kind: concept
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0179-2026-04-21-reorder-functions-binaryen-research.md
  - ../../../raw/research/0211-2026-04-21-reorder-functions-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast
  - https://api.github.com/repos/WebAssembly/binaryen/contents/test/lit/passes?ref=version_129
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./count-surfaces-ordering-and-omissions.md
  - ./module-shapes.md
---

# Upstream implementation structure and test map for `reorder-functions`

## Why this page exists

`reorder-functions` is small enough that it is easy to skip over.
That makes it easy to misremember too.
This page keeps the real file surface compact and explicit.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/ReorderFunctions.cpp` | Core implementation for both public pass names | The pass family is just a function-order sort plus a tiny static reference counter. |
| `src/passes/pass.cpp` | Public registration surface | Binaryen officially exposes both `reorder-functions` and `reorder-functions-by-name`. |
| `test/lit/passes/reorder-functions-by-name.wast` | Direct shipped golden file for the sibling variant | The by-name pass really is a separate public contract and it only changes declaration order. |
| `test/lit/passes/` directory listing | Negative evidence / coverage context | In the reviewed `version_129` pass-test directory, the only dedicated reorder-functions-family lit file is the by-name sibling file. |
| current `main` `src/passes/ReorderFunctions.cpp` | Freshness spot check | The reviewed current-main implementation is identical to `version_129`. |

## The implementation file is the contract

`ReorderFunctions.cpp` is short, but it fully defines the behavior of both public passes.

### `CallCountScanner`

This helper proves three important facts:

1. counting is done as a **walker pass**
2. the walk is **function-parallel**
3. the scanner only visits **direct `Call`** nodes

That is the real counting surface inside function bodies.

### `ReorderFunctions`

This struct owns the main public pass.
Its `run(Module* module)` method is the whole algorithm:

- seed counts
- run the direct-call scanner
- count start/export/element uses
- sort `module->functions`

The same struct also returns `false` from `requiresNonNullableLocalFixups()`, which is a compact source-level confirmation that the pass is declaration-only and does not introduce local-type repair obligations.

### `ReorderFunctionsByName`

This struct owns the sibling pass.
It sorts by ascending name and does nothing else.

## The sibling pass matters

A good rule for reading this file is:

- if both passes share the same file but different comparators, then the family's true shared core is the declaration reorder itself, not the scoring policy

That helps prevent a common teaching mistake where `reorder-functions-by-name` gets treated as a test-only curiosity instead of a real public pass.

## `pass.cpp` tells you what upstream thinks the pass is for

The registration strings are important here because they are unusually honest:

- `reorder-functions-by-name`: useful for debugging
- `reorder-functions`: sorts functions by access frequency

That gives a stable beginner framing without overinterpreting the tiny source file.

## The test surface is asymmetric

The reviewed dedicated pass lit file is:

- `reorder-functions-by-name.wast`

It proves the sibling variant directly by checking lexical function order.

In the reviewed `version_129` `test/lit/passes` directory listing, I did not find a dedicated `reorder-functions.wast` file.
So the plain pass is comparatively under-documented by direct lit goldens in this reviewed surface.

That does **not** prove the pass lacks all upstream test coverage elsewhere.
It only means the small source file carries more of the teaching burden than it would for a heavily tested pass.

## What the by-name lit file proves

The shipped file demonstrates these durable lessons:

- the pass family changes declaration order, not bodies
- sorting is deterministic
- unchanged lexical order stays unchanged
- scrambled lexical order is normalized into ascending name order

That is enough to teach the sibling honestly.
It also indirectly supports the shared rule that function-body content is not being optimized here.

## Freshness check

I compared `version_129` and current `main` `ReorderFunctions.cpp`.

Durable result:

- no implementation drift was observed in the reviewed file

So a future reader can safely treat the `version_129` source as current for the documented behavior here unless a later deliberate follow-up records new drift.

## Most important maintenance lesson

For this pass family, the implementation file matters more than a large test corpus.
The logic is so compact that a faithful port should begin by mirroring the source exactly before trying to infer smarter counting heuristics.

For the compact source-confirmed summary of the count surface, ordering comparator, explicit TODO omissions, and no-local-fixup boundary, see [`./count-surfaces-ordering-and-omissions.md`](./count-surfaces-ordering-and-omissions.md).

## Narrow source-trust rule for this dossier

- Treat `version_129` `ReorderFunctions.cpp` as the release oracle.
- Treat current-main identity as a useful freshness check, not as a reason to skip citing `version_129`.
- Treat the reviewed pass-test directory listing as support for the statement about dedicated reorder-functions-family lit coverage, but do not overstate it into a whole-repo absence proof.
