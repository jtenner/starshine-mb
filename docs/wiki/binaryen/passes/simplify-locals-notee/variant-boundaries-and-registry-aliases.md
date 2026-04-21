---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0166-2026-04-21-simplify-locals-notee-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
---

# `simplify-locals-notee`: variant boundaries and registry aliases

## Why this page exists

This pass has a small but durable naming problem in this repo:

- upstream public Binaryen name: `simplify-locals-notee`
- current local removed-registry placeholder: `simplify-locals-no-tee`

That difference is easy to ignore until someone tries to connect:

- upstream sources
- local registry names
- neighboring dossier folders

This page keeps that mapping explicit.

## Alias map

| Meaning | Upstream Binaryen public name | Current local registry spelling |
| --- | --- | --- |
| no tees, structure still enabled | `simplify-locals-notee` | `simplify-locals-no-tee` |
| no tees and no structure | `simplify-locals-notee-nostructure` | `simplify-locals-no-tee-no-structure` |
| no structure, tees still allowed | `simplify-locals-nostructure` | `simplify-locals-no-structure` |
| no nesting at all | `simplify-locals-nonesting` | `simplify-locals-no-nesting` |

## Exact semantic contrast

## `simplify-locals-notee`

Template identity:

- `SimplifyLocals<false, true>`

Meaning:

- no new tees
- structure still enabled
- ordinary nesting still enabled

## `simplify-locals-nostructure`

Template identity:

- `SimplifyLocals<true, false>`

Meaning:

- tees still allowed
- structure disabled
- ordinary nesting still enabled

## `simplify-locals-notee-nostructure`

Template identity:

- `SimplifyLocals<false, false>`

Meaning:

- no tees
- no structure
- ordinary nesting still enabled

## `simplify-locals-nonesting`

Template identity:

- `SimplifyLocals<false, false, false>`

Meaning:

- no tees
- no structure
- no new nesting at all

## The one-sentence rule to remember

If you forget everything else, remember this:

- `simplify-locals-notee` is the variant that still forms structure but refuses new tees.

That is what makes it different from both nearby reduced variants:

- not `-nostructure`
- not `-notee-nostructure`

## Why the alias mismatch matters for future Starshine work

A future port or scheduler surface should either:

- use the upstream public names directly, or
- document the local alias map explicitly at the registry boundary

What should not happen is silent conflation, because that makes the wrong variant easy to implement.
