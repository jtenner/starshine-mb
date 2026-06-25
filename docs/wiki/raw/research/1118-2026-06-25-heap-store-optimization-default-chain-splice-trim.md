---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1117-2026-06-25-heap-store-optimization-closeout-deferral.md
  - ./1116-2026-06-25-heap-store-optimization-performance-disposition.md
  - ./1115-2026-06-25-heap-store-optimization-pure-default-chain-fast-path.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO default-chain splice trim

## Question

Can the `1115` pure-default chain fast path remove extra per-store work without changing its narrow safety envelope?

## Failing target before the change

A fresh traced 2000-function allocation-heavy run before editing still missed HSO-I:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-iter2-slice-a-baseline.star.wasm
wasm-tools validate --features all .tmp/hso-iter2-slice-a-baseline.star.wasm
```

Result: Starshine HSO pass-local `8.912ms`, still above the `<= 2 * 2.028ms` target from the latest Binaryen median in `1111`.

## Change

The narrow pure `struct.new_default` chain fast path now removes the consumed `struct.set` roots from the rewritten region instead of replacing each consumed set with a freshly built `nop` root. The folded values are already moved into the replacement `struct.new`, the consumed stores are void roots, and the fast path is still limited to consecutive same-local/same-type stores with childless `Const` or `RefNull` values and zero effect mask.

This is performance-only: it does not widen matching to calls, traps, branch/control values, descriptor operands, target-local reads, or non-simple store values. Non-simple matching stores still fall back to the existing general safety path.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target-dir target --target native --release src/cmd
moon fmt
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-no-nop-default-chain-1000 \
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
| 1000 functions | `4.065ms`, `4.069ms`, `4.125ms` | `4.069ms` |
| 2000 functions | `8.282ms`, `8.384ms`, `8.417ms` | `8.384ms` |

This trims the `1115` medians (`4.285ms` at 1000 functions and `8.934ms` at 2000 functions) but still misses HSO-I: `8.384ms / 2.028ms ~= 4.1x` Binaryen on the 2000-function fixture.

## Interpretation

Avoiding generated `nop` roots removes some per-store allocation/lowering churn from the fixture's dominant pure-default chain. The improvement is real but small; HSO-I remains open under the `1116` disposition until the `<=2x` target is met, superseded with stronger evidence and reopening criteria, or explicitly accepted by the user.
