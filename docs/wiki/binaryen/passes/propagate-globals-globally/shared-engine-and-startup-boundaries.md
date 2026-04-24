---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md
  - ../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
---

# Shared engine and startup boundaries for `propagate-globals-globally`

This page explains the easiest part of the pass to misread:

- it shares owner-file machinery with `simplify-globals*`
- but its public pass boundary is a narrow subclass that only runs startup/global propagation
- its accepted expression scope is whatever Binaryen's constant-expression predicate accepts, not a wiki-maintained whitelist

## The one-sentence rule

`propagate-globals-globally` is Binaryen's public **startup/global-only** constant-propagation sibling of `simplify-globals`.

## What “shared engine” means here

Binaryen keeps this pass in `src/passes/SimplifyGlobals.cpp`, the same file as `simplify-globals` and `simplify-globals-optimizing`.

That does not mean the public pass runs the entire `simplify-globals` algorithm. The narrow pass uses the shared global-propagation routine, then stops.

## The actual boundary: subclass, not just `optimize = false`

The earlier wiki wording said the public pass boundary was `optimize = false`. That was too broad and misleading.

The reviewed `version_129` source shows the sharper boundary:

- `PropagateGlobalsGlobally::run(Module*)` calls `propagateConstantsToGlobals()` only
- broader `SimplifyGlobals::iteration(...)` calls `propagateConstantsToGlobals()` and then `propagateConstantsToCode()`
- the `optimize` flag controls cleanup behavior in the broader sibling after code-level propagation, but it is not the whole reason this public pass avoids function bodies

Future docs and ports should preserve this distinction.

## What counts as startup-level here

The pass works on module expressions evaluated at instantiation/startup time:

- defined global initializers
- active element segment offsets
- active data segment offsets

It does not walk ordinary function bodies.

## What counts as “known”

Binaryen records a global when the rewritten initializer is still a constant expression according to `Properties::isConstantExpression(...)`.

That is more robust than a hand-authored list. The lit file proves some important families, including:

- scalar constants
- arithmetic over known global values
- GC/string constant-expression construction

But the living wiki should avoid claiming an exhaustive list unless it reviews the predicate directly.

## What the map stores

The pass maps:

- global name -> literal values

During replacement, Binaryen rebuilds a constant expression from those literals. This matters for multi-value or compound constant-expression cases; the pass is not limited to one scalar integer literal.

## Positive versus negative scope

### Positive scope

- immutable defined global initializers that become constant expressions after substitution
- later global initializers that read already-known globals
- active data offsets that read already-known globals
- active elem offsets that read already-known globals

### Negative scope

- mutable globals whose runtime values may change
- ordinary function-body `global.get` uses
- passive/declarative segment payloads with no active offset expression to rewrite
- dead global removal
- runtime `global.set` cleanup
- nested cleanup reruns

## Relationship to nearby folders

### Compared with `simplify-globals`

Same owner file and startup/global routine, broader sibling behavior. `simplify-globals` continues into code propagation.

### Compared with `simplify-globals-optimizing`

Same broad sibling family again, with optimizing cleanup/rerun behavior documented in its own dossier.

### Compared with `string-gathering`

Different pass, but the dedicated lit file proves that GC/string constant expressions can participate in this pass's startup-global propagation surface.

## Porting rule for Starshine

A future Starshine port should preserve these three facts together:

1. module-level startup/global rewrite surface
2. active data/elem offsets as first-class targets
3. no function-body propagation in this public pass

If the implementation starts rewriting ordinary code, it has crossed into `simplify-globals` territory and should not be documented or validated as faithful `propagate-globals-globally` behavior.
