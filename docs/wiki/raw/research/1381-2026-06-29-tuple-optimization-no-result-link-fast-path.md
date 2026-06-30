# Tuple Optimization No-Result-Link Fast Path

## Summary

This slice kept a small `tuple-optimization` analysis fast path for source-only pure/drop-only fixtures: when query-summary construction sees no live one-result `block`, TO now skips `tuple_optimization_link_result_block_copy_groups(...)` and the follow-up local-group rebuild. The pass instead emits `detail:tuple-optimization:link-result-block-copy-groups:no-single-result-block-fast-path`.

## Motivation

After the local-set root elision fast path, the 1000-pair candidate-heavy detail trace still showed pass-local time outside the project target. Remaining owners included analysis/linking setup, drop-only precompute, root-removal cleanup, and untraced overhead. The result-block copy linker only creates groups for live `Block` nodes with result arity `1`; the candidate-heavy pure/drop-only fixtures use two-result typed blocks and have no result-block copy candidates, so the full scan and unconditional local-group rebuild were avoidable.

## Red-first test

Updated `src/passes/tuple_optimization_wbtest.mbt` so the existing perf-detail fixture requires:

- `detail:tuple-optimization:link-result-block-copy-groups:no-single-result-block-fast-path`
- absence of the generic `detail:tuple-optimization:link-result-block-copy-groups elapsed_us=` timer

Before implementation, the focused test failed because the generic linker timer appeared and the fast-path timer was absent.

Command:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'
```

Pre-implementation result: failed as intended.

## Implementation

`src/passes/tuple_optimization.mbt` now records `has_single_result_block_copy_candidate` while building `HotTupleOptimizationQuerySummary`. If false, `tuple_optimization_analyze_with_groups(...)` skips `tuple_optimization_link_result_block_copy_groups(...)` and the immediate `rebuild-local-groups-after-result-links` pass.

Safety rationale:

- The skipped linker only accepts live `Block` carriers with result arity exactly `1`.
- The new summary fact is computed from the same live HOT node set before TO mutation.
- When the fact is false, there is no locally representable result-block copy group for that linker to add.
- Existing copy-group, scalar-forward, traffic, badness, and rewrite phases remain unchanged.

## Validation

- Focused red-first perf test after implementation: `1 / 1` passed.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`: `56 / 56` passed.
- `moon fmt && moon test src/passes`: format passed; `3611 / 3611` passed.
- `moon build --target native --release src/cmd`: passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct GenValid smoke:
  - command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-result-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - result: compared `1000 / 1000`, normalized `1000`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `1000 / 0`.
- Bounded dedicated profile:
  - command: `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-result-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - result: stopped at mismatch cap after `80 / 100`, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`; selected/profile labels spill `33`, tee `12`, copy-chain `35`; input effect/trap counts all zero.
  - agent classification: unchanged known simple type-indexed pure/drop-only scalar-spelling residual surface; not final closeout evidence.

## Performance evidence

Candidate-heavy timing command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-no-result-fast --timing-only --tuple-optimization
```

First run Starshine/Binaryen pass-local timings:

- 100 pairs: `0.324ms / 0.043ms`
- 500 pairs: `1.212ms / 0.168ms`
- 1000 pairs: `2.197ms / 0.299ms`
- 2000 pairs: `4.428ms / 0.786ms`

Spot reruns:

- 1000 pairs: `2.099ms / 0.285ms`, `2.522ms / 0.338ms`
- 2000 pairs: `4.496ms / 0.808ms`, `4.688ms / 0.878ms`

The 1000-pair detail trace `.tmp/to-passlocal-candidate-heavy-1000-20260629-no-result-fast/starshine.stderr.txt` records:

- `collect-seed-groups`: `0.384ms`
- `build-query-summary`: `0.341ms`
- `link-copy-groups`: `0.164ms`
- `link-result-block-copy-groups:no-single-result-block-fast-path`: `0.000ms`
- `link-scalar-forward-copy-groups`: `0.006ms`
- `precompute-drop-only-elision-mask`: `0.266ms`
- `rewrite-group-defs`: `0.319ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions`: `0.193ms`
- `cleanup-post-rewrite`: `0.211ms`
- `pass:tuple-optimization`: `2.197ms`

Interpretation: this reduces a small analysis/linking owner and improves the first 1000/2000-pair timings versus the preceding local-set-root-fast first run, but TO still misses the pass-local target (`starshine_time <= 2 * binaryen_time`). Remaining owners are seed collection, query-summary construction, copy-linking, drop-only precompute, targeted root cleanup, and untraced pass overhead.

## Remaining work

The TO audit remains open for:

- candidate-heavy pass-local performance target closure or explicit accepted exception with evidence
- broader type/lane-count/effect/non-drop residual triage
- exact-slot/neighborhood evidence
- full pass closeout ladder, including the required 100k/10k lanes
