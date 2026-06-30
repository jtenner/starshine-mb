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

# Tuple Optimization Root-Slot Lookup Performance Slice

## Question

The prior TO performance-attribution slice showed candidate-heavy synthetic fixtures dominated by `detail:tuple-optimization:rewrite-group-defs`. This slice tested a localized hypothesis: repeated full-function root-slot discovery during group-definition rewriting is one measurable contributor.

## Change

`tuple_optimization_find_root_slot_with_use_def(...)` now uses the pre-rewrite use-def root-use owner to restrict lookup to the containing region instead of recursively searching the whole function from the root for every target. It still verifies the current slot by scanning the owning region, so stale use-def slot numbers remain safe after earlier prefix insertions shift roots. The region scan starts at the stale use-def slot and wraps around, which favors the common case where inserted prefixes move targets forward from their original slots.

Call sites in the TO analysis/rewrite path now use the use-def-aware helper for root host lanes, no-host carrier lanes, anchor selection, result-block copy discovery, and root copy/source rewrites. The old full recursive lookup remains as a fallback.

A red-first white-box guard was added:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*root-slot use-def lookup*'
```

It failed before the helper existed, then passed after the helper was implemented. The guard proves stale use-def root metadata can still find a root whose slot shifted after an insertion.

## Candidate-Heavy Measurement

Commands after rebuilding `_build/native/release/build/cmd/cmd.exe`:

```sh
moon build --target native --release src/cmd
for n in 100 500 1000; do
  bun scripts/self-optimize-compare.ts \
    .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-root-slot-hint \
    --timing-only \
    --tuple-optimization
done
```

Results versus the prior detail-timer baseline:

| Pairs | Prior Starshine/Binaryen pass | New Starshine/Binaryen pass | Prior `rewrite-group-defs` | New `rewrite-group-defs` | Notes |
| ---: | ---: | ---: | ---: | ---: | --- |
| 100 | `4.132ms / 0.047ms` | `2.944ms / 0.047ms` | `3.057ms` | `2.070ms` | cleanup `0.408ms`, use-def build `0.257ms`, ensure splits `0.032ms` |
| 500 | `41.643ms / 0.183ms` | `31.320ms / 0.144ms` | `31.378ms` | `23.919ms` | cleanup `4.690ms`, use-def build `1.551ms`, ensure splits `0.454ms` |
| 1000 | `153.200ms / 0.310ms` | `116.342ms / 0.369ms` | `118.803ms` | `92.264ms` | cleanup `16.212ms`, use-def build `4.260ms`, ensure splits `1.799ms` |

An initial post-helper run without the stale-slot hint also improved 500/1000 but less consistently: `3.970ms`, `36.403ms`, and `128.329ms` Starshine pass time for 100/500/1000. The stale-slot start hint supersedes that intermediate measurement for this slice.

The `2000` fixture was not rerun because `.tmp/to-perf/tuple-candidate-heavy-2000.wasm` was absent in this workspace during the loop. Regenerate it before using a 2000-pair datapoint for the final performance trend.

## Correctness Checks

- Red-first focused helper guard failed before implementation because `tuple_optimization_find_root_slot_with_use_def` was unbound.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*root-slot use-def lookup*'` => `1 / 1` passed after implementation.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` => `50 / 50` passed.
- `moon test src/passes` => `3605 / 3605` passed.
- `moon build --target native --release src/cmd` => completed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-root-slot-hint --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` => `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, Binaryen cache `100 / 900`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-root-slot-hint --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` => stopped at mismatch cap after `65 / 100` compared, zero failures, `65` raw mismatches, selected profiles spill `26`, tee `10`, copy-chain `29`, profile labels spill `26`, tee `10`, copy-chain `29`. This remains the known dedicated-profile raw-red scalar-spelling surface; no new semantic classification is claimed here.
- `moon fmt` and `git diff --check` completed cleanly.

## Interpretation

The use-def-bounded root-slot lookup is a safe localized speed win and reduces the 1000-pair candidate-heavy Starshine pass time by about 24% versus the detail baseline (`153.200ms -> 116.342ms`). It does not close the performance blocker: Starshine remains hundreds of times slower than Binaryen pass-local time on this synthetic surface, and `rewrite-group-defs` is still dominant.

The remaining likely owners are repeated root-region insertions/replacements and post-rewrite cleanup over the enlarged root list. The next slice should profile or reduce per-group insertion/mutation work, ideally by batching root-prefix insertions or replacing simple root no-host carrier patterns without repeated root-array splicing, while preserving the existing narrow scalar-spelling classification.

## Remaining Work

- Continue performance work inside `rewrite-group-defs`; root-slot lookup is improved but not the main remaining cost.
- Rebuild or regenerate the missing 2000-pair candidate-heavy fixture before reporting a full 100/500/1000/2000 trend.
- Keep the dedicated profile raw-red classification narrow until broader type/lane/effect/non-drop surfaces are inspected or reduced.
- Final TO audit closeout still needs exact-slot/neighborhood evidence and the full required 100k/10k lanes.
