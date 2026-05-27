# DAE004 Func3732 fallback removal

Date: 2026-05-26

## Scope

Continues `[DAE]004` selected dropped-result fallback retirement. This slice removes `3732` from `dae_selected_dropped_result_fallback_neighborhood_defs()` after the existing fact-path fixture already covers `3732` in `dae-optimizing removes selected mid-prefix dropped callee results`.

## Test-first evidence

- Added `assert_false(fallback.contains(3732))` to `src/passes/dead_argument_elimination_wbtest.mbt`.
- Confirmed expected red with `moon test src/passes`: `dae selected dropped-result fallback skips covered entries` failed because the fallback list still contained `3732`.
- Removed `3732` from the fallback list in `src/passes/dead_argument_elimination.mbt`.
- Re-ran `moon test src/passes`: passed (`1419/1419`), with only existing unused helper warnings in `pass_manager_wbtest.mbt`.

## Compare refresh

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-func3732-20260526
```

Result:

- Compared: `998/1000`
- Exact normalized matches: `615`
- Cleanup-normalized matches: `373`
- Remaining mismatches: `10`
- Validation failures: `0`
- Command failures: `2`, both `binaryen-rec-group-zero`

Agent classification: the remaining mismatches match the accepted DAE004-D7 refresh shape from notes `0679` and `0680`: semantic-safe generator cleanup/control-debris drift after the explicit DAE normalizers, not a dropped-result scheduling gap. The command failures are Binaryen parser/tool failures, not Starshine validation failures. No validation failure or semantic mismatch was observed in this 1000-case refresh.

## Status

`3732` is retired from the handpicked selected-def fallback. `[DAE]004` remains open until the remaining fallback entries (`3814`, `4232`, `4240`, `4241`, `4242`) are retired or evidence proves no remaining dropped-result scheduling gap exists.
