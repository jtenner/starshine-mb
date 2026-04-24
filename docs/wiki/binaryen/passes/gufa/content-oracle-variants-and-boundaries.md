---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-primary-sources.md
  - ../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa-optimizing/index.md
  - ../gufa-cast-all/index.md
  - ../type-refining/normal-vs-gufa-and-fixups.md
---

# `gufa`: content oracle, variants, and boundaries

## Why this page exists

The hardest part of teaching GUFA is not the phrase “whole-program analysis.”
The hard part is explaining three things at once:

1. what `ContentOracle` actually knows
2. why plain `gufa`, `gufa-optimizing`, and `gufa-cast-all` are different public contracts
3. where the pass deliberately stops even when the oracle knows more than the current IR says
4. why current Starshine cannot implement the pass without a module-wide oracle owner

This page is the dedicated home for those details.

## What `ContentOracle` actually answers

A beginner-friendly approximation is:

- “What values can really reach this location in the closed-world program?”

The answer is not just yes/no or const/non-const.
The helper tracks several distinct kinds of knowledge.

### `None`

No value can reach the location.
That means the location is effectively unreachable.

### `Literal`

Exactly one constant-like value can reach the location.
That can be emitted directly.

### `GlobalInfo`

Exactly one specific global or function identity reaches the location.
That may be materializable as `global.get` or `ref.func`.

### `ConeType`

The location contains a reference whose possible runtime types lie inside a smaller type cone than the IR currently advertises.
That is the key to `ref.test`, `ref.cast`, and `gufa-cast-all` improvements.

### `Many`

There is still useful reachability information, but not enough precision to emit one replacement value.

## Why this is bigger than constant propagation

If GUFA only knew constants, it could not do several of its source-backed rewrites:

- impossible `ref.eq` => `0`
- guaranteed `ref.test` => `1`
- impossible `ref.test` => `0`
- narrowing an existing `ref.cast`
- inserting a new cast in `gufa-cast-all`

Those all depend on type-cone and set-intersection reasoning, not only literals.

## Closed-world is not optional background noise

The helper comments in `possible-contents.h` explicitly say the analysis assumes a **closed world**.
The main `gufa.wast` test also runs with `--closed-world` and explains why that matters.

That means a future Starshine port must not quietly replace this with an open-world local pass and still call it GUFA. Today, Starshine exposes `closed_world` option plumbing in the command/pipeline configuration, but it has no GUFA owner that turns that option into a `ContentOracle`-style analysis; see [`./starshine-strategy.md`](./starshine-strategy.md).

## What plain `gufa` does with oracle answers

Plain `gufa` uses the oracle in only a few ways.
That narrow surface is easy to miss.

### It turns `None` into `unreachable`

But it preserves child side effects by dropping or appending them correctly.

### It emits one known value when possible

Only if Binaryen can materialize that value directly and its type validates at the original location.

### It specializes `ref.eq`

By asking whether the operand contents can intersect.

### It specializes `ref.test`

By comparing operand contents against the target type cone.

### It narrows existing `ref.cast`

When a more specific result type is provable and valid.

That is already a useful pass, but it is still less than “rewrite everything the oracle knows.”

## Why plain `gufa` sometimes refuses to emit a known value

This is the single most easy-to-misread source rule.

Suppose the oracle knows that the only runtime value here is:

- a `global.get`, or
- a `ref.func`

But that emitted expression's static type does not fit the original location's type.

Binaryen currently does **not** force the replacement.
It bails out.

Why?

Because runtime identity and static validation are different concerns.
The oracle may know the value is right while the plain emitted node would still be the wrong IR type.

So a beginner should remember:

- **one known runtime value** does not automatically mean **one legal emitted replacement node**.

## Why `gufa-optimizing` is a separate public pass

Plain GUFA can preserve effects by wrapping old children in `drop` / `block` scaffolding.
That is correct, but it can leave ugly code behind.

The optimizing sibling exists to clean up exactly that aftermath.
It runs:

- `dce`
- `vacuum`

on modified functions.

So the real public split is:

- plain `gufa` = prove and rewrite, then refinalize / EH-repair
- `gufa-optimizing` = prove and rewrite, refinalize / EH-repair, then immediately clean up the mess that proof-based rewriting can create

## Why `gufa-cast-all` is a separate public pass

Plain GUFA only sharpens **existing** casts.
It does not insert new casts at every site with a refined oracle type.

`gufa-cast-all` performs that extra insertion step.
It is useful because later passes may benefit from explicit cast structure that the plain pass leaves implicit.

But it also has costs:

- temporary code-size growth
- possible runtime cast-count growth
- feature-sensitive exactness limits

So the public split is meaningful, not cosmetic.

## Ordered atomics are a hard semantic barrier

The generic expression visitor bails out if the memory order is not `Unordered`.

That means GUFA treats synchronization as part of the semantics, not an optimization inconvenience.
A future port must preserve that barrier.

## Tuple types are an explicit scope boundary

The pass file skips tuple-typed expressions entirely.
So even though GUFA is a whole-program analysis, it is not yet a general multivalue contents-rewriter.

That is another “sounds bigger than it is” boundary worth teaching directly.

## The type-cone story behind `ref.test`

`ref.test` is a very good beginner example of how the oracle differs from plain constants.

The test target defines one cone of types.
The operand contents define another set of possible runtime values.

Then Binaryen asks:

- no overlap? => result `0`
- operand set fully inside target cone? => result `1`
- partial overlap? => keep the test

So this is set reasoning, not syntactic folding.

## The type-cone story behind `ref.cast`

`ref.cast` is different from `ref.test` in one important way.

Binaryen can sometimes sharpen the **result type** of the cast itself before it tries any larger rewrite.
That means GUFA is not only deleting casts or folding them away.
Sometimes it makes them more precise.

And in `gufa-cast-all`, it may insert new casts altogether.

## Connection to `type-refining-gufa`

The existing `type-refining` dossier already explains that the GUFA-backed variant uses `ContentOracle` instead of the normal direct scanner.

This dedicated GUFA folder clarifies the division of labor:

- `gufa` = use the oracle to rewrite expressions directly
- `type-refining-gufa` = use the oracle to infer better field declarations and then repair reads/writes

That shared analysis / different rewrite split is one of the clearest reusable Binaryen design patterns in this late-GC cluster.

## What future Starshine work should not blur together

Keep these pairs separate:

- `gufa` vs `gufa-optimizing`
- `gufa` vs `gufa-cast-all`
- `gufa` vs `type-refining-gufa`
- oracle knowledge vs materializable emitted replacements
- whole-program inference vs default-preset membership
- local boundary-only registry status vs an implemented Starshine pass

If those distinctions blur, the pass becomes much harder to implement or teach honestly.

## Short checklist for readers

If you want the correct beginner-to-intermediate mental model, remember:

- GUFA is closed-world whole-program contents analysis
- the oracle knows more than just constants
- plain GUFA rewrites only a narrow set of shapes
- `gufa-optimizing` adds nested cleanup
- `gufa-cast-all` adds new casts
- type validation and feature rules still gate what the pass can emit
- current Starshine has instruction/HOT surfaces for many GUFA rewrites, but the missing whole-program contents oracle is the blocker

## Sources

- [`../../../raw/binaryen/2026-04-24-gufa-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-primary-sources.md)
- [`../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md`](../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md`](../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md)
