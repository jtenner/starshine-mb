---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md
  - ../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-05-05-remove-unused-types-current-main-recheck.md
  - ../../../raw/research/0477-2026-05-05-remove-unused-types-current-main-recheck.md
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
---

# `remove-unused-types`: closed-world visibility and private-group rewrite rules

This page covers the part of `remove-unused-types` that is easiest to misunderstand.
A 2026-05-05 current-main recheck kept this shape intact.

The pass is not mainly asking:

- did one old rec-group member survive, so should the whole old rec group stay?

The corrected source-backed question is:

1. which type groups are **public** and must anchor the boundary?
2. which private heap types are still **used by the IR**?
3. how should Binaryen rebuild the surviving private types around public anchors and private dependency edges?

## The biggest beginner misunderstanding

The old easy model was:

- find used private types and keep their whole old rec groups.

The corrected model is:

- keep public groups as anchors,
- drop unused private heap types,
- rebuild surviving private heap types in dependency order,
- and remap the module to the new graph.

That correction matters because old private rec-group boundaries are not automatically preservation boundaries.

## Part 1: closed world is a hard proof boundary

`RemoveUnusedTypes.cpp` treats open-world execution as unsupported.
The reason is not just profitability.

In open world, public type identity and public subtype/group shape can be observed outside the module.
A private type-section rewrite that is safe in a closed-world module may be invalid or at least unproven when outside code can depend on the old graph.

A future Starshine port should keep that rule explicit:

- no GC: unchanged,
- open world: rejected or not scheduled,
- closed-world GC: eligible.

## Part 2: public groups are anchors

`GlobalTypeRewriter` identifies public type groups and preserves them as anchoring structure.

A public type can survive for reasons other than local profitability.
Conceptually:

```wat
(module
  (type $pub (sub (struct)))
  (export "T" (type $pub))
  (func (result i32)
    (i32.const 0)))
```

The internal code may not need `$pub`, but the type is externally visible.
That external visibility is enough to keep the public group anchored.

## Part 3: used private types are the cleanup candidates that survive

Private types do not survive merely because they used to sit near a public group or inside a larger private group.
They survive when they are still used by the module's IR-facing type graph.

That includes more than obvious function-body operands:

- function signatures,
- locals,
- globals,
- tables and element segments,
- tags,
- heap-type fields,
- expression result types.

## Part 4: old private rec groups are not automatically retained whole

This is the main corrected rule.

If a private old rec group contains two members and only one remains relevant, Binaryen's corrected `GlobalTypeRewriter` story is not “keep the whole old group because one member is live.”
It can rebuild only the surviving private type(s), subject to real dependency edges.

Conceptual old input:

```wat
(rec
  (type $live (struct))
  (type $dead (struct)))
(func (result (ref null $live))
  (ref.null $live))
```

Correct mental output:

```wat
;; $live survives under a rewritten private type identity.
;; $dead can disappear if no surviving type or declaration references it.
```

The old rec-group boundary is not the keep unit.
The used private heap-type set and dependency graph are.

## Part 5: private dependency edges still matter

Binaryen cannot reorder surviving private types arbitrarily.
The helper derives predecessor constraints from private dependencies such as:

- private supertypes,
- described-type relationships.

If a surviving private type refers to another surviving private type as a supertype or descriptor-related dependency, the rebuilt order must respect that relationship.

Beginner translation:

- Binaryen deletes unused private types,
- but it still keeps enough ordering structure for the remaining private type definitions to be valid.

## Part 6: public supertypes do not keep the whole private subtype forest alive

A public type being live does not mean every private subtype group under it must survive.

Conceptually:

```wat
(module
  (type $pub (sub (struct)))
  (export "T" (type $pub))
  (type $private-sub (sub $pub (struct)))
  (func (result i32)
    (i32.const 0)))
```

The public supertype stays.
The private subtype can disappear if it is not used.

That is why the pass is different from a public-root reachability closure over every private subtype.

## Part 7: used private subtypes of public types can survive without moving the public group

If a private subtype of a public type is still used, the private type can be rebuilt as part of the new private group while still referring to the public supertype.

The public group remains the anchor.
The private survivor is rebuilt around it.

That is the key shape behind “public boundary stable, private graph smaller.”

## Part 8: descriptor / described links are not ordinary dead text

The helper gives descriptor/described relationships ordering significance.
That means future Starshine work must be careful with pages that discuss custom descriptors, exact refs, `ref.get_desc`, or `struct.new_desc`.

A private described type or descriptor type may impose a predecessor edge even when the visible WAT looks like a simple type deletion.

## Part 9: this is why the pass is not just a smaller RUME

[`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md) decides which module elements survive.

`remove-unused-types` runs in a different space:

- after declarations and code have been cleaned up,
- which heap types are still needed,
- and how should the module's type graph be rebuilt?

The two passes are adjacent, but not duplicates.

## Future Starshine port rules

A future port must preserve at least these rules:

- closed-world and GC gates are required,
- public groups are a separate boundary from private survivor selection,
- old private rec groups are not automatically preserved whole,
- private supertype and descriptor/described dependencies must constrain the rebuild order,
- public supertypes do not keep all private subtype groups alive,
- the final output must be a valid rewritten module heap-type graph.

## Bottom line

The best one-sentence explanation of the corrected `remove-unused-types` contract is:

- **preserve public group anchors, rebuild only the used private heap-type graph, then rewrite the module around that new graph**.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md)
- [`../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md`](../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md)
- Historical, superseded for the whole-old-rec-group model: [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
