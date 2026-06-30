# Tuple Optimization Root-Removal Performance Rejection

Date: 2026-06-29

## Question

Would removing simple pure drop-only source `local.set` roots directly, instead of replacing them with `nop` and relying on post-rewrite `prune-nops`, reduce `tuple-optimization` candidate-heavy pass-local time?

## Experiment

A red-first white-box probe was temporarily added for the existing simple two-lane type-indexed drop-only spill fixture. Before implementation it failed because `tuple_optimization_try_elide_simple_drop_only_source_group_defs(...)` left the root count at `4` by replacing the two source `local.set` roots with temporary `nop`s. A conservative implementation was then tested that:

- only handled the already-supported pure/drop-only source-group contract;
- only handled live `LocalSet` definitions, not `LocalTee` definitions;
- required all defining roots to be in the same region;
- first removed one root at a time, then a follow-up version removed each group's contiguous roots in one splice.

The experiment was reverted from the worktree because both variants regressed the candidate-heavy fixtures.

## Results

Baseline from the previous detached-delete slice:

| pairs | Starshine pass | Binaryen pass |
| ---: | ---: | ---: |
| 100 | 2.879ms | 0.032ms |
| 500 | 16.288ms | 0.147ms |
| 1000 | 45.108ms | 0.295ms |
| 2000 | 113.093ms | 0.770ms |

Per-root removal attempt:

| pairs | Starshine pass | Binaryen pass |
| ---: | ---: | ---: |
| 100 | 2.960ms | 0.039ms |
| 500 | 21.308ms | 0.154ms |
| 1000 | 51.267ms | 0.306ms |
| 2000 | 145.677ms | 1.012ms |

Per-group contiguous root-batch removal attempt:

| pairs | Starshine pass | Binaryen pass |
| ---: | ---: | ---: |
| 100 | 3.003ms | 0.038ms |
| 500 | 20.504ms | 0.180ms |
| 1000 | 53.376ms | 0.301ms |
| 2000 | 135.664ms | 0.630ms |

The batch variant did reduce `cleanup-post-rewrite:prune-nops` on the 1000-pair fixture to about `0.033ms`, but it moved the cost into `rewrite-group-defs:source`: the 1000-pair detail trace showed about `39.092ms` source rewrite time and `17.860ms` inside the root-removal subphase before the pass ended at `53.376ms`. This was worse than the detached-delete baseline (`rewrite-group-defs:source` about `24.081ms`, pass `45.108ms`).

## Interpretation

Per-group root splicing is a poor replacement for the current temporary-nop strategy on large same-region candidate-heavy functions. Even batched per group, root-vector shifts during rewrite dominate enough to erase the later `prune-nops` win.

The useful conclusion is negative: do not pursue per-group root removal as the next closeout fix. A viable root-removal direction would need a pass-level batch plan that collects all removable roots and rewrites each region once, or it should target the remaining `rewrite-group-defs:source`, `scalarized-tuple-locals`, and rewrite-time preparation costs without moving work into repeated root splices.

## Validation After Reverting The Experiment

The implementation experiment was not kept. After reverting it, the following checks passed:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'` — `1/1` passed.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` — `50/50` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-100-root-remove-rejected-baseline --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — compared `100/100`, normalized `100`, zero validation/generator/property/command failures, Binaryen cache `100/0`.

## Reopening Criteria

Revisit direct root removal only with a design that batches all same-region removals across the whole pass/function or otherwise proves it avoids repeated root-vector shifts. A future red-first test should require pass-level batching or a measured speed win, not merely absence of temporary `nop` roots in a per-group helper.
