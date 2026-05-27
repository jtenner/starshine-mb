# DAE004 singleton 4249 fallback removal and validation

Date: 2026-05-26

## Scope

Recovery/completion slice for another `[DAE004-D7]` singleton-family iteration after notes `0666`/`0667`, `0668`, and `0669` removed and validated singleton selected fallback entries `445`, `3834`, and `4106`.

This slice tests that broad-large singleton `4249` is reached by the ordinary fact/core path and no longer needs the handpicked selected dropped-result fallback entry.

## Test-first evidence

Extended `dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path` in `src/passes/dae_optimizing_test.mbt` to cover `4249` in addition to `445`, `3834`, and `4106`.

Before implementation, `moon test src/passes` failed for `4249`: the callee result had already been removed by the normal core path (`pass[dae-optimizing]:core iter=0 primary_def=4249`), but the selected fallback loop still traced `selected-dropped-result-candidate def=4249`. That proved the fallback entry was stale for this singleton shape.

## Implementation

Removed `4249` from the selected dropped-result fallback lists in `src/passes/dead_argument_elimination.mbt`, and removed it from the black-box selected mid-prefix fallback fixture list in `src/passes/dae_optimizing_test.mbt` so the fixture no longer advertises retired fallback coverage.

This does not raise the broad-large descending cap, does not enable the rejected broad bucketed scheduler, and does not remove any multi-caller, dense, bridge, or late-cluster selected fallback family.

## Validation

- Focused regression:
  - `moon test src/passes`
  - Result: failed before the fallback removal on `dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path`; passed after it.
- Debug-artifact timing replay:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae004-d7-singleton4249-validation-20260526 --timing-only --dae-optimizing`
  - Result: Starshine pass-local `1532.373ms`; Binaryen pass-local `847.036ms`. This stays within the DAE target because `1532.373 <= 2 * 847.036`.
- Output validation:
  - `wasm-opt --all-features .tmp/dae004-d7-singleton4249-validation-20260526/starshine.wasm -o /tmp/dae004-d7-singleton4249-validated.wasm`
  - Result: passed with only the existing large-local-count VM warning.
- Direct compare refresh:
  - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae004-d7-singleton4249-20260526`
  - Result: `45/10000` compared before the known max-failure threshold, `26` normalized matches, `19` normalized mismatches, `0` validation failures, `0` generator failures, and `1` command failure.

## Mismatch classification

Agent judgment: no new DAE004 semantic or validation regression was introduced. The `19` mismatches are the accepted `gen-valid` semantic-safe, size-winning raw-cleanup family where Starshine strips leading dropped pure/nontrapping debris that Binaryen preserves. The command failure is the known Binaryen/tool failure class observed by the DAE direct compare refreshes, not a Starshine semantic mismatch.

## Status

Singleton fallback entry `4249` can stay removed. `[DAE004-D7]` remains open for the remaining selected fallback families: tiny multi-caller, mid-prefix dense, high-index bridge, and late-cluster entries.
