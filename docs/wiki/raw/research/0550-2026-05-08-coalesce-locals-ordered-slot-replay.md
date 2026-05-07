---
kind: research
status: current
last_reviewed: 2026-05-08
sources:
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/starshine-strategy.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/coalesce_locals_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/starshine-strategy.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
  - ./0518-2026-05-06-coalesce-locals-direct-revalidation.md
---

# `coalesce-locals` ordered-slot replay

## Question

Now that `local-subtyping`, `local-cse`, and `reorder-locals` are all active, can Starshine replay Binaryen's exact `coalesce-locals` neighborhoods and retire `[CL]003`?

## Evidence

### New ordered-neighborhood regressions

Added three focused regressions to `src/passes/coalesce_locals_test.mbt`:

1. `test "coalesce-locals uses local-subtyping's exact slot before local-cse and simplify-locals"`
   - runs `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
   - proves the pass-start order directly and validates the resulting module
2. `test "coalesce-locals narrows a base ref local to the child slot before merging"`
   - uses a two-local ref-type fixture where `coalesce-locals` can only merge after `local-subtyping` narrows the broader base local to the child type
3. `test "coalesce-locals replays the reorder-locals sandwich and reorders the merged slot"`
   - runs `reorder-locals -> coalesce-locals -> reorder-locals`
   - proves the exact pass order and locks the final remapped local indices after the merge

### Direct-pass parity refresh

Ran on 2026-05-08:

- `moon test src/passes`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass coalesce-locals --out-dir .tmp/pass-fuzz-coalesce-locals-20260508`

Results:

- compared cases: `6759 / 10000`
- normalized matches: `6759`
- mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- command failures: `20`

The command failures are the standing Binaryen empty-recursion-group parser lane, not Starshine semantic mismatches.

### Debug-artifact reorder-sandwich replay

Ran on 2026-05-08:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --reorder-locals --coalesce-locals --reorder-locals --out-dir .tmp/self-opt-cl-reorder-sandwich-20260508`

The replay reported:

- canonical wasm equal: `no`
- normalized WAT text equal: `no`
- normalized WAT equal: `yes`
- canonical function compare equal: `yes`
- Starshine runtime: `28399.742 ms`
- Binaryen runtime: `405431.613 ms`
- Starshine pass runtime: `27928.480 ms`
- Binaryen pass runtime: `404937.000 ms`

This is enough for the repo's representation-stable proof surface: the exact `reorder-locals -> coalesce-locals -> reorder-locals` neighborhood now compares green on normalized WAT and canonical-function equality over the checked-in debug artifact.

## Conclusion

`[CL]003` is now closed.

Starshine has current-head evidence for all parts of the slice scope:

- direct `coalesce-locals` parity is still green at the standard 10k compare-pass lane,
- the `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` slot is regression-covered in-tree,
- the `reorder-locals -> coalesce-locals -> reorder-locals` slot is regression-covered and replayed on the checked-in debug artifact.

What remains open is not `coalesce-locals` itself, but broader neighboring-pass or preset work owned by other backlog slices, especially the public `reorder-locals` scheduling policy and the later local-cluster/runtime follow-up elsewhere in the optimize-path queue.
