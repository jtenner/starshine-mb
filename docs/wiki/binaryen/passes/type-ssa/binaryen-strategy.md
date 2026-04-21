---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0217-2026-04-21-type-ssa-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
  - ../type-merging/index.md
  - ../ssa/index.md
---

# Binaryen `type-ssa` strategy

## Upstream source rule

Use Binaryen `version_129` as the source oracle for this pass.
The core sources are:

- `src/passes/TypeSSA.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-ssa.wast`
- `src/ir/ReFinalize.cpp`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>

## The pass in one sentence

Binaryen `type-ssa` is a small GC function pass that remembers exact created reference types, propagates them through SSA-like local/global and control-value flows, and retags later uses, call operands, and returns when the narrower type is subtype-safe.

## Biggest naming fact

The easiest mistake is to read `type-ssa` as if it meant:

- “convert the function to SSA form, but for types.”

That is not the real `version_129` contract.

A better reading is:

- “preserve exact created heap-type information across simple SSA-like flows.”

So the pass is much smaller than full [`../ssa/index.md`](../ssa/index.md), and much more local than broader GC/type passes.

## Public-pass fact

`pass.cpp` registers `type-ssa` as its own public pass name.
So this is not just an unnamed helper mentioned by `type-merging`.
It is a real public Binaryen pass.

## Scheduler fact

For this repo, `type-ssa` is currently upstream-only:

- it is not in the local Starshine registry,
- it is not in the no-DWARF default optimize path page,
- and it is not in the saved generated-artifact `-O4z` skipped-slot queue.

So this dossier is a justified upstream-only expansion rather than a missing default-parity pass.

## Core state: `createdTypes`

The implementation keeps one central map:

- `std::unordered_map<Expression*, Type> createdTypes;`

That is the entire pass's mental center.
It is not building a broad lattice over all expressions.
It is only remembering places where Binaryen knows a value has a more specific exact reference type.

## Helper 1: `getTargetType`

The helper `getTargetType(Type type)` is the first real boundary.
It rejects:

- non-reference types,
- `anyref`,
- `eqref`,
- `i31ref`,
- and `none`.

If the type is already exact, it keeps it.
Otherwise it turns the heap type into an **exact non-null** version.

That means the pass's precision starts from a very narrow idea:

- concrete heap-typed references that Binaryen can treat as freshly exact.

## Helper 2: `setCreatedType`

The pass only records a created type when the target type is not `none`.
That small gate is why the pass does not try to generalize broad abstract reference families.

## Helper 3: `getValue`

`getValue(Expression*)` defines how control-flow wrappers propagate created types.
The reviewed `version_129` source handles:

- ordinary expressions by default,
- `block` via the last child,
- `if` only when both arms produce the same created type,
- `try` through the `do` body or catch bodies when the values agree,
- but it returns `nullptr` for `loop`.

So the pass is deliberately conservative at joins.
It only forwards a created type when Binaryen can point at one stable carried value.

## Phase 1: seed created exact types

The pass records created exact types for a tiny seed surface:

- `visitStructNew`
- `visitArrayNew`
- `visitArrayNewFixed`
- `visitRefAs`
- `visitRefCast`

This is the core positive surface.
In beginner terms, these are the places where Binaryen says:

- “I know exactly what heap type this value just became.”

## Phase 2: propagate through locals and globals

When a `local.set` or `global.set` stores a value with a remembered created type, the pass records that same created type for the set node.
Later:

- `visitLocalGet` can retag the get to that more precise type,
- `visitGlobalGet` can do the same.

The get keeps its original nullability, so the main improvement is heap-type precision and exactness, not unconditional non-null forcing.

## Phase 3: propagate through signature-facing sites

The pass also pushes created-type precision into typed boundaries.
In the reviewed `version_129` source that means:

- `visitCall` for direct call operands,
- `visitReturn` for returned values.

For each value, if the remembered created type is a subtype of the expected parameter or result type, Binaryen rewrites the expression type to that narrower type.

This is why the pass matters to later GC optimization.
It does not just make local gets prettier.
It makes more exact types visible at call and return boundaries too.

## Refinalization is part of the contract

At the end of a changed function, if GC is enabled, Binaryen runs:

- `ReFinalize().walkFunctionInModule(curr, module);`

That is not optional cleanup.
It is how Binaryen makes parent expression types consistent with the newly narrowed children.

## Positive family 1: fresh constructor to local.get

The classic shape is:

- create an exact value,
- store it in a local,
- later load the local again.

`type-ssa` can retag the later `local.get` to the created exact subtype.

## Positive family 2: matching branch values

If both `if` arms produce values with the same created type, the enclosing `if` can carry that type too.
The same idea appears in narrow `try` result families.

## Positive family 3: narrower call operands and returns

If the pass knows an operand or return value is a created exact subtype, and that subtype fits the expected signature slot, it rewrites the expression type at that boundary.

## Negative family 1: loops

`loop` is an explicit non-goal for the value-propagation helper here.
That is a real design boundary, not a documentation omission.

## Negative family 2: mixed branch types

If `if` or `try` flows do not agree on one created type, the pass keeps the broader original type.

## Negative family 3: abstract refs

Because `getTargetType` rejects `anyref`, `eqref`, `i31ref`, and `none`, the pass does not try to build exact created-type precision for those broader families.

## Important pass interactions

## 1. With `type-merging`

This is the key neighboring relationship.
The `type-merging` dossier already points out that `type-ssa` can create distinctions that help earlier optimization.
Later, `type-merging` can collapse distinctions that are no longer worth preserving.

So the relationship is:

- `type-ssa` creates useful use-site precision,
- `type-merging` later removes unneeded declaration-level distinctions.

## 2. With `ssa`

The pass name is misleading because this is **not** the same kind of transformation as full `ssa`.
`type-ssa` does not introduce merge locals or entry prepends.
It only forwards precise created reference types across existing flows.

## 3. With `type-refining`

`type-refining` is a closed-world field-analysis pass.
`type-ssa` is much smaller and more local.
Its precision comes from created values, not from whole-program write aggregation.

## 4. With `type-generalizing`

`type-generalizing` consumes a content oracle over a narrow expression family.
`type-ssa` does not use a content oracle at all.
Its evidence is “this exact value was just created here.”

## What a future Starshine port would need to preserve

A faithful port would need to preserve at least these boundaries:

1. the tiny created-type seed surface,
2. the `getTargetType` rejection of abstract refs,
3. conservative `block` / `if` / `try` value forwarding,
4. the explicit `loop` exclusion,
5. local/global propagation,
6. call-operand and return-value retagging,
7. GC-only refinalization after changes.

## Current-main drift check

I did a narrow current-main spot check on:

- `src/passes/TypeSSA.cpp`
- `test/lit/passes/type-ssa.wast`

On the reviewed surfaces, current `main` still matched the tagged `version_129` behavior relevant to this dossier.
So the documented contract here is not sitting on a known current-main semantic drift.

## Most important beginner correction

If someone says:

- “`type-ssa` is basically SSA plus types”

that is too vague and points in the wrong direction.

A much better sentence is:

- “`type-ssa` is a small GC pass that remembers exact created heap types and keeps that precision alive across SSA-like uses.”
