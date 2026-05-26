# DAE003 immutable global generalization

Date: 2026-05-26

## Scope

Recovery slice for `[DAE003-G]`: broaden immutable `global.get` constant-actual materialization beyond the old selected Func313 lane while keeping mutable globals live.

## Test-first evidence

Added focused coverage in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing materializes high immutable global actuals outside selected list`
- `dae-optimizing keeps mutable global actuals outside selected list`

The first regression failed before implementation under `moon test src/passes` with the target still retaining one parameter (`1 != 0`). The mutable-global negative guard was added with the same slice to keep the behavior boundary explicit.

## Implementation

`src/passes/dead_argument_elimination.mbt` now adds a bounded `defined <= 4096` immutable-global revisit after the low forwarded-constant revisit. It scans candidate definitions one at a time through `dae_try_rewrite_selected_defs_exact_literal_with_facts_once(..., allow_immutable_global_get=true)`, stops after 64 productive rewrites, and recomputes call facts between productive iterations.

This deliberately does not widen the large debug-artifact path (`defined > 4096`), preserving the DAE011 pass-local timing boundary and the selected Func313 lane for current artifact behavior.

## Validation

- Test-first failure: `moon test src/passes` failed on the new immutable-global positive regression.
- After implementation: `moon test src/passes` passed (`1406` tests), with existing unrelated unused-helper warnings in `pass_manager_wbtest.mbt`.
- Standard quick gate: `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed (`3478` tests).
- Direct compare refresh: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-immutable-global-20260526-1000` stopped at the known mismatch threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure. Agent classification: the mismatches stay in the accepted DAE010/DAE011 gen-valid raw-cleanup/size-winning semantic-safe family; no new validation or semantic failure was observed.

## Status

`[DAE003-G]` can be closed for the current v0.1.0 surface: immutable globals are now materialized by the bounded mid-size revisit outside the selected lane, mutable globals remain guarded, and large-artifact/global-type-reference risks stay outside this subtask unless new evidence attributes a DAE003 frontier to immutable global materialization.
