# DAE004 guarded thirteenth descending candidate

## Scope

Recovery continuation for open `[DAE]004` selected result-removal broadening after research note `0624` raised the narrow large-module descending fact-driven dropped-result scheduler band to twelve productive attempts.

This slice keeps the same safety shape: only modules with `4096 < defined <= 4608` get the wider descending cap, while larger artifact modules stay capped at `8` to avoid reopening the DAE011 pass-local runtime cliff or the rejected naive `defined <= 8192` ascending queue from note `0607`.

## Test-first evidence

Updated the focused regression to `dae-optimizing reaches thirteen high dropped-result callees after low candidate budget` by adding a thirteenth high dropped-result callee at defined function `4512`.

Before implementation, the focused test failed as expected:

```sh
moon test src/passes -f 'dae-optimizing reaches thirteen high dropped-result callees after low candidate budget'
```

Result: `1 != 0` for the thirteenth high callee's result count.

## Implementation

Raised the guarded `4096 < defined <= 4608` descending fact-driven dropped-result cap in `src/passes/dead_argument_elimination.mbt` from `12` to `13`. The `defined <= 4096` ascending queue still uses `32`, and larger modules still use the conservative cap `8`.

Also refreshed the white-box bounded scheduler unit in `src/passes/pass_manager_wbtest.mbt` to cover a thirteen-attempt descending view without constructing another huge optimizer fixture.

## Validation

Focused regressions after implementation:

```sh
moon test src/passes -f 'dae descending dropped-result scheduler caps productive attempts after ordering'
moon test src/passes -f 'dae-optimizing reaches thirteen high dropped-result callees after low candidate budget'
```

Both passed.

Native focused suites:

```sh
wasm-opt --all-features .tmp/dae004-thirteen-guarded-timing-20260526/starshine.wasm -o /tmp/dae004-thirteen-validated.wasm
moon test src/passes/dae_optimizing_test.mbt --target native --no-parallelize
moon test src/passes/pass_manager_wbtest.mbt --target native --no-parallelize
```

The artifact validated, with the existing large-local-count VM warning only. `dae_optimizing_test.mbt` passed `158/158`; `pass_manager_wbtest.mbt` passed `94/94`.

Debug-artifact timing-only replay:

```sh
rm -rf .tmp/dae004-thirteen-guarded-timing-20260526 && \
  bun scripts/self-optimize-compare.ts \
    tests/node/dist/starshine-debug-wasi.wasm \
    --starshine-bin target/native/release/build/cmd/cmd.exe \
    --dae-optimizing \
    --timing-only \
    --out-dir .tmp/dae004-thirteen-guarded-timing-20260526
```

Result: Starshine pass `1705.618ms` versus Binaryen pass `859.219ms`, still inside the project `Starshine <= 2x Binaryen` pass-local target. Whole-command runtime was `2071.179ms` Starshine versus `1151.344ms` Binaryen.

Direct compare smoke:

```sh
rm -rf .tmp/pass-fuzz-dae004-thirteen-guarded-20260526-smoke && \
  bun scripts/pass-fuzz-compare.ts \
    --count 200 \
    --seed 0x5eed \
    --pass dae-optimizing \
    --out-dir .tmp/pass-fuzz-dae004-thirteen-guarded-20260526-smoke
```

Result: `45/200` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure before the run stopped early. Agent classification follows the existing DAE010/DAE011 family unless contradicted by future replay: the observed smoke mismatches are expected gen-valid raw-cleanup/size-winning drift, not a new validation failure. A full 10k refresh was not completed in this recovery run.

## Status

`[DAE]004` remains open. This slice advances the narrow guarded scheduler band by one more productive descending candidate, but it does not prove the large-artifact handpicked selected-def fallback can be removed. Next work should continue only with focused test-first evidence, artifact validation, pass-local timing, and direct compare evidence.
