---
kind: research
status: current
last_reviewed: 2026-05-08
sources:
  - ../../binaryen/passes/simplify-locals-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-strategy.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/simplify_locals_nostructure_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/simplify-locals-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-strategy.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-port-readiness-and-validation.md
  - ./0543-2026-05-06-slns-direct-revalidation.md
  - ./0542-2026-05-06-tuple-optimization-direct-revalidation.md
---

# `simplify-locals-nostructure` ordered-slot replay

## Question

Now that `tuple-optimization`, `vacuum`, and `reorder-locals` are all active, can Starshine replay the exact Binaryen early local neighborhood for `simplify-locals-nostructure` and retire `[SLNS]003`?

## Evidence

### New ordered-neighborhood regressions

Added three focused regressions:

1. `test "simplify-locals-nostructure exact slot replays tuple cleanup before vacuum and reorder-locals"` in `src/passes/simplify_locals_nostructure_test.mbt`
   - runs `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals`
   - proves the pass-start order directly
   - validates the resulting module
   - proves the tuple scratch locals disappear by the end of the neighborhood
2. `test "simplify-locals-nostructure exact slot keeps the no-structure if boundary"` in `src/passes/simplify_locals_nostructure_test.mbt`
   - runs the same ordered neighborhood on a structured `if` fixture
   - proves the pass still refuses to synthesize `if` results inside the real slot
3. `test "simplify-locals-nostructure exact slot helper exposes the ordered replay lane"` in `src/passes/optimize_test.mbt`
   - locks the documented exact slot array in `src/passes/optimize.mbt`
   - keeps public `optimize` / `shrink` conservative even after the replay proof lands

### Current-head signoff and direct lane refresh

Ran on 2026-05-08:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-simplify-locals-nostructure-20260508`

Direct-lane results:

- compared cases: `6759 / 10000`
- normalized matches: `6759`
- mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- command failures: `20`

The command failures are the standing Binaryen empty-recursion-group parser/canonicalization lane, not Starshine semantic mismatches.

### Debug-artifact exact-slot replay

Ran on 2026-05-08:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --tuple-optimization --simplify-locals-nostructure --vacuum --reorder-locals --out-dir .tmp/self-opt-slns-slot-20260508`

The replay reported:

- canonical wasm equal: `no`
- normalized WAT text equal: `no`
- normalized WAT equal: `yes`
- canonical function compare equal: `yes`
- Starshine runtime: `17490.821 ms`
- Binaryen runtime: `443225.139 ms`
- Starshine pass runtime: `603.064 ms`
- Binaryen pass runtime: `442852.000 ms`
- Starshine pass skipped raw: `yes`

For this repo's representation-stable proof surface, that is enough: the exact `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` neighborhood now compares green on normalized WAT plus canonical-function equality over the checked-in debug artifact.

## Conclusion

`[SLNS]003` is now closed.

Starshine now has current-head evidence for the whole slice scope:

- direct `simplify-locals-nostructure` parity is still green at the standard 10k compare-pass lane,
- the exact ordered local neighborhood is regression-covered in-tree,
- and the checked-in debug artifact replays that exact neighborhood with representation-stable parity.

Public `optimize` / `shrink` should still stay unchanged for now, but that remaining caution no longer belongs to a standalone `SLNS` blocker. The open work moves to neighboring slices instead, especially `tuple-optimization` exact-slot/preset proof and the broader local-cluster scheduling story.
