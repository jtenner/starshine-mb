---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md
  - ../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md
  - ../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0193-2026-04-21-type-un-finalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./private-boundaries-sibling-split-and-no-leaf-rule.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-finalizing/implementation-structure-and-tests.md
  - ../remove-unused-types/implementation-structure-and-tests.md
---

# `type-unfinalizing` implementation structure and tests

## Main upstream files

Primary online source provenance is captured in [`../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md), with a 2026-04-27 current-main implementation-readiness recheck in [`../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md). The older 0193 research note is still useful historical context, but this page now treats the raw manifests as the source anchors.

| File | Kind | Why it matters |
| --- | --- | --- |
| `src/passes/TypeFinalizing.cpp` | Core implementation | Holds the entire shared engine for both `type-finalizing` and `type-unfinalizing`: GC gate, private-type filtering, tiny `GlobalTypeRewriter` subclass, and the final `setOpen(!finalize)` mutation. For this sibling, the key teaching fact is that the implementation does **not** build `SubTypes` or apply the leaf-only filter. |
| `src/passes/pass.cpp` | Public registration | Proves that Binaryen exposes `type-unfinalizing` as its own public pass name rather than burying it as an internal mode under `type-finalizing`. |
| `test/lit/passes/type-finalizing.wast` | Dedicated official lit surface | Proves the public-vs-private rule, sibling split, reopening behavior, and function-type participation. |

## Supporting helper surfaces to understand the pass correctly

This pass is tiny, but it leans on helper concepts that are easy to under-teach if you only read the one `.cpp` file.

| Helper surface | Why it matters for this pass | Where this repo already explains it in more depth |
| --- | --- | --- |
| `ModuleUtils::getPrivateHeapTypes(...)` | Defines the visibility boundary: only private heap types are candidates for reopening | [`../remove-unused-types/implementation-structure-and-tests.md`](../remove-unused-types/implementation-structure-and-tests.md), [`../type-finalizing/implementation-structure-and-tests.md`](../type-finalizing/implementation-structure-and-tests.md) |
| `GlobalTypeRewriter` | Performs the coherent module-wide heap-type rewrite instead of a local declaration edit | [`../remove-unused-types/implementation-structure-and-tests.md`](../remove-unused-types/implementation-structure-and-tests.md) |
| `TypeBuilder::setOpen(...)` | Is the actual mutation the pass applies to selected type-builder entries | directly visible in `TypeFinalizing.cpp` |
| `SubTypes` | Matters here mainly by absence: `type-unfinalizing` does not need the leaf proof that `type-finalizing` requires | [`../type-finalizing/implementation-structure-and-tests.md`](../type-finalizing/implementation-structure-and-tests.md) |

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

### 3. this sibling does not need subtype knowledge

The optional `SubTypes` construction appears only under the `finalize` mode.
For `type-unfinalizing`, the implementation skips it.

That proves the exact split in safety reasoning:

- finalize => must prove leaf-ness
- unfinalize => privacy is enough

### 4. private types are the only candidates

The file explicitly seeds from `ModuleUtils::getPrivateHeapTypes(*module)`.
That proves the pass is visibility-limited by design.

### 5. the visible mutation is only `setOpen(true)`

The local `TypeRewriter` override only toggles:

- `typeBuilder[i].setOpen(!parent.finalize)`

For this sibling, that means `setOpen(true)`.
That proves this is not a general declaration rewrite pass.
It is one exact state toggle applied through the global helper.

## What `pass.cpp` proves

`pass.cpp` contributes three durable facts:

### 1. `type-unfinalizing` is a public pass name

Binaryen registers:

- `type-unfinalizing`

So the sibling is not just an internal debug flag or helper mode.

### 2. the public description is intentionally narrow

The registration description says the pass marks types open again.
That matches the tiny implementation.

### 3. the local Starshine registry spelling differs

Comparing upstream `pass.cpp` with local `src/passes/optimize.mbt` shows the local alias:

- `type-un-finalizing`

This naming split is worth preserving in the docs because it is easy to miss when searching the repo.

## What the dedicated lit file proves

`type-finalizing.wast` is the official behavior map for both siblings.

### Lit section A: private final types reopen

The first module checks a private final type and shows that `--type-unfinalizing` makes it open.
That is the basic positive case.

### Lit section B: public final types stay final

The same module also includes public types and exports that keep them observable.
Those public types stay unchanged under the sibling.
That is the strongest upstream proof of the private/public boundary.

### Lit section C: the sibling is broader than leaf-only finalization

The second module creates a small subtype tree.
Reading the source and the test together shows the sibling does not rely on the leaf-only proof used by `type-finalizing`.
That is the main contract difference future ports must keep visible.

### Lit section D: function heap types are part of the rewrite surface

The same second module keeps alive a function heap type and locals using the heap types.
That proves the rewrite surface includes function heap types and their uses, not only struct declarations.

## Minimal implementation narrative

If you need to explain the file to someone quickly, the best outline is:

1. decide that this run is in unfinalizing mode
2. collect private heap types
3. treat those private types as modifiable
4. let `GlobalTypeRewriter` rebuild the type graph
5. toggle the chosen type entries open during that rebuild

That five-step outline is basically the whole pass.

## Why the helper references still matter

Because the core file is so small, most misunderstanding comes from underestimating the helpers.

The pass only *looks* trivial.
It would be unsafe without helper contracts for:

- which types are private
- how type uses are remapped coherently
- how the sibling stays separate from the leaf-only `type-finalizing` mode

So a future port should treat helper fidelity as part of pass fidelity.

## Practical test-reading advice

If you only have time to read one test file, read `type-finalizing.wast` slowly while keeping the sibling split in mind.
It captures almost every real rule relevant here:

- public vs private
- open vs final
- sibling split between finalizing and unfinalizing
- struct types and function types

## Starshine local structure note

Current Starshine has no matching owner file or tests for this sibling. The local structure readers should inspect today is [`./starshine-strategy.md`](./starshine-strategy.md): `src/passes/optimize.mbt` keeps `type-un-finalizing` boundary-only and rejects active requests, while the future implementation would need type-section, WAT, validator, and binary roundtrip support. For the recommended first slices and validation lanes, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Source URLs

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>
