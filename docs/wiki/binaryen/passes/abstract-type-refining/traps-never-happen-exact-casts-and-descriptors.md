---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md
  - ../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `abstract-type-refining`: TNH, exact casts, and descriptors

This page focuses on the easiest part of the pass to misread.

This page is anchored by the immutable primary-source manifest in [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md) and the current Starshine status page in [`./starshine-strategy.md`](./starshine-strategy.md).

If you only remember one thing from this page, remember this:

- `abstract-type-refining` is **not** allowed to make a previously impossible exact or descriptor-sensitive check start succeeding just because `--traps-never-happen` lets it reason more aggressively about abstract parent types.

That is why the pass has a real preoptimization phase.

## The core split: bottomization vs child refinement

The pass has two different kinds of rewrite.

### Always-on bottomization

If a struct type and all its subtypes are never created, then Binaryen can rewrite that family to bottom in both TNH and non-TNH modes.

Examples of the visible results are:

- `(ref $T)` -> `(ref none)`
- `(ref null $T)` -> `nullref`
- shared ref families -> shared bottom families

### TNH-only child refinement

If an abstract parent has exactly one still-relevant child branch, then `--traps-never-happen` lets Binaryen refine:

- casts to the parent
- tests of the parent
- local/result/global type uses of the parent

into the live child.

But that second rule is **not** unconditional.
Exact and descriptor-sensitive operations need extra care first.

## Why TNH changes only part of the algorithm

The source comment at the top of `AbstractTypeRefining.cpp` explains the key idea:

- if `$B` is abstract in a chain like `$A :> $B :> $C`, and TNH says the cast cannot fail, then a cast to `$B` can effectively only mean `$C` or one of its subtypes

That is enough to justify parent-to-child refinement for ordinary inexact checks.

But TNH does **not** justify everything.
Some operations would change semantics if naively retargeted.

The exact-cast and descriptor lit files exist to make that boundary explicit.

## Exact casts: why Binaryen often goes to bottom instead of to a live child

The most important exact-cast lesson is:

- a cast that was impossible before must not become possible after refinement

Consider the dangerous naive rewrite:

- original: exact cast to never-instantiated `$uninstantiated`
- naive TNH rewrite: exact cast to live child `$instantiated`

That would make the cast start succeeding on real `$instantiated` values.
That is wrong.

So Binaryen does something stricter.

### Non-null exact casts

A non-null exact cast to an optimized-away type becomes a cast to:

- `(ref none)`

That preserves the “can only fail” meaning.

### Nullable exact casts

A nullable exact cast becomes a cast to:

- `nullref`

That preserves the one surviving success case:

- null can still pass

### Branching exact casts

The same rule applies to:

- `br_on_cast`
- `br_on_cast_fail`

So impossible exact branch casts do **not** refine to live children either.
They become branch casts on bottom or nullref-like targets instead.

## Descriptor casts: why the descriptor child matters

Descriptor-sensitive casts are even trickier.
For operations like:

- `ref.cast_desc_eq`
- `br_on_cast_desc_eq`
- `br_on_cast_desc_eq_fail`

there are two typed inputs that matter:

1. the reference being checked
2. the descriptor value

A naive heap-type rewrite can leave those two pieces inconsistent.
That is why the preoptimizer repairs them before shared type rewriting runs.

## Descriptor casts whose target goes to bottom

When the optimized target goes to bottom, Binaryen rewrites descriptor casts to the corresponding ordinary bottom/null cast.

The result is essentially:

- keep the ref input evaluation
- keep the descriptor input evaluation when needed
- but remove the descriptor-sensitive type relation itself
- then cast/branch on the impossible bottom/null target

This is why descriptor-branch ops become ordinary branch-cast ops after preoptimization.

## Why nullable descriptor operands may get `ref.as_non_null`

Outside TNH, a nullable descriptor operand can still matter because evaluating it may null-trap.

So before dropping the descriptor child, Binaryen may insert:

- `ref.as_non_null`

around the descriptor operand.

That preserves the original trap behavior.

The descriptor lit file shows this most clearly in the non-TNH cases where the output grows:

- a fresh temp local
- `ref.as_non_null`
- then the simplified cast/branch

