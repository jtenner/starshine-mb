# Tuple Optimization Detached Replacement Delete Performance

Date: 2026-06-29

## Context

This slice continues the active `tuple-optimization` (`TO`) O4z audit after the pure/drop-only source elision slice. Candidate-heavy direct-pass timings still showed `detail:tuple-optimization:rewrite-group-defs` dominating the synthetic independent two-lane type-indexed spill fixtures, especially at 1000 and 2000 groups.

Relevant prior note: [`1366-2026-06-29-tuple-optimization-drop-only-elision-performance.md`](./1366-2026-06-29-tuple-optimization-drop-only-elision-performance.md).

## Changes

- Added red-first white-box perf-detail expectations for finer TO timers:
  - `detail:tuple-optimization:rewrite-group-defs:source`
  - `detail:tuple-optimization:rewrite-group-defs:copy`
  - `detail:tuple-optimization:rewrite-group-defs:elide-simple-drop-only-source`
  - `detail:tuple-optimization:rewrite-group-defs:elide-simple-drop-only-source:{can-elide,payload,replace-defs}`
  - `detail:tuple-optimization:cleanup-post-rewrite:{drop-local-tees,scalarized-tuple-locals,prune-nops,unused-body-locals}`
- Added those timers in `src/passes/tuple_optimization.mbt`.
- Replaced two TO replacement helpers' use of `@ir.hot_delete_node(...)` for newly-built, detached replacement nodes with `@ir.hot_delete_detached_node(...)`:
  - `tuple_optimization_replace_with_built(...)`
  - `tuple_optimization_replace_elided_drop_only_def(...)`
- Reused one built/detached nop node per simple drop-only source group instead of building/deleting one nop per elided `local.set` lane.

The delete change is intended as a performance-only mutation-path fix: the replacement node has just been built, has not been inserted into a root region or child span, and is read only to copy its `HotNode` payload into the real target. The previous `hot_delete_node(...)` path performed the full unreferenced scan, which is unnecessary for these fresh detached nodes.

## Red-first evidence

Command:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'
```

Result before implementation: failed because the new subphase timer names were absent from the trace.

After implementation, the same focused test passed.

## Validation

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*type-indexed block*'` — `2/2` passed.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'` — `1/1` passed.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` — `50/50` passed.
- `moon build --target native --release src/cmd` — passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon test src/passes` — `3605/3605` passed.
- General direct compare smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-detached-delete-timers --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/generator/property/command failures, Binaryen cache `1000/0`.

- Dedicated TO profile smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-detached-delete-timers --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: stopped at the mismatch cap after `65/100` compared, `65` raw mismatches, `0` validation/generator/property/command failures, selected profiles spill `26`, tee `10`, copy-chain `29`, profile labels spill `26`, tee `10`, copy-chain `29`. This remains the known narrow simple pure/drop-only scalar-spelling residual surface; it is not closeout evidence.

## Candidate-heavy pass-local timings

The first subphase-only instrumentation run identified `replace-defs` as the local owner inside simple drop-only elision:

- 1000 pairs: pass `101.361ms`, `rewrite-group-defs` `85.749ms`, elide `71.687ms`, `replace-defs` `58.466ms`.
- 2000 pairs: pass `332.541ms`, `rewrite-group-defs` `274.359ms`, elide `246.191ms`, `replace-defs` `223.722ms`.

After using detached replacement deletes and reusing a per-group nop node, the refreshed candidate-heavy direct `--tuple-optimization` timings were:

| pairs | Starshine pass | Binaryen pass | `rewrite-group-defs` | elide-simple-drop-only-source | replace-defs | cleanup |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 100 | `2.879ms` | `0.032ms` | not summarized in this note | not summarized | not summarized | not summarized |
| 500 | `16.288ms` | `0.147ms` | not summarized in this note | not summarized | not summarized | not summarized |
| 1000 | `45.108ms` | `0.295ms` | `27.694ms` | `15.976ms` | `3.904ms` | `7.903ms` |
| 2000 | `113.093ms` | `0.770ms` | `56.343ms` | `29.113ms` | `6.975ms` | `30.267ms` |

Compared with the previous batched-mark baseline from `1366`, this is a real speedup at larger sizes:

- 1000 pairs: `73.728ms -> 45.108ms` Starshine pass-local.
- 2000 pairs: `291.755ms -> 113.093ms` Starshine pass-local.

The 100-pair run is noisy and slower than the previous `1.916ms` result because the new detail timers add overhead; the 500/1000/2000 trend still confirms the deleted-node scan was a real superlinear owner.

## Interpretation

`rewrite-group-defs:replace-defs` was dominated by replacement-node deletion overhead rather than semantic tuple analysis. The old helper used `hot_delete_node(...)`, whose safety check scans existing nodes for references. That is appropriate for possibly-attached nodes, but unnecessarily expensive for newly-built replacement nodes that are known detached.

The remaining candidate-heavy owners after this slice are:

1. `rewrite-group-defs:source` overhead outside the now-small `replace-defs` bucket.
2. `cleanup-post-rewrite`, especially `prune-nops` and `scalarized-tuple-locals`, which scale with enlarged HOT functions.
3. `rewrite-use-def-build`, `ensure-split-locals`, and `build-rewrite-mask` as secondary costs.

The pass still misses the project pass-local target by a wide margin, so TO closeout remains blocked.

## Reopen / follow-up criteria

- Reopen this slice if detached-delete replacement changes produce a validation failure, semantic mismatch, or label-owner/control-node regression.
- Continue TO performance work by removing or reducing residual nop/prune cleanup for simple root `local.set` elisions, or by batching/removing root definitions directly when all defining nodes are same-region roots.
- Do not broaden the pure/drop-only Starshine-win classification beyond the documented simple type-indexed surface without new tests and evidence.
