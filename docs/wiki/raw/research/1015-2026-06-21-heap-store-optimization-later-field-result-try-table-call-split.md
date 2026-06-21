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

# HSO later-field result-typed `try_table` call split

## Question

Does Binaryen `version_130` apply the same later-constructor-field ordering split when the later field is a dropped result-typed `try_table` with a catchable direct call?

This narrows HSO-D/E beyond the earlier select/if/block-br_if later-field condition probes. The tested constructor has field 1 supplied by a result-typed `try_table`; the later same-object `struct.set` targets field 0.

## Binaryen probes

Probe files:

- `.tmp/hso-later-field-result-try-call-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-call-moved-call-catchall.wat`

Commands:

```sh
wasm-opt --all-features .tmp/hso-later-field-result-try-call-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-call-moved-const-catchall.opt.wat
wasm-opt --all-features .tmp/hso-later-field-result-try-call-moved-call-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-call-moved-call-catchall.opt.wat
```

Results:

- Pure moved set value: Binaryen folds `i32.const 9` into field 0 of `struct.new`, preserves the result-typed `try_table` as field 1, and removes the later `struct.set`.
- Effectful moved set value: Binaryen preserves the constructor, the result-typed `try_table`, the moved `call`, and the later `struct.set`, because folding would move the call before the later-field wrapper.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization folds pure set values into later-field result try_table constructors`
- `heap-store-optimization keeps effectful set values after later-field result try_table constructors`

Starshine already matched both Binaryen shapes. This extends the existing later-field directional barrier matrix from select/if/block-br_if conditions to the result-typed `try_table` direct-call field form without generalizing to all typed-function-reference or old-field result-wrapper bodies.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'later-field result try_table'
```

Result: `387/387` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior split, Starshine match. Pure moved values can fold across the result-typed `try_table` later field; effectful moved values cannot be moved before that later-field direct call.

Reopen if Binaryen changes either side of this split, if Starshine starts folding effectful set values before later-field result wrappers, or if broader later-field result-wrapper families such as indirect calls, typed-function-reference calls, tail calls, old-field interactions, or descriptor constructors show a distinct behavior.
