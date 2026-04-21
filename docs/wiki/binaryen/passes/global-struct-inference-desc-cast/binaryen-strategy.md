---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md
  - ../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md
  - ../global-struct-inference/binaryen-strategy.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-singleton-gate-and-dedicated-tests.md
  - ./wat-shapes.md
  - ../global-struct-inference/index.md
---

# Binaryen `global-struct-inference-desc-cast` / upstream `gsi-desc-cast` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/GlobalStructInference.cpp`
- `src/passes/pass.cpp`

Dedicated and nearby lit surfaces that matter here:

- `test/lit/passes/gsi-to-desc-cast.wast`
- `test/lit/passes/gsi-desc.wast`
- `test/lit/passes/gsi.wast`

## High-level intent

Binaryen exposes `gsi-desc-cast` as a sibling of plain `gsi`.
The sibling still performs all the ordinary shared-engine GSI work, but it also enables one extra rewrite family:

- turn some `ref.cast` nodes into `ref.cast_desc_eq`

The crucial source-confirmed correction is **how** it proves that rewrite.

It does **not** inspect the origin story of the cast input value in the rich way plain GSI inspects field-read sources.
Instead, the desc-cast-specific proof is much narrower:

1. the cast target heap type has a descriptor type
2. the target is exact, or the target heap type has no strict subtypes
3. the descriptor heap type has exactly one immutable top-level global instance in `typeGlobals`

When those hold, Binaryen builds a descriptor global read and rewrites the cast.

So the real mental model is:

- **plain GSI:** optimize trusted reads from struct-valued globals and propagated closed-world type families
- **`gsi-desc-cast`:** run plain GSI, and additionally rewrite some casts using a singleton descriptor global for the target type

## Where the pass runs

`pass.cpp` registers both:

- `gsi`
- `gsi-desc-cast`

The repo's canonical no-DWARF open-world path tracks only plain `gsi`.
So the descriptor-cast variant is:

- a real public upstream pass
- outside the repo's current top-level no-DWARF path
- a sibling in the same late GC/type neighborhood

## Shared pass skeleton

The sibling still uses the same owning class:

- `GlobalStructInference(bool optimizeToDescCasts)`

### Phase 0: GC gate

`run(Module* module)` returns immediately when the module lacks GC features.

### Phase 1: subtype data only when desc casts are enabled

If `optimizeToDescCasts` is true, the pass builds:

- `subTypes = std::make_unique<SubTypes>(*module)`

That is a desc-cast-specific requirement.
Plain `gsi` does not need it for the ordinary field-read rewrite surface.

### Phase 2: optional closed-world analysis

If `getPassOptions().closedWorld` is set, the pass runs:

- `analyzeClosedWorld(module)`

That populates `typeGlobals` by finding optimizable top-level immutable globals and then propagating those globals up supertype chains.

Important nuance:

- the pass as a whole can still run without closed world
- but the desc-cast-specific rewrite depends on `typeGlobals`
- so in practice, the desc-cast sibling needs closed-world analysis for the extra cast rewrites to fire

### Phase 3: shared optimization walk

The pass then calls:

- `optimize(module)`

That runs the shared function walker in parallel, the same way plain `gsi` does.

## Shared walker surface vs variant-only surface

The shared `FunctionOptimizer` handles:

- `visitStructGet`
- `visitRefGetDesc`
- ordinary value grouping
- select-based rewrites
- constant / nonconstant read replacement
- un-nesting into fresh immutable globals
- optional refinalization

The desc-cast sibling adds one extra visit hook:

- `visitRefCast(RefCast* curr)`

That is the only place where the public sibling differs in direct rewrite surface.

## The real `visitRefCast` contract

The actual source logic is short and very specific.

### Gate 1: desc-cast mode must be enabled

If `!parent.optimizeToDescCasts`, the hook returns immediately.

So plain `gsi` and `gsi-desc-cast` differ by constructor flag, not by separate owner files.

### Gate 2: the cast result type must not be `unreachable`

If `curr->type == Type::unreachable`, the pass leaves the cast alone.

That matches the dedicated lit file's unreachable-preservation case.

### Gate 3: the target heap type needs a descriptor type

The pass does:

- `auto heapType = type.getHeapType();`
- `auto desc = heapType.getDescriptorType();`

If there is no descriptor type, there is no rewrite.

### Gate 4: the target must be exact or have no strict subtypes

