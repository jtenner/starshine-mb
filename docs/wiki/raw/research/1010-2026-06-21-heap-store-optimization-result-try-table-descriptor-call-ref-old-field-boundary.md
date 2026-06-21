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

# HSO result-typed `try_table` descriptor `call_ref` old-field boundary

## Question

Does Binaryen `version_130` preserve a descriptor constructor and later `struct.set` across a dropped result-typed `try_table` when both the overwritten constructor field and wrapper body use catchable `call_ref`?

This complements `1008`: the `call_ref` set-value shape folds, but an overwritten old field with typed-function-reference call side effects should remain ordered before the wrapper and later store.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-desc-call-ref-old-field.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-call-ref-old-field.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-call-ref-old-field.opt.wat
```

Result: Binaryen preserves the descriptor `struct.new_desc` with its overwritten `call_ref` field, preserves the dropped result-typed `try_table`, preserves the catchable wrapper `call_ref`, preserves the immutable descriptor `global.get`, and keeps the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps descriptor result try_table call_ref old fields`

Starshine already matched Binaryen after `1005`. The descriptor result-wrapper fold remains blocked when an overwritten old field has typed-function-reference call side effects, so the old-field `call_ref` and later `struct.set` remain intact while the wrapper call is preserved.

The test uses an AST-built descriptor/call-ref fixture because the local WAT parser surface for exact descriptors is narrower than Binaryen's text parser in this shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'descriptor result try_table call_ref old fields'
```

Result: `379/379` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. The descriptor result-typed `try_table` `call_ref` set-value positive from `1008` does not extend to overwritten old fields with typed-function-reference call side effects.

Reopen if Binaryen starts folding this old-field descriptor result-wrapper shape, if Starshine later treats old-field `call_ref` as reorderable across catchable result wrappers, or if another descriptor old-field result-wrapper family shows different direct-call, indirect-call, typed-function-reference, tail-call, catch, or descriptor-effect behavior.
