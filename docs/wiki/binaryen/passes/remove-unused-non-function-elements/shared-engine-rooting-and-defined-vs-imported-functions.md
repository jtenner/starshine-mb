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
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
  - ../remove-unused-module-elements/roots-reference-only-and-nullification.md
---

# Shared engine, rooting policy, and the defined-vs-imported function boundary

## Why this page exists

This page is anchored by the 2026-04-24 raw manifest [`../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md) and the 2026-04-26 port-readiness recheck [`../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md). The local implementation ladder for this exact defined-vs-imported boundary is in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

This is the easiest part of the sibling to misread.
The pass name suggests one thing:

- remove unused non-function module elements

But the implementation really means something narrower and more exact:

- root all **defined** functions first,
- then run ordinary RUME cleanup.

If you flatten that distinction, you will teach the pass incorrectly.

## The shortest honest summary

Use this mental model:

- **same engine as RUME**
- **different initial root set**
- **defined functions are protected**
- **imported functions are not automatically protected**

That is the public-contract split in one sentence.

## The sibling is not a separate algorithm

Nothing here replaces the shared analyzer, shared startup-root logic, or shared cleanup stages.
The sibling inherits all of that.

The only teaching-important difference is:

- defined functions are rooted up front through `ModuleUtils::iterDefinedFunctions(...)`

So the sibling should be taught as a mode of RUME, not as a separate family.

## Why “defined” matters more than “function”

The pass does **not** say:

- root every function declaration

The code says:

- iterate **defined** functions
- add those names to the root set

That means this pass still has room to remove:

- unused imported functions

This is not speculation; the dedicated upstream all-features test proves it.

## What happens to dead defined functions

Because every defined function is rooted before the analyzer runs, dead defined functions:

- stay in the module
- keep their bodies
- are not replaced by `unreachable`
- may remain even if they form a dead cycle that nothing calls

This is the main positive guarantee of the sibling.

## What still can happen to imported functions

Imported functions are outside the special root-all-defined-functions step.
So imported functions can still follow the ordinary shared cleanup logic.

In practice that means:

- live imported functions stay
- dead imported functions can disappear

That is the biggest surprise many readers will miss if the docs say only “non-function elements.”

## Why function types still shrink

The sibling still shares the same post-reachability module cleanup surface.
So even though dead defined functions remain, Binaryen can still remove:

- duplicate function types
- unused function types

That is another important correction.
The sibling protects defined function bodies, not the entire function-related declaration world.

## The no-op start special case is another good example

The shared engine still drops a defined start declaration when the start body is exactly `nop`.
After that, the sibling still roots the defined function itself.
So one observable outcome is:

- the start section disappears
- the function body stays

That is a nice compact example of the real contract.

## How to explain the sibling without lying

A safe explanation for beginners is:

> Binaryen wants to clean unused module structure, but sometimes you want to keep all defined code bodies around. This sibling says “pretend every defined function is live,” then run the usual module cleanup everywhere else.

That captures:

- same engine
- different rooting policy
- non-function focus without overclaiming

## Shared RUME concepts still matter here

Because the engine is shared, the sibling still inherits all the harder RUME concepts:

- startup-visible roots
- startup trap retention
- active imported-parent segment retention
- table and element-content reachability
- reference-style versus strong use distinctions
- kind-specific cleanup for globals, memories, tables, tags, and segments

This page does **not** replace those ideas.
It only clarifies how the sibling changes the function boundary.

## Source-backed examples worth remembering

### Example 1: dead helper island stays

A dead defined helper chain stays because the sibling rooted it up front.

### Example 2: dead imported helper disappears

An unused imported function disappears because the sibling never gave it the special defined-function root.

### Example 3: duplicate function types disappear

The module can still shrink around the surviving defined functions.

### Example 4: empty start metadata disappears, body remains

The shared start cleanup still runs, then the sibling keeps the body.

## Easy mistakes to avoid

### Mistake 1: “This is the pass that never touches function things.”

Wrong.
It still changes imported functions, start metadata, and function types.

### Mistake 2: “Imported and defined functions behave the same.”

Wrong.
That is exactly the boundary the sibling introduces.

### Mistake 3: “The sibling does not need the ordinary RUME analyzer anymore.”

Wrong.
The root policy changes, but the cleanup logic remains shared.

## Starshine implication

Current Starshine exposes this sibling as `remove-unused-nonfunction-module-elements` by reusing the existing full-RUME module pass with the defined-function root policy described here; see [`./starshine-strategy.md`](./starshine-strategy.md).

## Bottom line

If you remember only one thing from this page, remember this:

- the real sibling split is **defined functions versus everything else**, not **functions versus non-functions in the abstract**.

That is the source-backed rule the active Starshine port must preserve.
