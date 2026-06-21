---
kind: research
status: supported
date: 2026-06-21
sources:
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/index.md
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# Heap-store-optimization call_indirect constructor growth boundary

## Question

How does Binaryen `version_130` treat a fresh `struct.new` whose overwritten constructor field is produced by `call_indirect`, when an unrelated `memory.grow` or `table.grow` root appears before the later `struct.set`?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture: `.tmp/hso-probe-call-indirect-constructor-growth.wat`.

Shape:

- allocate a fresh two-field struct into a local;
- field `0` is the result of `call_indirect`;
- run either `drop(memory.grow 1)` or `drop(table.grow null 1)`;
- write field `0` again with a later `struct.set`;
- read/drop the final value to keep the allocation observable.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-indirect-constructor-growth.wat \
  -S -o .tmp/hso-probe-call-indirect-constructor-growth.opt.wat && \
  grep -n "call_indirect\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-call-indirect-constructor-growth.opt.wat
```

Relevant oracle output kept `struct.new`, `call_indirect`, the growth root, and the later `struct.set` for both `memory.grow` and `table.grow` variants.

## Finding

Binaryen does **not** fold the later store into the constructor for this indirect-call constructor operand / growth-root shape. The `call_indirect` constructor operand remains ordered before the unrelated growth root, and the later `struct.set` remains after the growth root.

Starshine already matched this behavior. Focused coverage was added in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call_indirect constructor operands before unrelated growth roots`

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call_indirect'
```

Result: `297/297` tests passed.

No native rebuild or direct compare was required for this slice because it was coverage/classification only and made no implementation change.

## Scope impact

This narrows HSO-D/G for `call_indirect` constructor operands crossing unrelated growth roots. It complements the covered `call_indirect` constructor/old-field boundaries for unrelated `global.set`, `table.set`, and `i32.store`, but it does not close arbitrary indirect-call branch/catch roots, descriptor interactions, old-field growth-root variants, typed-function-reference `call_ref` growth-root variants, or all moved-value hazard combinations.
