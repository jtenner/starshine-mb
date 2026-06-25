---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1118-2026-06-25-heap-store-optimization-default-chain-splice-trim.md
  - ./1116-2026-06-25-heap-store-optimization-performance-disposition.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO pure-default const value effect skip

## Question

Can the `1115`/`1118` pure-default fast path avoid another small slice of generic safety work while keeping its simple-value envelope exact?

## Failing target before the change

A traced 2000-function allocation-heavy run on top of `1118` still missed HSO-I before editing:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-iter2-slice-b-baseline.star.wasm
wasm-tools validate --features all .tmp/hso-iter2-slice-b-baseline.star.wasm
```

Result: Starshine HSO pass-local `8.115ms`, above the `<= 4.056ms` target implied by the latest Binaryen median (`2.028ms`).

## Change

The pure-default chain fast path now proves simple store values by checking that the value node is childless and has `Const` or `RefNull` op shape, instead of asking the generic effects summary for each value. Childless constants and `ref.null` nodes are intrinsically pure in HOT, so this preserves the same accepted value set while removing repeated effect-mask lookups in the synthetic allocation-heavy chain.

The fast path still rejects any value with children and any non-`Const`/`RefNull` op, and it still falls back to the general safety path for non-simple matching stores.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target-dir target --target native --release src/cmd
moon fmt
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-const-value-effect-skip-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- Focused HSO tests: `417/417` passed.
- Native `src/cmd` build: passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon fmt`: passed.
- 1000-case direct GenValid compare: `1000/1000` compared, `1000` normalized matches, `0` mismatches/failures, Binaryen cache `1000` hits / `0` misses.

## Allocation-heavy timing after the change

Three Starshine traced runs using the rebuilt native binary:

| Fixture | Samples | Median |
|---:|---:|---:|
| 1000 functions | `4.210ms`, `4.062ms`, `3.916ms` | `4.062ms` |
| 2000 functions | `8.114ms`, `8.108ms`, `7.980ms` | `8.108ms` |

This is a small improvement over `1118`'s 2000-function median (`8.384ms`) but not a structural closeout; HSO-I remains about `4.0x` Binaryen on the 2000-function fixture.

## Negative experiment during this slice

A broader attempt to use HOT op shape instead of effect masks for the pre-rewrite nested-region descent was rejected by focused tests. It made pure-looking `block` roots with branch-valued stores enter nested HSO processing and broke the disappearing-bad-get safety regressions. That experiment was reverted before this note's validation and reinforces why the current slice only skips effect lookup after the value is already proven childless `Const`/`RefNull`.
