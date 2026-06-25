---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1129-2026-06-25-heap-store-optimization-post-1128-validation.md
  - ./1128-2026-06-25-heap-store-optimization-array-make-known-length.md
  - ./1127-2026-06-25-heap-store-optimization-local-attribution.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO in-place heap mutation for pure default chains

## Question

Can HSO-I reduce the pure-default chain HOT mutation cost by mutating the existing `struct.new_default` heap node into `struct.new` in place, instead of building a temporary heap node, copying its payload, deleting it, and replacing the original node?

## Answer

Yes, enough to supersede the previous best committed 2000-function Starshine median, but not enough to close HSO-I.

The kept source change uses the existing public HOT mutation APIs for the narrow places where HSO changes a heap instruction and child span:

- `hso_try_fold_into_struct_new(...)` default-materialization path now calls `hot_node_exact_instr_set(...)` and `hot_replace_child_span(...)` instead of `hot_build_heap(...)`, `hot_delete_node(...)`, and `hot_replace_node(...)`.
- `hso_try_fold_pure_default_struct_set_chain(...)` does the same for the pure `struct.new_default` to `struct.new` chain path.

This avoids allocating and then deleting a temporary `Heap` node while keeping normal HOT side-table allocation for the new exact instruction payload and child span.

## TDD / target-first note

Before the edit, the local rebuilt baseline on `.tmp/hso-allocation-heavy-candidates-2000-20260625.wat` produced Starshine HSO samples `8.362ms`, `8.501ms`, and `8.341ms` (median `8.362ms`). That fails the current `1120` Binaryen-derived `<=2x` target of `<=2.57844ms` and was the red performance target for this slice.

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
  -o .tmp/hso-sliceA-inplace-2000.<n>.wasm
wasm-tools validate --features all .tmp/hso-sliceA-inplace-2000.<n>.wasm
```

Samples: `7.103ms`, `7.478ms`, `7.039ms`, `7.178ms`, `7.003ms`; median `7.103ms`.

This improves on the same-slice rebuilt baseline (`8.362ms`) and supersedes the previous best committed `1122` reference median (`7.710ms`). It is still about `5.51x` the refreshed Binaryen `1120` median (`1.28922ms`), so it does not satisfy the `<=2.57844ms` target.

Direct compare smoke:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-inplace-heap-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `1000` hits / `0` misses.

## Interpretation

The temporary node build/delete/replace sequence was measurable on the allocation-heavy lane. Replacing it with direct public mutation reduces HOT mutation overhead without changing HSO's safety envelope.

HSO-I remains open under `1116`: the current best committed Starshine 2000-function median is now `7.103ms`, still above the `<=2x` target. HSO-J final closeout remains deferred until HSO-I is resolved, superseded with stronger artifact/neighborhood evidence plus reopening criteria, or explicitly accepted by the user.
