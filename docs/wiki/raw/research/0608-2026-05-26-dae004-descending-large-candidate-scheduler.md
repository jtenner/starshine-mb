# DAE004 descending large candidate scheduler

Date: 2026-05-26

## Scope

Follow-up recovery/completion slice for `[DAE]004` selected result-removal broadening. The previous recovery note `0607` rejected a naive `defined <= 8192` widening because the ascending fact-driven dropped-result queue spent its 32-iteration budget on low candidates, still needed the handpicked high-def fallback, and failed the debug-artifact validation/timing contract.

This slice keeps the existing small/mid-size ascending queue unchanged for modules with `defined <= 4096`, but adds a deliberately bounded large-module path for `4096 < defined <= 8192`: one descending fact-driven dropped-result attempt before the historical selected-def fallback. The single-attempt limit is intentional; it proves high-candidate reachability without reopening the earlier DAE011 runtime cliff.

## Test-first evidence

Added `dae-optimizing reaches high dropped-result callee after low candidate budget` in `src/passes/dae_optimizing_test.mbt`. The fixture creates 40 low dropped-result candidates plus a high dropped-result target at defined function `4500`, outside the old `defined <= 4096` fact queue and outside the handpicked selected-def list.

Failing command before implementation:

```sh
moon test src/passes -f 'dae-optimizing reaches high dropped-result callee after low candidate budget'
```

Failure: the high target still had one result (`1 != 0`). This reproduced the starvation problem without relying on the huge debug artifact.

## Implementation

`src/passes/dead_argument_elimination.mbt` now factors the shared dropped-result rewrite body into `dae_try_remove_dropped_result_def_with_facts(...)`. The existing ascending selected-def helper uses that shared helper unchanged for the small/mid-size queue and handpicked selected-def list.

A new `dae_try_remove_descending_dropped_results_with_facts_once(...)` scans the fact-derived candidate bitmap from high to low. `dae_run_core` invokes it only when the original module has `4096 < defined <= 8192`, and caps that large-module lane at one productive rewrite before continuing to the historical selected-def fallback.

## Validation

Focused and pass-suite validation:

```sh
moon test src/passes -f 'dae-optimizing reaches high dropped-result callee after low candidate budget'
moon test src/passes
```

Both passed after implementation.

Debug-artifact timing and validation:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --timing-only \
  --out-dir .tmp/dae004-descending-large-limit1-timing-20260526
wasm-opt --all-features .tmp/dae004-descending-large-limit1-timing-20260526/starshine.wasm -o /tmp/dae004-validate.wasm
```

Result: Starshine output validates with only the existing large-local-count VM warning. Pass-local timing was `1485.439ms` Starshine versus `858.552ms` Binaryen, inside the project target of `Starshine <= 2x Binaryen`.

Direct 10k compare refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass dae-optimizing \
  --max-failures 10000 \
  --keep-going-after-command-failures \
  --out-dir .tmp/pass-fuzz-dae004-descending-large-20260526-full2
```

Result: `9975/10000` compared, `6078` normalized matches, `3897` mismatches, `0` validation failures, and `25` Binaryen/tool command failures. Command failures matched the known Binaryen/tool classes from the accepted DAE010/DAE011/DAE004 lanes. Agent classification for the mismatch family remains the accepted `gen-valid` size-winning semantic-safe raw-cleanup drift: Starshine removes pure/nontrapping dropped generator debris that Binaryen preserves; this slice did not introduce a new validation or semantic mismatch family.

## Post-implementation fallback trace

A traced direct artifact run after the descending lane showed the new fact-driven path first removes high candidate `4651`, then the historical selected-def fallback still removes `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, and `4249`:

```sh
STARSHINE_TRACING=helper target/native/release/build/cmd/cmd.exe \
  --dead-argument-elimination-optimizing \
  --out .tmp/dae004-descending-large-limit1-trace/starshine.raw.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
```

This confirms the selected fallback is still productive and should not be removed in this slice.

## Status and remaining work

This completes the `[DAE]004` candidate-ordering regression and lands a measured first large-module ordered scheduler step. `[DAE]004` remains open because the handpicked selected-def fallback is still present. Removing that fallback still requires additional artifact/fuzz evidence that a broader ordered scheduler covers the remaining result-removal frontier without exceeding the pass-local timing target or producing invalid output. The next focused work should target the remaining fallback candidates above, starting with a regression that demonstrates why the current single descending candidate plus selected list is still needed on the debug-artifact family.
