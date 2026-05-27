# DAE004 Func4232 Fallback Removal

## Scope

Continue `[DAE004-D7]` by retiring fallback def `4232` from the selected dropped-result fallback lane without raising the broad-large scheduler cap or enabling the rejected bucketed broad-large switch.

## Test-first evidence

- Added `assert_false(fallback.contains(4232))` to `src/passes/dead_argument_elimination_wbtest.mbt` in `dae selected dropped-result fallback skips covered entries`.
- Confirmed failure before implementation with `moon test src/passes`: the new assertion failed because `4232` was still present in `dae_selected_dropped_result_fallback_neighborhood_defs()`.

## Implementation

- Removed `4232` from `dae_selected_dropped_result_fallback_neighborhood_defs()` in `src/passes/dead_argument_elimination.mbt`.
- Removed `4232` from the handpicked selected dropped-result loop in `src/passes/dead_argument_elimination.mbt`.
- Kept the broad-large fact scheduler cap unchanged; this is a fallback retirement only.

## Validation

- `moon test src/passes` passed after implementation: `1419/1419` tests.
- Direct compare refresh:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-func4232-20260527`
  - Compared: `998/1000`
  - `normalizedMatchCount`: `615`
  - `cleanupNormalizedMatchCount`: `373`
  - Remaining `mismatchCount`: `10`
  - Validation failures: `0`
  - Generator failures: `0`
  - Command failures: `2`

## Mismatch classification

Agent classification: remaining compare mismatches are the accepted DAE/gen-valid cleanup drift family already covered by `[DAE]010`/`[DAE004-D7]` evidence, not a new dropped-result scheduling gap. The explicit `drop-consts` and `unreachable-control-debris` normalizers accounted for `373` cleanup-normalized cases, and no validation failures were reported. The command failures are treated as tool/Binaryen failures, not Starshine semantic failures.

## Result

`4232` is retired from handpicked selected fallback coverage. Remaining selected fallback entries are `4240`, `4241`, and `4242`; `[DAE004-D7]`, `[DAE004-H]`, and `[DAE004-I]` remain open.
