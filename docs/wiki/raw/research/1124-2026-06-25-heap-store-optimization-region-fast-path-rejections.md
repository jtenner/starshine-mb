# Heap-store-optimization region fast-path rejections

## Question

Can HSO-I improve by avoiding root-copy/segment-array churn around the allocation-heavy pure-default fixture after `1122`?

## Answer

Not with the trial shapes tested here. Both experiments preserved focused behavior locally, but neither improved the 2000-function allocation-heavy timing enough to commit as an implementation change:

1. a no-control region preflight plus in-place pure-default rewrite, and
2. a narrower direct-call path that reused complete-chain replacement arrays and avoided the direct `segment_roots` return allocation.

Both were reverted before this note. HSO-I remains open at the committed `1122` best current 2000-function median of `7.710ms` against the `1120` Binaryen median of `1.28922ms` (`<=2.57844ms` target).

## Baseline target

Local pre-experiment samples on `.tmp/hso-allocation-heavy-candidates-2000-20260625.wat` using the existing native binary:

| Sample | Starshine HSO total |
|---:|---:|
| 1 | `8.068ms` |
| 2 | `8.706ms` |
| 3 | `8.023ms` |

Local median: `8.068ms`. This reproduces the open performance blocker and is still far above the `<=2.57844ms` target derived from `1120`.

## Rejected experiment A: no-control region in-place rewrite

Trial shape:

- Pre-scanned each no-control region to ensure every direct `local.set(struct.new_default)` HSO candidate was a complete pure-default overwrite chain.
- Rewrote matching chains in-place by replacing the original `struct.new_default` node with `struct.new` and removing the consumed `struct.set` roots with `hot_region_remove(...)`.
- Fell back to the existing generic path for any control root, tee-wrapped heap candidate, non-default constructor, partial chain, non-simple value, or uncovered root shape.

Focused behavior check:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `417/417` passed.

Native build:

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

Timing result:

| Fixture | Samples | Median | Disposition |
|---|---:|---:|---|
| 1000-function allocation-heavy | `4.268ms`, `4.158ms`, `4.256ms` | `4.256ms` | worse than `1122` (`3.861ms`) |
| 2000-function allocation-heavy | `8.905ms`, `8.620ms`, `8.561ms` | `8.620ms` | worse than `1122` (`7.710ms`) |

Interpretation: the extra preflight scans and `hot_region_remove(...)` shifting outweighed any avoided root-copy or `next_roots` construction on the tiny five-root functions.

## Rejected experiment B: direct complete-chain return path

Trial shape:

- Reused the complete-chain `replacements` array as the `struct.new` children when every field was overwritten, avoiding the extra child array build.
- Changed the pure-default helper to return only `next_idx`, and taught the direct `LocalSet` root branch in `hso_process_region(...)` to push `root_id` directly instead of returning a one-element `segment_roots` array through `hso_process_local_set_chain(...)`.
- Left the general `hso_process_local_set_chain(...)` path available for tee-derived chains and non-fast fallback.

Focused behavior check and native build were the same as experiment A and passed.

Timing result:

| Fixture | Samples | Median | Disposition |
|---|---:|---:|---|
| 1000-function allocation-heavy | `4.048ms`, `3.919ms`, `4.296ms` | `4.048ms` | worse than `1122` (`3.861ms`) |
| 2000-function allocation-heavy | `8.267ms`, `8.542ms`, `8.938ms` | `8.542ms` | worse than `1122` (`7.710ms`) |

Interpretation: the direct return/array-reuse micro-path was too small to overcome noise or may have harmed native code shape. It should not be revived without fresh profiling evidence.

## Current status

- No source changes from these experiments were kept.
- HSO correctness evidence remains the committed post-`1122` state from `1123`.
- HSO-I remains unresolved.
- HSO-J remains deferred until HSO-I is resolved, superseded with stronger artifact/neighborhood evidence plus reopening criteria, or explicitly accepted by the user.

## Next candidates

Avoid repeating the rejected in-place/preflight and direct-return shapes. More promising next probes:

- subphase instrumentation inside `hso_process_region(...)` / pure-default fast path to attribute the remaining linear cost before another structural change;
- eliminate or amortize `hso_region_roots(...)` / `next_roots` only with a no-extra-preflight design;
- investigate whether HOT root splicing or per-function analysis setup dominates the tiny-function fixture;
- measure a stronger artifact/O4z-neighborhood performance lane if the synthetic fixture is no longer representative, with explicit reopening criteria.
