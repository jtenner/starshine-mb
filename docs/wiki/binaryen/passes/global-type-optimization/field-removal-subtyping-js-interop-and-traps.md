---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md
  - ../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `global-type-optimization`: field removal, subtyping, JS interop, and traps

This page covers the half of `gto` that is easiest to misunderstand.

The pass name sounds simple.
The hard part is not “find an unread field.”
The hard part is preserving everything that makes the module still valid afterward.

## Mental model

Binaryen is trying to keep four promises at the same time:

1. if a field can disappear, subtype layout must still stay valid
2. if a field can become immutable, inherited parent/child slots must still agree
3. if JS could observe a descriptor prototype field, it must not disappear by accident
4. if a removed field had side effects or could trap, those effects and traps must still happen in the right order

That is the real pass contract.

## Part 1: why removing a field is not just deleting an index

### The easy case: unread everywhere

If a field is never read anywhere in the compatible hierarchy, Binaryen can remove it.
That is the simple “write-only field” case.

But the harder case is when a field is:

- dead in a parent
- still live in a child

That is where the pass becomes a layout pass.

### The parent/child problem

Suppose a parent has fields:

- `x`
- `y`

and a child extends that layout with:

- `z`

If the parent no longer needs `x` but the child still does, Binaryen cannot simply delete `x` from the parent and leave the child alone.
That would change the child's inherited field indexes and break subtype layout compatibility.

### What Binaryen actually does

Binaryen may first reorder the parent so the removable field is at the end of the inherited prefix.
Then it can remove that trailing parent field, and the child can re-add or keep its own version as an appended field.

That is why the source computes:

- `indexesAfterRemovals`

instead of a plain “removed yes/no” bit.

### The source-backed removal split

The pass removes a field when either:

- there are **no reads anywhere** in the compatible family
- or there are **no reads or writes in ourselves and our supertypes**, meaning only strict subtypes still need the field

That second rule is the key.
It is the reason `gto` can shrink parents even when children still use some of those fields.

## Part 2: why public parents matter

### Public types are frozen

The pass skips public heap types entirely.
That means it is not free to reorder or remove their fields.

### Consequence for children

If a child shares an inherited field with a public parent, that inherited slot may also be frozen even when the child itself is private.
The child still has to remain layout-compatible with the parent's exported shape.

### But child-only fields can still optimize

There is an important positive exception:

- if the child has a field the public parent does **not** have,
- the pass can still optimize that child-only field

The mutability lit tests check exactly this distinction.

So the real rule is not:

- public parent means private child cannot optimize anything

It is:

- public parent means the inherited shared prefix is fixed
- private child-only suffix fields may still optimize

## Part 3: why immutability is also a hierarchy problem

Making a field immutable sounds easier than removing it.
It is not entirely local either.

### What Binaryen requires

Binaryen can make a field immutable only if:

- the field is currently mutable
- there are no writes to that field anywhere in the relevant family
- if the parent has that same field index, the parent can make it immutable too

### Why the parent check matters

A mutable parent field and an immutable child field at the same inherited slot are not compatible.
So the pass refuses to optimize the child slot alone in that situation.

### The beginner-friendly summary

The actual rule is:

- **no runtime family writes, and parent-compatible layout allows the same immutability choice**

That is stricter than “I couldn't find a `struct.set` in this one type.”

## Part 4: why JS interop can keep a descriptor field alive

The most surprising liveness rule in this pass is usually not wasm code at all.
It is JS exposure.

### The specific field Binaryen cares about

When custom descriptors are enabled, `gto` pays special attention to descriptor field `0`.
That field can hold a JS-visible prototype.

### When Binaryen treats it as live

If a value may flow out to JS through:

- exported or JS-called functions
- imported functions
- imported or exported tables
- imported or exported globals

and the descriptor's field `0` could plausibly be a JS prototype carrier, Binaryen treats that field like it was read.

### Exact versus inexact types

There is also a type-precision wrinkle:

- if the boundary type is **inexact**, exposure propagates to subtypes
- if the boundary type is **exact**, that same subtype propagation does not happen automatically

That distinction is easy to miss if you only think in terms of field presence.
The JS interop lit file proves it directly.

### What does *not* count as a JS prototype here

The tests also prove negative rules:

