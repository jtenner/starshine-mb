# DAE004 Func503 fallback removal and validation

Date: 2026-05-26

## Scope

Recovery/completion slice for `[DAE004-D7]` after singleton removals `445`, `3834`, `4106`, and `4249`. This slice removes `503` from the selected dropped-result fallback lists after proving it is no longer needed as handpicked fallback coverage.

`503` is treated as the first non-singleton cleanup from the remaining fallback-neighborhood set: the focused fixture reaches it through ordinary fact-driven result removal, so keeping it in the selected fallback list only preserves stale fallback metadata.

## Test-first evidence

Updated the white-box fallback guard in `src/passes/dead_argument_elimination_wbtest.mbt` to require `dae_selected_dropped_result_fallback_neighborhood_defs()` to exclude both the already-unobserved `3799` and the now-covered `503`.

Before implementation, `moon test src/passes --target native` failed at that guard because `503` was still present in `dae_selected_dropped_result_fallback_neighborhood_defs()`.

## Implementation

Removed `503` from both selected dropped-result fallback lists in `src/passes/dead_argument_elimination.mbt`:

- the helper-visible `dae_selected_dropped_result_fallback_neighborhood_defs()` list used by bucketed attempt-order tests; and
- the active selected fallback loop in `dae_run_core`.

Also removed `503` from the black-box selected mid-prefix fallback fixture list in `src/passes/dae_optimizing_test.mbt` so the fixture no longer advertises retired fallback coverage.

This does not raise the broad-large descending cap, does not enable the rejected broad bucketed scheduler, and does not remove the remaining dense, bridge, or late-cluster selected fallback families.

## Validation

- Focused/pass-suite regression:
  - `moon test src/passes --target native`
  - Result: failed before removal on the new `503` fallback guard; passed after implementation (`1474` tests).
- Debug-artifact timing replay:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing --timing-only --out-dir .tmp/dae004-d7-func503-validation-20260526`
  - Result: Starshine pass-local `1531.921ms`; Binaryen pass-local `863.462ms`. This stays within the DAE target because `1531.921 <= 2 * 863.462`.
- Output validation:
  - `wasm-opt --all-features .tmp/dae004-d7-func503-validation-20260526/starshine.wasm -o /tmp/dae004-d7-func503-validation.wasm`
  - Result: passed with only the existing large-local-count VM warning.
- Direct compare refresh:
  - `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --max-failures 20 --out-dir .tmp/pass-fuzz-dae004-d7-func503-20260526`
  - Result: `571/1000` compared, `352` normalized matches, `200` compare-normalized/drop-const matches, `19` remaining mismatches, `0` validation failures, `0` generator failures, and `1` command failure.

## Mismatch classification

Agent judgment: no new DAE004 semantic or validation regression was introduced. The direct compare refresh used the DAE `drop-consts` compare normalizer, so the `200` compare-normalized matches are accepted dropped-constant cleanup drift. The remaining `19` mismatches match the known DAE direct-compare raw-cleanup family: Starshine strips leading pure/nontrapping dropped generator debris that Binaryen preserves. This is semantic-safe and size-winning under the documented DAE cleanup policy, not a true dropped-result scheduling gap. The single command failure is a Binaryen/tool failure class, not a Starshine validation or semantic failure.

## Status

Fallback entry `503` can stay removed. `[DAE004-D7]` remains open for the remaining selected fallback families: dense mid-prefix entries, high-index bridge entries, and late-cluster entries. The broad-large cap remains unchanged until artifact timing evidence supports a broader scheduler or all productive fallback families are retired.
