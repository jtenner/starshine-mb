# DAE004 bucketed large dropped-result worklist preparation

Date: 2026-05-26

## Scope

Recovery continuation for open `[DAE]004`, specifically the first preparation step after the runtime-neutral design in note `0631`.

This slice adds a focused white-box contract for the intended bucketed broad-large attempt order but does **not** switch the active large-module scheduler. A trial active switch exceeded the pass-local `Starshine <= 2x Binaryen` target on the debug artifact, so the behavior change was intentionally not kept.

## Test-first evidence

Added a white-box regression in `src/passes/dead_argument_elimination_wbtest.mbt`:

- `dae large dropped-result bucket order interleaves fallback neighborhood before low tail`

The test constructs synthetic selected dropped-result candidates with high candidates (`4648..4644`), selected-fallback-neighborhood candidates (`298`, `299`, `427`, `445`), and low candidates (`1`, `2`). It expects the first broad-large attempt batch at cap `8` to be:

```text
4648, 4647, 4646, 4645, 298, 299, 427, 445
```

Initial focused validation failed during `moon test src/passes` because `dae_collect_bucketed_large_dropped_result_attempts(...)` did not exist yet, confirming the new ordering contract was not already implemented.

## Implementation kept

`src/passes/dead_argument_elimination.mbt` now has:

- `dae_selected_dropped_result_fallback_neighborhood_defs()` for the current selected fallback neighborhood from notes `0628` and `0629`;
- `dae_collect_bucketed_large_dropped_result_attempts(...)` with initial quotas: high descending `4`, fallback-neighborhood `4`, low ascending `2`, bounded by the existing attempt limit.

The active scheduler remains unchanged after the failed timing trial: `defined <= 4096` keeps the ascending path; `4096 < defined <= 4608` keeps the existing descending path with the fourteen-candidate narrow-band cap; and broad large modules keep the existing descending path with cap `8` before selected fallback.

## Rejected active switch

A local trial routed `original_defined > 4608` through the bucketed attempt order while keeping the productive cap at `8`. Timing-only artifact replays were:

- `.tmp/dae004-bucketed-first-timing-20260526`: Starshine pass `1871.393ms`, Binaryen pass `892.572ms` (over target; `2x` Binaryen is `1785.144ms`).
- `.tmp/dae004-bucketed-first-timing-repeat-20260526`: Starshine pass `1818.466ms`, Binaryen pass `875.108ms` (over target; `2x` Binaryen is `1750.216ms`).

Because both trials exceeded the accepted DAE011 pass-local target, the active switch was reverted. Agent classification: the bucketed ordering remains promising for selected-fallback removal, but it needs a more targeted implementation or performance work before it can replace broad-large descending order on the debug artifact.

## Remaining work

`[DAE004-D]` remains open. Next behavior-changing work should add trace metadata and/or a narrower family-specific bucketed path, then prove:

1. a formerly selected-only dropped-result family is covered by the fact-driven worklist;
2. artifact output validates with `wasm-opt --all-features`;
3. pass-local timing stays inside `Starshine <= 2x Binaryen`;
4. direct compare evidence has no new semantic or validation regression;
5. only then, delete or gate one selected fallback entry.

## Validation

- `moon test src/passes` passed after adding the preparatory collector: `1389` tests.

Full signoff and artifact/fuzz validation are still required before deleting selected fallback entries or closing `[DAE004-D]`.
