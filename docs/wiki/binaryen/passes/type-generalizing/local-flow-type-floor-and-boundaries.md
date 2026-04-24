---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
supersedes:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
---

# `type-generalizing` local-flow type floors and boundaries

## Why this page exists

The easiest way to misunderstand this pass is to keep the old `call_ref` / cast story alive.
The reviewed Binaryen `version_129` owner file does not implement that story.

This page focuses on the actual hard part:

- local-flow type evidence,
- subtype/LUB compatible-type selection,
- the `local.get` fallback,
- and the boundaries that keep the pass safe.

## The real evidence source

The pass tracks type evidence by local index.
The meaningful producers are local assignment shapes:

- `local.set`
- `local.tee`

Those operations tell the pass what types are flowing into locals at nearby points in the expression tree.
The pass can then ask whether a surrounding expression can use a compatible type that avoids unnecessary local/type mismatch.

## The compatible-type decision

The pass does not compare type names by string and does not depend on a whole-program oracle.
It uses Binaryen's `Type` lattice:

- subtype checks decide whether one type is already good enough for another use
- least-upper-bound computation joins multiple pieces of observed evidence into one safe type

The important invariant is:

- the chosen type must be compatible with the original expression and the observed local-flow uses

If that proof fails, the expression is preserved.

## Why defaultability matters

The pass has one rewrite that may need to manufacture a value: the `local.get` fallback.
That means candidate expressions with nondefaultable target types are unsafe.

A future port should therefore treat defaultability as a semantic precondition, not a convenience check.

## The `local.get` drop-plus-zero rule

A `local.get` gets its type from the local declaration.
If the pass wants a different compatible type for the expression result, directly mutating the `local.get` type would make the IR inconsistent.

Binaryen solves this by replacing the candidate with a sequence:

1. evaluate and drop the original `local.get`
2. emit a default/zero value of the chosen type

Shape sketch:

```wat
;; before, conceptually
(local.get $x) ;; declared local type is not the chosen compatible type

;; after, conceptually
(block (result $chosen)
  (drop (local.get $x))
  (ref.null $chosen-or-other-default))
```

This is the most visible transformation in the pass.
It is also why nondefaultable types must bail out.

## Barrier family 1: concrete types

Concrete typed expressions act as barriers in the implementation.
When the pass sees one, it clears/rescans evidence rather than trying to force a broad rewrite through it.

Beginner rule:

- if the expression is already concrete, this pass is not the tool that tries to make it more clever.

## Barrier family 2: unreachable expressions

Unreachable expressions do not need this kind of local-flow cleanup.
The pass skips them.

This is different from the stale old dossier, which claimed impossible `call_ref` targets became `unreachable`.
The corrected pass does not have a `call_ref` visitor at all.

## Barrier family 3: nondefaultable types

If the chosen type might need a default value but no default value exists, the `local.get` fallback would be invalid.
The pass bails out.

This boundary is especially important for future Wasm GC work, where not every reference or aggregate type is safely defaultable in every context.

## Boundary family 4: no module-level closed-world reasoning

This pass should not be grouped with the `ContentOracle` / GUFA family.
It does not prove all possible runtime contents of references.
It uses local expression and local assignment types.

So a future Starshine port should not require a closed-world module oracle to match the reviewed Binaryen contract.

## Boundary family 5: no cast sibling

The previous dossier described an optimizing-casts sibling.
No reviewed `version_129` source surface backs that claim.

That means the corrected rule is simple:

- no `ref.cast` visitor,
- no cast-target tightening,
- no cast insertion,
- no separate `type-generalizing-with-optimizing-casts` page unless future primary sources add one.

## Boundary family 6: no GC field/call-ref visitors

The corrected pass does not transform these instruction families directly:

- `struct.get`
- `struct.set`
- `call_ref`
- `ref.cast`

Those shapes can still matter to nearby dossiers, but they are not the transformed surface of `type-generalizing` in the reviewed source.

## Beginner-friendly decision table

| Situation | What the corrected Binaryen pass does |
| --- | --- |
| local-set/local-tee evidence gives a compatible defaultable type | may retag a candidate expression |
| candidate is `local.get` | use drop-plus-zero instead of direct type mutation |
| candidate type is nondefaultable | bail out |
| candidate is unreachable | preserve |
| candidate is concrete | treat as a scan barrier / preserve |
| user expects `struct.get` or `call_ref` rewrite | not this pass |
| user expects cast-target optimization | not this pass in reviewed `version_129` |

## What a future Starshine port must not blur together

A correct port should keep these separations explicit:

1. local assignment evidence versus whole-program contents analysis
2. retagging ordinary expressions versus replacing `local.get`
3. defaultable values versus nondefaultable bailout
4. hidden/test upstream pass identity versus Starshine boundary-only alias
5. this pass versus neighboring `type-refining`, `gufa`, and `gufa-cast-all`

## Most useful beginner sentence

If someone wants the simplest correct summary of the hard part, use this:

- Binaryen `experimental-type-generalizing` uses local assignment type evidence to retag safe defaultable expressions; when the candidate is a `local.get`, it drops the original get and emits a default value of the chosen type instead.
