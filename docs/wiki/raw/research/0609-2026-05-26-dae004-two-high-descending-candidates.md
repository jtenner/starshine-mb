# DAE004 two-high descending candidates

Date: 2026-05-26

## Scope

Follow-up recovery/completion slice for `[DAE]004` selected result-removal broadening. Research note `0608` landed the first bounded large-module ordered step for `4096 < defined <= 8192`: one descending fact-driven dropped-result rewrite before the historical handpicked selected-def fallback. That proved high-candidate reachability, but it still left an obvious scheduler gap when more than one high fact-driven candidate exists above the low-candidate budget.

This slice keeps the same large-module guard and descending ordering, but raises the large-module productive rewrite cap from `1` to `2`. The scope is intentionally narrow: it covers two high fact-discovered dropped-result callees while retaining the selected-def fallback and avoiding a broad ascending-queue widening.

## Test-first evidence

Added `dae-optimizing reaches two high dropped-result callees after low candidate budget` in `src/passes/dae_optimizing_test.mbt`. The fixture creates 40 low dropped-result candidates plus two high dropped-result targets at defined functions `4500` and `4501`, both outside the `defined <= 4096` ascending fact queue and outside the handpicked selected-def list.

Expected failure before implementation: with the large-module cap still at `1`, the first high callee is rewritten but the second high callee still reports one result (`1 != 0`). The recovered workspace already contained the test plus the one-line cap change, so the available replay was post-implementation:

```sh
moon test src/passes -f 'dae-optimizing reaches two high dropped-result callees after low candidate budget'
```

Result after implementation: passed.

## Implementation

`src/passes/dead_argument_elimination.mbt` changes only the large-module fact-driven dropped-result attempt cap in `dae_run_core`: modules with `defined <= 4096` still get the existing ascending queue cap of `32`, while `4096 < defined <= 8192` now gets `2` descending productive rewrites instead of `1`.

The candidate guard remains unchanged: private non-tail direct callees with a single current result, current direct-call facts proving every direct call drops that result, and caller-filtered result-removal/`call; drop` repair. The historical selected-def fallback remains active after the bounded fact-driven queue.

## Validation

Focused and pass-suite validation:

```sh
moon test src/passes -f 'dae-optimizing reaches two high dropped-result callees after low candidate budget'
moon test src/passes
```

Both passed after implementation.

Debug-artifact timing and validation:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --timing-only \
  --out-dir .tmp/dae004-descending-large-limit2-timing-20260526
wasm-opt --all-features \
  .tmp/dae004-descending-large-limit2-timing-20260526/starshine.wasm \
  -o .tmp/dae004-descending-large-limit2-timing-20260526/starshine.validated.wasm
```

Result: Starshine output validates with only the existing large-local-count VM warning. Pass-local timing was `1688.317ms` Starshine versus `953.230ms` Binaryen, inside the project target of `Starshine <= 2x Binaryen`.

Direct 10k compare refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass dae-optimizing \
  --max-failures 10000 \
  --keep-going-after-command-failures \
  --out-dir .tmp/pass-fuzz-dae004-descending-large-limit2-20260526-full
```

Result: `9975/10000` compared, `6078` normalized matches, `3897` mismatches, `0` validation failures, and `25` Binaryen/tool command failures. Command failures matched the known Binaryen/tool classes from the accepted DAE010/DAE011/DAE004 lanes. Agent classification for the mismatch family remains the accepted `gen-valid` size-winning semantic-safe raw-cleanup drift: Starshine removes pure/nontrapping dropped generator debris that Binaryen preserves; this slice did not introduce a new validation or semantic mismatch family.

## Status and remaining work

This completes a second bounded large-module ordered scheduler step for `[DAE]004`: two high fact-driven dropped-result candidates can now be reached before low candidates and before the handpicked selected-def fallback. `[DAE]004` remains open because the handpicked fallback is still present and broader removal still needs artifact/fuzz evidence that the ordered fact-driven queue covers the remaining result-removal frontier without exceeding the pass-local timing target or producing invalid output.
