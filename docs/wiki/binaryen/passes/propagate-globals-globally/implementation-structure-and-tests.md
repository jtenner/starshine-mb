---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
  - ../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
---

# `propagate-globals-globally`: implementation structure and tests

This page is the file-and-test map for Binaryen `version_129` `propagate-globals-globally`.

## Core source files

## `src/passes/SimplifyGlobals.cpp`

This is the real implementation file.

That correction is the whole reason this deepening exists.
The pass does **not** live in a standalone `PropagateGlobals.cpp`.
Instead, `SimplifyGlobals.cpp` defines the shared `PropagateGlobals` engine used by:

- `propagate-globals-globally`
- `simplify-globals`
- `simplify-globals-optimizing`

For this dossier, the important pieces inside the file are:

- the `PropagateGlobals` pass class
- the `optimize` field that splits startup-only mode from the broader siblings
- `canHandleAsGlobal`, which defines the startup-safe expression subset
- `allInputsConstant`, which decides whether a rebuilt expression is now startup-known
- `GlobalUseModifier` / `replaceUses`, which substitute known startup globals into other startup expressions
- the reverse scan over defined globals
- the rewrite loops over active data and active element offsets

That list is the durable source map a future port should preserve.

## `src/passes/pass.cpp`

This file matters because it proves:

- `propagate-globals-globally` is a public pass name in Binaryen `version_129`
- the pass is registered separately from `simplify-globals` and `simplify-globals-optimizing`
- the registration constructs the shared engine in the startup-only mode (`optimize = false`)

So `pass.cpp` is what turns the implementation detail into a stable public contract.

## `test/lit/passes/propagate-globals-globally.wast`

This is the dedicated behavior file for the pass.

It matters because it keeps three things explicit:

- startup global propagation is a public behavior surface
- active startup offsets are part of the contract
- the smaller public pass stops short of the broader simplify-globals family

## Optional drift-check source

## current `main` `src/passes/SimplifyGlobals.cpp`

A spot check against current `main` matters here because the earlier folder state had the source layout wrong.

The reviewed surface still matches the same key family structure:

- implementation remains in `SimplifyGlobals.cpp`
- public registration still exists
- the startup-only versus broader-mode split still hinges on the `optimize` gate

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `src/passes/SimplifyGlobals.cpp` | Core algorithm | The pass is a startup-only mode of the shared global-propagation engine |
| `src/passes/pass.cpp` | Public registration | `propagate-globals-globally` is a real public pass name with separate constructor wiring |
| `test/lit/passes/propagate-globals-globally.wast` | Behavior oracle | Defined globals plus active startup offsets are the visible rewrite surface |
| current `main` `src/passes/SimplifyGlobals.cpp` | Drift check | The reviewed family structure still matches upstream trunk on the checked surface |

## What this source map says about dependencies

Compared with nearby global passes, this pass still looks lightweight, but the shared-engine fact changes how to describe that lightness.

It depends on:

- module-level declaration traversal
- a curated startup-safe expression matcher
- startup-expression substitution helpers
- active data/elem offset rewriting

It does **not** require as part of this public mode:

- CFG analysis
- dominance
- liveness
- branch-target reasoning
- function-body useful-pass reruns

So the best porting lesson is not "totally separate pass" but:

- same engine family, narrower stop point

## What the test map says about the real contract

The dedicated lit file prevents two common mistakes.

### Mistake 1: treating the pass as too broad

The test surface keeps attention on startup globals and active offsets, not arbitrary function-body propagation.

### Mistake 2: treating the pass as too tiny

The test surface also shows the pass is not just "replace one direct global alias." It owns a real startup-expression and offset rewrite surface.

## Porting takeaway

If Starshine ever ports this pass, the file/test map suggests a clean design target:

- a module pass
- probably sharing helpers with future `simplify-globals*` work
- but with a hard public stop after startup/global/offset rewriting

That boundary is the important source-backed contract.
