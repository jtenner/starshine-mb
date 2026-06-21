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

# Heap-store-optimization call constructor growth boundary

## Question

How does Binaryen `version_130` treat a fresh `struct.new` whose overwritten constructor field is produced by an ordinary direct `call`, when an unrelated `memory.grow` or `table.grow` root appears before the later `struct.set`?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture: `.tmp/hso-probe-call-constructor-growth.wat`.

Shape:

- allocate a fresh two-field struct into a local;
- field `0` is the result of direct `call $helper`;
- run either `drop(memory.grow 1)` or `drop(table.grow null 1)`;
- write field `0` again with a later `struct.set`;
- read/drop the final value to keep the allocation observable.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-constructor-growth.wat \
  -S -o .tmp/hso-probe-call-constructor-growth.opt.wat && \
  grep -n "call\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-call-constructor-growth.opt.wat
```

Relevant oracle output kept `struct.new`, the direct `call`, the growth root, and the later `struct.set` for both `memory.grow` and `table.grow` variants.

## Finding

Binaryen does **not** fold the later store into the constructor for this direct-call constructor operand / growth-root shape. The call-valued constructor operand remains ordered before the unrelated growth root, and the later `struct.set` remains after the growth root.

Starshine already matched this behavior. Focused coverage was added in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call constructor operands before unrelated growth roots`

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'growth roots'
```

Result: `296/296` tests passed.

No native rebuild or direct compare was required for this slice because it was coverage/classification only and made no implementation change.

## Scope impact

This narrows HSO-D/G for ordinary direct-call constructor operands crossing unrelated growth roots. It complements the previous direct-call constructor boundaries for unrelated `global.set`, `i32.store`, and `table.set`, but it does not close arbitrary call-bearing control roots, descriptor interactions, old-field combinations, or all typed-function-reference / indirect-call growth-root variants.
