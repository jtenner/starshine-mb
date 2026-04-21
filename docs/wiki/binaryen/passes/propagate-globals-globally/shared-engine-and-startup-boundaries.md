---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
---

# Shared engine and startup boundaries for `propagate-globals-globally`

This page explains the easiest part of the pass to misread:

- how it shares an engine with `simplify-globals*`
- where the startup-only boundary actually lives
- which expressions Binaryen is willing to treat as startup-safe

## The one-sentence rule

`propagate-globals-globally` is the public **startup-only** mode of Binaryen's shared `PropagateGlobals` engine.

## What "shared engine" means here

Binaryen did not implement three unrelated passes.
It implemented one engine in `SimplifyGlobals.cpp` and exposed three public constructor modes.

So the family is:

- `propagate-globals-globally`: same engine, stop after startup/module rewrites
- `simplify-globals`: same engine, continue into broader code-level work
- `simplify-globals-optimizing`: same broader engine mode, plus optimizing-family scheduling and reruns

That is why this pass must be taught as a sibling, not as an isolated side utility.

## The actual boundary: `optimize = false`

The public registration for `propagate-globals-globally` constructs the shared engine with the optimize flag turned off.

That one choice explains the real behavioral split:

- startup global and offset propagation still happens
- function-body propagation and broader cleanup do not

If a future port preserves that flag boundary, it will stay on the right side of the contract.
If it starts propagating through arbitrary function bodies, it has silently turned into `simplify-globals` instead.

## What counts as startup-safe

The pass accepts a curated subset of expression kinds in startup positions.

The reviewed source includes:

- literals (`Const`)
- `GlobalGet`
- unary wrappers whose child is startup-safe
- binary wrappers whose children are startup-safe
- `Select` whose inputs are startup-safe
- several startup-legal `string.*` forms

This is important because it shows two things at once:

- the pass is more capable than direct-alias replacement
- the pass is still much narrower than a generic evaluator for arbitrary IR

## What the constant map actually stores

Another easy beginner mistake is imagining a map from global name to raw integer literal.

That is too narrow.
Binaryen stores replacement **expressions** that are already safe and known in startup context.

So the map may hold things like:

- `i32.const 8`
- `i32.add (i32.const 8) (i32.const 4)`
- a startup string expression with known inputs

That is why the pass can remove `global.get` layers from more complex startup expressions.

## Why active offsets matter so much

The pass does not stop after rewriting globals.
It also rewrites:

- active data offsets
- active element offsets

This is the biggest visible consequence of the startup-only design.

If you remember only one beginner rule, remember this one:

- `propagate-globals-globally` is about **startup expressions**, not just global declarations

## Positive versus negative scope

## Positive scope

- defined global initializers
- active data offsets
- active elem offsets
- startup-safe arithmetic / select / string expressions using known globals

## Negative scope

- ordinary function-body `global.get` uses
- broad runtime current-value reasoning
- read-only-to-write cleanup
- dead `global.set` cleanup in code
- optimizing-family reruns

## Relationship to nearby folders

## Compared with `simplify-globals`

Same engine, broader stop point.

## Compared with `simplify-globals-optimizing`

Same engine family again, plus the optimizing rerun story.

## Compared with `string-gathering`

Different pass, but startup string expressions are a real place where this pass can simplify the module before string gathering happens later.

## Porting rule for Starshine

A future Starshine port should preserve these three facts together:

1. shared family identity with `simplify-globals*`
2. startup-only stop point for this public pass
3. active data/elem offsets as first-class rewrite targets

If any one of those three disappears, the port will teach the wrong pass.
