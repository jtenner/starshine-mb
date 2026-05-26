# DAE004 guarded tenth descending candidate

Date: 2026-05-26

## Scope

Recovery continuation for `[DAE]004` selected result-removal broadening after the guarded ninth-candidate slice in note `0621`. This run advances only the narrow large-module scheduler band that was already protected from the large debug-artifact runtime cliff.

## Test-first failure

Updated the large-module regression in `src/passes/dae_optimizing_test.mbt` from nine to ten high dropped-result callees after many low candidates.

Command before the fix:

- `moon test src/passes/dae_optimizing_test.mbt --target native --filter '*ten high dropped-result*'`

Result before the fix:

- failed with the tenth target still reporting one result: `1 != 0`.

## Fix

Raised the large-module descending fact-driven dropped-result cap from nine to ten only for the narrow `4096 < defined <= 4608` band covered by the focused regression. Modules up to `4096` still use the existing ascending queue cap of `32`, and larger modules, including the debug artifact, stay at cap `8` so this slice does not reopen the DAE011 artifact runtime cliff.

Also refreshed the white-box bounded scheduler unit so its ten-attempt view proves high candidates `4509..4500` are selected before low candidates.

This is a guarded behavior step, not selected-fallback removal. `[DAE]004` remains open.

## Validation

- Focused TDD filter passed after the fix: `moon test src/passes/dae_optimizing_test.mbt --target native --filter '*ten high dropped-result*'`.
- White-box scheduler unit passed: `moon test src/passes/pass_manager_wbtest.mbt --target native --filter '*scheduler caps productive attempts*'`.
- Native pass suite passed: `moon test src/passes --target native --no-parallelize` (`1442/1442`).
- Standard quick signoff passed: `moon info`, `moon fmt`, and `moon test` (`3459/3459`).

## Classification

No fuzz/compare refresh was run in this recovery slice. Based on the implementation shape, this is the same guarded scheduler family as note `0621`; retain the existing accepted DAE010/DAE011 fuzz classification until a fresh direct compare is run.

## Next step

Continue `[DAE]004` by replacing the handpicked selected-def fallback only when artifact/fuzz evidence proves broader fact-driven scheduling covers the remaining result-removal frontier without exceeding the pass-local `<= 2x` runtime target. The next large-module scheduler expansion should continue to avoid the rejected full-artifact cap bump; use narrow bands, better batching, or direct selected-fallback replacement evidence.
