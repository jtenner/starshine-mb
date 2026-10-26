---
kind: concept
status: supported
last_reviewed: 2026-07-27
sources:
  - ./index.md
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
---

# `simplify-locals-notee`: variant boundaries and registry aliases

> **Comparison baseline:** New comparisons require a verified [Binaryen 133](../../release-horizon-and-oracles.md) oracle. Older sources, commands, artifacts, and results retain their original versions.

> **Binaryen-v131 renewal (2026-07-27):** The released owner contract is unchanged from v130. Current executable evidence is recorded in [`index.md`](./index.md) and the family [fuzzing closeout](../simplify-locals/fuzzing.md); older v129/v130 labels below are retained only as historical provenance, not as the current oracle.


## Why this page exists

This pass has a small but durable naming problem in this repo:

- upstream public Binaryen name: `simplify-locals-notee`
- local compatibility alias: `simplify-locals-no-tee`

That difference is easy to ignore until someone tries to connect:

- upstream sources
- local registry names
- neighboring dossier folders

This page keeps that mapping explicit.

## Alias map

| Meaning | Upstream Binaryen public name | Current local registry spelling |
| --- | --- | --- |
| no tees, structure still enabled | `simplify-locals-notee` | `simplify-locals-notee` and `simplify-locals-no-tee` (active alias) |
| no tees and no structure | `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure`; `simplify-locals-no-tee-no-structure` is removed |
| no structure, tees still allowed | `simplify-locals-nostructure` | `simplify-locals-nostructure` and `simplify-locals-no-structure` (active alias) |
| no nesting at all | `simplify-locals-nonesting` | `simplify-locals-nonesting` and `simplify-locals-no-nesting` (active alias) |

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

## Registry boundary

The canonical names and active aliases are registered separately. The old
`no-tee-no-structure` spelling is removed. See
[`./starshine-strategy.md`](./starshine-strategy.md) for the implementation map.
