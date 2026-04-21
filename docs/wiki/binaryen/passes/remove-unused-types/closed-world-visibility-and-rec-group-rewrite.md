---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
---

# `remove-unused-types`: closed-world visibility and rec-group rewrite rules

This page covers the part of `remove-unused-types` that is easiest to misunderstand.

The pass is not mainly asking:

- is this heap type referenced anywhere locally?

It is asking two stricter questions:

1. is this heap type **public** and therefore part of the external boundary?
2. if a private type stays, what **whole rec group** and rewritten group structure must stay with it?

Those two questions explain both the closed-world gate and the `GlobalTypeRewriter` helper.

## The biggest beginner misunderstanding

The easy wrong model is:

- find unreferenced types and delete them one by one

The real model is:

- keep public types first,
- find used private heap types,
- keep whole rec groups for those private types,
- then rebuild the module's type graph without needlessly perturbing public groups.

## Part 1: public types are not the same thing as locally used types

`remove-unused-types` starts by collecting `publicTypes` with `ModuleUtils::getPublicHeapTypes(*module)`.

That means a type can survive for reasons other than local use.

### Positive public-type family

Conceptually:

```wat
(type $pub (sub (struct)))
(export "T" (type $pub))
```

Even if the remaining internal code never mentions `$pub` again, the type still stays because it is public.

### Why this matters

If Binaryen deleted that type just because it was not used inside function bodies, it would break the external closed-world boundary the pass is still trying to preserve.

So the pass treats:

- **public**
- **used private**

as two different reasons to keep a type.

## Part 2: only private used types enter the rebuild set

After collecting `usedTypes`, Binaryen erases all public types from that set.

That leaves:

- private types that are actually still used

This is a deliberate split.
Public types stay because of visibility.
Private types stay only if the module still needs them internally.

A good short rule is:

- public types are preserved
- private types must still earn their place by use

## Part 3: rec groups are the real retention unit

This is the most important structural rule in the pass.

When a private used type survives, Binaryen copies that type's **whole old rec group** into the new private builder.

That means a shape like this is misleading if read one type at a time:

```wat
(rec
  (type $A (struct (field (ref null $B))))
  (type $B (struct (field i32))))
```

If `$A` is still used privately, Binaryen does not try to keep only `$A` and throw away `$B` casually.
It keeps the whole recursive group.

### Positive family

- one used private member in a private rec group
- result: the whole private group stays

### Negative family

- no member of a private rec group is used privately
- result: the whole private group can disappear

This is why the pass is rec-group-aware type GC, not isolated node deletion.

## Part 4: public groups must not be perturbed unnecessarily

`GlobalTypeRewriter` has the subtle job of threading rewritten private groups around public groups.

The important source-backed rule is:

- if the current old group is public, keep that public group structure as the anchor
- only add rewritten private pieces into that public group when the rewritten type relationship actually requires it
- do not drag unrelated private groups into a live public group for no reason

The dedicated lit file explicitly checks this family.

### Conceptual family

Before:

```wat
(rec
  (type $Pub ...))
(rec
  (type $PrivateUnused ...)
  (type $PrivateUsed ...))
```

If only `$PrivateUsed` matters, Binaryen does **not** treat the public group as a free dumping ground for every later private type that happened to exist nearby in the old numbering.

That is a major correctness and readability rule.

## Part 5: closed world is required because public type identity is not trivial

The helper comments in `type-updating.h` make the closed-world dependency explicit.

In beginner terms:

- once public type identity and subtype relations can escape the module,
- Binaryen cannot freely decide that a rewritten internal subtype arrangement is still externally safe.

That is why `remove-unused-types` exits immediately when `!module->closedWorld`.

The correct lesson is:

- closed world is part of the proof, not just a heuristic

## Part 6: public supertypes do not automatically keep every private subtype group alive

This is another easy trap.

A public type being live does **not** mean every private subtype group somewhere below it must also stay.

What matters is whether those private types are actually used.

So the mental model is not:

- public root implies keep whole private subtype forest

The mental model is:

- keep public boundary structure stable,
- then keep only the private subgraph that is still used

That distinction is one reason the dedicated test file is worth reading together with `GlobalTypeRewriter`.

## Part 7: this is why the pass is not just a smaller RUME

`remove-unused-module-elements` works at the declaration graph level.
It decides whether functions, globals, tags, tables, memories, elem segments, and data segments survive.

`remove-unused-types` runs after that kind of cleanup and asks a different question:

- now that the surviving declaration and code graph is smaller, which private heap types are still needed and how do we rewrite the type section safely?

So the two passes are adjacent, but they are not duplicates.

## Future Starshine port rules

A future port must preserve at least these rules:

- public heap types are a separate keep-set from used private types
- rec groups are the retention unit for private survivors
- open-world modules must not silently enter this pass's rewrite logic
- public groups should not absorb unrelated private groups unnecessarily
- the final output must be a fully rewritten module heap-type graph, not just a filtered type list

## Bottom line

The best one-sentence explanation of `remove-unused-types` is:

- **keep the public boundary stable, keep the live private rec groups, then rewrite the module around that split**

That is the real contract hidden behind the tiny pass file.

## Sources

- [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
