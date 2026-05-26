# DAE004 three-high descending candidates

Date: 2026-05-26

## Scope

Follow-up recovery/completion slice for `[DAE]004` selected result-removal broadening. Research note `0609` raised the large-module descending fact-driven dropped-result cap to two productive rewrites for `4096 < defined <= 8192`, but the handpicked selected-def fallback still remained active. This slice takes the next narrow ordered step by proving and allowing three high fact-driven dropped-result callees before low candidates and before the selected fallback.

The scope intentionally keeps the existing guards: no broad `<= 8192` ascending queue, no selected-def fallback removal, and no change to small/mid-size `defined <= 4096` behavior.

## Test-first evidence

Added `dae-optimizing reaches three high dropped-result callees after low candidate budget` in `src/passes/dae_optimizing_test.mbt`. The fixture creates 40 low dropped-result candidates plus three high dropped-result targets at defined functions `4500`, `4501`, and `4502`, all outside the mid-size ascending queue and outside the handpicked selected-def list.

Expected failure before implementation:

```sh
moon test src/passes -f 'dae-optimizing reaches three high dropped-result callees after low candidate budget'
```

Result before implementation: failed with the third high target still reporting one result (`1 != 0`).

## Implementation

`src/passes/dead_argument_elimination.mbt` changes only the large-module fact-driven dropped-result attempt cap in `dae_run_core`: modules with `defined <= 4096` still get the existing ascending queue cap of `32`, while `4096 < defined <= 8192` now gets `3` descending productive rewrites instead of `2`.

The candidate guard remains unchanged: private non-tail direct callees with a single current result, current direct-call facts proving every direct call drops that result, and caller-filtered result-removal/`call; drop` repair. The historical selected-def fallback remains active after the bounded fact-driven queue.

## Validation

Focused validation:

```sh
moon test src/passes -f 'dae-optimizing reaches three high dropped-result callees after low candidate budget'
```

Result after implementation: passed.

Standard quick signoff later in this recovery run:

```sh
moon info
moon fmt
moon test
```

Result: passed. `moon info` still reports existing unused helper warnings in `src/passes/pass_manager_wbtest.mbt`; no new validation failure was introduced.

## Status and remaining work

This completes a third bounded large-module ordered scheduler step for `[DAE]004`: three high fact-driven dropped-result candidates can now be reached before low candidates and before the handpicked selected-def fallback. `[DAE]004` remains open because the handpicked fallback is still present and broader removal still needs artifact/fuzz evidence that the ordered fact-driven queue covers the remaining result-removal frontier without exceeding the pass-local timing target or producing invalid output.
