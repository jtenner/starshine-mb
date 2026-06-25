---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1130-2026-06-25-heap-store-optimization-inplace-heap-mutation.md
  - ./1128-2026-06-25-heap-store-optimization-array-make-known-length.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO complete pure-default chain child-array reuse

## Question

Can the pure-default chain path avoid another known allocation/copy step when every field is overwritten?

## Answer

Slightly. The kept change tracks `missing_count` while scanning the pure `struct.new_default` plus consecutive childless constant/null `struct.set` chain. When every struct field has a replacement value, HSO now reuses the `replacements` array directly as the final `struct.new` child list instead of allocating a separate `children` array and copying all replacements into it.

Partial chains still allocate a separate `children` array and materialize defaults for the missing fields, preserving the existing safety and defaultability behavior.

## TDD / target-first note

After `1130`, the local 2000-function allocation-heavy median was `7.103ms`, still failing the `1120` Binaryen-derived `<=2x` target of `<=2.57844ms`. This was the red performance target for this slice.

## Evidence

Focused formatting/tests:

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
  -o .tmp/hso-sliceB-complete-children-2000.<n>.wasm
wasm-tools validate --features all .tmp/hso-sliceB-complete-children-2000.<n>.wasm
```

Samples: `6.867ms`, `7.396ms`, `6.908ms`, `7.010ms`, `6.972ms`; median `6.972ms`.

This narrowly improves on `1130` (`7.103ms`) and is now the best committed Starshine reference for this fixture. It is still about `5.41x` the refreshed Binaryen `1120` median (`1.28922ms`), so it does not satisfy the `<=2.57844ms` target.

Direct compare smoke:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-complete-children-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `1000` hits / `0` misses.

## Interpretation

The allocation-heavy fixture consists of complete three-field overwrite chains, so reusing the already-filled replacement array removes one predictable copy in the hot path. The win is real but small; HSO-I remains open under `1116`, and HSO-J remains deferred until HSO-I is resolved, superseded with stronger evidence plus reopening criteria, or explicitly accepted by the user.
