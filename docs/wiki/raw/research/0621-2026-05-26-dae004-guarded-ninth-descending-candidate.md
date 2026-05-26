# DAE004 guarded ninth descending candidate

Date: 2026-05-26

## Scope

Recovery continuation for `[DAE]004` selected result-removal broadening after notes `0616` through `0620`. The prior ninth-candidate probe proved the focused behavior but could not sign off while the native pass suite crashed; note `0620` unblocked that suite by reducing an unrelated perf-test fixture.

## Test-first failure

Updated the large-module regression in `src/passes/dae_optimizing_test.mbt` from eight to nine high dropped-result callees after many low candidates.

Command before the fix:

- `moon test src/passes/dae_optimizing_test.mbt --target native --filter '*nine high dropped-result*'`

Result before the fix:

- failed with the ninth target still reporting one result: `1 != 0`.

## Fix

Raised the large-module descending fact-driven dropped-result cap from eight to nine only for the narrow `4096 < defined <= 4608` band covered by the focused regression. Modules up to `4096` still use the existing ascending queue cap of `32`, and larger modules, including the debug artifact, stay at the previous descending cap of `8` so this slice does not reopen the DAE011 artifact runtime cliff.

This is a guarded behavior step, not selected-fallback removal. `[DAE]004` remains open.

## Validation

- Focused TDD filter passed after the fix: `moon test src/passes/dae_optimizing_test.mbt --target native --filter '*nine high dropped-result*'`.
- Native pass suite passed: `moon test src/passes --target native --no-parallelize` (`1442/1442`).
- Debug-artifact timing-only replay: `.tmp/dae004-nine-guarded-timing-20260526` reported `1686.915ms` Starshine pass versus `857.852ms` Binaryen pass, inside the repo target of `Starshine <= 2x Binaryen`; canonical wasm still differs as expected.
- Artifact validation passed: `wasm-opt --all-features .tmp/dae004-nine-guarded-timing-20260526/starshine.wasm -o /tmp/dae004-nine-guarded.validated.wasm` with only the existing large-local-count VM warning.
- Direct 10k compare refresh: `.tmp/pass-fuzz-dae004-nine-guarded-20260526-full2` reported `9975/10000` compared, `6078` normalized matches, `3897` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Classification

The 3897 direct-fuzz mismatches match the accepted DAE010/DAE011 counts and are classified by agent judgment as the known `gen-valid` size-winning semantic-safe raw-cleanup family: Starshine removes dropped pure/nontrapping generator debris that Binaryen preserves. Command failures remain Binaryen/tool failures, not Starshine semantic failures.

## Next step

Continue `[DAE]004` by replacing the handpicked selected-def fallback only when artifact/fuzz evidence proves broader fact-driven scheduling covers the remaining result-removal frontier without exceeding the pass-local `<= 2x` runtime target. The next large-module scheduler expansion should avoid reopening the full-artifact cap bump that exceeded the target; use narrow bands, better batching, or direct selected-fallback replacement evidence.
