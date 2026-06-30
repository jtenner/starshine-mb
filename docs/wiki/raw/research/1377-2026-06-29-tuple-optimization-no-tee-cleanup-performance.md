# Tuple Optimization No-Tee Cleanup Performance Slice

Date: 2026-06-29

## Goal

Continue the `tuple-optimization` (`TO`) O4z audit by reducing remaining candidate-heavy pass-local cleanup overhead without changing the Binaryen behavior surface or broadening the existing narrow scalar-spelling residual classification.

The targeted fixture family is the existing pure/drop-only source-only elision path: many independent two-lane `i32, i64` type-indexed block carriers whose scalarized lanes only feed direct drops.

## Change kept

`src/passes/tuple_optimization.mbt` now records whether the pre-rewrite query summary saw any `local.tee` definitions (`has_local_tee_defs`). The rewrite cleanup plan carries `skip_drop_local_tee_cleanup`, set when the analysis observed no local tee definitions. In that case, post-rewrite cleanup emits:

- `detail:tuple-optimization:cleanup-post-rewrite:drop-local-tees:no-local-tee-fast-path`

and skips the full dropped-`local.tee` cleanup pre-scan. This is safe for this narrow path because TO rewrite does not create new `local.tee` definitions; if the original function had any local tee definitions, the old cleanup scan still runs.

A red-first white-box invariant was added in `src/passes/tuple_optimization_wbtest.mbt`: the pure constant-payload drop-only fixture must emit the no-local-tee fast-path timer and must not emit the ordinary `drop-local-tees` timer line.

## Rejected experiments in this slice

Before the kept cleanup change, I briefly tried a no-direct-copy-payload fast path that pre-scanned group block payloads and skipped `link-copy-groups` when every source payload was constant-only. The red-first timer invariant worked, but candidate-heavy timings regressed badly because the predicate duplicated much of the direct-copy payload walk before the existing link loop. It was fully reverted and is not present in the final worktree.

Representative rejected 1000-pair spot timings after that experiment were `4.976ms`, `4.944ms`, and `4.009ms` Starshine pass-local versus Binaryen around `0.400-0.516ms`, much worse than the kept payload-facts baseline.

After the kept no-tee cleanup fast path, I also tried a no-single-result-block fast path for `link-result-block-copy-groups` using a `has_single_result_block` bit gathered during query-summary construction. Focused coverage passed, but performance was neutral to slightly regressive: first 100/500/1000/2000 timings were `0.315ms`, `1.508ms`, `2.444ms`, and `4.714ms`; spot reruns were `2.088-2.123ms` at 1000 pairs and `4.179-4.542ms` at 2000 pairs. The extra query-summary work did not clearly pay for the skipped result-copy scan on this fixture, so that experiment was reverted too.

## Validation

Red-first:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*drop-local-tee cleanup fast-skips*'`
  - failed before implementation because only `detail:tuple-optimization:cleanup-post-rewrite:drop-local-tees` was emitted.

After implementation:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*drop-local-tee cleanup fast-skips*'`
  - passed `1/1`.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - passed `55/55`.
- `moon test src/passes`
  - passed `3610/3610`.
- `moon build --target native --release src/cmd`
  - passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.

Compare-pass:

- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-tee-cleanup-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - compared `1000/1000`, normalized `1000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000/0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-tee-cleanup-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - stopped at mismatch cap after `80/100`, raw mismatches `80`, normalized matches `0`, validation/generator/property/command failures `0`, Binaryen cache `80/0`.
  - selected/profile labels: spill `33`, tee `12`, copy-chain `35`.
  - agent classification unchanged: the sampled bounded dedicated profile remains the known simple type-indexed pure/drop-only scalar-spelling residual surface, not a broader TO classification or final closeout.

## Candidate-heavy pass-local timings

Command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-no-tee-cleanup-fast \
  --timing-only --tuple-optimization
```

First run Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.313ms` | `0.031ms` |
| 500 | `1.160ms` | `0.144ms` |
| 1000 | `2.136ms` | `0.295ms` |
| 2000 | `5.375ms` | `0.905ms` |

Spot reruns:

- 1000 pairs: `2.063/0.278`, `2.156/0.287`, `2.093/0.386` ms.
- 2000 pairs: `4.040/0.726`, `4.153/0.594`, `4.017/0.716` ms.

The 1000-pair kept detail trace now shows:

- `collect-seed-groups`: `0.353ms`
- `build-query-summary`: `0.145ms`
- `link-copy-groups`: `0.152ms`
- `link-result-block-copy-groups`: `0.081ms`
- `precompute-drop-only-elision-mask`: `0.227ms`
- `rewrite-group-defs:source-only-elide-fast-path`: `0.313ms`
- `rewrite-group-defs`: `0.350ms`
- `cleanup-post-rewrite:drop-local-tees:no-local-tee-fast-path`: `0.000ms`
- `cleanup-post-rewrite:scalarized-tuple-locals`: `0.066ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions`: `0.181ms`
- `cleanup-post-rewrite`: `0.321ms`
- `pass:tuple-optimization`: `2.136ms`

## Interpretation

This is a small kept cleanup win and removes one unnecessary whole-function scan from no-tee source-only elision fixtures. It does not close the performance blocker. The 1000-pair fixture is still roughly `5.5x-7.8x` Binaryen pass-local across spot runs, and 2000 pairs is still roughly `5.6x-6.8x` Binaryen. Remaining owners are analysis setup (`collect-seed-groups`, query summary, direct/result copy link scans), drop-only elision precompute, source replacement work, targeted root removal, scalarized-local cleanup pre-scan, and unused-local cleanup.

## Remaining work

- Continue performance work before final TO closeout. Highest-leverage next candidates are analysis setup on no-copy source-only fixtures and cleanup scans/root-removal.
- The dedicated `tuple-optimization-all` profile remains raw-red with the known narrow scalar-spelling residual; do not broaden that classification without new inspection and measurements.
- Exact-slot/neighborhood evidence and the required final closeout ladder, including 100k lanes, remain open.
