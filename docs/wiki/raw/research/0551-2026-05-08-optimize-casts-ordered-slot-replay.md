---
kind: research
status: current
last_reviewed: 2026-05-08
sources:
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/optimize-casts/starshine-strategy.md
  - ../../binaryen/passes/optimize-casts/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize_casts_test.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/optimize-casts/starshine-strategy.md
  - ../../binaryen/passes/optimize-casts/starshine-port-readiness-and-validation.md
  - ./0537-2026-05-06-optimize-casts-direct-revalidation.md
---

# `optimize-casts` ordered-slot replay

## Question

Now that `heap2local`, `local-subtyping`, `coalesce-locals`, and `local-cse` are all active, can Starshine prove the exact `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood, schedule `optimize-casts` in public `optimize` / `shrink`, and retire `[OC]005`?

## Evidence

### New ordered-neighborhood regression and preset wiring

Updated the live preset surface and added focused neighborhood coverage:

1. `src/passes/optimize_casts_test.mbt`
   - added `test "optimize-casts ordered neighborhood stays valid through local cleanup consumers"`
   - runs `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse`
   - locks the exact pass-start order, validates the resulting module, and checks that the neighborhood removes the redundant `ref.cast`
2. `src/passes/optimize_test.mbt`
   - renamed and tightened the preset-slot assertion to `test "optimize preset schedules the proven optimize-casts GC/local cleanup neighborhood"`
   - now locks `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
3. `src/passes/registry_test.mbt`
   - updated the full `optimize` / `shrink` preset expansion snapshots to include `optimize-casts` in the exact GC/local cleanup slot
4. `src/passes/optimize.mbt`
   - inserted `optimize-casts` into both preset-expansion helpers and the preset registry snapshots immediately after `heap2local`

### Direct-pass parity refresh

Ran on 2026-05-08:

- `moon test src/passes`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-oc005-20260508`

Results:

- compared cases: `6759 / 10000`
- normalized matches: `6759`
- mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- command failures: `20`

The command failures remain the standing Binaryen empty-recursion-group parser/canonicalization lane, not Starshine semantic mismatches.

### Debug-artifact ordered-slot replay

Ran on 2026-05-08:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse --out-dir .tmp/self-opt-optimize-casts-neighborhood-20260508`

The replay reported:

- canonical wasm equal: `no`
- normalized WAT text equal: `no`
- normalized WAT equal: `yes`
- canonical function compare equal: `yes`
- Starshine runtime: `30160.994 ms`
- Binaryen runtime: `287500.619 ms`
- Starshine pass runtime: `28090.567 ms`
- Binaryen pass runtime: `287090.000 ms`

This is enough for the repo's representation-stable proof surface: the exact `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood now compares green on normalized WAT and canonical-function equality over the checked-in debug artifact.

## Conclusion

`[OC]005` is now closed.

Starshine now has current-head evidence for all parts of the slice scope:

- direct `optimize-casts` parity is still green at the standard 10k compare-pass lane,
- the exact GC/local cleanup neighborhood is regression-covered in-tree,
- the checked-in debug artifact replays that same neighborhood with representation-stable parity,
- public `optimize` / `shrink` now schedule `optimize-casts` in the proven slot immediately after `heap2local`.

What remains open is broader non-slice work outside `OC`: upstream-aligned widening beyond the current narrow HOT rewrite, and the larger full no-DWARF parity follow-up already tracked under neighboring GC/local backlog slices.
