---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0193-2026-04-21-type-un-finalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../type-finalizing/leaf-types-public-boundaries-and-sibling-split.md
---

# `type-unfinalizing`: private boundaries, sibling split, and the no-leaf rule

This page covers the easiest part of `type-unfinalizing` to misread.

## The three rules that matter most

If you remember only three things, remember these:

1. **public types stay untouched**
2. **private types may reopen even when they are not leaves**
3. **this is the broader sibling of `type-finalizing`, not a synonym for it**

That is almost the entire pass contract.

## Rule 1: public types stay untouched

The pass begins from `ModuleUtils::getPrivateHeapTypes(...)`, not from all heap types.
So public types are out of scope before Binaryen even thinks about openness.

Why this matters:

- public heap types are observable outside the module
- changing them casually is a different compatibility question
- Binaryen keeps this pass simple by not doing that

Beginner correction:

- `type-unfinalizing` does **not** mean “reopen everything now”

## Rule 2: the sibling drops the leaf-only restriction

`type-finalizing` needs to prove a private type has no immediate children before marking it final.
`type-unfinalizing` does not need that proof.

Why?

Because reopening a type does not claim the type has no subtypes.
It only relaxes the declaration state.

Beginner correction:

- `type-unfinalizing` is not “finalizing but backward with the same filter”
- it is broader specifically because the leaf-only truthfulness check is unnecessary here

## Rule 3: the sibling exists for workflow reasons

The source comment in `TypeFinalizing.cpp` explains the intended workflow:

- reopen private types before transformations that benefit from flexibility
- finalize safe leaves again later when desired

So the sibling is not an arbitrary inverse operation.
It is part of a real maintenance flow for the private nominal type graph.

## Exact sibling comparison

The cleanest comparison is:

| Pass | Modification set | Main safety rule |
| --- | --- | --- |
| `type-finalizing` | private leaf types | only finalize types with no immediate subtypes |
| `type-unfinalizing` | private types | privacy alone is enough |

That table is the easiest way to keep the family straight.

## The naming split is worth documenting

Starshine's local registry spells the sibling as:

- `type-un-finalizing`

Upstream Binaryen registers:

- `type-unfinalizing`

That tiny spelling difference is easy to miss when searching or mapping pass names.

## How public and private interact with the lit file

The dedicated lit file proves the visibility rule in a beginner-friendly way:

- public types stay unchanged in both modes
- private types change according to the selected mode

That is a stronger teaching surface than the source file alone because it shows the public contract directly in WAT.

## What changes visibly in WAT

Usually the visible shift is one of these:

- private `sub final` declaration becomes open `sub (...)`
- private final function heap type becomes open too
- public final declaration stays final

The main point is that Binaryen is changing **nominal type openness**, not optimizing function bodies.

## What this pass is not doing

This pass is not:

- deleting types
- merging types
- removing subtype edges
- inferring better field types
- retagging `struct.get` or `call_ref`

That makes it very different from neighbors like:

- `remove-unused-types`
- `type-merging`
- `type-generalizing`
- `unsubtyping`

## Porting rule of thumb

A good future-port rule of thumb is:

- if your implementation ever starts changing public types, or insists on a leaf-only proof before reopening private types, it is no longer matching Binaryen `version_129`

That is the clearest possible correctness alarm for this sibling.
