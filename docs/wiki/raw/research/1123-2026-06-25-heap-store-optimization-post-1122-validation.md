# Heap Store Optimization Post-1122 Validation

## Question

Do the `1121` lazy predicate-cache and `1122` complete-chain field-count changes move HSO closeout forward enough to unblock HSO-J?

## Answer

No. The post-`1122` correctness lane is green, but HSO-I remains open because the best current 2000-function allocation-heavy Starshine median is still `7.710ms`, about `5.98x` the `1120` refreshed Binaryen median (`1.28922ms`) and above the `<= 2.57844ms` target.

HSO-J remains deferred until HSO-I is resolved, superseded with stronger artifact/neighborhood evidence plus reopening criteria, or explicitly accepted by the user.

## Validation

```sh
moon test src/passes
```

Result: `3045/3045` passed.

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-post-1122-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `10000` hits / `0` misses.

## Rejected experiment

A trial change combined root copying with control-root collection in `hso_process_region(...)` to avoid a separate descent pre-scan on straight-line regions. It passed focused HSO tests and native build, but regressed the allocation-heavy fixture, so it was reverted before this note:

| Fixture | Samples | Median |
|---|---:|---:|
| 1000-function Starshine HSO with trial | `4.139ms`, `3.901ms`, `3.888ms` | `3.901ms` |
| 2000-function Starshine HSO with trial | `8.195ms`, `8.208ms`, `8.272ms` | `8.208ms` |

The likely cost was the extra control-index array allocation/management, which outweighed the avoided pass over roots for these tiny straight-line functions. Do not revive that exact shape as an HSO-I fix without a stronger proof or a no-allocation variant.

## Current HSO-I status after this slice

Current best Starshine allocation-heavy medians remain those from `1122`:

| Fixture | Starshine median | Binaryen median reference | Status |
|---|---:|---:|---|
| 1000-function allocation-heavy | `3.861ms` | not refreshed in `1120` | improved but not closing evidence |
| 2000-function allocation-heavy | `7.710ms` | `1.28922ms` from `1120` | open, about `5.98x` Binaryen |

The next high-leverage work should avoid per-root/per-function allocation rather than add another side array. Candidate directions: direct in-place region splicing for recognized complete pure-default chains, cheaper root sequence scanning that avoids `next_roots` construction when unchanged, or a stronger artifact/O4z-neighborhood performance argument with explicit reopening criteria.
