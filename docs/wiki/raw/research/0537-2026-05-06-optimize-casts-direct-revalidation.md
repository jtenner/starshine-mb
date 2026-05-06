---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/optimize-casts/starshine-strategy.md
  - ../../binaryen/passes/optimize-casts/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize_casts.mbt
  - ../../../../src/passes/optimize_casts_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/optimize-casts/starshine-strategy.md
  - ../../binaryen/passes/optimize-casts/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `optimize-casts` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `optimize-casts` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

The revalidation also corrected stale living-doc wording that still described `optimize-casts` as removed/unimplemented. Current source has an active HOT pass in `src/passes/optimize_casts.mbt`, a dispatcher arm in `src/passes/pass_manager.mbt`, registry coverage in `src/passes/optimize.mbt`, and focused tests in `src/passes/optimize_casts_test.mbt`.

## Conclusion

`optimize-casts` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass.

This does **not** close the broader OC backlog. The current Starshine pass remains a narrow direct HOT rewrite for provably redundant GC casts and statically known `ref.test` outcomes; ordered-neighborhood proof for `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse`, descriptor/branch-cast expansion, exact-ref tightening, and public preset scheduling remain future work.
