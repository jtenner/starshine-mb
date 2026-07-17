---
kind: concept
status: supported
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

## Starshine completion state

- All five canonical variants and compatibility aliases are active through one explicit tee/structure/nesting policy engine.
- Focused tests cover no-tee structure synthesis, nonesting parent-position legality, loop-result lifting, no-tee self-copy handling, reachable dead-write cleanup, nested-loop result nops, and one-run idempotence.
- Every canonical variant has a stable aggregate profile with selected-leaf metadata.
- The required four-lane matrix, runtime probes, idempotence reruns, pass-local timing, and O4z neighborhood are complete; see [`fuzzing.md`](./fuzzing.md).
- Retained raw gates are performance/correctness boundaries, not semantic omissions. The newly narrowed no-tee stack/global gate admits small source-owned GC cleanup shapes while preserving the large-function boundary.

## Completion rule

The family was closed only after satisfying:

- focused TDD coverage for every inventory row and every variant gate;
- stable pass-owned GenValid aggregate profiles for all five canonical variants;
- zero unclassified residual transform families;
- the required four-lane closeout matrix for every variant;
- pass-local timing evidence;
- the O4z `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood and shared nested-rerun proof.
