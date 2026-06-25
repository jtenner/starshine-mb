---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1111-2026-06-25-heap-store-optimization-post-refcast-performance.md
  - ./1092-2026-06-25-heap-store-optimization-simple-skip-fast-path.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO reorder-mask fast path probe

## Question

Can HSO-I reduce allocation-heavy candidate-chain overhead by avoiding generic reorder predicate walks when both sides of a reorder check are known, from their effect summaries, to have no relevant control or global state?

## Change

`hso_nodes_can_reorder(...)` now uses two narrow fast paths:

- It only walks `hso_subtree_global_order_conflicts(...)` when at least one node's effect summary includes `EFFECT_MASK_GLOBAL_STATE`.
- It only asks `hso_subtree_may_skip_local_set(...)` for a node when that node's effect summary includes `EFFECT_MASK_CONTROL`; otherwise the raw effect mask is already the reorder mask.

This mirrors the earlier `1092` simple-value skip fast path in `hso_reorder_effect_mask(...)`. It is intended as a performance-only cleanup: control-carrying, global-touching, trap/call/throw, and local-state nodes still take the existing safety checks.

## Baseline failure before the change

Before editing, the current rebuilt native binary still missed the allocation-heavy HSO-I target on the 2000-function fixture:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-slice-a-baseline.star.wasm
wasm-tools validate --features all .tmp/hso-slice-a-baseline.star.wasm
```

Result: Starshine HSO pass-local total `10.741ms` for the fixture. This remains above the documented `<=2x Binaryen` target from `1111` (`2.028ms` Binaryen median for the same fixture).

## Validation after the change

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt
moon build --target-dir target --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-reorder-mask-fast-path-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- Focused HSO tests: `417/417` passed.
- `moon fmt`: passed.
- Native `src/cmd` build: passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- 1000-case direct GenValid compare: `1000/1000` compared, `1000` normalized matches, `0` mismatches/failures, Binaryen cache `1000` hits / `0` misses.

## Allocation-heavy timing after the change

Three Starshine traced runs using the rebuilt native binary:

| Fixture | Samples | Median |
|---:|---:|---:|
| 1000 functions | `4.939ms`, `5.268ms`, `5.155ms` | `5.155ms` |
| 2000 functions | `10.691ms`, `11.213ms`, `11.083ms` | `11.083ms` |

The 1000-function fixture improved relative to `1111` (`5.465ms` median), but the 2000-function fixture stayed noise-flat/slightly worse relative to `1111` (`10.765ms` median). HSO-I therefore remains open.

## Interpretation

The change removes unnecessary safety-predicate recursion for effect summaries that already prove no control or global interaction. It is correctness-preserving and slightly helps the smaller allocation-heavy fixture, but it does not structurally close the 2000-function candidate-chain slowdown. Further work should focus on larger per-function fixed costs, module/type cache reuse opportunities, or reducing repeated candidate-chain bookkeeping rather than expecting this mask fast path to close HSO-I by itself.
