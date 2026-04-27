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
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-types/closed-world-visibility-and-rec-group-rewrite.md
---

# `type-finalizing`: leaf types, public boundaries, and the sibling split

This page covers the easiest part of `type-finalizing` to misread. It is source-confirmed by the 2026-04-24 raw manifest [`../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md).

## The three rules that matter most

If you remember only three things, remember these:

1. **public types stay untouched**
2. **only private leaf types can become final**
3. **the sibling can reopen private types**

That is almost the entire pass contract.

## Rule 1: public types stay untouched

The pass begins from `ModuleUtils::getPrivateHeapTypes(...)`, not from all heap types.
So public types are out of scope before Binaryen even thinks about finality.

Why this matters:

- public heap types are observable outside the module
- changing them casually is a very different compatibility question
- Binaryen keeps this pass simple by not doing that

Beginner correction:

- `type-finalizing` does **not** mean “mark everything final now”

## Rule 2: finalizing requires leaf types

When Binaryen is in finalizing mode, it checks whether each private type has any immediate subtypes.
If it does, the type is not modifiable.

Why?

Because a type with children cannot truthfully be marked final.

Beginner correction:

- `type-finalizing` is really “finalize the safe private leaves,” not “finalize the private graph indiscriminately”

## Rule 3: unfinalizing is broader on purpose

The sibling `type-unfinalizing` does not need the leaf proof.
It can reopen private types unconditionally.

This is the exact sibling split:

| Mode | Safety question |
| --- | --- |
| `type-finalizing` | “Can this private type honestly claim it has no children?” |
| `type-unfinalizing` | “Is this private enough that we are allowed to relax it?” |

## Why the sibling exists at all

The top comment in `TypeFinalizing.cpp` explains the intended workflow in plain language:

- unfinalize broadly before a batch of transformations
- finalize again at the end when safe

So the sibling is not a random inverse operation.
It is part of a practical type-graph maintenance workflow.

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

- open private leaf `sub` declaration becomes a plain final declaration under finalizing
- explicit `sub final` private declaration becomes open `sub (...)` under unfinalizing
- parent types with children stay open

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

For the current Starshine port map, exact local code surfaces, and future validation ladder, see [`./starshine-strategy.md`](./starshine-strategy.md) and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

A good future-port rule of thumb is:

- if your implementation ever starts changing public types, or starts finalizing non-leaf types, it is no longer matching Binaryen `version_129`

That is the clearest possible correctness alarm for this pass family.