The pass checks:

- if the target type is not exact
- and `subTypes->getStrictSubTypes(heapType)` is not empty
- then bail out

This is the key legality condition behind the dedicated subtype tests.

It means `ref.cast_desc_eq` is used only when descriptor equality is strong enough to preserve the original cast semantics.

### Gate 5: the descriptor type must map to exactly one global

This is the most important source-confirmed correction.

The pass looks up:

- `parent.typeGlobals.find(*desc)`

and then requires:

- `globals.size() == 1`

If there are zero globals or more than one global for that descriptor type, it bails out.

This is a **target-descriptor-singleton** proof, not a cast-input-origin proof.

### Rewrite

If all gates pass, the pass emits:

- a `global.get` of the singleton descriptor global
- `builder.makeRefCast(curr->ref, getGlobal, curr->type)`

which prints as `ref.cast_desc_eq` in the dedicated lit output.

## What `typeGlobals` really means here

`typeGlobals` is populated in closed world by scanning:

- struct allocations inside functions, which can poison types as unoptimizable
- global initializers, where only top-level immutable non-imported globals with equality-comparable declared types are accepted
- supertype propagation, so a subtype's known globals can also become candidate globals for the supertype

That broad map is central for plain GSI field-read optimizations.

For `gsi-desc-cast`, however, only one narrow slice of it matters:

- the vector of globals for the **descriptor heap type of the cast target**

That is why the desc-cast sibling is narrower than the rest of the engine.

## What the pass does **not** do

Binaryen `gsi-desc-cast` in `version_129` does **not** do any of these:

- it does not optimize casts without GC
- it does not optimize casts to types without descriptors
- it does not optimize non-exact targets that still have strict subtypes
- it does not optimize when the descriptor type has zero globals in `typeGlobals`
- it does not optimize when the descriptor type has multiple globals in `typeGlobals`
- it does not inspect the cast input's runtime origin with the same grouping logic used for `StructGet` / `RefGetDesc`
- it does not replace `optimize-casts`
- it is not part of the repo's current no-DWARF default path

Those negative boundaries are as important as the positive rewrite.

## Dedicated test-backed shape families

The dedicated `gsi-to-desc-cast.wast` file proves all of these concrete families:

- `--gsi` leaves the casts alone while `--gsi-desc-cast` can produce `ref.cast_desc_eq`
- a non-exact cast to a type with strict subtypes bails out
- an exact cast can optimize even when the inexact sibling cannot
- independent descriptor hierarchies can both optimize
- zero descriptor-instance globals bail out
- multiple descriptor-instance globals bail out
- targets without descriptors bail out
- nullable targets can still optimize
- unreachable cast inputs are preserved

The related `gsi-desc.wast` file proves nearby shared descriptor machinery such as:

- `ref.get_desc` optimization
- descriptor un-nesting into fresh globals
- the nested `reorder-globals-always` repair path after adding globals

## Interaction with neighboring passes

### Plain `gsi`

This sibling should be taught as:

- plain `gsi`
- plus one extra desc-cast rewrite family

not as an entirely separate analysis family.

### `reorder-globals-always`

The sibling still inherits the shared un-nesting machinery.
If fresh globals are added, the pass runs a nested:

- `reorder-globals-always`

That remains part of the real module-validity contract.

### `optimize-casts`

This is the most important contrast.

- `optimize-casts` is an in-function cast reuse / motion family
- `gsi-desc-cast` is a target-descriptor-singleton rewrite in the shared GSI engine

A future port should keep those explanations separate.

## Current-main freshness note

A narrow freshness check against current `main` found:

- only comment typo fixes in `GlobalStructInference.cpp`
- no inspected logic drift in `visitRefCast`
- no inspected drift in `gsi-desc.wast`
- no inspected drift in `gsi-to-desc-cast.wast`

So the reviewed `version_129` contract still matches current `main` on the inspected surfaces.

## Bottom line

Binaryen `gsi-desc-cast` is really:

- **plain GSI's shared engine plus a narrow `ref.cast` -> `ref.cast_desc_eq` rewrite gated by target descriptor singleton globals and strict-subtype legality**

That is the behavior a future Starshine port would need to preserve.

## Sources

- [`../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md`](../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md)
- [`../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md`](../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md)
- [`../global-struct-inference/binaryen-strategy.md`](../global-struct-inference/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
