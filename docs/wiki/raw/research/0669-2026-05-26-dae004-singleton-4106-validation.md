# DAE004 singleton 4106 fallback removal and validation

Date: 2026-05-26

## Scope

Recovery/completion slice for another `[DAE004-D7]` singleton-family iteration after notes `0666`/`0667` removed and validated `445`, and note `0668` removed and validated `3834`.

This slice tests that broad-large singleton `4106` is reached by the ordinary fact/core path and no longer needs the handpicked selected dropped-result fallback entry.

## Test-first evidence

Extended `dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path` in `src/passes/dae_optimizing_test.mbt` to cover `4106` in addition to `445` and `3834`.

Before implementation, the focused test failed for `4106`: the callee result had already been removed by the normal core path (`pass[dae-optimizing]:core iter=0 primary_def=4106`), but the selected fallback loop still traced `selected-dropped-result-candidate def=4106`. That proved the fallback entry was stale for this singleton shape.

## Implementation

Removed `4106` from the selected dropped-result fallback lists in `src/passes/dead_argument_elimination.mbt`, and removed it from the black-box selected mid-prefix fallback fixture list in `src/passes/dae_optimizing_test.mbt` so the fixture no longer advertises retired fallback coverage.

This does not raise the broad-large descending cap, does not enable the rejected broad bucketed scheduler, and does not remove singleton `4249` or any multi-caller/dense/bridge fallback family.

## Validation

- Focused regression:
  - `moon test src/passes -f 'dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path'`
  - Result: failed before the fallback removal, passed after it.
- Debug-artifact timing replay:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae004-d7-singleton4106-validation-20260526 --timing-only --dae-optimizing`
  - Result: Starshine pass-local `1548.629ms`; Binaryen pass-local `857.949ms`. This stays within the DAE target because `1548.629 <= 2 * 857.949`.
- Output validation:
  - `wasm-opt --all-features .tmp/dae004-d7-singleton4106-validation-20260526/starshine.wasm -o /tmp/dae004-d7-singleton4106-validated.wasm`
  - Result: passed with only the existing large-local-count VM warning.
- Direct compare refresh:
  - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae004-d7-singleton4106-20260526`
  - Result: `45/10000` compared before the known max-failure threshold, `26` normalized matches, `19` normalized mismatches, `0` validation failures, `0` generator failures, and `1` command failure.
- Commit-ready Moon validation:
  - `moon info`, `moon fmt`, and `moon test`
  - Result: passed; `moon test` reported `3491` tests passed and only existing unused-helper warnings.

## Mismatch classification

Agent judgment: no new DAE004 semantic or validation regression was introduced. The `19` mismatches are the accepted `gen-valid` semantic-safe, size-winning raw-cleanup family where Starshine strips leading dropped pure/nontrapping debris that Binaryen preserves. The command failure is the known Binaryen/tool failure class observed by the DAE direct compare refreshes, not a Starshine semantic mismatch.

## Status

Singleton fallback entry `4106` can stay removed. `[DAE004-D7]` remains open for more remaining families, with singleton `4249` still available as the next narrow candidate.
