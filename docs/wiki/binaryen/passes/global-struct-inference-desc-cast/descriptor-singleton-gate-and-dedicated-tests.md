---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md
  - ../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md
  - ../../../raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../raw/research/0488-2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../global-struct-inference/closed-world-analysis-and-unnesting.md
---

# `gsi-desc-cast` singleton descriptor gate and dedicated tests

This page isolates the part of the pass that was easiest to mis-teach:

- what exactly makes Binaryen willing to emit `ref.cast_desc_eq`
- which upstream lit files actually prove that behavior

## The exact gate in one sentence

Binaryen `version_129` emits `ref.cast_desc_eq` only when the **target type's descriptor type** has **exactly one** known immutable top-level global in the closed-world `typeGlobals` map, and the target is exact or has no strict subtypes.

That is the simplest accurate summary of the source.
A 2026-05-05 current-main recheck kept the same gate on the reviewed surfaces.

## Why this matters

The broader GSI engine really does reason about trusted struct-valued globals, value grouping, subtype propagation, and un-nesting.
That can tempt a reader to assume the desc-cast sibling also performs a rich source analysis on the value being cast.

The actual `visitRefCast` logic does not do that.

It asks about:

- the cast **target** type
- the target's **descriptor** type
- the target's **strict subtypes**
- the descriptor type's **singleton global**

and then rewrites the cast using that global.

## The gate, step by step

## 1. Desc-cast mode must be enabled

Plain `gsi` and `gsi-desc-cast` share one owner class.
The sibling rewrite exists only when `GlobalStructInference(true)` was constructed.

## 2. The cast result type cannot be `unreachable`

If the result type is already `unreachable`, the pass leaves the cast alone.

## 3. The target heap type must have a descriptor type

No descriptor type means there is no descriptor-equality cast to emit.

## 4. The target must be exact or have no strict subtypes

A desc-equality cast only preserves the original cast when descriptor equality is strong enough.
If the target is non-exact and still has strict subtypes, Binaryen bails out.

## 5. The target descriptor type must map to exactly one global

This is the decisive rule.

- zero globals: no rewrite
- one global: possible rewrite
- more than one global: no rewrite

Binaryen does not try a select here.
The dedicated lit file records both zero-global and two-global bailout cases.

## 6. The replacement is direct

When the gates pass, Binaryen emits:

- the original cast input `curr->ref`
- a `global.get` of the singleton descriptor global
- the original target type

The printed WAT becomes `ref.cast_desc_eq`.

## What the dedicated lit files prove

## `gsi-to-desc-cast.wast`

This is the main proof file for the sibling.
It directly compares:

- `wasm-opt --gsi`
- `wasm-opt --gsi-desc-cast`

### Positive cases it proves

- leaf non-exact target with singleton descriptor global
- exact cast that can optimize even when the non-exact sibling cannot
- independent descriptor hierarchies where both casts optimize
- nullable target cast that still optimizes

### Bailout cases it proves

- non-exact target with relevant strict subtypes
- zero descriptor-instance globals
- two descriptor-instance globals
- target without a descriptor type
- unreachable cast input

### Extra nuance it proves

The file also includes an explicit comment noting one exact-cast family Binaryen still does not optimize because the pass propagates on `typeGlobals`.
That comment is part of the real reviewed contract and should not be silently erased in local docs.

## `gsi-desc.wast`

This is not the desc-cast delta file, but it proves the neighboring descriptor machinery that the sibling reuses:

- `ref.get_desc` rewrites
- descriptor-value selection
- descriptor un-nesting into fresh globals
- the need for nested `reorder-globals-always`

So it is best read as:

- shared descriptor-family proof for the underlying engine
- not the primary oracle for `ref.cast_desc_eq`

## `gsi.wast`

This broader family file is still useful neighboring context, but it is no longer the right headline test citation for the sibling.

## Beginner-safe mental model

If you need one short rule to remember, use this:

- **plain GSI** proves things about struct reads
- **`gsi-desc-cast`** proves one thing about cast targets: “I know exactly which descriptor global this target type corresponds to, and descriptor equality is precise enough here.”

That model matches the source much better than the older “trusted cast-input origin” story.

## Porting checklist

A future Starshine port should preserve these exact conditions explicitly:

- same shared engine as plain `gsi`
- desc-cast mode flag
- subtype table for legality
- closed-world population of `typeGlobals`
- target descriptor existence check
- exact-or-no-strict-subtypes check
- exactly-one-global rule for the descriptor type
- ordinary bailout on zero or many descriptor globals
- no fake select-based desc-cast extension unless documented as a local departure

## Sources

- [`../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md)
- [`../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md`](../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md`](../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast>
