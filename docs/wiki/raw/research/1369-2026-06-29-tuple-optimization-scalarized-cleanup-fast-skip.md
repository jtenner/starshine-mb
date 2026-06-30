# Tuple Optimization Scalarized Cleanup Fast-Skip

Date: 2026-06-29

## Question

Can `tuple-optimization` avoid rebuilding use-def data and scanning every local in the post-rewrite scalarized tuple-local cleanup when the rewrite only performed the current simple pure/drop-only source elision and therefore left no `local.set (tuple.make ...)` cleanup candidates?

## Change

Added a cheap live-node pre-scan to `tuple_optimization_cleanup_scalarized_tuple_locals(...)`. The cleanup now:

1. scans for a live `LocalSet` whose single live child is a live `TupleMake` with arity greater than one;
2. returns immediately when no such candidate exists;
3. builds use-def only after the pre-scan finds a possible scalarized tuple-local cleanup candidate.

This is a performance-only fast path. It does not change the cleanup's positive candidate contract: the full use-def-based rewrite still handles the existing `local.set tuple.make(local.get ...)` / `tuple.extract(local.get ...)` form when the pre-scan finds a candidate.

## Red-First Coverage

A new white-box performance invariant test, `tuple-optimization scalarized tuple-local cleanup fast-skips pure drop-only elision`, was added for the current simple two-lane type-indexed pure/drop-only elision fixture. Before implementation it failed because the expected `scalarized-tuple-locals:pre-scan` timer did not exist. After implementation it passes and confirms that the pure/drop-only fixture records the pre-scan timer but does not record `scalarized-tuple-locals:use-def-build`.

## Performance Results

The first full 100/500/1000/2000 timing loop was noisy at 500/1000, so the rerun numbers below are the cleaner representative timings for this slice. They should be compared against the previous kept detached-delete baseline in [`1367`](./1367-2026-06-29-tuple-optimization-detached-delete-performance.md): 500/1000/2000 Starshine pass times `16.288ms`, `45.108ms`, and `113.093ms` versus Binaryen `0.147ms`, `0.295ms`, and `0.770ms`.

Rerun after the fast-skip:

| pairs | Starshine pass | Binaryen pass |
| ---: | ---: | ---: |
| 100 | 2.766ms | 0.041ms |
| 500 | 17.776ms | 0.162ms |
| 1000 | 36.571ms | 0.318ms |
| 2000 | 100.860ms | 0.879ms |

Detail timers from the same rerun show the intended cleanup effect:

| pairs | scalarized tuple-local cleanup | notes |
| ---: | ---: | --- |
| 100 | ~0.012ms in the first loop | pre-scan only, no cleanup use-def build |
| 500 | ~0.036ms in the first loop | pre-scan only, no cleanup use-def build |
| 1000 | ~0.080ms in the first loop | pre-scan only, no cleanup use-def build |
| 2000 | ~0.100ms in the first loop | pre-scan only, no cleanup use-def build |

This directly removes the previous scalarized tuple-local cleanup owner from the pure/drop-only candidate-heavy fixture; earlier detached-delete detail timers reported that phase at about `3.467ms` for 1000 pairs and `11.693ms` for 2000 pairs. The pass is still far outside the project pass-local target because remaining time is dominated by `rewrite-group-defs:source`, `prune-nops`, rewrite-time `use_def` construction, and split-local preparation.

## Validation

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*scalarized tuple-local cleanup fast-skips*'` failed before implementation, then passed `1/1` after the fast path.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` — passed `51/51`.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Candidate-heavy timings were refreshed with `bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-scalarized-cleanup-fast-skip[-rerun] --timing-only --tuple-optimization` for `n = 100, 500, 1000, 2000`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-scalarized-cleanup-fast-skip --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — compared `1000/1000`, normalized `1000`, zero validation/generator/property/command failures, Binaryen cache `1000/0`.
- `moon fmt && moon test src/passes` — passed; `src/passes` reported `3606/3606`.

## Interpretation And Next Work

The fast-skip is a kept improvement because it removes a cleanup phase that is provably irrelevant for the current pure/drop-only elision path, and it is guarded by a pre-scan that is strictly broader than the existing positive cleanup predicate. It is not a TO closeout: candidate-heavy pass-local timing remains roughly two orders of magnitude slower than Binaryen on larger fixtures.

Next performance work should target a pass-level region/nop rewrite strategy or the repeated rewrite-source preparation costs. The previous per-group root-removal experiment in [`1368`](./1368-2026-06-29-tuple-optimization-root-removal-rejected.md) remains rejected; do not reintroduce repeated per-group root splicing.
