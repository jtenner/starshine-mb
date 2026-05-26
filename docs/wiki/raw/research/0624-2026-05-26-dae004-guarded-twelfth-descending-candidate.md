# DAE004 guarded twelfth descending candidate

Date: 2026-05-26

## Scope

Recovery continuation for `[DAE]004` selected result-removal broadening after note `0623`. This run advances only the same narrow large-module scheduler band (`4096 < defined <= 4608`) and leaves larger artifact modules capped at `8` to avoid reopening the DAE011 runtime cliff.

## Test-first failure

Updated the large-module regression in `src/passes/dae_optimizing_test.mbt` from eleven to twelve high dropped-result callees after many low candidates.

Command before the fix:

- `moon test src/passes`

Result before the fix:

- failed in `dae-optimizing reaches twelve high dropped-result callees after low candidate budget` with the twelfth target still reporting one result: `1 != 0`.

## Fix

Raised the large-module descending fact-driven dropped-result cap from eleven to twelve only for the narrow `4096 < defined <= 4608` band covered by the focused regression. Modules up to `4096` still use the existing ascending queue cap of `32`, and larger modules, including the debug artifact, stay at cap `8`.

Also refreshed the white-box bounded scheduler unit so its twelve-attempt view proves high candidates `4511..4500` are selected before low candidates.

This is a guarded behavior step, not selected-fallback removal. `[DAE]004` remains open.

## Validation

- Test-first failure reproduced before the fix: `moon test src/passes` (`1 != 0` in the twelve-high regression).
- Pass package after the fix: `moon test src/passes` passed (`1387/1387`).
- Debug artifact timing-only replay: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing --timing-only --out-dir .tmp/dae004-twelfth-candidate-timing-20260526`.
  - Starshine pass runtime: `1688.482ms`.
  - Binaryen pass runtime: `846.427ms`.
  - Agent judgment: inside the project pass-local floor (`1688.482 <= 2 * 846.427`). The helper's `Starshine pass at least as fast: no` means not faster than Binaryen, not a failure of the repo's `<= 2x` pass-local target.
- Artifact validation: `wasm-opt --all-features .tmp/dae004-twelfth-candidate-timing-20260526/starshine.wasm -o /tmp/dae004-validate.wasm` passed with only the existing large-local-count VM warning.
- Direct compare refresh attempted: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae004-twelfth-20260526-full` produced `45/10000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure before stopping early in this run. Treat this as partial evidence only, not a full 10k signoff.
- Standard quick signoff: `moon info`, `moon fmt`, and `moon test` passed (`3459/3459`).

## Classification

The partial direct compare reproduced the known DAE mismatch shape without validation failures, but the run did not reach the standard 10k count. Retain the existing accepted DAE010/DAE011 agent classification for the full 10k lane: gen-valid size-winning semantic-safe raw-cleanup drift, with Binaryen/tool failures classified separately. No new validation failure or true semantic mismatch was found in this slice.

## Next step

Continue `[DAE]004` by replacing the handpicked selected-def fallback only when artifact/fuzz evidence proves broader fact-driven scheduling covers the remaining result-removal frontier without exceeding the pass-local `<= 2x` runtime target. Further narrow-band expansion should include artifact validation/timing and either a complete direct compare refresh or a documented reason why only partial compare evidence was available.
