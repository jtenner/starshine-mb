# DAE004 Func459 Fallback Removal

Date: 2026-05-26

## Scope

Advance `[DAE004-D7]` by retiring `459` from the selected dropped-result fallback neighborhood. The change keeps the broad-large scheduler cap unchanged and does not enable the rejected bucketed broad-large scheduler switch.

## Test-first evidence

- Updated `src/passes/dead_argument_elimination_wbtest.mbt` so `dae_selected_dropped_result_fallback_neighborhood_defs()` must not contain `459`.
- The focused `moon test src/passes` run failed before implementation because `459` was still present in the fallback list.
- After implementation, the pass suite passed with the fallback guard, bucket-order guard, selected-fallback trace fixture, and mid-prefix dropped-result fixture updated for the remaining fallback set.

## Implementation

- Removed `459` from `dae_selected_dropped_result_fallback_neighborhood_defs()`.
- Removed `459` from the selected dropped-result fallback attempt loop in `dae_run_core`.
- Retargeted selected-fallback metadata coverage from `459` to `472`, since `459` no longer emits selected fallback metadata.
- Removed `459` from selected mid-prefix fixture coverage, leaving that fixture focused on entries that still use selected fallback coverage.

## Validation

Commands run:

- `moon test src/passes` — failed first on the new fallback-list guard before implementation, as expected.
- `moon test src/passes` — passed after implementation (`1419/1419`).
- `moon info` — passed.
- `moon fmt` — passed.
- `moon test` — passed (`3491/3491`).
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-d7-func459-20260526` — `998/1000` compared, `615` normalized matches, `373` cleanup-normalized matches, `10` remaining mismatches, `0` validation failures, and `2` command failures.

## Mismatch classification

The 1000-case refresh matches the recent DAE004-D7 fallback-removal profile. The remaining `10` mismatches are agent-classified as accepted `gen-valid` raw-cleanup/control-debris drift, not true dropped-result scheduling gaps, because exact normalized matches plus the two explicit DAE cleanup normalizers account for the inspected generator debris family while validation remains green. The `2` command failures are Binaryen/tool failures and are not semantic mismatches.

## Result

`459` is retired from handpicked selected dropped-result fallback coverage. Remaining `[DAE004-D7]` work should continue with `472`, `476`, `3566`, `3732`, `3814`, `4232`, `4240`, `4241`, or `4242`, then proceed to `[DAE004-H]` only after the fallback list is empty or fully gated off with artifact/fuzz/timing evidence.
