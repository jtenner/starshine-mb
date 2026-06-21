---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
---

# `heap-store-optimization` descriptor target-local hazard

Question: does Binaryen `version_130` keep the target-local hazard even when the constructor is a descriptor form?

## Answer

Yes. A local `wasm-opt version 130 (version_130)` probe with `struct.new_desc` followed by a `struct.set` whose moved value reads the target local preserves the `struct.set`. The descriptor operand does not relax the core target-local hazard: moving the value into the constructor would read the local before the fresh struct assignment.

Starshine already matched this shape. This was a coverage-only HSO-E slice; no implementation behavior changed, and no native rebuild or direct compare was required.

## Probe command

```sh
wasm-opt .tmp/hso-probe-desc-target-local-read.wat --heap-store-optimization -all -S -o -
```

Observed behavior:

- Binaryen preserved `struct.new_desc` with its original field operands and descriptor operand.
- Binaryen preserved the later `struct.set $pair 0` whose value block performs `drop(local.get $p)` before producing `i32.const 9`.

## Starshine test

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps descriptor store when moved value reads target local`

Focused validation:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 211, passed: 211, failed: 0.
```

## Backlog impact

This narrows HSO-E by covering a descriptor-constructor variant of the moved-value target-local read hazard. HSO-E remains open for descriptor/later-field hazard combinations beyond this direct target-local read case and any moved-value hazard variants not already covered by `0854`, `0855`, and this note.
