---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1119-2026-06-25-heap-store-optimization-const-value-effect-skip.md
  - ./1118-2026-06-25-heap-store-optimization-default-chain-splice-trim.md
  - ./1117-2026-06-25-heap-store-optimization-closeout-deferral.md
  - ./1116-2026-06-25-heap-store-optimization-performance-disposition.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO post-1119 validation and performance refresh

## Question

After the `1118` and `1119` performance-only fast-path trims, is HSO ready for final HSO-J closeout?

## Answer

No. The correctness/compare evidence added in this slice is green, but HSO-I remains open. A fresh Binaryen timing refresh on the same 2000-function allocation-heavy fixture was faster than the prior `1111` Binaryen median, so the current ratio is worse than the already-open `1119` disposition.

HSO-J remains explicitly deferred until HSO-I is resolved, superseded with stronger artifact/neighborhood evidence and reopening criteria, or user-accepted.

## Commands and results

### Focused package validation

```sh
moon test src/passes
```

Result: `3045/3045` passed.

### Full Moon validation

```sh
moon test
```

Result: `6362/6362` passed.

### Direct GenValid compare after `1119`

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-post-1119-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `10000` hits / `0` misses.

### 2000-function allocation-heavy timing refresh

Fixture: `.tmp/hso-allocation-heavy-candidates-2000-20260625.wat`.

Starshine command shape:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-iter2-slice-c-star-2000.<n>.wasm
wasm-tools validate --features all .tmp/hso-iter2-slice-c-star-2000.<n>.wasm
```

Binaryen command shape:

```sh
wasm-opt --all-features --heap-store-optimization --debug \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-iter2-slice-c-bin-2000.<n>.wasm
wasm-tools validate --features all .tmp/hso-iter2-slice-c-bin-2000.<n>.wasm
```

Results:

| Tool | Samples | Median |
|---|---:|---:|
| Starshine HSO | `8.210ms`, `8.004ms`, `8.186ms` | `8.186ms` |
| Binaryen HSO | `1.2455ms`, `1.28922ms`, `1.49815ms` | `1.28922ms` |

The current target under the usual `starshine_time <= 2 * binaryen_time` rule is therefore `<= 2.57844ms` for this refreshed Binaryen run. Starshine remains about `6.35x` Binaryen on the fixture.

## Interpretation

The `1118`/`1119` changes did not introduce observed direct-compare drift and broader Moon validation stayed green. However, HSO-I cannot be closed on the existing allocation-heavy fixture. The refreshed Binaryen timing strengthens, rather than weakens, the performance blocker.

Next structural work should focus beyond the pure-default simple-value micro-path: per-function fixed costs, root-array/copy churn, type/module lookup churn, or a more direct complete-chain rewrite for all-fields default constructors. If a future slice proposes superseding this fixture, it must provide stronger artifact or O4z-neighborhood evidence plus explicit reopening criteria, per `1116`.