The beginner-friendly reading is:

- Binaryen keeps the descriptor's trap semantics even when the final type relation is being simplified away.

## Why `ChildLocalizer` appears in the output

If both the ref child and the descriptor child can have side effects, Binaryen cannot just delete or reorder them.

So it uses `ChildLocalizer` to create a block that:

- evaluates the children in original order
- stores them in temps when necessary
- then runs the simplified cast/branch using those temps

That is why the descriptor tests often show a pattern like:

- create temp for ref input
- create temp for descriptor input
- maybe add `ref.as_non_null` on the descriptor temp
- then run the simplified `ref.cast` / `br_on_cast`

The local scaffolding is not incidental pretty-print noise.
It is the evaluation-order proof.

## `ref.get_desc`: trap-only vs refined-survivor cases

`ref.get_desc` is the other hard surface.
If the fetched descriptor type is being optimized, Binaryen must avoid leaving an operation whose result type no longer validates.

There are two important cases.

### Case 1: the fetch is impossible

If the result descriptor type is exact, or there is no surviving live subtype path, the pass rewrites to:

- drop the input ref
- then `unreachable`

The test file makes this visible in cases where the function result type itself bottomizes.
The pass must remove the `ref.get_desc`, not just change the surrounding type.

### Case 2: an inexact input may still hold a surviving subtype

If the input is inexact and a subtype like `$A.sub` can still exist, Binaryen can keep the operation, but only after inserting a cast to the surviving described subtype.

So the result becomes something like:

- `ref.get_desc $A.sub`
- applied to `ref.cast (ref $A.sub) ...`

That is one of the clearest examples of the pass being conservative and precise at the same time.
It does **not** drop the operation, and it does **not** pretend the original broader type is still right.

## `struct.new_desc`: function vs module context

Impossible descriptor-bearing allocations are repaired differently depending on where they appear.

### In functions

If a `struct.new_desc` becomes impossible in a function body, Binaryen rewrites it to:

- preserve child side effects
- then `unreachable`

This is why the descriptor tests show patterns like:

- `drop` side-effectful child block
- `unreachable`

### In globals/module code

At module level, Binaryen cannot synthesize ordinary local temps and blocks.
So it simply rewrites the descriptor operand to:

- `ref.null none`

That preserves the correct module-level impossible-allocation meaning without introducing illegal structure.

The function/global split is a real contract surface.

## TNH does **not** erase side effects

A common wrong intuition is:

- if TNH lets Binaryen treat some operation as impossible, then it can just delete the whole thing

That is false whenever children have side effects.

The lit files repeatedly show TNH cases where Binaryen still preserves:

- calls in the ref input
- calls in the descriptor input
- temp locals or block structure needed to keep order

TNH weakens trap constraints.
It does not permit arbitrary side-effect deletion.

## Relationship to `unsubtyping`

Another easy confusion is between:

- `abstract-type-refining`
- `unsubtyping`

The descriptor/exact-cast repair in this pass does **not** mean it owns full late relation cleanup.

The split is:

- `abstract-type-refining`
  - rewrites type **uses** based on creation evidence
  - repairs exact/descriptor operations so the use rewrite is legal and behavior-preserving
  - preserves declared supertypes
- `unsubtyping`
  - later minimizes declared subtype and descriptor relations themselves

So when a future port sees the pass changing many use sites but not the declaration graph, that is expected.

## Practical beginner rules

When reading a possible `abstract-type-refining` rewrite, ask these questions in order:

1. Is this type truly never created, or does some subtype still exist?
2. Are we in `--traps-never-happen` mode?
3. Is the operation exact or inexact?
4. Is there a descriptor operand that can null-trap?
5. Do the children have side effects that require localization?
6. Is this a use-site rewrite only, with declared subtype cleanup deferred to `unsubtyping`?

Those six questions explain most of the non-obvious output shapes.

## Bottom line

The hard half of `abstract-type-refining` is not “pick a better type.”
It is:

- **keep impossible exact and descriptor-sensitive operations impossible, preserve side effects and nullable-descriptor traps, and only then let shared type rewriting proceed**

That is why the preoptimization phase is part of the real algorithm.

## Sources

- [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md)
- [`../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md`](../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/drop.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
