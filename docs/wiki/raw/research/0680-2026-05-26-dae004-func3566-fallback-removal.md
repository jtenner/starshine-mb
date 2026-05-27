# DAE004 Func3566 fallback removal

Date: 2026-05-26

## Scope

Continues `[DAE]004` selected dropped-result fallback retirement. This slice removes `3566` from `dae_selected_dropped_result_fallback_neighborhood_defs()` after the existing fact-path fixture already covers `3566` in `dae-optimizing removes selected mid-prefix dropped callee results`.

## Test-first evidence

- Added `assert_false(fallback.contains(3566))` to `src/passes/dead_argument_elimination_wbtest.mbt`.
- Confirmed expected red with `moon test src/passes`: `dae selected dropped-result fallback skips covered entries` failed because the fallback list still contained `3566`.
- Removed `3566` from the fallback list in `src/passes/dead_argument_elimination.mbt`.
- Re-ran `moon test src/passes`: passed (`1419/1419`), with only existing unused helper warnings in `pass_manager_wbtest.mbt`.

## Compare refresh

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-func3566-20260526
```

Result:

- Compared: `998/1000`
- Exact normalized matches: `615`
- Cleanup-normalized matches: `373`
- Remaining mismatches: `10`
- Validation failures: `0`
- Command failures: `2`, both `binaryen-rec-group-zero`

Agent classification: the inspected representative mismatch `case-000086-gen-valid` is semantic-safe raw cleanup drift. Starshine removes a long prefix of dropped pure constant/nontrapping arithmetic/comparison debris while Binaryen preserves it; this matches the accepted `[DAE]010` / `[DAE]011` gen-valid cleanup family. The two wasm-smith failures are Binaryen parser/tool failures, not Starshine validation failures. No validation failure or semantic mismatch was observed in this 1000-case refresh.

## Status

`3566` is retired from the handpicked selected-def fallback. `[DAE]004` remains open until the remaining fallback entries (`3732`, `3814`, `4232`, `4240`, `4241`, `4242`) are retired or evidence proves no remaining dropped-result scheduling gap exists.
