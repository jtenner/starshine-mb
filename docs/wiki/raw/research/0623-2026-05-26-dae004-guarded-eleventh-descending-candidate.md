# DAE004 guarded eleventh descending candidate

Date: 2026-05-26

## Scope

Recovery continuation for `[DAE]004` selected result-removal broadening after the guarded tenth-candidate slice in note `0622`. This run advances only the same narrow large-module scheduler band that avoids the known large debug-artifact runtime cliff.

## Test-first failure

Updated the large-module regression in `src/passes/dae_optimizing_test.mbt` from ten to eleven high dropped-result callees after many low candidates.

Command before the fix:

- `moon test src/passes/dae_optimizing_test.mbt --target native --filter '*eleven high dropped-result*'`

Result before the fix:

- failed with the eleventh target still reporting one result: `1 != 0`.

## Fix

Raised the large-module descending fact-driven dropped-result cap from ten to eleven only for the narrow `4096 < defined <= 4608` band covered by the focused regression. Modules up to `4096` still use the existing ascending queue cap of `32`, and larger modules, including the debug artifact, stay at cap `8` so this slice does not reopen the DAE011 artifact runtime cliff.

Also refreshed the white-box bounded scheduler unit so its eleven-attempt view proves high candidates `4510..4500` are selected before low candidates.

This is a guarded behavior step, not selected-fallback removal. `[DAE]004` remains open.

## Validation

- Test-first failure reproduced before the fix: `moon test src/passes/dae_optimizing_test.mbt --target native --filter '*eleven high dropped-result*'` (`1 != 0`).
- Focused regression passed after the fix: `moon test src/passes/dae_optimizing_test.mbt --target native --filter '*eleven high dropped-result*'`.
- White-box scheduler unit passed: `moon test src/passes/pass_manager_wbtest.mbt --target native --filter '*scheduler caps productive attempts*'`.

## Classification

No fuzz/compare refresh was run in this recovery slice. Based on the implementation shape, this is the same guarded scheduler family as notes `0621` and `0622`; retain the existing accepted DAE010/DAE011 fuzz classification until a fresh direct compare is run.

## Next step

Continue `[DAE]004` by replacing the handpicked selected-def fallback only when artifact/fuzz evidence proves broader fact-driven scheduling covers the remaining result-removal frontier without exceeding the pass-local `<= 2x` runtime target. Further narrow-band expansion should include artifact validation/timing or a clearer fallback-removal proof before raising the large-artifact cap.
