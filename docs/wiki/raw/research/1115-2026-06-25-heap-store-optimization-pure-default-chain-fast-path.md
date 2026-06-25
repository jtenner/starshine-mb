---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1114-2026-06-25-heap-store-optimization-post-safety-closeout-probe.md
  - ./1112-2026-06-25-heap-store-optimization-reorder-mask-fast-path.md
  - ./1111-2026-06-25-heap-store-optimization-post-refcast-performance.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO pure default chain fast path

## Question

Can HSO-I reduce allocation-heavy default-constructor chain overhead without changing the broader safety matrix?

## Baseline failure before the change

Before editing, the current native Starshine binary still missed the documented HSO-I pass-local target on the 2000-function allocation-heavy fixture:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-iter-baseline.star.wasm
wasm-tools validate --features all .tmp/hso-iter-baseline.star.wasm
```

Result: Starshine HSO pass-local total `11.228ms`. The latest Binaryen median for the same fixture remains `2.028ms` from `1111`, so this was still over the `starshine_time <= 2 * binaryen_time` target.

## Change

`hso_process_local_set_chain(...)` now has a narrow fast path for straight-line chains of at least two consecutive pure constant/null `struct.set` roots after a `local.set (struct.new_default ...)`:

- the constructor must be `struct.new_default` for the same type;
- every consumed store must target the same local/type and have a valid field index;
- every consumed value must be a childless `Const` or `RefNull` node whose effect mask is zero;
- the fast path stops only at a non-matching root; if a matching store has a non-simple value, it falls back to the existing general safety path;
- default field types are cached in `HsoTypeCache` so materialization does not resolve the same struct field list twice inside one function.

This deliberately does **not** widen behavior for branch/control values, calls, traps, descriptor operands, target-local reads, or other safety-family roots. The focused disappearing-bad-get branch-value regression remained green and caught an over-broad draft of this fast path before the final guard was narrowed.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt
moon build --target-dir target --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-pure-default-chain-1000 \
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
| 1000 functions | `4.780ms`, `4.244ms`, `4.285ms` | `4.285ms` |
| 2000 functions | `8.668ms`, `8.979ms`, `8.934ms` | `8.934ms` |

This is a real improvement over `1112`'s medians (`5.155ms` at 1000 functions and `11.083ms` at 2000 functions), but it still misses the HSO-I ratio target: `8.934ms / 2.028ms ~= 4.4x` Binaryen on the 2000-function fixture.

## Interpretation

The fast path removes repeated general safety bookkeeping for the synthetic pure-default chain that dominates the current allocation-heavy fixture, while leaving non-simple matching stores on the old path. It narrows HSO-I but does not close it. Remaining structural work likely needs to reduce per-function fixed costs, allocation/cache churn, or generic chain bookkeeping outside the pure constant/default subset.
