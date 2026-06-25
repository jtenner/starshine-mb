# Heap Store Optimization Lazy Predicate Cache

## Question

Can HSO-I allocation-heavy runtime improve by avoiding per-function predicate-cache allocation when the pure-default chain fast path handles the whole straight-line function?

## Change

`src/passes/heap_store_optimization.mbt` now initializes `HsoPredicateCache` lazily:

- `readonly_revision` and `skip_revision` start as empty arrays.
- `readonly_result` and `skip_result` start as zero-length bitsets.
- The existing `hso_ensure_predicate_cache_capacity(...)` growth path remains responsible for allocating predicate state when a predicate walk actually queries a node.

This is performance-only. The pass behavior and safety predicates are unchanged. The allocation-heavy fixture's pure-default fast path does not need the predicate cache, so preallocating two revision arrays and two bitsets for every tiny function was unnecessary churn.

## Evidence

Baseline before the edit on `.tmp/hso-allocation-heavy-candidates-2000-20260625.wat` using the existing native binary:

| Tool | Samples | Median |
|---|---:|---:|
| Starshine HSO before change | `8.450ms`, `8.067ms`, `8.305ms` | `8.305ms` |

Post-change validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `417/417` passed.

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

```sh
moon fmt
```

Result: passed.

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-lazy-predicate-cache-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `1000` hits / `0` misses.

Post-change allocation-heavy timing:

| Fixture | Samples | Median |
|---|---:|---:|
| 1000-function Starshine HSO | `3.935ms`, `4.099ms`, `3.986ms` | `3.986ms` |
| 2000-function Starshine HSO | `7.985ms`, `7.935ms`, `7.999ms` | `7.985ms` |

Using the `1120` refreshed Binaryen 2000-function median (`1.28922ms`), this is still about `6.19x` Binaryen and above the `<= 2.57844ms` target. HSO-I remains open.

## Interpretation

The lazy predicate-cache change removes unnecessary per-function allocation for the current pure-default fixture and gives a small 2000-function median improvement (`8.186ms` post-`1119` / `8.305ms` local pre-change to `7.985ms`). It is not enough to change the HSO-I disposition. Further work should target the larger remaining fixed per-function/root churn, especially region-root copying and pure-default chain rewrite overhead.
