---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md
  - ../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
  - ../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
---

# Binaryen `propagate-globals-globally` Strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass. The 2026-04-24 raw manifest captures the official release page, `SimplifyGlobals.cpp`, `pass.cpp`, the dedicated lit file, helper surfaces, and the first narrow current-`main` spot check; the 2026-05-05 recheck keeps that freshness layer current: [`../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md).

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>

## The pass in one sentence

Binaryen `propagate-globals-globally` substitutes known immutable-global constant values into other startup-level constant expressions, then rewrites defined global initializers and active element/data offsets, while deliberately leaving ordinary function bodies to `simplify-globals`.

## Source-backed algorithm

### 1. Public registration

`pass.cpp` registers `propagate-globals-globally` as a separate public pass. The description says it propagates global values to other globals and frames it as useful for tests. That public entry is distinct from `simplify-globals` and `simplify-globals-optimizing`.

### 2. Owner file and subclass boundary

The implementation is in `src/passes/SimplifyGlobals.cpp`.

The important source correction is that the narrow pass is a `PropagateGlobalsGlobally` subclass. Its `run(Module*)` method sets the module pointer and calls only:

- `propagateConstantsToGlobals()`

It does **not** call the broader sibling's `propagateConstantsToCode()` step.

### 3. Constant map construction

Inside `propagateConstantsToGlobals()`, Binaryen keeps a `globalValues` map from global name to `Literals`.

For each defined global initializer:

1. find `GlobalGet` nodes under the initializer
2. when a referenced global already has known literals, replace that `global.get` with a copied constant expression via `Builder::makeConstantExpression(...)`
3. after replacement, ask `Properties::isConstantExpression(...)` whether the initializer is still a constant expression
4. if yes, extract and record its literal values for future replacements

That means the map stores **literal tuples**, not arbitrary expression trees and not just scalar `i32` constants.

### 4. Scan order

The reviewed `version_129` source scans defined globals in declaration order while growing `globalValues`.

This supersedes the older wiki wording that said the pass scans in reverse. Future ports should either preserve the source order or explicitly prove why a different fixed point is equivalent.

### 5. Active segment offsets

After global initializers, the same replacement helper is applied to:

- active element segment offsets
- active data segment offsets

Passive and declarative segments do not have startup offsets to rewrite in this pass.

### 6. No function-body rewrite

The dedicated lit file demonstrates the negative boundary: after `--propagate-globals-globally`, function bodies can still contain `global.get` instructions that `--simplify-globals` would remove. That is the easiest user-visible way to distinguish the two passes.

## Corrected family table

| Public pass | Owner file | Startup/global propagation | Function-body propagation | Cleanup behavior |
| --- | --- | --- | --- | --- |
| `propagate-globals-globally` | `SimplifyGlobals.cpp` subclass | yes | no | no broader useful-pass cleanup |
| `simplify-globals` | `SimplifyGlobals.cpp` | yes | yes | non-optimizing sibling behavior |
| `simplify-globals-optimizing` | `SimplifyGlobals.cpp` plus scheduler context | yes | yes | optimizing-family cleanup / rerun behavior documented in its own folder |

Important correction: do not describe `propagate-globals-globally` as merely `SimplifyGlobals(false)`. The pass boundary is the subclass that calls only the startup/global routine.

## What the pass transforms

The core transformed shapes are covered in [`./wat-shapes.md`](./wat-shapes.md). The important source-backed families are:

- direct global chain: `$b = global.get $a` after `$a` is known
- chained constant expression: `$c = i32.add (global.get $a) ...`
- multi-value / GC constant-expression families proven by the dedicated lit file's `struct.new` / `string.const` example
- active element offset using `global.get`
- active data offset using `global.get`

## What the pass deliberately does not own

It does not own:

- ordinary function-body `global.get` propagation
- runtime value tracking for mutable globals
- dead global removal
- `global.set` cleanup
- practical read-only-to-write analysis
- nested `dce` / `vacuum` / `precompute` cleanup loops

Those belong to neighboring passes or sibling modes.

## Current-main drift check

The 2026-05-05 current-main recheck on `SimplifyGlobals.cpp`, `pass.cpp`, and `propagate-globals-globally.wast` still shows the same teaching-relevant surfaces: `pass.cpp` registration, the `SimplifyGlobals.cpp` subclass boundary, and the dedicated lit-file contract. This is not an exhaustive semantic diff against trunk, but it is enough to keep the wiki freshness layer honest.

## Relationship to Starshine

Starshine now exposes this pass as an active module pass over the shared startup/global propagation subset. It rewrites startup-level expressions and preserves function bodies; see [`./starshine-strategy.md`](./starshine-strategy.md) and [`../../../raw/research/0699-2026-05-26-sgo-shared-family-exposure.md`](../../../raw/research/0699-2026-05-26-sgo-shared-family-exposure.md).

## Superseded older claims

- [`../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md`](../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md) is superseded for the standalone `PropagateGlobals.cpp` source-layout claim.
- [`../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md`](../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md) is superseded for helper-name, reverse-scan, and `optimize=false` boundary wording. Its main source-file correction remains useful historical context.
- [`../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md`](../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md) is the freshness bridge for the 2026-05-05 source spot check.
