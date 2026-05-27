# DAE004 Func299 Fallback Removal

Date: 2026-05-26

## Scope

Advance `[DAE004-D7]` by retiring `299` from the selected dropped-result fallback neighborhood. The change does not raise the broad-large scheduler cap and does not enable the rejected bucketed broad-large scheduler switch.

## Test-first evidence

- Updated `src/passes/dead_argument_elimination_wbtest.mbt` so `dae_selected_dropped_result_fallback_neighborhood_defs()` must not contain `299`.
- The focused check failed before implementation because `299` was still present in the fallback list.
- After implementation, the focused fallback guard, bucket-order guard, selected-fallback trace fixture, and mid-prefix dropped-result fixture passed.

## Implementation

- Removed `299` from `dae_selected_dropped_result_fallback_neighborhood_defs()`.
- Removed `299` from the selected dropped-result fallback attempt loop in `dae_run_core`.
- Retargeted the selected-fallback metadata fixture to `459`, since `299` is now covered without selected fallback metadata.

## Validation

Commands run:

- `moon info` — passed.
- `moon fmt` — passed.
- `moon test src/passes -f "dae selected dropped-result fallback skips covered entries"` — passed.
- `moon test src/passes -f "dae large dropped-result bucket order interleaves fallback neighborhood before low tail"` — passed.
- `moon test src/passes -f "dae-optimizing traces selected dropped-result fallback metadata"` — passed.
- `moon test src/passes -f "dae-optimizing removes selected mid-prefix dropped callee results"` — passed.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing --timing-only --out-dir .tmp/dae004-d7-func299-timing-20260526` — produced valid artifacts; Starshine pass `1540.545ms`, Binaryen pass `901.638ms`, inside the `Starshine <= 2x Binaryen` target.
- `wasm-opt --all-features .tmp/dae004-d7-func299-timing-20260526/starshine.wasm -o /tmp/dae004-d7-func299-validated.wasm` — passed with the existing large-local-count VM warning.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-d7-func299-20260526` — `998/1000` compared, `615` normalized matches, `373` cleanup-normalized matches, `10` remaining mismatches, `0` validation failures, and `2` command failures.

## Mismatch classification

The 1000-case refresh matches the recent DAE004-D7 fallback-removal profile. The remaining `10` mismatches are agent-classified as accepted `gen-valid` raw-cleanup/control-debris drift, not true dropped-result scheduling gaps, because exact normalized matches plus the two explicit DAE cleanup normalizers account for the inspected generator debris family while validation remains green. The `2` command failures are Binaryen/tool failures and are not semantic mismatches.

## Result

`299` is retired from handpicked selected dropped-result fallback coverage. Remaining `[DAE004-D7]` work should continue with `459`, `472`, `476`, `3566`, `3732`, `3814`, `4232`, `4240`, `4241`, or `4242`, then proceed to `[DAE004-H]` only after the fallback list is empty or fully gated off with artifact/fuzz/timing evidence.
