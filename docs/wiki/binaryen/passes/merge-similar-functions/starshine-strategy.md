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
- a candidate that fails full module validation is discarded
- name metadata is stripped after a successful rewrite because helper insertion and local clearing invalidate local/debug names

## O4z artifact result

On the same 14,943,550-byte debug CLI used for the prior O4z comparison:

- previous Starshine O4z: 5,261,119 bytes
- Starshine O4z with generic MSF portfolio integration: **5,113,549 bytes**
- pinned Binaryen 131 O4z: 5,144,062 bytes
- Starshine now emits **30,513 fewer bytes** than Binaryen on this artifact
- the new Starshine artifact validates with `wasm-tools --features all` and passes `bun validate self-opt-smoke`

The direct MSF stage takes a median 1.225 seconds versus Binaryen 131's 0.616 seconds with `-s 2`, a 1.989x ratio that satisfies the repository's `<=2x` pass-local target.

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
