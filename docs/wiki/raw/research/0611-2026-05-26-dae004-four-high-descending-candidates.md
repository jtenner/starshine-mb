# DAE004 four-high descending candidates

Date: 2026-05-26

## Scope

Follow-up recovery/completion slice for `[DAE]004` selected result-removal broadening. Research note `0610` raised the large-module descending fact-driven dropped-result cap to three productive rewrites for `4096 < defined <= 8192`, while leaving the handpicked selected-def fallback active. This slice takes the next narrow ordered step by proving and allowing four high fact-driven dropped-result callees before low candidates and before the selected fallback.

The scope intentionally keeps the existing guards: no broad `<= 8192` ascending queue, no selected-def fallback removal, and no change to small/mid-size `defined <= 4096` behavior.

## Test-first evidence

Added `dae-optimizing reaches four high dropped-result callees after low candidate budget` in `src/passes/dae_optimizing_test.mbt`. The fixture creates 40 low dropped-result candidates plus four high dropped-result targets at defined functions `4500`, `4501`, `4502`, and `4503`, all outside the mid-size ascending queue and outside the handpicked selected-def list.

Expected failure before implementation:

```sh
moon test src/passes -f 'dae-optimizing reaches four high dropped-result callees after low candidate budget'
```

Result before implementation: failed with the fourth high target still reporting one result (`1 != 0`).

## Implementation

`src/passes/dead_argument_elimination.mbt` changes only the large-module fact-driven dropped-result attempt cap in `dae_run_core`: modules with `defined <= 4096` still get the existing ascending queue cap of `32`, while `4096 < defined <= 8192` now gets `4` descending productive rewrites instead of `3`.

The candidate guard remains unchanged: private non-tail direct callees with a single current result, current direct-call facts proving every direct call drops that result, and caller-filtered result-removal/`call; drop` repair. The historical selected-def fallback remains active after the bounded fact-driven queue.

## Validation

Focused validation:

```sh
moon test src/passes -f 'dae-optimizing reaches four high dropped-result callees after low candidate budget'
```

Result after implementation: passed.

Artifact timing/validation:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing --timing-only --out-dir .tmp/dae004-four-high-descending-20260526
wasm-opt --all-features .tmp/dae004-four-high-descending-20260526/starshine.wasm -o /tmp/dae004-four-high-descending.validate.wasm
```

Result: Starshine pass `1779.870ms` versus Binaryen pass `974.610ms`, inside the `Starshine <= 2x Binaryen` pass-local target. Output validation passed with the existing large-local-count VM warning.

Direct compare refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --max-failures 10000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dae004-four-high-descending-20260526-full2
```

Result: `9975/10000` compared, `6078` normalized matches, `3897` normalized mismatches, `0` validation failures, `25` Binaryen/tool command failures. Agent classification remains the accepted `[DAE]010`/`[DAE]011` family: known `gen-valid` semantic-safe raw-cleanup drift where Starshine strips pure/nontrapping generator debris that Binaryen preserves, plus Binaryen/tool failures outside Starshine semantics.

## Status and remaining work

This completes a fourth bounded large-module ordered scheduler step for `[DAE]004`: four high fact-driven dropped-result candidates can now be reached before low candidates and before the handpicked selected-def fallback. `[DAE]004` remains open because the handpicked fallback is still present and broader removal still needs artifact/fuzz evidence that the ordered fact-driven queue covers the remaining result-removal frontier without exceeding the pass-local timing target or producing invalid output.
