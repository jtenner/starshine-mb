---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1128-2026-06-25-heap-store-optimization-array-make-known-length.md
  - ./1127-2026-06-25-heap-store-optimization-local-attribution.md
  - ./1116-2026-06-25-heap-store-optimization-performance-disposition.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO post-1128 validation

## Question

After keeping the `1128` known-length `Array::make(..., 0)` buffer cleanup, can HSO-J final closeout proceed?

## Answer

No. The post-change focused package and direct compare evidence is green, but HSO-I remains open. The `1128` implementation improved over this thread's same-environment restored baseline, but it did not beat the best committed `1122` 2000-function median (`7.710ms`) and remains far above the `1120` refreshed Binaryen `<=2x` target (`<=2.57844ms`).

Therefore HSO-J remains explicitly deferred under the `1116` disposition: resolve HSO-I by meeting the fixture target, superseding the fixture with stronger artifact/neighborhood evidence and reopening criteria, or getting explicit user approval to carry the measured gap.

## Commands and results

### Pass package validation

```sh
moon test src/passes
```

Result: `3045/3045` passed.

### Direct GenValid compare after `1128`

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-post-1128-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, `0` command failures, Binaryen cache `10000` hits / `0` misses.

## Current closeout status

- HSO-C through HSO-H remain closed/narrow-covered by the safety-family audit through `1113`, with exact descriptor `ref.cast` closed by `1109`.
- HSO-B baseline/direct/O4z evidence remains current through `1114`, `1123`, and `1126`, but final publication still belongs to HSO-J.
- HSO-I remains the active blocker. Current best committed Starshine 2000-function median is still `7.710ms` from `1122`; the `1128` local median was `8.814ms` and does not supersede it.
- HSO-J remains open for the final focused/full validation, native rebuild, full four-lane compare matrix, O4z replay, docs/wiki/log updates, and backlog cleanup after the HSO-I decision.

## Recommended next work

The next implementation should target a larger per-chain or HOT mutation cost, not another tiny array-copy tweak unless profiling identifies one. Candidate directions:

- mutate a consecutive pure-default chain with one range splice instead of rebuilding and comparing the entire root snapshot;
- reduce per-function HOT replacement/revision churn inside the complete-chain path;
- inspect whether `hot_build_heap` + `hot_delete_node` + `hot_replace_node` can be replaced by a narrower public helper that swaps the heap instruction/children in place for this exact case;
- if no safe implementation fits a bounded slice, gather stronger artifact/neighborhood timing evidence and decide whether the synthetic fixture should be superseded under `1116`.
