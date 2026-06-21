---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/index.md
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
---

# HSO result-typed `try_table` descriptor `call_indirect` set-value fold

## Question

Does Binaryen `version_130` extend the descriptor result-typed `try_table` set-value fold from direct calls to catchable `call_indirect` bodies?

This follows `1005`, which fixed the direct-call descriptor positive, and keeps the descriptor result-wrapper audit narrow instead of inferring indirect-call behavior from direct-call behavior.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-desc-call-indirect-value.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-call-indirect-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-call-indirect-value.opt.wat
```

Result: Binaryen folds the later `i32.const 9` into the immutable-descriptor `struct.new_desc`, preserves the dropped result-typed `try_table`, preserves the catchable `call_indirect`, preserves the descriptor `global.get`, and removes the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization folds descriptor result try_table call_indirect set values`

Starshine already matched Binaryen after the `1005` implementation. The dropped result-typed wrapper can swap before the pure descriptor constructor when the constructor operands have no ordering conflict, and the catchable `call_indirect` remains preserved in the wrapper.

The test uses an AST-built descriptor/table fixture because the local WAT parser surface for exact descriptors is narrower than Binaryen's text parser in this shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'descriptor result try_table call_indirect set values'
```

Result: `376/376` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior positive, Starshine match. The descriptor result-typed `try_table` set-value fold covers catchable `call_indirect` in addition to the direct-call positive from `1005`; this note does not generalize to old-field side effects, tail calls, thrown/caught exits, same-effect stores, or mutable/effectful/trapping descriptor operands.

Reopen if Binaryen stops folding this indirect-call descriptor result-wrapper shape, if Starshine later preserves a redundant `struct.set` here, or if an adjacent descriptor result-wrapper family shows a different old-field, tail-call, catch, or descriptor-effect boundary.
