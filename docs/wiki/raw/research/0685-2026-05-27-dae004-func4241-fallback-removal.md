# DAE004 Func4241 fallback removal

Date: 2026-05-27

## Scope

Advance `[DAE004-D7]` by retiring `4241` from the handpicked selected dropped-result fallback coverage. This keeps the broad-large scheduler cap unchanged and relies on the existing ordinary core/fact path for the focused broad-large fixture.

## Test-first evidence

Updated `src/passes/dead_argument_elimination_wbtest.mbt` so `dae selected dropped-result fallback skips covered entries` now asserts that `4241` is absent from `dae_selected_dropped_result_fallback_neighborhood_defs()`.

Before the implementation, `moon test src/passes` failed as expected:

- `dae selected dropped-result fallback skips covered entries` reported that `fallback.contains(4241)` was still `true`.

## Implementation

Changed `src/passes/dead_argument_elimination.mbt` to remove `4241` from:

- `dae_selected_dropped_result_fallback_neighborhood_defs()`
- the selected dropped-result fallback loop list

Also extended `src/passes/dae_optimizing_test.mbt` so `dae-optimizing reaches fallback-neighborhood dropped result through fact path` includes `4241`, proving the broad-large focused fixture reaches that callee without a selected-fallback trace.

The remaining late-cluster handpicked entry is `4242`.

## Validation

- `moon test src/passes` passed: `1419/1419`.
- Direct compare refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-func4241-20260527
```

Result:

- compared: `998/1000`
- normalized matches: `615`
- cleanup-normalized matches: `373`
- remaining mismatches: `10`
- validation failures: `0`
- command failures: `2`, both known Binaryen/tool command failures in this lane

Agent classification: the remaining ten compared mismatches are the accepted DAE gen-valid raw-cleanup/control-debris family tracked by DAE010/DAE011/DAE004 D7 refreshes after the opt-in normalizers. They are not evidence that `4241` still needs handpicked fallback coverage. The two command failures are Binaryen parser/tool failures, not Starshine validation failures.

## Next

Continue `[DAE004-D7]` with the final remaining late-cluster selected fallback entry `4242`, then proceed to `[DAE004-H]` fallback removal evidence and `[DAE004-I]` closeout only after the handpicked list is empty or fully gated off.
