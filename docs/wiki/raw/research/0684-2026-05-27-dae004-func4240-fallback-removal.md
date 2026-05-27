# DAE004 Func4240 fallback removal

Date: 2026-05-27

## Scope

Advance `[DAE004-D7]` by retiring `4240` from the handpicked selected dropped-result fallback coverage. This keeps the broad-large scheduler cap unchanged and relies on the existing ordinary core/fact path for the focused broad-large fixture.

## Test-first evidence

Updated `src/passes/dae_optimizing_test.mbt` so `dae-optimizing reaches fallback-neighborhood dropped result through fact path` includes `4240`.

Before the implementation, `moon test src/passes` failed because the trace still emitted:

- `pass[dae-optimizing]:selected-dropped-result-candidate def=4240 ... bucket=selected-fallback`

The same failing run showed the ordinary core had already changed `primary_def=4240`, so the remaining failure was stale handpicked fallback coverage rather than a missing result-removal transform.

## Implementation

Changed `src/passes/dead_argument_elimination.mbt` to remove `4240` from:

- `dae_selected_dropped_result_fallback_neighborhood_defs()`
- the selected dropped-result fallback loop list

The remaining late-cluster handpicked entries are `4241` and `4242`.

## Validation

- `moon test src/passes` passed: `1419/1419`.
- Direct compare refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-func4240-20260526
```

Result:

- compared: `998/1000`
- normalized matches: `615`
- cleanup-normalized matches: `373`
- remaining mismatches: `10`
- validation failures: `0`
- command failures: `2`, both `binaryen-rec-group-zero`

Agent classification: the remaining ten compared mismatches are the same accepted DAE gen-valid raw-cleanup/control-debris family tracked by DAE010/DAE011/DAE004 D7 refreshes after the opt-in normalizers. They are not evidence that `4240` still needs handpicked fallback coverage. The two command failures are Binaryen parser/tool failures, not Starshine validation failures.

## Next

Continue `[DAE004-D7]` with the remaining late-cluster selected fallback entries `4241` and `4242`, then proceed to `[DAE004-H]` fallback removal evidence and `[DAE004-I]` closeout only after the handpicked list is empty or fully gated off.
