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

# HSO result-typed `try_table` descriptor `call_indirect` old-field boundary

## Question

Does Binaryen `version_130` preserve a descriptor constructor and later `struct.set` across a dropped result-typed `try_table` when both the overwritten constructor field and wrapper body use catchable `call_indirect`?

This complements `1007`: the `call_indirect` set-value shape folds, but an overwritten old field with indirect-call side effects should remain ordered before the wrapper and later store.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-desc-call-indirect-old-field.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-call-indirect-old-field.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-call-indirect-old-field.opt.wat
```

Result: Binaryen preserves the descriptor `struct.new_desc` with its overwritten `call_indirect` field, preserves the dropped result-typed `try_table`, preserves the catchable wrapper `call_indirect`, preserves the immutable descriptor `global.get`, and keeps the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps descriptor result try_table call_indirect old fields`

Starshine already matched Binaryen after `1005`. The descriptor result-wrapper fold remains blocked when an overwritten old field has indirect-call side effects, so the old-field `call_indirect` and later `struct.set` remain intact while the wrapper call is preserved.

The test uses an AST-built descriptor/table fixture because the local WAT parser surface for exact descriptors is narrower than Binaryen's text parser in this shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'descriptor result try_table call_indirect old fields'
```

Result: `378/378` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. The descriptor result-typed `try_table` `call_indirect` set-value positive from `1007` does not extend to overwritten old fields with indirect-call side effects.

Reopen if Binaryen starts folding this old-field descriptor result-wrapper shape, if Starshine later treats old-field `call_indirect` as reorderable across catchable result wrappers, or if another descriptor old-field result-wrapper family shows different direct-call, indirect-call, typed-function-reference, tail-call, catch, or descriptor-effect behavior.
