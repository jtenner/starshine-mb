---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1127-2026-06-25-heap-store-optimization-local-attribution.md
  - ./1126-2026-06-25-heap-store-optimization-post-1125-rebuild-validation.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO known-length Array.make buffers

## Question

Can the HSO-I root-copy/chain-bookkeeping path improve by replacing capacity-plus-`push` buffers with `Array::make(..., 0)` and direct indexed writes for arrays whose final length is known?

## Answer

Slightly, in this local environment. This change is safe and compare-green, but it does not close HSO-I or supersede the best committed `1122` 2000-function median.

The kept implementation changes only arrays whose final length is known before filling:

- `hso_array_insert_prefix_roots(...)` suffix copy;
- `hso_tee_wrapped_struct_set(...)` replacement-root array;
- `hso_region_roots(...)` region root snapshot;
- the pure-default chain `children` array;
- nested-region `child_external_roots` construction.

Variable-length arrays, such as the general `next_roots` rebuilt region and fallback chain segment roots, still use capacity/push because their final length is not known without adding the rejected extra preflight from `1124`.

## Evidence

Focused tests:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `moon fmt` up to date; focused HSO tests `417/417` passed.

Native build:

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed, with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

Allocation-heavy fixture:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-sliceB-arraymake-2000.<n>.wasm
wasm-tools validate --features all .tmp/hso-sliceB-arraymake-2000.<n>.wasm
```

Samples: `8.494ms`, `9.709ms`, `10.010ms`, `8.762ms`, `8.814ms`; median `8.814ms`.

Same-thread comparison:

- Restored local baseline from `1127`: `9.605ms` median.
- Capacity-only trial before `Array::make`: `9.754ms` median.
- Kept `Array::make` implementation: `8.814ms` median.

This is a local improvement over the same-thread measurements, but it does not improve on the better committed `1122` reference median (`7.710ms`) or the post-rebuild `1126` median (`8.372ms`). Keep `1122` as the best reference until a future run beats it in a comparable environment.

Direct compare smoke:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-arraymake-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `1000` hits / `0` misses.

## Interpretation

`Array::make(..., 0)` helps enough to keep as a narrow allocation/copy cleanup for known-length buffers, and it avoids the rejected extra-preflight shapes from `1124`. However, HSO-I remains open: the 2000-function fixture target from `1120` is still `<=2.57844ms`, and this change remains far above that.

Next work should still target larger per-chain/HOT mutation costs rather than more tiny root-copy tweaks unless profiling shows another low-risk known-length array.
