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

# HSO result-typed `try_table` descriptor call old-field boundary

## Question

Does Binaryen `version_130` still fold a descriptor constructor across a dropped result-typed `try_table` direct call when the overwritten constructor field also has a direct-call side effect?

This complements `1005`: the set-value shape folds, but an overwritten old field with a call must remain ordered before the result wrapper and later store.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-desc-call-old-field.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-call-old-field.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-call-old-field.opt.wat
```

Result: Binaryen preserves the descriptor `struct.new_desc` with its overwritten direct-call field, the dropped result-typed `try_table`, the catchable direct call in the wrapper, the immutable descriptor `global.get`, and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps descriptor result try_table call old fields`

Starshine already matched Binaryen after `1005`: the new dropped-result-wrapper swap is blocked when the constructor operands themselves have an ordering conflict with the wrapper call, so the old-field direct call and later `struct.set` remain intact.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'descriptor result try_table call old fields'
```

Result: `375/375` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. The result-typed descriptor direct-call set-value positive from `1005` does not extend to overwritten old fields with direct-call side effects.

Reopen if Binaryen starts folding this old-field descriptor result-wrapper shape, if Starshine later treats old-field calls as reorderable across catchable result wrappers, or if direct compare exposes another descriptor old-field result-wrapper family with different behavior.
