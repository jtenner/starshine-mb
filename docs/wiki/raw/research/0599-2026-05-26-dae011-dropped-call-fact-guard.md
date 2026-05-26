# DAE011 dropped-call fact guard

Date: 2026-05-26

## Scope

Recovery/completion run for open `[DAE]011` performance stabilization. The prior profile in `0598` attributed the current debug-artifact hotspot to `detail:dae:core:selected-lanes:dropped-results:selected-defs`, especially repeated selected-def candidate checks inside `dae_try_remove_dropped_results(...)`.

## Change

`dae_try_remove_selected_defs_dropped_results_with_facts_once(...)` already receives shared current call facts, including both `direct_calls` and `dropped_calls`, but it passed `direct_call_count` as both arguments to `dae_try_remove_dropped_results(...)`. That forced candidates with any direct call through the expensive dropped-result helper even when the shared facts already proved not all direct calls were dropped.

The fix threads `call_facts.dropped_calls[callee_abs]` into `dae_try_remove_dropped_results(...)`, with an out-of-range fallback of `0`. This preserves the helper's existing `direct_call_count == 0 || dropped_call_count != direct_call_count` early exit and avoids relying on the later whole-module undropped-call scan for candidates that can be rejected from shared facts.

## Regression

Added `dae selected dropped-result helper respects precomputed dropped-call facts` in `src/passes/pass_manager_wbtest.mbt`. The test supplies intentionally inconsistent precomputed facts (`direct_calls[callee]=1`, `dropped_calls[callee]=0`) for a module whose body actually contains `call; drop`. Before the fix the selected helper ignored `dropped_calls` and rewrote the callee; after the fix it returns unchanged.

TDD evidence:

- `moon test src/passes` failed before the fix with `FAILED: true is not false` for the new white-box test.
- `moon test src/passes` passed after the fix (`1375/1375`).

## Timing evidence

After rebuilding the native CLI with `moon build --target native src/cmd`, a timing-only artifact replay completed:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing --timing-only \
  --out-dir .tmp/dae011-dropped-facts-timing-rebuilt-20260526
```

Result:

- Starshine runtime: `3166.090ms`
- Binaryen runtime: `1146.993ms`
- Starshine pass runtime: `2807.905ms`
- Binaryen pass runtime: `850.135ms`
- canonical wasm equal: `no`

This does **not** close `[DAE]011`: Starshine remains over the `<= 2x Binaryen` pass-local target. The guard is still useful because it removes an unnecessary selected-def path and locks the shared-fact contract, but the artifact hotspot likely lies in candidates whose direct calls are all dropped or in repeated work after fact-based filtering.

## Next step

Continue `[DAE]011` with deeper selected-def-loop profiling or a batched dropped-result rewrite path. Promising targets remain:

- reuse type indices and function/type-section snapshots across selected-def candidates;
- avoid repeated whole-module scans inside `dae_module_has_undropped_direct_call_to_except(...)` when current call facts are already available;
- avoid repeated caller-body rewrites over artifact-sized modules unless a candidate passes cheap prechecks.
