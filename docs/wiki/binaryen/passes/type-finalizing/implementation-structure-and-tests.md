---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md
  - ../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0192-2026-04-21-type-finalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./leaf-types-public-boundaries-and-sibling-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-types/implementation-structure-and-tests.md
  - ../type-merging/implementation-structure-and-tests.md
---

# `type-finalizing` implementation structure and tests

This page is source-confirmed by the 2026-04-24 raw manifest [`../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md) and refreshed by the 2026-04-27 current-main implementation-readiness recheck [`../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md). For the current Starshine non-implementation, future-port code map, and validation ladder, see [`./starshine-strategy.md`](./starshine-strategy.md) and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Main upstream files

| File | Kind | Why it matters |
| --- | --- | --- |
| `src/passes/TypeFinalizing.cpp` | Core implementation | Holds the entire shared engine for both `type-finalizing` and `type-unfinalizing`: GC gate, optional `SubTypes`, private-type filtering, tiny `GlobalTypeRewriter` subclass, and the final `setOpen(!finalize)` mutation. |
| `src/passes/pass.cpp` | Public registration | Proves that Binaryen exposes both sibling names publicly: `type-finalizing` and `type-unfinalizing`. |
| `test/lit/passes/type-finalizing.wast` | Dedicated official lit surface | Proves the public-vs-private rule, leaf-only finalization rule, sibling split, and function-type participation. |

## Supporting helper surfaces to understand the pass correctly

This pass is tiny, but it leans on helper concepts that are easy to under-teach if you only read the one `.cpp` file.

| Helper surface | Why it matters for this pass | Where this repo already explains it in more depth |
| --- | --- | --- |
| `ModuleUtils::getPrivateHeapTypes(...)` | Defines the visibility boundary: only private heap types are candidates for toggling | [`../remove-unused-types/implementation-structure-and-tests.md`](../remove-unused-types/implementation-structure-and-tests.md), [`../type-merging/implementation-structure-and-tests.md`](../type-merging/implementation-structure-and-tests.md) |
| `SubTypes` | Defines the leaf proof used only in finalizing mode | neighboring GC/type dossiers such as [`../signature-pruning/implementation-structure-and-tests.md`](../signature-pruning/implementation-structure-and-tests.md) and [`../abstract-type-refining/implementation-structure-and-tests.md`](../abstract-type-refining/implementation-structure-and-tests.md) |
| `GlobalTypeRewriter` | Performs the coherent module-wide heap-type rewrite instead of a local declaration edit | [`../remove-unused-types/implementation-structure-and-tests.md`](../remove-unused-types/implementation-structure-and-tests.md) |
| `TypeBuilder::setOpen(...)` | Is the actual mutation the pass applies to selected type-builder entries | directly visible in `TypeFinalizing.cpp` |

## What `TypeFinalizing.cpp` proves by itself

The source file is small enough that its structure is the contract.

### 1. one implementation, two passes

The file ends with:

- `createTypeFinalizingPass()`
- `createTypeUnFinalizingPass()`

Both return the same implementation class with different constructor arguments.

That proves the sibling relation is first-class, not accidental.

### 2. the pass is module-level and GC-only

The implementation overrides `run(Module* module)` and immediately checks `module->features.hasGC()`.

That proves:

- module pass, not function pass
- GC-only, not generic wasm cleanup

### 3. finalizing needs subtype knowledge, unfinalizing does not

The optional `SubTypes` construction appears only under the `finalize` mode.

That proves the exact split in safety reasoning:

- finalize => must prove leaf-ness
- unfinalize => no leaf proof needed

### 4. private types are the only candidates

The file explicitly seeds from `ModuleUtils::getPrivateHeapTypes(*module)`.
That proves the pass is visibility-limited by design.

### 5. the visible mutation is only `setOpen(...)`

The local `TypeRewriter` override only toggles:

- `typeBuilder[i].setOpen(!parent.finalize)`

That proves this is not a general declaration rewrite pass.
It is one exact state toggle applied through the global helper.

## What `pass.cpp` proves

`pass.cpp` contributes three durable facts:

### 1. both siblings are public pass names

Binaryen registers:

- `type-finalizing`
- `type-unfinalizing`

So neither one is just an internal helper mode.

### 2. the public descriptions are intentionally narrow

The registration descriptions are short and honest:

- `type-finalizing` marks leaf types final
- `type-unfinalizing` marks types open

That matches the tiny implementation.

### 3. the local Starshine registry spelling differs for the sibling

Comparing upstream `pass.cpp` with local `src/passes/optimize.mbt` shows the local alias:

- `type-un-finalizing`

This naming split is worth preserving in the docs because it is easy to miss when searching the repo.

## What the dedicated lit file proves

`type-finalizing.wast` is the official behavior map.

### Lit section A: public types never change

The first module checks:

- open public type
- final public type
- public globals
- public exports

Both pass modes leave those public pieces alone.
That is the strongest upstream proof of the private/public boundary.

### Lit section B: private leaves do change

The same first module shows:

- final private type becomes open under unfinalizing
- open private type becomes final under finalizing

This proves both halves of the sibling split.

### Lit section C: parent with children stays open

The second module creates:

- one parent type
- two children

The parent stays open even under `type-finalizing`.
That is the strongest upstream proof of the leaf-only rule.

### Lit section D: function heap types are part of the rewrite surface

The same second module keeps alive a function heap type and locals using the heap types.
That proves the rewrite surface includes function heap types and their uses, not only struct declarations.

## Minimal implementation narrative

If you need to explain the file to someone quickly, the best outline is:

1. decide whether this run is finalizing or unfinalizing
2. if finalizing, build immediate-subtype info
3. collect private heap types
4. choose which private types are modifiable
5. let `GlobalTypeRewriter` rebuild the type graph
6. toggle the chosen type entries open/final during that rebuild

That six-step outline is basically the whole pass.

## Why the helper references still matter

Because the core file is so small, most misunderstanding comes from underestimating the helpers.

The pass only *looks* trivial.
It would be unsafe without helper contracts for:

- which types are private
- which types are leaves
- how type uses are remapped coherently

So a future port should treat helper fidelity as part of pass fidelity.

## Practical test-reading advice

If you only have time to read one test file, read `type-finalizing.wast` slowly.
It captures almost every real rule:

- public vs private
- final vs open
- leaf vs non-leaf
- struct types and function types
- sibling split between finalizing and unfinalizing

That is unusually good coverage for such a small pass.

## Source URLs

- [`../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>