- `anyref` descriptor fields are not treated as prototype carriers here
- null-only extern refs are not treated as useful prototype carriers here
- `stringref` descriptor fields are not treated as prototype carriers here
- mutable descriptor fields are not treated as prototype carriers here

So the pass is conservative, but not maximally conservative.

## Part 5: why removed writes still keep work alive

Another easy wrong mental model is:

- the field is dead, so the entire write can disappear

That is false.

### Removed `struct.set`

If the removed field had a `struct.set`, Binaryen still has to preserve:

- the value's side effects
- the null trap on the reference
- the original order between them

The source does that by building a replacement that:

- drops the value
- still forces the ref through `ref.as_non_null`
- keeps the trap after the value's effects

### Removed atomic sets

There is also a small but important atomic rule.
If the removed write was an atomic set, Binaryen does **not** emit a fence.
The source comment explains why:

- a field that was removed has no reads left,
- so there is no remaining synchronized reader to preserve here

That is a subtle source-backed non-goal.

## Part 6: why removed constructor operands need localization

Field removal in `struct.new` is even trickier because operands can be:

- reordered
- removed
- side-effectful
- trapping
- unreachable

### Inside functions

Binaryen uses `ChildLocalizer` before removing or reordering constructor operands.
That means side-effectful children can become locals first, making it safe to move or drop the field positions afterward.

This explains several test shapes:

- helper calls for removed operands turn into temps
- immutable `global.get` sometimes avoids a temp because its effects do not interact with later work
- mutable `global.get` does need a temp because later code could in theory change that global
- kept fields may also be localized for simplicity once the pass is already rewriting the constructor

### Unreachable children

When an unreachable operand appears, Binaryen still preserves the right observable behavior instead of silently dropping the surrounding constructor structure.
The lit file's replacement block for an unreachable constructor is the proof that this is an intentional contract.

## Part 7: why module initializers need synthetic globals

Inside functions, locals can preserve side effects while removed operands vanish.
Module-level code does not have that option.

### The problem

A global initializer may mention a constructor operand that:

- is attached to a field that will be removed
- but might still trap during instantiation

If Binaryen simply deletes that operand, it would change instantiation behavior.

### The solution

The pass records removed trapping initializer expressions and later emits fresh globals named like:

- `gto-removed-0`
- `gto-removed-1`

Those globals preserve the instantiation-time traps even though the unread field itself disappeared.

The descriptor-focused test file exercises this directly.

## Part 8: why EH fixups show up in a field-layout pass

At first glance, EH has nothing to do with field removal.
The connection is indirect:

- `ChildLocalizer` may insert a block
- if that block lands around `pop`-using code inside `try` / `catch` structure
- nested-pop validity may need repair afterward

So `gto` ends up calling:

- `EHUtils::handleBlockNestedPops(...)`

for functions that required this kind of localization.

This is not generic cleanup luck.
It is part of the pass's real rewrite safety story.

## Part 9: why later passes care about `gto`

The pass is not just cleaning up internal layout for its own sake.

### Concrete payoff chain

`gto_and_cfp_in_O.wast` shows the main closed-world story:

1. `gto` removes a dead `funcref` field
2. that deletes a `ref.func` edge that used to keep a function alive
3. later global cleanup can now remove that dead function
4. later constant-field propagation can infer the surviving field more aggressively

So the pass's place after `global-refining` and before later cleanup passes is part of the algorithmic meaning, not just default-pipeline decoration.

## What future Starshine work must preserve

A future port must preserve all of these at once:

- unread-field removal is hierarchy-aware, not just local
- public-parent shared prefix fields are frozen
- child-only fields can still optimize when absent from the public parent
- JS-visible descriptor prototype fields stay alive
- removed writes still preserve child effects and null-trap timing
- removed module-initializer traps still happen
- constructor reordering uses localization or an equivalent ordering-preserving strategy
- EH nested-pop repair still happens when localization inserted blocks

If any one of those is missing, the result is not really Binaryen `gto` any more.

## Bottom line

The hard part of `gto` is not “discover that field 3 is unread.”
The hard part is:

- **making that field disappear without breaking subtype layout, public ABI, JS-visible descriptors, or trap behavior**.

That is the source-backed behavior a future port must preserve.

## Sources

- [`../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md)
- [`../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md`](../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md`](../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalTypeOptimization.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals-rmw.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-mutability.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-shared-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-strings-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
