---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md
  - ../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
---

# Binaryen `simplify-locals-nonesting` strategy

## Why this page exists

The full `simplify-locals` dossier already explains the family.
This page answers the narrower question:

- what does Binaryen actually do when the chosen public variant is `simplify-locals-nonesting`?

The short answer is:

- run the same shared locals engine
- but with the strongest conservative setting in the whole family
- so the pass still optimizes locals, while preserving flatness

## Exact public identity

Official `version_129` source defines the constructors:

- `createSimplifyLocalsPass()` -> `SimplifyLocals<true, true>()`
- `createSimplifyLocalsNoTeePass()` -> `SimplifyLocals<false, true>()`
- `createSimplifyLocalsNoStructurePass()` -> `SimplifyLocals<true, false>()`
- `createSimplifyLocalsNoTeeNoStructurePass()` -> `SimplifyLocals<false, false>()`
- `createSimplifyLocalsNoNestingPass()` -> `SimplifyLocals<false, false, false>()`

So `simplify-locals-nonesting` is the only public variant that disables all three semantic axes at once.

## Public contract in `pass.cpp`

`pass.cpp` registers the pass as:

- `simplify-locals-nonesting`
- `miscellaneous locals-related optimizations (no nesting at all; preserves flatness)`

That registration matters for teaching.
The official description does **not** say merely:

- no tees
- no structure

It explicitly says:

- no nesting at all
- preserves flatness

That is the durable wording a future port should preserve.

## Shared engine, stricter movement rule

A beginner might expect a tiny dedicated implementation file.
That is not how Binaryen does it.

The nonesting pass still uses the full shared `SimplifyLocals` engine:

1. `LocalGetCounter` counts uses
2. the pass performs repeated linear-execution sinking cycles
3. `EffectAnalyzer` blocks unsafe motion
4. the late `EquivalentOptimizer` canonicalizes equal-copy traffic
5. `UnneededSetRemover` removes dead sets
6. `ReFinalize` runs if a replacement sharpened types

So the real semantic split is not “different pass architecture.”
It is “same architecture, stricter allowed rewrites.”

## The first-cycle rule still applies

Like the rest of the family, the pass starts with a first cycle that only considers one-use sinks.
That source comment matters because it explains why the pass can unlock later wins incrementally.

Even in the nonesting variant, Binaryen still relies on the same fixed-point idea:

- one rewrite may expose another flat rewrite later

## Main nonesting gate: `optimizeLocalGet(...)`

The decisive variant-specific behavior lives in `optimizeLocalGet(...)`.

The pass first checks whether there is a sinkable `local.set` for the current `local.get`.
Then, when `allowNesting` is false, Binaryen adds the extra rule:

- a `local.get` copy is always ok to sink
- a non-copy value may only sink if the parent is another `local.set`
- otherwise the sink is rejected to avoid introducing nesting

This is the heart of the pass.

### What that means operationally

Allowed flat rewrite shape:

```wat
(local.set $tmp
  (local.get $src))
(local.set $dst
  (local.get $tmp))
```

can become a flatter direct copy chain or equivalent-local cleanup.

Disallowed nesting rewrite shape:

```wat
(local.set $tmp
  (i32.add
    (local.get $x)
    (i32.const 1)))
(drop
  (local.get $tmp))
```

cannot become:

```wat
(drop
  (i32.add
    (local.get $x)
    (i32.const 1)))
```

because that would create new nesting under `drop`.

## No tee fallback for multi-use copies

There is one subtle extra rule here.

If nesting is disallowed, and the sinkable set is just a copy (`local.set $b (local.get $a)`), and the use is not one-use, then Binaryen cannot:

- sink a real value expression
- create a tee
- or nop the origin immediately

So it takes a smaller step:

- rewrite the current `local.get $b` into `local.get $a`
- mark another cycle

This is a nice beginner-facing example of Binaryen being conservative but still useful.
The pass chooses a flat canonicalization step instead of a more aggressive nested rewrite.

## What this variant forbids at the source level

## 1. No tees

`canSink(...)` rejects multi-use sinks whenever:

- it is the first cycle, or
- `allowTee` is false

Since this variant sets `allowTee = false`, it never creates new `local.tee` nodes.

## 2. No structure rewrites

The following helpers are guarded by `allowStructure` and are therefore disabled entirely here:

- `optimizeLoopReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeIfReturn(...)`

So the pass never invents:

- block result carriers
- `if (result ...)` carriers from local traffic
- loop result carriers

## 3. No new nesting

The `optimizeLocalGet(...)` parent check is the explicit enforcement point.
The pass refuses rewrites that would push a real expression under a new consumer.

## What this variant still does

This is the most important correction after “preserves flatness.”
The pass is still a real optimizer.

## 1. Flat one-use sinking into `local.set` value positions

If the use position is itself a set-value slot, the pass can still simplify the local chain without increasing nesting depth.

## 2. Copy-chain retargeting

`local.get $copy` can be retargeted back to the original local when that preserves flatness.

## 3. Equivalent-local canonicalization

The late `EquivalentOptimizer` still runs.
That means equal local classes still matter even in the nonesting variant.

## 4. Dead-set cleanup

`UnneededSetRemover` still deletes leftover dead sets and dead tees.

## 5. Type repair through refinalization

If a flat rewrite substitutes a more refined value and changes a parent expression's inferred type, the pass still marks `refinalize = true`.
Correctness still matters even in a conservative variant.

## Analysis and helper dependencies

The core helpers are the same as the broader family:

- `linear-execution.h`
  - straight-line trace model
- `effects.h`
  - motion safety, traps, memory/global/table ordering, dangling-pop checks
- `local-utils.h`
  - `LocalGetCounter` and `UnneededSetRemover`
- `equivalent_sets.h`
  - late equal-local classes
- `pass.cpp`
  - public registration and wording
- `passes.h`
  - public constructor surface

The pass is therefore conservative in shape, not simplistic in analysis.

## Why Binaryen keeps this as a separate public pass

The official combo tests give the answer.
This variant is useful when Binaryen wants:

- some local simplification after `flatten`
- but not the full nesting, teeing, or structure-forming behavior of the ordinary variants

That is why the pass matters to nearby aggressive-pipeline stories like:

- `flatten -> simplify-locals-nonesting -> dfo`
- `flatten -> simplify-locals-nonesting -> souperify`

## Important nearby-pass boundaries

### Not the same as `simplify-locals-notee-nostructure`

That variant is `SimplifyLocals<false, false, true>`.
It may still create nesting.
This variant may not.

### Not the same as `flatten`

`flatten` creates Flat IR.
`simplify-locals-nonesting` only promises not to add new nesting during its own cleanup.
Those are related but distinct contracts.

### Not the same as `untee`

`untee` removes explicit `local.tee` nodes.
`simplify-locals-nonesting` refuses to create new tees and also performs broader flat local cleanup.

## Future-port rules

For concrete local sequencing and validation, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
A future honest Starshine port should preserve these facts:

- use the upstream public name or document the alias explicitly
- model it as `SimplifyLocals<false, false, false>`
- preserve the distinction from `-notee-nostructure`
- keep the late equivalent-local and dead-set phases; do not reduce it to “copy retargeting only"
- preserve the flatness rule in `optimizeLocalGet(...)` instead of silently allowing nested sinks
- keep the pass separate from `flatten` even if they are scheduled together in some aggressive pipelines

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md)
- [`../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md`](../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md`](../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
