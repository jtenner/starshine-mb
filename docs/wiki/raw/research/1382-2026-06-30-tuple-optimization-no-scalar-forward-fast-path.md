# 1382 - 2026-06-30 - tuple-optimization no-scalar-forward fast path

## Context

This slice continues the `tuple-optimization` (`TO`) O4z audit after the no-single-result-block result-link fast path in [`1381`](./1381-2026-06-29-tuple-optimization-no-result-link-fast-path.md). Candidate-heavy pure/drop-only fixtures still miss the pass-local target; the latest 1000-pair detail trace before this slice showed remaining TO-owned costs in seed collection, query-summary construction, copy linking, drop-only elision precompute, rewrite, targeted root cleanup, and untraced overhead.

## Change

`HotTupleOptimizationQuerySummary` now records whether the existing query-summary scan found any scalar-forward copy candidate. `tuple_optimization_analyze_with_groups(...)` uses that fact to skip `tuple_optimization_link_scalar_forward_copy_groups(...)` and the immediate `rebuild-local-groups-after-scalar-links` pass when no scalar-forward candidate exists, emitting `detail:tuple-optimization:link-scalar-forward-copy-groups:no-scalar-forward-fast-path` instead.

Safety rationale:

- the skipped linker only adds copy groups from nodes that have exactly one child-use through a `local.set` / `local.tee` to a single-written local;
- the new summary fact is set at the same point where `scalar_forward_present[node_id]` is set, over the same live pre-mutation use-def snapshot;
- if the fact is false, the scalar-forward linker has no candidate node from which it can add a group, so the follow-up local-group-id rebuild would be a no-op;
- result-block linking, ordinary copy linking, lane-traffic accounting, badness propagation, and rewrite/cleanup decisions are unchanged.

## Red-first guard

Updated `src/passes/tuple_optimization_wbtest.mbt` so the existing pure/drop-only performance-detail fixture requires the new no-scalar-forward fast-path timer, rejects the generic `link-scalar-forward-copy-groups elapsed_us=` timer, and rejects `rebuild-local-groups-after-scalar-links` for this no-scalar-forward shape.

Before the implementation, the focused test failed as intended because the old generic scalar-forward timer and scalar-link rebuild timer were still present and the new fast-path timer was absent.

## Validation

Focused/unit validation:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'` before implementation: failed as intended.
- Same focused command after implementation: passed `1 / 1`.
- `moon fmt && moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt && moon test src/passes`: formatting passed, tuple white-box tests passed `56 / 56`, and `moon test src/passes` passed `3611 / 3611`.
- `moon build --target native --release src/cmd`: passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.

Compare-pass evidence:

- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-scalar-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - compared `1000 / 1000`, normalized `1000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000 / 0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-scalar-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - stopped at the mismatch cap after `80 / 100`, with `80` raw mismatches and zero validation/generator/property/command failures;
  - selected/profile labels: spill `33`, tee `12`, copy-chain `35`;
  - input effect/trap facts remained zero.

## Candidate-heavy pass-local timings

Command form:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260630-no-scalar-fast \
  --timing-only --tuple-optimization
```

First-run Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.301ms` | `0.039ms` |
| 500 | `1.050ms` | `0.151ms` |
| 1000 | `3.728ms` | `0.371ms` |
| 2000 | `4.625ms` | `0.679ms` |

Spot reruns:

- 1000 pairs: `2.246ms / 0.326ms`, `2.951ms / 0.315ms`.
- 2000 pairs: `4.468ms / 0.958ms`, `4.753ms / 0.709ms`.

The 1000-pair first-run detail trace in `.tmp/to-passlocal-candidate-heavy-1000-20260630-no-scalar-fast/starshine.stderr.txt` confirms the new fast path:

- `collect-seed-groups` `0.358ms`
- `build-query-summary` `0.334ms`
- `link-copy-groups` `0.154ms`
- `link-result-block-copy-groups:no-single-result-block-fast-path` `0.000ms`
- `link-scalar-forward-copy-groups:no-scalar-forward-fast-path` `0.000ms`
- `precompute-drop-only-elision-mask` `0.291ms`
- `rewrite-group-defs` `1.213ms`
- source-only rewrite `0.905ms`
- local-set-root fast total `0.724ms`
- targeted root cleanup `0.646ms`
- cleanup `0.740ms`
- `pass:tuple-optimization` `3.728ms`

Interpretation: the fast path removes a no-op scalar-forward link/rebuild owner on no-scalar fixtures, but the representative timings remain noisy and outside the project pass-local target. This is a small analysis/linking cleanup, not TO closeout. Remaining candidate-heavy owners are still seed collection, query-summary construction, copy-linking, drop-only precompute, source/root cleanup, and untraced pass overhead.

## Status

TO audit remains open. Dedicated profile residuals are still the known narrow simple type-indexed pure/drop-only scalar-spelling surface; this slice does not broaden that classification. General direct smoke is green, but final closeout still needs exact-slot/neighborhood evidence, pass-local performance within target or an explicitly accepted exception, the full signoff ladder, and the required 100k/10k lanes.
