---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md
  - ../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0192-2026-04-21-type-finalizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./leaf-types-public-boundaries-and-sibling-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../remove-unused-types/index.md
  - ../type-merging/index.md
---

# Binaryen `type-finalizing` strategy

## Upstream source rule

Use Binaryen `version_129` as the source oracle for this pass, anchored by the 2026-04-24 raw manifest [`../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md).
The core sources are:

- `src/passes/TypeFinalizing.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-finalizing.wast`

Important helper surfaces the pass relies on conceptually:

- `ModuleUtils::getPrivateHeapTypes(...)`
- `SubTypes`
- `GlobalTypeRewriter`
- `TypeBuilder::setOpen(...)`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>

## The pass in one sentence

Binaryen `type-finalizing` is a tiny GC-only module pass that finalizes private **leaf** heap types by toggling their open/final bit during one coherent module-wide type rewrite.

## Biggest naming fact

The local Starshine registry uses two names:

- `type-finalizing`
- `type-un-finalizing`

Upstream Binaryen registers the sibling pair as:

- `type-finalizing`
- `type-unfinalizing`

So the first naming correction is small but real:

- the unfinalizing sibling drops the extra local hyphen in upstream Binaryen

## Scheduler fact

This pass is **registered publicly** in Binaryen `pass.cpp`, but it is **not scheduled** in the reviewed default no-DWARF `-O` / `-Os` pipeline and it does not appear in the saved generated-artifact `-O4z` audit.
So this dossier is a deliberate upstream-only registry expansion.

## Core gates

Unlike many neighboring GC/type passes, `type-finalizing` does **not** ask for closed world.
Its real hard gate is simpler:

- if the module does not have GC, return immediately

Beginner translation:

- no GC nominal types means nothing to finalize or unfinalize
- public/open-world safety is handled by a **private-type visibility rule**, not by a closed-world mode requirement

## Shared engine with the sibling

`TypeFinalizing.cpp` defines one small pass class:

- `TypeFinalizing(bool finalize)`

The public registrations are just two constructor modes:

| Public pass name | Constructor mode | Behavior |
| --- | --- | --- |
| `type-finalizing` | `TypeFinalizing(true)` | finalize private leaf types |
| `type-unfinalizing` | `TypeFinalizing(false)` | reopen private types |

So the sibling story is exactly:

- same engine
- same module rewrite helper
- one mode bit controls which direction the open/final toggle goes

## What the implementation is really organized around

The durable structure is:

1. check that GC is enabled
2. if finalizing, build a subtype index
3. collect private heap types
4. filter them into a `modifiableTypes` set
5. subclass `GlobalTypeRewriter`
6. toggle `setOpen(!finalize)` on those selected type-builder entries
7. run the global type rewrite

This is a **type-section state cleanup** pass, not an expression optimizer.

## Phase 1: GC check

The pass immediately returns on:

- `!module->features.hasGC()`

That means there is no fallback scalar or non-GC mode.

## Phase 2: subtype index only when finalizing

When `finalize` is true, the pass constructs:

- `SubTypes(*module)`

When `finalize` is false, it does not.

Why?

- making a type final is only safe when that type has no subtypes
- reopening a type does not need the same leaf proof

This is the pass's entire safety proof split between the siblings.

## Phase 3: private heap types define the visibility boundary

The pass next asks for:

- `ModuleUtils::getPrivateHeapTypes(*module)`

That helper is the core observability rule.
The pass only modifies **private** heap types.

This is the most important beginner correction:

- `type-finalizing` does **not** mean “mark all types final”
- it means “mark the private safe subset final”

## Phase 4: leaf-only filter in finalizing mode

The pass inserts a private type into `modifiableTypes` only when:

- unfinalizing mode: always
- finalizing mode: `subTypes->getImmediateSubTypes(type).empty()`

So the source-backed rule is:

- only private **leaf** heap types can become final

Parents with immediate subtypes remain open.

## Phase 5: the actual mutation is tiny

The inner `TypeRewriter` subclass overrides only:

- `modifyTypeBuilderEntry(TypeBuilder& typeBuilder, Index i, HeapType oldType)`

If `oldType` is modifiable, it runs:

- `typeBuilder[i].setOpen(!parent.finalize);`

Everything else the pass does is there only to decide *which* heap types are safe to toggle and to apply that change coherently.

## Phase 6: `GlobalTypeRewriter` carries the real module rewrite

The pass ends with:

- `TypeRewriter(*module, *this).update();`

That is why this pass can safely change more than one declaration line.
`GlobalTypeRewriter` is the whole-module helper that rebuilds the type graph and updates its uses consistently.

Beginner translation:

- Binaryen is not doing a text substitution on one `type` definition
- it is rebuilding the relevant part of the module's nominal type world

## Important source comment: signature-called functions do not matter here

One small source comment is easy to overlook but useful:

- the pass says it does not need special `configureAll` handling because signature-called functions do not care about finality

That matters because many neighboring type passes have more complicated JS or closed-world publicity rules.
Here, Binaryen keeps the contract small instead.

## No refinalization step

`TypeFinalizing.cpp` does **not** call `ReFinalize`.
That is a meaningful contrast with nearby passes such as:

- `type-merging`
- `type-generalizing`
- `gufa*`
- `signature-refining`

A good beginner explanation is:

- this pass changes declaration finality state and rewrites heap-type uses coherently through the global helper,
- but it is not narrowing local expression result types by AST walking,
- so there is no explicit second expression-refinalization phase here.

## Positive family 1: private open leaf becomes final

When a private type is open and has no immediate subtypes, `type-finalizing` can make it final.
In Binaryen's printed WAT, that often means a leaf `sub` form simplifies to a plain type declaration.

## Positive family 2: private final leaf becomes open under the sibling

The sibling `type-unfinalizing` does the reverse for private types.
This is useful for workflows that want to relax the internal type graph before more transformations.

## Positive family 3: function heap types participate too

The dedicated lit file shows that function heap types are also part of the rewrite surface, not just structs.
So the pass is about nominal heap-type finality broadly, not only object-layout types.

## Positive family 4: globals and locals keep following the rewritten graph

Because the pass uses a global helper, globals and locals that mention the rewritten heap types stay coherent after the update.
That is an important helper-level contract even though the pass body itself is tiny.

## Negative family 1: no GC means no effect

No GC, no pass action.

## Negative family 2: no public-type rewriting

Public heap types remain unchanged.
This is the main visibility boundary.

## Negative family 3: no non-leaf finalization

A private parent type with immediate subtypes stays open under `type-finalizing`.

## Negative family 4: no body optimization

The pass does not walk function bodies looking for instructions to optimize.
Any visible body-level type use changes are consequences of the global remap, not targeted AST rewrites.

## Important helper dependencies

The most important helper dependencies are:

- `ModuleUtils::getPrivateHeapTypes(...)`
  - defines the visibility boundary
- `SubTypes`
  - proves which private types are leaves
- `GlobalTypeRewriter`
  - performs the coherent module rewrite
- `TypeBuilder::setOpen(...)`
  - is the actual state toggle the pass applies

So this pass is best understood as:

- **private-type selection plus one global open/final bit rewrite**

not as a complicated optimizer.

## What a future Starshine port must preserve

For exact current local status and code locations, see [`./starshine-strategy.md`](./starshine-strategy.md). A faithful port should preserve at least nine things:

1. the GC-only gate
2. the private-type visibility boundary
3. leaf-only finalization
4. unconditional private-type reopening for the sibling
5. the shared-engine split between finalizing and unfinalizing
6. module-wide coherent heap-type remapping
7. the fact that public types are not touched
8. the fact that no closed-world request is needed upstream here
9. the local-vs-upstream naming split for the unfinalizing sibling

## Most important beginner correction

If someone says:

- “`type-finalizing` is a general type optimization pass”

that is too vague to be useful.

A much better sentence is:

- “Binaryen `type-finalizing` is a tiny GC-only module rewrite that marks safe private leaf heap types final, while its sibling can reopen private types again.”
