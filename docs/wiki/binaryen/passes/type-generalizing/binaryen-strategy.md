---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./call-ref-casts-and-boundaries.md
  - ./wat-shapes.md
  - ../type-refining/index.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
---

# Binaryen `type-generalizing` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this family.
The core sources are:

- `src/passes/TypeGeneralizing.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-generalizing.wast`
- `test/lit/passes/type-generalizing-with-optimizing-casts.wast`

Important helper dependencies:

- `src/ir/possible-contents.h`
- `src/ir/lubs.h`

Primary source URLs:

- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeGeneralizing.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing-with-optimizing-casts.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>

## The pass in one sentence

Binaryen `type-generalizing` is a small closed-world GC pass that consumes `ContentOracle` facts to narrow types on `struct.get`, `struct.set`, and `call_ref`, with an optional sibling that also tightens `ref.cast` targets.

## Biggest naming fact

The local name `type-generalizing` is misleading if taught alone.
Upstream actually exposes two **experimental** public names:

- `experimental-type-generalizing`
- `experimental-type-generalizing-with-optimizing-casts`

So this is best taught as an **experimental two-variant family**, not as one broad mature public pass.

## Scheduler fact

This family is **registered publicly** in Binaryen `pass.cpp`, but it is **not scheduled** in the reviewed default no-DWARF `-O` / `-Os` pipeline and it does not appear in the saved generated-artifact `-O4z` audit.
So this dossier is a deliberate upstream-only registry expansion.

## Core gates

`getPassOptions()` requests:

- `PassOptions::ClosedWorld`
- `optimizeLevel = 3`

The pass also reports `isFunctionParallel() = true`.

Beginner translation:

- the analysis assumes Binaryen can reason about the whole closed-world module
- this is a fairly aggressive late type-shaping helper
- each function can be walked independently after the shared module-wide oracle is built

## Core dependency: `ContentOracle`

The family keeps one field:

- `std::unique_ptr<ContentOracle> contentOracle;`

and initializes it in `doWalkModule`.

This is the same possible-contents analysis family already important in the `gufa` dossiers.
That is the first teaching correction:

- this pass does **not** invent a fresh inference system
- it reuses a whole-program oracle and only exposes a tiny rewrite surface on top of it

## The family split

The constructor takes one boolean:

- `optimizeCasts`

That produces the two siblings:

| Upstream public name | `optimizeCasts` | Distinctive behavior |
| --- | --- | --- |
| `experimental-type-generalizing` | `false` | no `ref.cast` tightening |
| `experimental-type-generalizing-with-optimizing-casts` | `true` | also tightens `ref.cast` targets |

So the sibling story is exactly:

- same oracle
- same main visitors
- one extra cast visitor effect when the flag is enabled

## What the implementation is really organized around

The durable structure is:

1. build one module-wide `ContentOracle`
2. walk each function post-order
3. on supported nodes, ask the oracle for possible contents
4. compute a narrower safe type when possible
5. mutate the expression or field type in place
6. if anything changed and GC is enabled, run `ReFinalize`

This is a **retagging / type-precision** pass, not a body-restructuring pass.

## Visitor 1: `visitStructGet`

This visitor only tries to refine **nullable reference result types**.
If the current result type is not nullable, it exits immediately.

Then it:

- asks the oracle for possible contents of the receiver
- collects their heap types
- computes a least upper bound
- checks whether the inferred type is a subtype of the current heap type
- rewrites the result type to the narrower heap type while preserving nullability

This is the cleanest beginner example of the pass:

- broad static field result type in the IR
- narrower actual receiver set in the closed world
- narrower visible result type after the pass

## Visitor 2: `visitStructSet`

This visitor does the same kind of reasoning on the **write-side field type**.

It:

- reasons about the receiver's possible heap types
- finds the actual field type on the inferred narrower receiver type
- checks whether that field type is a subtype of the current declared field type
- rewrites `curr->field.type` when that is safe

This is an easy thing to miss if you only skim the name.
The pass does not just refine expression results; it also refines the expected field type on writes.

