# Heap-store-optimization post-1125 rebuild validation

## Question

After the reverted Slice A/B experiments, is the checked-in HSO source still aligned with the post-`1122` correctness baseline, and can HSO-J close?

## Answer

Correctness smoke remains green after rebuilding the native binary from the reverted source state, but HSO-J still cannot close because HSO-I remains unresolved. The refreshed local timing in this slice was noisier/slower than the committed `1122` best median, so it does not supersede `1122` as the best current performance result.

## Validation

Formatting:

```sh
moon fmt
```

Result: passed / up to date.

Focused HSO tests:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `417/417` passed.

Native rebuild:

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

Direct compare smoke:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-post-1125-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `1000` hits / `0` misses.

## Timing refresh

All emitted wasm files validated with `wasm-tools validate --features all`.

| Fixture | Samples | Median |
|---|---:|---:|
| 1000-function allocation-heavy | `4.603ms`, `4.104ms`, `4.275ms` | `4.275ms` |
| 2000-function allocation-heavy | `8.139ms`, `8.372ms`, `8.432ms` | `8.372ms` |

Interpretation:

- The checked-in source is back to the non-instrumented/non-experimental shape and direct compare is green.
- The local 2000-function timing median (`8.372ms`) is slower than the committed `1122` best median (`7.710ms`), likely reflecting local run noise and/or rebuild variation; it should not be treated as progress.
- Either value is still far above the `1120` Binaryen median `1.28922ms` and the `<=2.57844ms` target.

## HSO-J status

HSO-J remains explicitly deferred. Final closeout still requires an HSO-I decision first: meet the existing fixture target, supersede the fixture with stronger artifact/neighborhood evidence plus reopening criteria, or get explicit user acceptance for the measured gap. Only after that should the final validation/compare/O4z matrix be rerun and the backlog cleaned up.
