---
kind: concept
status: working
last_reviewed: 2026-07-17
sources:
  - ../../../raw/research/1571-2026-07-17-simplify-locals-family-transform-inventory.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/SimplifyLocals.cpp
related:
  - ./index.md
  - ./variant-matrix-and-scheduler.md
  - ./implementation-map.md
  - ./effect-ordering-and-barriers.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
---

# `SimplifyLocals` transform-family inventory

The canonical detailed inventory is [`../../../raw/research/1571-2026-07-17-simplify-locals-family-transform-inventory.md`](../../../raw/research/1571-2026-07-17-simplify-locals-family-transform-inventory.md).

## Audit contract

All five Binaryen `version_130` public variants must be implemented and signed off against the same source-owned family table:

- full: tee + structure + nesting
- no-tee: structure + nesting, but no sink-created tee
- no-structure: tee + nesting, but no result synthesis
- no-tee/no-structure: nesting only
- nonesting: flat copy cleanup only; no tee, structure, or ordinary new nesting

The family inventory contains 35 source-owned transform/postcondition rows. The highest-risk distinctions are:

1. no-tee still performs structure synthesis;
2. structured `br_if` result synthesis may require a tee even in no-tee mode, because the tee belongs to structure formation rather than multi-use sinking;
3. nonesting permits copy retargeting and set-value sinks while rejecting real expressions under ordinary consumers;
4. `EquivalentOptimizer` removes redundant equivalent sets only when structure is enabled, but canonicalizes equivalent gets in every variant;
5. refinalization and nondefaultable-local repair are part of the pass contract, not optional downstream polish.

## Starshine starting gap map

- Active: `simplify-locals`, `simplify-locals-nostructure`, compatibility `simplify-locals-no-structure`, and `simplify-locals-notee-nostructure`.
- Missing active public variants: `simplify-locals-notee` and `simplify-locals-nonesting`.
- Missing policy axis: `allow_nesting`.
- Existing no-structure aggregate generation is useful but too narrow for family closeout.
- Large/sparse equivalent-cleanup cutoffs and raw skip gates remain performance boundaries that require proof; they are not accepted semantic omissions.

## Completion rule

Do not close the family because one variant or one random lane is green. Completion requires:

- focused TDD coverage for every inventory row and every variant gate;
- stable pass-owned GenValid aggregate profiles for all five canonical variants;
- zero unclassified residual transform families;
- the required four-lane closeout matrix for every variant;
- pass-local timing evidence;
- the O4z `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood and shared nested-rerun proof.
