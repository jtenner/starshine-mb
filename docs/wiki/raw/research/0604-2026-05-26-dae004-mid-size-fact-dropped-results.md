# DAE004 mid-size fact-dropped result queue

Date: 2026-05-26

## Question

Can `[DAE]004` use the fact-driven dropped-result queue beyond the original small-module guard without reopening the selected dropped-result safety contract or the debug-artifact runtime cliff?

## Change

`src/passes/dead_argument_elimination.mbt` now runs the bounded fact-driven dropped-result queue for modules up to `2048` defined functions before the handpicked selected-def fallback. That broadens the old `<= 1024` small-module guard while intentionally avoiding the known huge debug artifact until a separate measured batch can preserve the closed DAE011 runtime target. The queue still derives candidates from current direct-call facts and only considers non-escaped, non-tail direct callees whose current direct calls all drop the single result. The existing caller-filtered helper then preserves the deeper result-removal guards: single-result signature, no live undropped direct callers, non-self-only reachability, call/drop repair, callee result drop insertion, signature update, type-section update, and touched-function reporting.

## Test-first evidence

Added `dae-optimizing removes high fact-discovered dropped callee result outside selected list` in `src/passes/dae_optimizing_test.mbt` with target definition `1500`, above the previous `original_defined <= 1024` guard and outside the handpicked selected-def list.

Before the implementation it failed in `moon test src/passes` with the target still reporting one result (`1 != 0`). After widening the guard to `<= 2048`, `moon test src/passes` passed all `1379` tests. Full validation also passed `git diff --check`, `moon info`, `moon fmt`, `moon test`, and `.tmp/pass-fuzz-dae004-mid-fact-20260526-full` (`9975/10000` compared, `6078` normalized matches, `3897` known gen-valid raw-cleanup mismatches, `0` validation failures, `25` Binaryen/tool command failures).

A full unguarded experiment was rejected during recovery: the debug-artifact timing-only replay reached many fact-driven rewrites and did not complete cleanly, so this slice keeps the huge artifact on the closed DAE011 selected-list path until a measured large-artifact batch is designed separately. The guarded timing replay `.tmp/dae004-mid-fact-timing-20260526` reports `1439.590ms` Starshine pass time versus `914.804ms` Binaryen pass time, inside the repo target of `Starshine <= 2x Binaryen`; both canonical outputs validate with `wasm-opt --all-features` with only the existing large-local-count VM warning.

## Status

This completes a DAE004 breadth step by batching mid-size fact-discovered dropped-result candidates ahead of the selected-def list. It does not remove the historical selected-def fallback or cover the huge debug artifact yet, and it does not close all of `[DAE]004`; future work still needs artifact/fuzz evidence that no remaining dropped-result frontier depends on the handpicked list or on broader result-removal scheduling.
