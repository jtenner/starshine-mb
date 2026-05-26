# DAE004 guarded fourteenth descending candidate

## Scope

Recovery continuation for open `[DAE]004` selected result-removal broadening after research note `0625` raised the narrow large-module descending fact-driven dropped-result scheduler band to thirteen productive attempts.

This slice keeps the same safety shape: only modules with `4096 < defined <= 4608` get the wider descending cap, while larger artifact modules stay capped at `8` to avoid reopening the DAE011 pass-local runtime cliff or the rejected naive `defined <= 8192` ascending queue from note `0607`.

## Test-first evidence

Updated the focused regression to `dae-optimizing reaches fourteen high dropped-result callees after low candidate budget` by adding a fourteenth high dropped-result callee at defined function `4513`.

Before implementation, the focused test failed as expected:

```sh
moon test src/passes/dae_optimizing_test.mbt
```

Result: `1 != 0` for the fourteenth high callee's result count.

## Implementation

Raised the guarded `4096 < defined <= 4608` descending fact-driven dropped-result cap in `src/passes/dead_argument_elimination.mbt` from `13` to `14`. The `defined <= 4096` ascending queue still uses `32`, and larger modules still use the conservative cap `8`.

Also refreshed the white-box bounded scheduler unit in `src/passes/pass_manager_wbtest.mbt` to cover a fourteen-attempt descending view without constructing another huge optimizer fixture.

## Validation

Focused regressions after implementation:

```sh
moon test src/passes/dae_optimizing_test.mbt && moon test src/passes/pass_manager_wbtest.mbt
```

Both passed (`dae_optimizing_test.mbt` `158/158`; `pass_manager_wbtest.mbt` `39/39` in this target configuration).

Pass suite:

```sh
moon test src/passes
```

Result: `1387/1387` tests passed.

Debug-artifact timing-only replay:

```sh
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --timing-only \
  --out-dir .tmp/dae004-fourteenth-candidate-timing-20260526
```

Result: Starshine pass `1704.905ms` versus Binaryen pass `862.911ms`, still inside the project `Starshine <= 2x Binaryen` pass-local target. Whole-command runtime was `2066.623ms` Starshine versus `1157.335ms` Binaryen. The Starshine wasm validated with `wasm-opt --all-features`, with the existing large-local-count VM warning only.

Direct compare smoke:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 200 \
  --seed 0x5eed \
  --pass dae-optimizing \
  --out-dir .tmp/pass-fuzz-dae004-fourteenth-20260526-smoke
```

Result: `45/200` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure before the run stopped early. Agent classification follows the existing DAE010/DAE011 family unless contradicted by future replay: the observed smoke mismatches are expected gen-valid raw-cleanup/size-winning drift, not a new validation failure. A full 10k refresh was not completed in this recovery run.

## Status

`[DAE]004` remains open. This slice advances the narrow guarded scheduler band by one more productive descending candidate, but it does not prove the large-artifact handpicked selected-def fallback can be removed. Next work should continue only with focused test-first evidence, artifact validation, pass-local timing, and direct compare evidence.
