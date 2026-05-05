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
  - ./binaryen-strategy.md
  - ./lexical-order-proof-and-boundaries.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../reorder-functions/index.md
---

# Upstream implementation structure and test map for `reorder-functions-by-name`

## Why this page exists

`reorder-functions-by-name` is small enough that it is easy to wave away as obvious. That makes it easy to misremember too. This page keeps the real file surface compact and explicit.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/ReorderFunctions.cpp` | Core implementation for both public pass names | The by-name sibling really is a separate public pass with its own comparator, even though it shares a file with `reorder-functions`. |
| `src/passes/pass.cpp` | Public registration surface | Binaryen officially exposes `reorder-functions-by-name` as a debugging-oriented pass, not as a hidden helper. |
| `test/lit/passes/reorder-functions-by-name.wast` | Direct shipped golden file | The sibling has direct upstream golden coverage and the contract is declaration-order-only lexical sorting. |
| current `main` `src/passes/ReorderFunctions.cpp` | Freshness spot check | The reviewed current-main implementation has no teaching-relevant drift from `version_129` on the documented surface. |

## `ReorderFunctions.cpp` is the contract

`ReorderFunctions.cpp` is short, but it fully defines the behavior of this pass.

### `ReorderFunctionsByName`

This struct owns the public pass.

Its `run(Module* module)` method is the whole algorithm:

- sort `module->functions`,
- compare by ascending name with `a->name < b->name`.

It also explicitly reports:

- `requiresNonNullableLocalFixups() = false`.

That is the real declaration-only contract.

### Shared-file context with `ReorderFunctions`

The same file also contains the count-based sibling. That shared context matters because it proves the family split is about **ordering policy**, not about two unrelated mechanisms.

## `pass.cpp` tells you what upstream thinks the pass is for

The registration string is important because it is unusually honest:

- `reorder-functions-by-name` is useful for debugging.

That gives a stable beginner framing without overinterpreting the tiny source file.

## The lit file is the main test oracle

The reviewed dedicated pass lit file is:

- `reorder-functions-by-name.wast`

It proves the sibling variant directly by checking lexical function order.

That matters because this pass is not just inferred from the shared source file. It has direct shipped test coverage of its own.

## What the lit file proves

The shipped file demonstrates these durable lessons directly:

- module `$c,$b,$a` becomes `$a,$b,$c`,
- module `$a,$b,$c` stays `$a,$b,$c`,
- module `$b,$a,$c` becomes `$a,$b,$c`,
- module `$c,$a,$b` becomes `$a,$b,$c`.

That proves the sibling's core contract concretely instead of only by comparator inference.

## Current-main freshness check

A 2026-05-05 current-main recheck compared `version_129` and current `main` `ReorderFunctions.cpp` on the reviewed surface.

Durable result:

- no teaching-relevant implementation drift was observed for `ReorderFunctionsByName`.

So a future reader can safely treat the `version_129` source as current for the documented behavior here unless a later deliberate follow-up records new drift.

## What this source map does not prove

The direct upstream source map does not prove a complicated optimizer because there is none here. It also does not audit Binaryen's writer internals or every downstream index bookkeeping detail.

For Starshine, those details still matter because local lowered modules carry numeric function indices. That local implementation concern is tracked in [`./starshine-strategy.md`](./starshine-strategy.md), not in Binaryen's tiny comparator file.

## Most important maintenance lesson

For this pass, the implementation file and the dedicated lit file already tell almost the entire upstream story. A faithful port should mirror that tiny source exactly before inventing any richer notion of function-order normalization.

## Narrow source-trust rule for this dossier

- Treat `version_129` `ReorderFunctions.cpp` as the release oracle.
- Treat `pass.cpp` as the definitive statement that this is a real public debugging-oriented pass.
- Treat `reorder-functions-by-name.wast` as the direct behavioral oracle.
- Treat current-main identity as a useful freshness check, not as a reason to skip citing `version_129`.

## Sources

- [`../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md)
- [`../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md`](../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md`](../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md)
- [`../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md`](../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md)
