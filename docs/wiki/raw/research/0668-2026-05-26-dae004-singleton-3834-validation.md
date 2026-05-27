# DAE004 singleton 3834 fallback removal and validation

Date: 2026-05-26

## Scope

Recovery/completion slice for the next `[DAE004-D7]` singleton-family iteration after notes `0666` and `0667` removed and validated singleton fallback entry `445`.

This slice tests that broad-large singleton `3834` is now reached by the ordinary fact/core path and no longer needs the handpicked selected dropped-result fallback entry.

## Test-first evidence

Extended `dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path` in `src/passes/dae_optimizing_test.mbt` to cover both `445` and `3834`.

Before implementation, the focused test failed for `3834`: the callee result had already been removed by the normal core path (`pass[dae-optimizing]:core iter=0 primary_def=3834`), but the selected fallback loop still traced `selected-dropped-result-candidate def=3834`. That proved the fallback entry was stale for this singleton shape.

## Implementation

Removed `3834` from the selected dropped-result fallback lists in `src/passes/dead_argument_elimination.mbt`, and removed it from the black-box selected mid-prefix fallback fixture list in `src/passes/dae_optimizing_test.mbt` so the fixture no longer advertises retired fallback coverage.

This does not raise the broad-large descending cap, does not enable the rejected broad bucketed scheduler, and does not remove other singleton entries (`4106` or `4249`).

## Validation

- Focused regression:
  - `moon test src/passes -f 'dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path'`
  - Result: failed before the fallback removal, passed after it.
- Debug-artifact timing replay:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae004-d7-singleton3834-validation-20260526 --timing-only --dae-optimizing`
  - Result: Starshine pass-local `1583.739ms`; Binaryen pass-local `874.786ms`. This stays within the DAE target because `1583.739 <= 2 * 874.786`.
- Output validation:
  - `wasm-opt --all-features .tmp/dae004-d7-singleton3834-validation-20260526/starshine.wasm -o /tmp/dae004-d7-singleton3834-validated.wasm`
  - Result: passed with only the existing large-local-count VM warning.
- Direct compare refresh:
  - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae004-d7-singleton3834-20260526`
  - Result: `45/10000` compared before the known max-failure threshold, `26` normalized matches, `19` normalized mismatches, `0` validation failures, `0` generator failures, and `1` Binaryen/tool command failure (`binaryen-rec-group-zero`).

## Mismatch classification

Agent judgment: no new DAE004 semantic or validation regression was introduced. The `19` mismatches are the accepted `gen-valid` semantic-safe, size-winning raw-cleanup family where Starshine strips leading dropped pure/nontrapping debris that Binaryen preserves. The lone non-`gen-valid` saved failure is the known Binaryen parser/tool failure class (`binaryen-rec-group-zero`), not a Starshine semantic mismatch.

## Status

Singleton fallback entry `3834` can stay removed. `[DAE004-D7]` remains open for more remaining families, with singleton `4106` or `4249` still available as the next narrow candidate.
