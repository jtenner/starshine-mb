---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md
  - ../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0193-2026-04-21-type-un-finalizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./private-boundaries-sibling-split-and-no-leaf-rule.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../type-finalizing/index.md
  - ../remove-unused-types/index.md
---

# Binaryen `type-unfinalizing` strategy

## Upstream source rule

Use Binaryen `version_129` as the source oracle for this pass, anchored by the committed raw manifest [`../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md). The older 0193 research note remains historical background, but new summaries should cite the raw manifest and this living page first.

The core sources are:

- `src/passes/TypeFinalizing.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-finalizing.wast`

Important helper surfaces the pass relies on conceptually:

- `ModuleUtils::getPrivateHeapTypes(...)`
- `GlobalTypeRewriter`
- `TypeBuilder::setOpen(...)`
- `SubTypes`, mainly because the sibling's strategy is defined partly by **not needing** the leaf proof that `type-finalizing` uses

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>

## The pass in one sentence

Binaryen `type-unfinalizing` is a tiny GC-only module pass that reopens private heap types by toggling their open/final bit during one coherent module-wide type rewrite.

## Biggest naming fact

The local Starshine registry uses:

- `type-un-finalizing`

Upstream Binaryen registers:

- `type-unfinalizing`

So the first naming correction is small but real:

- upstream drops the extra local hyphen

## Scheduler fact

This pass is **registered publicly** in Binaryen `pass.cpp`, but it is **not scheduled** in the reviewed default no-DWARF `-O` / `-Os` pipeline and it does not appear in the saved generated-artifact `-O4z` audit.
So this dossier is a deliberate upstream-only registry expansion.

## Core gates

Like its sibling, `type-unfinalizing` does **not** ask for closed world.
Its real hard gate is simpler:

- if the module does not have GC, return immediately

Beginner translation:

- no GC nominal types means there is nothing to reopen
- visibility safety is handled by the **private-type boundary**, not by a closed-world requirement

## Shared engine with `type-finalizing`

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
2. skip subtype construction because this mode does not need a leaf proof
3. collect private heap types
4. treat those private types as the `modifiableTypes` set
5. subclass `GlobalTypeRewriter`
6. toggle `setOpen(true)` on those selected type-builder entries
7. run the global type rewrite

This is a **type-section state cleanup** pass, not an expression optimizer.

## Phase 1: GC check

The pass immediately returns on:

- `!module->features.hasGC()`

That means there is no fallback scalar or non-GC mode.

## Phase 2: no subtype analysis in unfinalizing mode

Unlike `type-finalizing`, this mode does **not** construct:

- `SubTypes(*module)`

Why?

Because reopening a private type does not require proving it has no subtypes.
That is the main strategic difference from the finalizing sibling.

## Phase 3: private heap types define the visibility boundary

The pass asks for:

- `ModuleUtils::getPrivateHeapTypes(*module)`

That helper is the core observability rule.
The pass only modifies **private** heap types.

This is the most important beginner correction:

- `type-unfinalizing` does **not** mean “mark all types open again”
- it means “reopen the private safe subset Binaryen is allowed to rewrite internally”

## Phase 4: no leaf-only filter here

For the sibling, the pass inserts every private type into `modifiableTypes`.
There is no `getImmediateSubTypes(type).empty()` test in this mode.

So the source-backed rule is:

- any private heap type may be reopened

That is the whole reason this sibling deserves its own page instead of being treated as a footnote under `type-finalizing`.

## Phase 5: the actual mutation is tiny

The inner `TypeRewriter` subclass overrides only:

- `modifyTypeBuilderEntry(TypeBuilder& typeBuilder, Index i, HeapType oldType)`

If `oldType` is modifiable, it runs:

- `typeBuilder[i].setOpen(!parent.finalize);`

In unfinalizing mode that simplifies to:

- `setOpen(true)`

Everything else the pass does is there only to decide *which* heap types are safe to toggle and to apply that change coherently.

## Phase 6: `GlobalTypeRewriter` carries the real module rewrite

The pass ends with:

- `TypeRewriter(*module, *this).update();`

That is why this pass can safely change more than one declaration line.
`GlobalTypeRewriter` is the whole-module helper that rebuilds the type graph and updates uses consistently.

Beginner translation:

- Binaryen is not doing a text substitution on one `type` definition
- it is rebuilding the relevant part of the module's nominal type world

## Important source comment: this sibling exists for workflow reasons

The source comment explains the intended workflow in plain language:

- first un-finalize everything that is private
- run transformations that may need flexibility
- finalize safe leaf types again at the end

That comment makes the sibling's purpose concrete.
It is not a random inverse; it is a real type-state maintenance tool.

## No refinalization step

`TypeFinalizing.cpp` does **not** call `ReFinalize` for this sibling either.
That is a meaningful contrast with nearby passes such as:

- `type-merging`
- `type-generalizing`
- `gufa*`
- `signature-refining`

A good beginner explanation is:

- this pass changes declaration finality state and rewrites heap-type uses coherently through the global helper,
- but it is not narrowing local expression result types by AST walking,
- so there is no explicit second expression-refinalization phase here.

## Positive family 1: private final type becomes open

When a private type is final, `type-unfinalizing` can make it open again.
In Binaryen's printed WAT, that often means an explicit `sub final` form becomes a plain open `sub (...)` declaration.

## Positive family 2: private parent with children may reopen too

This is the key sibling difference.
A private non-leaf type cannot become final under `type-finalizing`, but it may still become open under `type-unfinalizing`.

## Positive family 3: function heap types participate too

The dedicated lit file shows that function heap types are also part of the rewrite surface, not just structs.
So the pass is about nominal heap-type openness broadly, not only object-layout types.

## Positive family 4: globals and locals keep following the rewritten graph

Because the pass uses a global helper, globals and locals that mention the rewritten heap types stay coherent after the update.
That is an important helper-level contract even though the pass body itself is tiny.

## Negative family 1: no GC means no effect

No GC, no pass action.

## Negative family 2: no public-type rewriting

Public heap types remain unchanged.
This is the main visibility boundary.

## Negative family 3: no body optimization

The pass does not walk function bodies looking for instructions to optimize.
Any visible body-level type use changes are consequences of the global remap, not targeted AST rewrites.

## Negative family 4: no deletion, merging, or subtype pruning

The pass does not:

- delete dead types
- merge equivalent types
- remove subtype edges

Those jobs belong to neighboring passes.

## Important helper dependencies

The most important helper dependencies are:

- `ModuleUtils::getPrivateHeapTypes(...)`
  - defines the visibility boundary
- `GlobalTypeRewriter`
  - performs the coherent module rewrite
- `TypeBuilder::setOpen(...)`
  - is the actual state toggle the pass applies
- `SubTypes`
  - matters indirectly because its absence here is part of the sibling split

So this pass is best understood as:

- **private-type selection plus one global open-bit rewrite**

not as a complicated optimizer.

## Starshine status bridge

Starshine currently preserves the local spelling `type-un-finalizing` only as a boundary-only registry name. It rejects direct requests before hot/module dispatch, has no owner file, and does not schedule the pass in `optimize` or `shrink` presets. The exact local follow-along map is [`./starshine-strategy.md`](./starshine-strategy.md).

## What a future Starshine port must preserve

A faithful port should preserve at least nine things:

1. the GC-only gate
2. the private-type visibility boundary
3. the lack of a leaf-only restriction for this sibling
4. the shared-engine split between finalizing and unfinalizing
5. module-wide coherent heap-type remapping
6. the fact that public types are not touched
7. the fact that no closed-world request is needed upstream here
8. the local-vs-upstream naming split for the sibling
9. the fact that there is no explicit AST refinalization phase

## Most important beginner correction

If someone says:

- “`type-unfinalizing` is just a broad open-all-types preparatory optimizer”

that is too vague to be useful.

A much better sentence is:

- “Binaryen `type-unfinalizing` is a tiny GC-only module rewrite that reopens private heap types through the same global type-rewrite engine used by `type-finalizing`, but without the leaf-only restriction.”
