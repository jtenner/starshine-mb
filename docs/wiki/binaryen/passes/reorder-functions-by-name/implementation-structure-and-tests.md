---
kind: concept
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md
  - ../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderFunctions.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-functions-by-name.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderFunctions.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./module-shapes.md
  - ../reorder-functions/index.md
---

# Upstream implementation structure and test map for `reorder-functions-by-name`

## Why this page exists

`reorder-functions-by-name` is small enough that it is easy to wave away as obvious.
That makes it easy to misremember too.
This page keeps the real file surface compact and explicit.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/ReorderFunctions.cpp` | Core implementation for both public pass names | The by-name sibling really is a separate public pass with its own comparator, even though it shares a file with `reorder-functions`. |
| `src/passes/pass.cpp` | Public registration surface | Binaryen officially exposes `reorder-functions-by-name` as a debugging-oriented pass, not as a hidden helper. |
| `test/lit/passes/reorder-functions-by-name.wast` | Direct shipped golden file | The sibling has direct upstream golden coverage and the contract is declaration-order-only lexical sorting. |
| current `main` `src/passes/ReorderFunctions.cpp` | Freshness spot check | The reviewed current-main implementation is identical to `version_129` on the documented surface. |

## The implementation file is the contract

`ReorderFunctions.cpp` is short, but it fully defines the behavior of this pass.

### `ReorderFunctionsByName`

This struct owns the public pass.
Its `run(Module* module)` method is the whole algorithm:

- sort `module->functions`
- compare by ascending name with `a->name < b->name`

It also explicitly reports:

- `requiresNonNullableLocalFixups() = false`

That is the real declaration-only contract.

### Shared-file context with `ReorderFunctions`

The same file also contains the count-based sibling.
That shared context matters because it proves the family split is about **ordering policy**, not about two unrelated mechanisms.

## `pass.cpp` tells you what upstream thinks the pass is for

The registration string is important here because it is unusually honest:

- `reorder-functions-by-name`: useful for debugging

That gives a stable beginner framing without overinterpreting the tiny source file.

## The lit file is the main test oracle

The reviewed dedicated pass lit file is:

- `reorder-functions-by-name.wast`

It proves the sibling variant directly by checking lexical function order.

That matters because it shows this pass is not just inferred from the shared source file.
It has direct shipped test coverage of its own.

## What the lit file proves

The shipped file demonstrates these durable lessons directly:

- module `$c,$b,$a` becomes `$a,$b,$c`
- module `$a,$b,$c` stays `$a,$b,$c`
- module `$b,$a,$c` becomes `$a,$b,$c`
- module `$c,$a,$b` becomes `$a,$b,$c`

That proves the sibling's core contract concretely instead of only by comparator inference.

## Freshness check

I compared `version_129` and current `main` `ReorderFunctions.cpp` on the reviewed surface.

Durable result:

- no implementation drift was observed in the file used by this dossier

So a future reader can safely treat the `version_129` source as current for the documented behavior here unless a later deliberate follow-up records new drift.

## Most important maintenance lesson

For this pass, the implementation file and the dedicated lit file already tell almost the entire story.
A faithful port should mirror that tiny source exactly before inventing any richer notion of function-order normalization.

## Narrow source-trust rule for this dossier

- Treat `version_129` `ReorderFunctions.cpp` as the release oracle.
- Treat `pass.cpp` as the definitive statement that this is a real public debugging-oriented pass.
- Treat `reorder-functions-by-name.wast` as the direct behavioral oracle.
- Treat current-main identity as a useful freshness check, not as a reason to skip citing `version_129`.