## Visitor 3: `visitCallRef`

This is the richest part of the family.
The pass:

- asks the oracle for possible contents of the target expression
- filters those contents down to function signatures
- bails if the target set is unknown or mixed
- if the target set is impossible, rewrites the target to `unreachable`
- if exactly one signature remains, rewrites:
  - `curr->target->type` to `funcref` of that signature, non-nullable
  - `curr->type` to the signature's result type when it is a subtype of the current result type

The core beginner rule is:

- **one signature or nothing**

If multiple signatures remain possible, Binaryen keeps the original broader `call_ref` typing.

## Visitor 4: `visitRefCast`

This visitor only has an effect when `optimizeCasts` is true.
Then it:

- asks the oracle for possible contents of the cast input
- computes a heap-type LUB over those possible contents
- if that LUB is a subtype of the current cast target heap type, rewrites the cast target type

This is important to separate from `gufa-cast-all`.
`gufa-cast-all` can insert **new** casts.
This family only tightens the target type of an **existing** cast expression.

## Refinalization is part of the contract

At the end of `doWalkFunction`, Binaryen checks whether anything changed.
If so, and if GC is enabled, it runs:

- `ReFinalize().walkFunctionInModule(curr, getModule())`

This matters because narrowing `struct.get`, `call_ref`, or cast types can change exact expression typing and LUB-sensitive parent nodes.
So refinalization is not optional cleanup; it is part of correctness.

## Positive family 1: narrower `struct.get` result types

When the receiver's possible contents all live in a narrower subtype cone, Binaryen can make the visible `struct.get` result type more precise.

## Positive family 2: narrower `struct.set` field expectations

When the receiver is provably narrower than its broad static type, the field type on the write can also be tightened.

## Positive family 3: `call_ref` target and result sharpening

When the possible target set collapses to exactly one signature, Binaryen can:

- make the target type non-nullable function-ref of that signature
- make the result type equal to the signature result when it is narrower

## Positive family 4: impossible `call_ref` turns into `unreachable`

If the target's possible-contents set is empty, Binaryen rewrites the target expression to `unreachable`.
That is a strong semantic rewrite, not just cosmetic retagging.

## Positive family 5: optional cast-target tightening

Only the optimizing-casts sibling tightens `ref.cast` targets.
That is the whole reason the second public experimental pass exists.

## Negative family 1: tiny supported surface

Everything outside the four visitors is untouched.
That includes many GC/type expressions a beginner might expect from the name.

## Negative family 2: no multi-signature `call_ref` generalization

If two or more different possible signatures remain, the pass preserves the original `call_ref` typing.
This conservatism is core to the contract.

## Negative family 3: no arbitrary new casts

Even in the optimizing-casts sibling, the pass only tightens existing `ref.cast` nodes.
It does not insert new ones.
That is a crucial split from `gufa-cast-all`.

## Important helper dependencies

The most important helper dependencies are:

- `ContentOracle` from `possible-contents.h`
- `LUB` support from `lubs.h`
- `ReFinalize`
- the pass-local four-visitor surface in `TypeGeneralizing.cpp`

So this family is best understood as:

- **closed-world oracle facts plus small targeted type retagging**

not as a whole-cluster optimizer.

## What a future Starshine port must preserve

A faithful port should preserve at least nine things:

1. the local alias versus upstream experimental-name split
2. the two-sibling `optimizeCasts` split
3. the hard closed-world assumption
4. function-parallel scheduling after one module-wide oracle build
5. the exact four-visitor rewrite surface
6. the one-signature-only `call_ref` rule
7. the impossible-target `unreachable` rewrite for `call_ref`
8. cast tightening only on the optimizing-casts sibling
9. post-change refinalization when GC is enabled

## Most important beginner correction

If someone says:

- “`type-generalizing` is just another broad type-refinement pass”

that is too vague to be useful.

A much better sentence is:

- “Binaryen `type-generalizing` is an experimental closed-world oracle consumer that narrows types on just four expression families, plus one sibling that also tightens existing cast targets.”
