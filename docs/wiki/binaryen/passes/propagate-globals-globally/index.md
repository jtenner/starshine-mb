---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md
  - ../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
  - ../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
  - ../string-gathering/index.md
  - ../tracker.md
---

# `propagate-globals-globally`

## Role

`propagate-globals-globally` is a real public Binaryen module pass that rewrites **startup-level constant global uses** in other globals and active segment offsets. It is currently **unimplemented** in Starshine and lives only as a boundary-only registry name in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).

It is not part of this repo's current canonical no-DWARF `-O` / `-Os` path and does not appear in the saved generated-artifact `-O4z` skip queue. The folder exists because the pass is named locally, sits beside `simplify-globals*`, and is easy to mis-teach from its broad name.

## Beginner summary

A good beginner mental model is:

1. Binaryen finds immutable globals whose initializers are constant expressions.
2. It records their literal values by global name.
3. It replaces `global.get` uses inside other startup-level expressions with those literal values.
4. It applies that rewrite to defined global initializers plus active element/data offsets.
5. It stops before ordinary function-body `global.get` propagation.

So the pass is best taught as:

- **startup-level global constant propagation**
- not generic whole-program propagation
- not dead-global cleanup
- not the broader `simplify-globals` function-body rewrite mode

## Why this folder was refreshed on 2026-04-24

The earlier folder had already corrected the biggest source-layout mistake: the pass is implemented in `src/passes/SimplifyGlobals.cpp`, not a standalone `PropagateGlobals.cpp`.

Fresh primary-source review found more stale mechanics:

- the reviewed release does not expose the previous wiki's `canHandleAsGlobal` / `allInputsConstant` helper pair
- the globals pass scans defined globals in declaration order, not reverse order
- the public pass is a `PropagateGlobalsGlobally` subclass that calls only `propagateConstantsToGlobals()`; it is not explained correctly as just “the shared engine with `optimize = false`”
- the broader `SimplifyGlobals` sibling calls `propagateConstantsToCode()` after startup/global propagation, which is why its behavior differs in the lit test

Those corrections are captured in [`../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md`](../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md) and [`../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md`](../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md). A 2026-05-05 current-main recheck of `SimplifyGlobals.cpp`, `pass.cpp`, and `propagate-globals-globally.wast` confirmed the same source-backed contract and is filed in [`../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md) and [`../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md`](../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md).

## Purpose and correctness constraints

The pass's purpose is size/canonicalization cleanup for top-level startup state:

- remove unnecessary `global.get` indirection in constant global initializers
- simplify chained startup expressions when their global inputs are already known
- make active element/data offsets more direct when they read known immutable globals
- keep ordinary runtime code untouched in this public pass

Correctness constraints:

- only treat a global initializer as known when Binaryen's constant-expression predicate accepts the rewritten initializer
- substitute into startup/module expressions by value, preserving the original constant-expression semantics
- do not infer mutable-global runtime values
- do not rewrite function-body uses here; that belongs to `simplify-globals`
- preserve active/passive/declarative segment mode semantics; only active offsets are first-class rewrite targets in this pass

## Inputs and outputs

Input: a Binaryen module with globals, element segments, and/or data segments that may contain constant-expression `global.get` uses.

Output: the same module shape with eligible startup-level `global.get` uses replaced by literal constant expressions. Function bodies are not rewritten by this public pass.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - exact upstream `version_129` strategy, source corrections, and current-main spot-check boundary.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - file/test map for `SimplifyGlobals.cpp`, `pass.cpp`, helper surfaces, and the dedicated lit file.
- [`./shared-engine-and-startup-boundaries.md`](./shared-engine-and-startup-boundaries.md) - focused guide to the subclass boundary, the relation to `simplify-globals*`, and what “startup-level” means here.
- [`./wat-shapes.md`](./wat-shapes.md) - beginner-to-advanced shape catalog covering direct chains, arithmetic chains, string/GC constant expressions, active offsets, and function-body negatives.
- [`./starshine-strategy.md`](./starshine-strategy.md) - exact local status and future port map with Starshine code locations.

## Validation checklist for future Starshine work

A future local port should validate at least:

- direct immutable-global initializer propagation
- chained constant-expression propagation
- active data offset propagation
- active element offset propagation
- ordinary function-body `global.get` preservation for this specific pass
- mutable-global and non-constant-expression bailouts
- parity against Binaryen `wasm-opt --propagate-globals-globally` using the pass-targeted compare harness before adding any preset role

## Current maintenance rule

Keep this folder explicitly marked as **unimplemented** until Starshine grows a real module pass for it. If a future port shares code with `simplify-globals*`, preserve the public-pass stop point: `propagate-globals-globally` must not silently become plain `simplify-globals`.

## Sources

- [`../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md`](../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md)
- [`../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md)
- [`../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md`](../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md)
- [`../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md`](../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md)
- [`../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md`](../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md) - historical; superseded for helper names, scan order, and `optimize`-gate explanation.
- [`../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md`](../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md) - historical; superseded for the standalone-file claim.
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
