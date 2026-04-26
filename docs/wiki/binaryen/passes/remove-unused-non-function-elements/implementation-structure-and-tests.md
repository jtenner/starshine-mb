---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md
  - ../../../raw/research/0408-2026-04-26-remove-unused-non-function-elements-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md
  - ../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0194-2026-04-21-remove-unused-non-function-elements-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-configureAll.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-tables.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_tnh.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/implementation-structure-and-tests.md
---

# Upstream implementation structure and test map for `remove-unused-nonfunction-module-elements`

## Why this page exists

The 2026-04-24 raw source manifest for this page is [`../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md). The 2026-04-26 port-readiness recheck and future local validation plan are [`../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md) and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

This pass is tiny at the registration level, which makes it easy to hand-wave.
That is exactly why it needs a compact file map.
The real contract is a sibling-mode split inside a bigger shared file, not a standalone implementation from scratch.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/RemoveUnusedModuleElements.cpp` | Shared core implementation for both public pass names | The sibling is the same analyzer/removal engine plus one `rootAllFunctions` policy toggle. |
| `src/passes/pass.cpp` | Public registration surface | Binaryen publishes `remove-unused-nonfunction-module-elements` as its own real pass, not a hidden internal mode. |
| `src/passes/passes.h` | Public constructor declaration surface | The sibling has its own factory symbol and is part of Binaryen's ordinary pass roster. |
| `test/passes/remove-unused-nonfunction-module-elements_all-features.wast` | Dedicated upstream regression file for this exact sibling | The sibling is source-backed as a separate public contract, and its real behavior is “keep defined functions, still clean other module structure.” |
| shared `remove-unused-module-elements*` lit files | Shared engine coverage | Startup-trap, table, `configureAll`, and refs behavior still matter because the sibling reuses the same engine. |

## The implementation file is the contract

`RemoveUnusedModuleElements.cpp` is where almost everything happens.
That file contains:

- the pass class
- the ordinary root seeding
- the sibling `rootAllFunctions` step
- the analyzer construction
- the deletion rules
- the shared startup-trap logic

So a future port should begin here, not from the shorter registration strings.

## The pass-class field that matters most

Inside the pass struct, the central knob is:

- `bool rootAllFunctions;`

That field is the sibling boundary.
If you miss it, the two public pass names look much more similar than they really are.

## The two public constructors are the public contract split

The bottom of the file contains the exact split:

- `createRemoveUnusedModuleElementsPass()` -> `new RemoveUnusedModuleElements(false)`
- `createRemoveUnusedNonFunctionModuleElementsPass()` -> `new RemoveUnusedModuleElements(true)`

That is the cleanest source-backed reason to treat the sibling as a real public pass rather than a side comment inside the full RUME dossier.

## `pass.cpp` confirms this is not an internal-only helper

`pass.cpp` registers both names separately:

- `remove-unused-module-elements`
- `remove-unused-nonfunction-module-elements`

and gives the sibling its own human-facing description.
So this is not a repo-local alias or an unexposed testing mode.

## `passes.h` confirms the factory is public API surface inside Binaryen

`passes.h` declares:

- `createRemoveUnusedModuleElementsPass()`
- `createRemoveUnusedNonFunctionModuleElementsPass()`

That matters because it keeps the sibling visible at the same level as other public pass factories.
A future reader should not treat the sibling as a parser-only spelling accident.

## The dedicated test file proves the sibling is real

The most important dedicated file is:

- `test/passes/remove-unused-nonfunction-module-elements_all-features.wast`

That file is especially valuable because it demonstrates the sibling's visible contract directly instead of making readers infer it only from the implementation.

## What the dedicated sibling test proves

The dedicated upstream test file proves several durable points.

### 1. Dead defined functions stay

The file includes clearly dead defined function families that remain after the pass.
That is the direct visible effect of `rootAllFunctions = true`.

### 2. Dead non-function declarations still vanish

Small modules with only dead memories or tables reduce to empty modules.
That proves the sibling still does real cleanup.

### 3. Exported or actually used non-function declarations stay

The file checks exported parents and truly used parents, so the sibling is clearly not a blunt “delete all non-functions unless functions mention them” tool.

### 4. Active imported-parent segments still keep parents alive

The file includes active data and elem segment cases that retain imported memories and tables.

### 5. Imported functions can still disappear

The file includes imported function cases where the dead imported function is removed.
That is the clearest proof that the pass roots defined functions, not all functions.

### 6. Dead tags can still disappear

The file also checks that non-exported tags may be removed while defined functions remain.

### 7. Function-type cleanup still happens

The first larger module shows type-surface cleanup even though the defined function bodies survive.
So the sibling still shares the broader module-shape cleanup story.

## Shared lit files still matter

The sibling's dedicated test file does not replace the shared RUME lit family.
Because the engine is shared, the shared tests still teach important things about the sibling's real semantics.

### `remove-unused-module-elements-configureAll.wast`

This file keeps the `configureAll` and JS-prototype-related engine behavior visible.
It matters because the sibling still uses the same engine even if its defined-function rooting changes the visible function outcomes.

### `remove-unused-module-elements-refs.wast`

This file keeps the reference-style and closed-world/open-world engine behavior visible.
The sibling still inherits those rules.

### `remove-unused-module-elements-tables.wast`

This file keeps table and element-content behavior visible, which still matters directly to the sibling.

### `remove-unused-module-elements_tnh.wast`

This file keeps the `trapsNeverHappen` startup retention rule visible.
That shared rule still applies unchanged to the sibling.

## The most important file-reading lesson

For this pass family, the honest reading order is:

1. read `RemoveUnusedModuleElements.cpp`
2. confirm the two public registrations in `pass.cpp`
3. confirm the public factory declarations in `passes.h`
4. inspect the dedicated sibling all-features test
5. use the shared RUME lit family for the deeper shared-engine semantics

That order preserves the difference between:

- what is unique to the sibling
- and what is inherited from full RUME

## Current-main drift note

This dossier is intentionally anchored to `version_129`.
A narrow 2026-04-24 current-`main` spot check confirmed that the pass identity, factory split, and dedicated test path remain present. The owner file has helper/container drift after `version_129`, so this page does **not** claim whole-file current-main equivalence. If a future thread wants to claim detailed drift or no-drift, it should do a fresh explicit comparison.

## Most important maintenance lesson

The sibling is small in code, but not small in teaching value.
The implementation surface is shared, and the most important behavior difference lives in one field and one constructor mode.
A future port should preserve that exact structure rather than forking a brand-new simplifier.
