# Tuple Optimization No-New-Local Cleanup Performance Slice

Date: 2026-06-29

## Goal

Continue the `tuple-optimization` (`TO`) O4z audit by trimming remaining cleanup overhead in the candidate-heavy pure/drop-only source-only elision fixture without changing transform behavior or broadening the existing dedicated-profile residual classification.

The targeted cleanup owner was the post-rewrite unused-body-local compaction scan. In the narrow source-only elision path, TO reuses original lane locals and appends no split locals, so the existing compaction scan cannot remove any newly-created body local.

## Change kept

`src/passes/tuple_optimization.mbt` now fast-skips `tuple_optimization_cleanup_unused_body_locals(...)` when the function's local count after rewrite equals the `initial_local_count` captured before rewrite. In that case cleanup emits:

- `detail:tuple-optimization:cleanup-post-rewrite:unused-body-locals:no-new-local-fast-path`

and does not emit the ordinary `unused-body-locals` timer.

This is behavior-preserving because the cleanup helper only compacts locals appended after `initial_local_count`: pre-existing locals are marked used by construction, so when no locals were appended the helper can only scan and return without mutation.

A red-first white-box invariant was added in `src/passes/tuple_optimization_wbtest.mbt`: the pure constant-payload drop-only fixture must emit the no-new-local fast-path timer and must not emit the ordinary `unused-body-locals` timer.

## Validation

Red-first:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*unused-body-local cleanup fast-skips*'`
  - failed before implementation because the ordinary `detail:tuple-optimization:cleanup-post-rewrite:unused-body-locals` timer was still emitted and no `no-new-local-fast-path` timer existed.

After implementation:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*unused-body-local cleanup fast-skips*'`
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

- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-new-local-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - compared `1000/1000`, normalized `1000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000/0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-new-local-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - stopped at the mismatch cap after `80/100`, raw mismatches `80`, normalized matches `0`, validation/generator/property/command failures `0`, Binaryen cache `80/0`.
  - selected profiles and `profile_case_label` counts: spill `33`, tee `12`, copy-chain `35`.
  - agent classification unchanged: this remains the known simple type-indexed pure/drop-only scalar-spelling residual surface, not a broader TO classification or final closeout.

## Candidate-heavy pass-local timings

Command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-no-new-local-fast \
  --timing-only --tuple-optimization
```

First run Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.347ms` | `0.052ms` |
| 500 | `1.485ms` | `0.225ms` |
| 1000 | `2.713ms` | `0.347ms` |
| 2000 | `5.987ms` | `0.665ms` |

Spot reruns:

- 1000 pairs: `2.341/0.298`, `2.197/0.312`, `2.476/0.320` ms.
- 2000 pairs: `4.498/0.709`, `4.036/0.742`, `4.068/0.645` ms.

The 1000-pair detail trace in `.tmp/to-passlocal-candidate-heavy-1000-20260629-no-new-local-fast/starshine.stderr.txt` shows the fast path firing:

- `collect-seed-groups`: `0.590ms`
- `build-query-summary`: `0.197ms`
- `link-copy-groups`: `0.193ms`
- `link-result-block-copy-groups`: `0.086ms`
- `precompute-drop-only-elision-mask`: `0.279ms`
- `rewrite-group-defs:source-only-elide-fast-path`: `0.386ms`
- `rewrite-group-defs`: `0.431ms`
- `cleanup-post-rewrite:drop-local-tees:no-local-tee-fast-path`: `0.000ms`
- `cleanup-post-rewrite:scalarized-tuple-locals`: `0.072ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions`: `0.198ms`
- `cleanup-post-rewrite:unused-body-locals:no-new-local-fast-path`: `0.000ms`
- `cleanup-post-rewrite`: `0.297ms`
- `pass:tuple-optimization`: `2.713ms`

## Interpretation

This is a small cleanup fast path, but not a decisive pass-local improvement. It removes one guaranteed-no-op full-function local-use scan from no-new-local rewrites, but candidate-heavy timings remain noisy and outside target. The best 1000-pair spot in this slice (`2.197ms`) is comparable to the previous no-tee cleanup spots (`2.063-2.156ms`), and 2000-pair spots (`4.036-4.498ms`) remain comparable to the previous `4.017-4.153ms` band.

The remaining candidate-heavy owners are unchanged in kind: analysis setup (`collect-seed-groups`, query summary, copy/result link scans), drop-only elision precompute, source replacement work, targeted root removal, scalarized-local cleanup pre-scan, and any residual cleanup scans. TO still misses the pass-local target and the full audit/closeout remains open.

## Remaining work

- Continue performance work before final TO closeout. Prefer changes that reuse facts already gathered during analysis or rewrite rather than adding new pre-scans.
- The dedicated `tuple-optimization-all` profile remains raw-red with the known narrow scalar-spelling residual; do not broaden that classification without new inspection and measurements.
- Exact-slot/neighborhood evidence and the required final closeout ladder, including 100k lanes, remain open.
