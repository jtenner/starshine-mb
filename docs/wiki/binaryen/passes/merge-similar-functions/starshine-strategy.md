---
kind: concept
status: supported
last_reviewed: 2026-08-29
sources:
  - ./index.md
  - ../../../../../src/passes/merge_similar_functions.mbt
  - ../../../../../src/passes/merge_similar_functions_test.mbt
  - ../../../../../src/passes/merge_similar_functions_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/gen_valid_merge_similar_functions.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./binaryen-strategy.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./fuzzing.md
---

# Starshine strategy for `merge-similar-functions`

## Current status

Starshine now implements `merge-similar-functions` as an active whole-module pass.

- registry category: `ModulePass`
- direct request: `--merge-similar-functions`
- owner: [`src/passes/merge_similar_functions.mbt`](../../../../../src/passes/merge_similar_functions.mbt)
- dispatcher: [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- O4z integration: the existing validated `optimized-similar-functions` portfolio candidate runs the legacy specialized outlines and then generic MSF
- locked O4z scheduler: unchanged; MSF is integrated through candidate selection rather than inserting another top-level slot

## Implemented algorithm

The local pass follows the Binaryen 131 contract:

1. hash defined functions while ignoring scalar/vector literal payloads and direct call targets
2. split hash collisions with an exact recursive structural comparison
3. require compatible resolved function signatures and local declaration layouts
4. derive literal and same-type direct-callee difference vectors in reverse DFS order
5. reuse one synthetic parameter for repeated identical vectors
6. enforce the 255-parameter limit and Binaryen's weighted profitability rule
7. append a shared helper type and function
8. shift original non-parameter local indices after synthetic parameters
9. replace originals with tail-call thunks
10. lower differing direct callees through `ref.func` and `call_ref` / `return_call_ref`
11. append declarative function references and validate the complete candidate transactionally

The pass also preserves Binaryen-observable details found during fuzzing:

- profitable exact duplicates are accepted by the direct pass
- canonical-equivalent simple function type indices may share a class
- local declaration types remain part of the hash prefilter
- equivalence classes are emitted in primary-function order
- function annotations make the pass fail closed rather than rewriting stale branch metadata

## Safety boundaries

- imported functions are never candidates because only code-section definitions are scanned
- differing direct callees must use the same exact function type index before function-reference parameterization
- accessed local indices must have compatible types across the class
- helper and thunk insertion preserves every original function index, export, start reference, and call target
- a candidate is discarded unless an append-only proof preserves every untouched section and existing type/function/element prefix, rebuilds the complete validation environment, and validates every changed or appended function
- name metadata is stripped after a successful rewrite because helper insertion and local clearing invalidate local/debug names

## O4z artifact result

On the same 14,943,550-byte debug CLI used for the prior O4z comparison:

- previous Starshine O4z: 5,261,119 bytes
- Starshine O4z with generic MSF portfolio integration: **5,113,549 bytes**
- pinned Binaryen 131 O4z: 5,144,062 bytes
- Starshine now emits **30,513 fewer bytes** than Binaryen on this artifact
- the new Starshine artifact validates with `wasm-tools --features all` and passes `bun validate self-opt-smoke`

After the retained performance rewrite, direct command medians are 0.945 seconds for Starshine and 0.603 seconds for Binaryen 131 with `-s 2`, a 1.567x ratio. Starshine falls 0.282 seconds / 22.96% from its 1.226-second pre-rewrite baseline while preserving exact output bytes. A final trace attributes 68.333ms to fused analysis, 5.032ms to class splitting, 6.176ms to planning/rewrite, and 44.482ms to append-only candidate validation; the previous full candidate scan took 333.195ms.

A seven-pair full O4z sample is host-noisy but near wall parity: independent medians are 25.508s for Starshine and 24.984s for Binaryen (`1.021x`), while the median paired difference is 0.010s in Starshine's favor. Starshine uses 33.402s median user CPU versus Binaryen's 194.593s and keeps the 30,513-byte output advantage.

## Fuzz ownership

The dedicated aggregate is `merge-similar-functions-all`. It includes:

- literals
- repeated diff vectors
- exact duplicates
- duplicate simple type indices
- local-index shifting
- nested control
- direct call targets
- tail-call targets

See [`./fuzzing.md`](./fuzzing.md) for commands and results.
