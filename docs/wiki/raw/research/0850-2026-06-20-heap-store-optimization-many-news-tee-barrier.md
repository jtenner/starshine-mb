---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../../src/passes/heap_store_optimization.mbt
  - ../../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` `$many-news` tee-chain barrier

Question: does Starshine match the Binaryen `version_130` lit `$many-news` family, where multiple independent tee-root constructor/store chains occur in the same function and inside an inner block?

## Answer

Not initially. A red-first focused fixture exposed a Starshine parity gap for the inner-block part of `$many-news`.

Binaryen optimizes tee-wrapped `struct.set` action roots before block-local chain swapping reaches the enclosing block. That means independent tee chains first become `local.set(struct.new ...)` roots, and Binaryen's existing constructor-ping-pong guard prevents one fresh-constructor chain from moving across another fresh-constructor chain.

Starshine's HOT region walker handled a tee-root and immediately continued the local-set chain scan over the original region root list. In the inner-block `$many-news` shape, the first local's chain could move across a later unprocessed tee-root for a different local, consuming that later tee-root as a safe blocker. That left the later chain partly unoptimized and produced `struct.set` remnants where Binaryen folds both independent chains.

The fix treats an unprocessed tee-wrapped `struct.set` root as a constructor local-set barrier for `hso_root_can_swap_before_local_struct_new(...)`. This mirrors Binaryen's action-order effect: tee roots are not generic reorderable blockers for another fresh-constructor chain.

## Evidence

Red-first command after adding the `$many-news` fixture:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Observed failure:

```text
Total tests: 203, passed: 202, failed: 1
```

The failing optimized body still contained `local.tee` / `struct.set` for the second inner-block chain after the first fresh constructor moved across it.

After implementation:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-many-news-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Observed results:

```text
moon info: passed with 3 existing warnings
moon fmt: passed
focused HSO tests: Total tests: 203, passed: 203, failed: 0
moon test src/passes: Total tests: 2831, passed: 2831, failed: 0
moon test: Total tests: 6144, passed: 6144, failed: 0
native src/cmd build: passed with existing warnings
compare: Compared cases: 10000/10000; Normalized matches: 10000; Mismatches: 0; Command failures: 0
```

Agent classification: the direct compare lane is behavior-parity green for this slice, with no residual mismatch family to classify.

## Files changed

- `src/passes/heap_store_optimization_test.mbt`
  - adds `heap-store-optimization folds Binaryen many-news independent chains`, covering the top-level multiple-news chain and the inner-block independent tee-chain family from Binaryen `version_130` lit.
- `src/passes/heap_store_optimization.mbt`
  - makes `hso_root_can_swap_before_local_struct_new(...)` reject unprocessed tee-wrapped `struct.set` blockers, preserving independent tee-chain processing order.

## Status

This closes the known `$many-news` lit-review gap in HSO-C. HSO-C still needs debris/output-shape classification before the broader HSO audit can close.
