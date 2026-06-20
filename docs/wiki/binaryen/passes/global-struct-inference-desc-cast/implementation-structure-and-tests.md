---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md
  - ../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md
  - ../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md
  - ../../../raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../raw/research/0488-2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./descriptor-singleton-gate-and-dedicated-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../global-struct-inference/index.md
---

# `gsi-desc-cast` implementation structure and tests

## Core file map

## `src/passes/GlobalStructInference.cpp`

This is the owning implementation file for both:

- plain `gsi`
- descriptor-cast sibling `gsi-desc-cast`

What it proves:

- the variant is not a separate engine
- `createGlobalStructInferencePass()` constructs `GlobalStructInference(false)`
- `createGlobalStructInferenceDescCastPass()` constructs `GlobalStructInference(true)`
- `requiresNonNullableLocalFixups() == false`
- subtype data is created only when desc-cast mode is enabled
- ordinary `StructGet` / `RefGetDesc` work still uses the shared optimizer
- desc-cast-specific logic is isolated to `visitRefCast(RefCast*)`
- fresh-global creation plus nested `reorder-globals-always` remains part of the inherited rewrite contract when un-nesting happens

### Most important owner detail

The desc-cast sibling's specific cast rewrite is **much narrower** than the old dossier implied.

`visitRefCast` checks only:

- desc-cast mode enabled
- result type not `unreachable`
- target heap type has a descriptor type
- target is exact or has no strict subtypes
- the descriptor heap type has exactly one global in `typeGlobals`

Then it rewrites the cast using that singleton descriptor global.

So this file proves the sibling is a **target-descriptor-singleton** optimization, not a general cast-input-origin analysis.

## `src/passes/pass.cpp`

This is the source of truth for public pass registration and scheduler meaning.

What it proves:

- Binaryen publishes `gsi-desc-cast` as a real separate public pass name
- its public summary is `globally optimize struct values, also emitting ref.cast_desc_eq`
- it is a sibling of `gsi`, not merely an internal debug mode
- it is not part of the repo's currently tracked no-DWARF default path even though plain `gsi` is

For this dossier, `pass.cpp` is also the main evidence behind the local-vs-upstream naming split:

- local registry: `global-struct-inference-desc-cast`
- upstream public name: `gsi-desc-cast`

## Shared helper dependencies that actually matter here

## `src/ir/subtypes.h`

This helper matters directly for the sibling because `visitRefCast` checks:

- whether the target heap type has strict subtypes

That is the legality reason some non-exact casts stay as ordinary `ref.cast`.

## `src/ir/module-utils.h`

This matters because closed-world analysis and parallel function analysis are still shared with plain `gsi`.
The sibling inherits the same `typeGlobals` population path even though its cast rewrite uses only the descriptor-type slice of that map.

## `src/ir/find_all.h`

This matters in `analyzeClosedWorld(...)` because the pass scans for `StructNew` in:

- defined function bodies, to mark types unoptimizable
- global initializers, to find optimizable top-level immutable globals and reject nested uses

## `src/ir/names.h`

This matters only indirectly here: the shared engine may still un-nest globals for ordinary descriptor-read optimizations, and then needs valid deterministic names for the added globals.

## Dedicated upstream lit surface

The old dossier said the visible reviewed proof surface was only the broad shared `gsi.wast` family.
That was incomplete.

The reviewed `version_129` sources contain two important dedicated files for this sibling area.

## `test/lit/passes/gsi-to-desc-cast.wast`

This is the most important dedicated test file for the sibling itself.

What it proves:

- `--gsi` and `--gsi-desc-cast` differ intentionally
- the sibling can emit `ref.cast_desc_eq`
- non-exact targets with relevant strict subtypes bail out
- exact casts can optimize more often than inexact casts
- independent descriptor hierarchies can both optimize
- zero descriptor-instance globals bail out
- multiple descriptor-instance globals bail out
- casts to types without descriptors bail out
- nullable target casts can still optimize
- unreachable cast inputs stay on the ordinary cast path

This file is the best direct proof for the public desc-cast variant.

## `test/lit/passes/gsi-desc.wast`

This file is not the cast-delta file, but it is still part of the real sibling story.

What it proves:

- the shared descriptor-read side of GSI is real and separately exercised
- `ref.get_desc` optimization is explicit upstream behavior
- descriptor values can be selected from multiple globals
- nonconstant descriptor operands can be un-nested into fresh globals
- the resulting global-order repair story is not hypothetical

That shared descriptor machinery matters because `gsi-desc-cast` is still built on top of the same engine and `typeGlobals` map.

## `test/lit/passes/gsi.wast`

This broader family file still matters as neighboring context, but it is no longer correct to describe it as the only visible reviewed proof surface for the variant.

## Current-main freshness result

A narrow freshness check on current `main` found:

- only comment typo cleanup in `GlobalStructInference.cpp`
- no inspected logic drift in `visitRefCast`
- no inspected changes in `gsi-to-desc-cast.wast`
- no inspected changes in `gsi-desc.wast`

So the reviewed `version_129` owner/test map still matches current `main` on the inspected surfaces.

## Structural lesson for a future Starshine port

A parity-minded local implementation should mirror these structural facts first:

1. keep `global-struct-inference-desc-cast` as a sibling of `gsi`, not as a mode mixed into unrelated cast passes
2. preserve the public naming split while treating the pass as a real module-pass surface, not a boundary-only alias
3. keep the desc-cast-specific rewrite isolated to a `visitRefCast`-style hook or local equivalent
4. drive that rewrite from the **target descriptor singleton** rule, not from a made-up richer cast-input-origin oracle
5. keep the strict-subtype legality check explicit
6. keep the inherited closed-world `typeGlobals` population and nested `reorder-globals-always` repair story explicit
7. use the dedicated `gsi-to-desc-cast.wast` delta file as the main oracle for the sibling

2026-06-20 Starshine activation note: the local pass now implements the singleton descriptor-global positive for immediate `local.get` / `global.get` cast operands plus nullable, exact target, closed-world, zero/multiple-global, and non-exact strict-subtype bailout tests. Broader operand coverage and dedicated closed-world descriptor-cast fuzz generation remain open in [`./starshine-strategy.md`](./starshine-strategy.md).

## Sources

- [`../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md)
- [`../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md`](../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md`](../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md)
- [`../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md`](../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
