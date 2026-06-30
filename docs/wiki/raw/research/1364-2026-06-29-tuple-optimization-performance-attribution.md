---
kind: research
status: working
last_reviewed: 2026-06-29
sources:
  - ../../../binaryen/passes/tuple-optimization/parity.md
  - ../../../binaryen/passes/tuple-optimization/fuzzing.md
  - ../../../../src/passes/tuple_optimization.mbt
  - ../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../agent-todo.md
---

# Tuple Optimization Performance Attribution

## Question

The previous candidate-heavy synthetic fixtures showed `tuple-optimization` missing the pass-local speed target by a large margin. This slice added pass-owned detail timers so the remaining closeout blocker can be assigned to concrete TO phases instead of the generic wall-time backlog.

## Change

Added `perf:timer` detail scopes for the TO analysis and rewrite pipeline:

- `detail:tuple-optimization:collect-seed-groups`
- `detail:tuple-optimization:build-query-summary`
- `detail:tuple-optimization:build-local-group-ids`
- `detail:tuple-optimization:link-copy-groups`
- `detail:tuple-optimization:link-result-block-copy-groups`
- `detail:tuple-optimization:link-scalar-forward-copy-groups`
- `detail:tuple-optimization:count-lane-traffic`
- `detail:tuple-optimization:finalize-host-lanes`
- `detail:tuple-optimization:propagate-badness`
- `detail:tuple-optimization:rewrite-use-def-build`
- `detail:tuple-optimization:build-rewrite-mask`
- `detail:tuple-optimization:collect-rewrite-order`
- `detail:tuple-optimization:ensure-split-locals`
- `detail:tuple-optimization:rewrite-group-defs`
- `detail:tuple-optimization:cleanup-post-rewrite`

The red-first guard was `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'`, which initially failed because only the coarse pass timer existed. The guard now passes and asserts representative analysis/rewrite detail timers on a two-lane type-indexed copy-chain fixture.

## Candidate-Heavy Measurement

Commands after rebuilding `_build/native/release/build/cmd/cmd.exe`:

```sh
moon build --target native --release src/cmd
for n in 100 500 1000; do
  bun scripts/self-optimize-compare.ts \
    .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-detail \
    --timing-only \
    --tuple-optimization
done
```

Results:

| Pairs | Starshine pass | Binaryen pass | Top TO phase | Top phase time | Notes |
| ---: | ---: | ---: | --- | ---: | --- |
| 100 | `4.132ms` | `0.047ms` | `rewrite-group-defs` | `3.057ms` | next: cleanup `0.420ms`, rewrite use-def `0.265ms`, ensure splits `0.152ms` |
| 500 | `41.643ms` | `0.183ms` | `rewrite-group-defs` | `31.378ms` | next: cleanup `5.013ms`, ensure splits `2.632ms`, rewrite use-def `1.828ms` |
| 1000 | `153.200ms` | `0.310ms` | `rewrite-group-defs` | `118.803ms` | next: cleanup `17.260ms`, ensure splits `11.145ms`, rewrite use-def `4.219ms` |

Interpretation:

- The candidate-heavy blocker remains inside TO pass-local work, not `[WALL]001`.
- `rewrite-group-defs` dominates and grows superlinearly across these independent two-lane spill fixtures.
- Cleanup and split-local preparation are secondary but also grow sharply.
- Analysis linking is not the primary blocker on this surface: query summary, copy linking, scalar-forward linking, lane traffic, and badness propagation are all sub-millisecond at 1000 pairs.
- A likely next optimization target is mutation/root-slot work inside group definition rewriting. The source path repeatedly finds root slots and inserts/replaces nodes for independent groups; this should be profiled or optimized before final closeout.

## Correctness Checks

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'` failed before the timers and passes after them.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` => `49 / 49` passed.
- `moon test src/passes` => `3604 / 3604` passed.
- `moon build --target native --release src/cmd` => completed with existing unused-function warnings in `pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-100-detail-timers --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` => `100 / 100` compared, `100` normalized matches, zero validation/generator/property/command failures, Binaryen cache `0 / 100`.

## Remaining Work

- The speed target is still badly missed. This slice identifies the owner phase but does not fix it.
- Add narrower attribution or implement a performance fix for `rewrite-group-defs`, likely by avoiding repeated root-slot scans, region inserts, replacement mutation tracing, or other per-group O(N) work on independent root-local spill ladders.
- Rerun the candidate-heavy 100/500/1000/2000 fixtures after any fix and compare against the pre-detail and detail baselines.
- Final TO audit closeout still needs broader family proof, exact-slot/neighborhood evidence, and the full 100k signoff ladder.
