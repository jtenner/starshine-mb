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

# HSO result-typed `try_table` descriptor `call_ref` set-value fold

## Question

Does Binaryen `version_130` extend the descriptor result-typed `try_table` set-value fold from direct and indirect calls to catchable typed-function-reference `call_ref` bodies?

This follows the direct-call positive in `1005` and the `call_indirect` counterpart in `1007`, keeping the descriptor result-wrapper audit specific to one call-family shape at a time.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-desc-call-ref-value.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-call-ref-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-call-ref-value.opt.wat
```

Result: Binaryen folds the later `i32.const 9` into the immutable-descriptor `struct.new_desc`, preserves the dropped result-typed `try_table`, preserves the catchable `call_ref`, preserves the descriptor `global.get`, and removes the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization folds descriptor result try_table call_ref set values`

Starshine already matched Binaryen after the `1005` implementation. The dropped result-typed wrapper can swap before the pure descriptor constructor when the constructor operands have no ordering conflict, and the catchable typed-function-reference call remains preserved in the wrapper.

The focused test uses an AST-built descriptor/call-ref fixture with a function-reference parameter because the local WAT parser surface for exact descriptors is narrower than Binaryen's text parser in this shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'descriptor result try_table call_ref set values'
```

Result: `377/377` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior positive, Starshine match. The descriptor result-typed `try_table` set-value fold covers catchable `call_ref` in addition to the direct-call and `call_indirect` positives; this note does not generalize to old-field side effects, tail calls, thrown/caught exits, same-effect stores, or mutable/effectful/trapping descriptor operands.

Reopen if Binaryen stops folding this typed-function-reference descriptor result-wrapper shape, if Starshine later preserves a redundant `struct.set` here, or if an adjacent descriptor result-wrapper family shows a different old-field, tail-call, catch, or descriptor-effect boundary.
