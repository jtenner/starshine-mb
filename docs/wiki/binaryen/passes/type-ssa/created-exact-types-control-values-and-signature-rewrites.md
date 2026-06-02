---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md
  - ../../../raw/binaryen/2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/research/0503-2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-01-type-ssa-current-main-recheck.md
  - ../../../raw/research/0688-2026-06-01-type-ssa-current-main-recheck.md
  - ../../../raw/research/0386-2026-04-26-type-ssa-source-correction.md
  - ../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `type-ssa`: fresh allocation subtypes, exactness blockers, and stale local-flow claims

## Why this page keeps its old filename

This page used to explain “created exact types, control values, and signature rewrites.” That framing is now explicitly stale for Binaryen `version_129` and current `main`.

The filename is kept for link stability, but the content now records the corrected hard part of the pass:

- which allocation sites can receive fresh private subtypes,
- which exactness observations block splitting,
- which interestingness rules make a split useful,
- and which older local-flow claims are superseded.

## Correct core concept

`type-ssa` gives selected allocation values a new heap type.

Instead of keeping every `struct.new $A` as exactly `$A`, the pass can create fresh private subtypes such as `$A.0` and `$A.1`, then rewrite individual allocation instructions to return exact non-null refs to those fresh subtypes.

That is the SSA analogy: one allocation value can get its own type identity.

## Allocation candidates

The source-backed candidate surface is allocation-centered:

- `struct.new`,
- `array.new`,
- `array.new_data`,
- `array.new_elem`,
- `array.new_fixed`.

The pass scans ordinary defined functions and module-level expression surfaces such as globals and element segments. Imported functions are skipped for body analysis because there is no body to inspect.

## Exactness blockers

A fresh subtype is unsafe if existing program constructs can observe exact identity of the original type. Binaryen records those blockers in `disallowedTypes`.

Important blocker families include:

- exact casts,
- exact tests,
- exact function result types,
- exact global types,
- exact element-segment types,
- child-type constraints discovered through `ChildTyper`.

The beginner rule is:

> Do not split an allocation's type if code may require the allocation to be exactly the old type.

## Interestingness rules

Safe is not enough. The allocation also needs to be useful to split.

Positive interestingness families include:

- default `struct.new`,
- constants stored into fields or arrays,
- globals stored into fields or arrays,
- operand types that are more refined than the declared field or element type,
- `array.new_data`,
- `array.new_elem`,
- `array.new_fixed` when all elements are interesting.

Common no-op families include:

- unreachable allocation results,
- allocations of final types,
- allocations of types whose `open` bit is disabled,
- descriptor/describee allocations,
- operands that do not expose a better type or constant/global fact.

## Rewrite mechanics

For selected candidates, Binaryen:

1. creates fresh private subtypes of the old allocated heap types,
2. groups them in one new rec group,
3. preserves sharing with an old-to-new map,
4. makes the rec group unique with type-shape machinery,
5. retags each allocation result to exact non-null fresh type,
6. copies a useful old type name plus a numeric suffix when possible,
7. runs refinalization afterward.

## Why the old local-flow model is stale

The superseded 2026-04-23 dossier claimed the pass was mostly about:

- a `createdTypes` expression map,
- `getTargetType(...)`,
- forwarding through `block`, `if`, and `try`,
- local/global set-to-get propagation,
- direct-call operand retagging,
- return-value retagging.

Those are not the corrected `version_129` / current-main implementation. Future readers should not use that model to write tests or code.

## Practical prediction checklist

To predict whether `type-ssa` should change a shape, ask:

1. Is the instruction one of the allocation candidates?
2. Is GC enabled?
3. Is the allocated type non-final, open, and outside descriptor/describee exclusions?
4. Has the old type avoided exact-observation blockers?
5. Is the allocation interesting under Binaryen's constants/globals/refined-operand/data/elem/fixed-array criteria?
6. Can the type section be extended with a fresh private subtype and then refinalized?

If all answers are yes, the allocation's result type is likely to become an exact non-null fresh subtype.

## Relationship to `type-merging`

This pass may intentionally create more private type distinctions. Later type cleanup passes such as [`../type-merging/index.md`](../type-merging/index.md) may collapse declarations that prove indistinguishable. That makes the passes complementary rather than contradictory:

- `type-ssa` exposes allocation-site distinctions,
- `type-merging` removes unnecessary declaration distinctions later.

For future Starshine port sequencing and reduced validation lanes for these blocker/interestingness families, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
