# Tuple Optimization No-Scalarized-Prescan Cleanup Performance Slice

Date: 2026-06-29

## Goal

Continue the `tuple-optimization` (`TO`) O4z audit by removing another guaranteed no-op cleanup scan from the candidate-heavy pure/drop-only source-only elision fixture without changing transform behavior or broadening the existing dedicated-profile residual classification.

The targeted owner was the scalarized tuple-local cleanup pre-scan. That cleanup only rewrites existing `local.set (tuple.make (local.get ...)+)` tuple-local materialization into direct scalar local gets. The no-copy/no-tee/no-new-local candidate-heavy fixture starts from type-indexed block-carrier lane sets, not `tuple.make` local sets, and the kept source-only elision rewrite does not create `local.set (tuple.make ...)` cleanup candidates.

## Change kept

`src/passes/tuple_optimization.mbt` now records `has_scalarized_tuple_local_cleanup_candidate` while building the existing TO query summary. The query summary already scans each local's live writes, so this piggybacks on existing analysis work instead of adding a new cleanup-time scan.

The rewrite cleanup plan now carries `skip_scalarized_tuple_local_cleanup` when analysis saw no live `local.set` whose single child is a multi-lane `TupleMake`. In that case post-rewrite cleanup emits:

- `detail:tuple-optimization:cleanup-post-rewrite:scalarized-tuple-locals:no-tuple-make-local-set-fast-path`

and does not emit the ordinary `scalarized-tuple-locals:pre-scan` or `scalarized-tuple-locals:use-def-build` timers.

Safety rationale: TO's source-only/drop-only elision path removes or rewrites tuple carriers but does not synthesize the cleanup helper's target shape (`local.set (tuple.make (local.get ...)+)`). If the pre-rewrite analysis saw no such cleanup candidate, then the cleanup helper can only scan and return on this path.

## Validation

Red-first:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*scalarized tuple-local cleanup fast-skips when analysis saw no tuple-make local sets*'`
  - failed before implementation because the ordinary `detail:tuple-optimization:cleanup-post-rewrite:scalarized-tuple-locals:pre-scan` timer still appeared and the new fast-path timer was absent.

After implementation:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*scalarized tuple-local cleanup fast-skips when analysis saw no tuple-make local sets*'`
  - passed `1/1`.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - passed `56/56`.
- `moon test src/passes`
  - passed `3611/3611`.
- `moon fmt`
  - passed.
- `git diff --check`
  - passed.
- `moon build --target native --release src/cmd`
  - passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.

Compare-pass:

- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-scalarized-prescan-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - compared `1000/1000`, normalized `1000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000/0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-scalarized-prescan-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - stopped at the mismatch cap after `80/100`, raw mismatches `80`, normalized matches `0`, validation/generator/property/command failures `0`, Binaryen cache `80/0`.
  - selected profiles and `profile_case_label` counts: spill `33`, tee `12`, copy-chain `35`.
  - input effect/trap counts are all zero.
  - agent classification unchanged: this remains the known simple type-indexed pure/drop-only scalar-spelling residual surface, not a broader TO classification or final closeout.

## Candidate-heavy pass-local timings

Command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-no-scalarized-prescan-fast \
  --timing-only --tuple-optimization
```

First run Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.407ms` | `0.047ms` |
| 500 | `1.244ms` | `0.149ms` |
| 1000 | `3.088ms` | `0.435ms` |
| 2000 | `5.344ms` | `0.630ms` |

Spot reruns:

- 1000 pairs: `2.148/0.423`, `2.328/0.293`, `2.529/0.311` ms.
- 2000 pairs: `4.550/0.880`, `4.518/0.675`, `5.047/0.999` ms.

The 1000-pair detail trace in `.tmp/to-passlocal-candidate-heavy-1000-20260629-no-scalarized-prescan-fast/starshine.stderr.txt` shows the new fast path firing:

- `collect-seed-groups`: `0.373ms`
- `cleanup-post-rewrite:scalarized-tuple-locals:no-tuple-make-local-set-fast-path`: `0.000ms`
- `pass:tuple-optimization`: `3.088ms`

## Interpretation

This slice removes a cleanup-time full-function pre-scan from no-candidate shapes by reusing a fact collected during existing query-summary construction. The wall/pass-local timing impact remains noisy and not decisive. Compared with the previous no-new-local slice, the best 1000-pair spot (`2.148ms`) is in the same band as previous best spots (`2.197ms` after no-new-local and `2.063-2.156ms` after no-tee cleanup), while 2000-pair spots remain around `4.5-5.0ms`.

TO still misses the project pass-local target by a wide margin on candidate-heavy fixtures. Remaining owners are still analysis setup (`collect-seed-groups`, query summary, copy/result-link scans), drop-only elision precompute, source replacement work, targeted root removal, and broader cleanup/root-edit overhead. Future work should keep reusing facts gathered in already-necessary passes and avoid standalone scans that do not replace existing work.

## Remaining work

- Continue performance work before final TO closeout; analysis setup and targeted root removal look more material than this removed cleanup pre-scan.
- Keep the dedicated `tuple-optimization-all` profile's raw-red classification narrow to the measured simple pure/drop-only scalar-spelling residual surface.
- Exact-slot/neighborhood evidence and the required final closeout ladder, including 100k lanes, remain open.
