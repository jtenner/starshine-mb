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

# HSO later-field result-typed `try_table` `call_ref` split

## Question

Does Binaryen `version_130` apply the `1015` later-field result-wrapper split to typed-function-reference `call_ref` bodies?

The tested constructor has field 1 supplied by a result-typed `try_table` whose body performs `call_ref`; the later same-object `struct.set` targets field 0. This keeps the typed-function-reference later-field family separate from the direct-call result-wrapper probe.

## Binaryen probes

Probe files:

- `.tmp/hso-later-field-result-try-call-ref-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-call-ref-moved-call-ref-catchall.wat`

Commands:

```sh
wasm-opt --all-features .tmp/hso-later-field-result-try-call-ref-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-call-ref-moved-const-catchall.opt.wat
wasm-opt --all-features .tmp/hso-later-field-result-try-call-ref-moved-call-ref-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-call-ref-moved-call-ref-catchall.opt.wat
```

Results:

- Pure moved set value: Binaryen folds `i32.const 9` into field 0 of `struct.new`, preserves the result-typed `try_table` / `call_ref` as field 1, and removes the later `struct.set`.
- Effectful moved set value: Binaryen preserves the constructor, the result-typed `try_table`, both `call_ref` evaluations, and the later `struct.set`, because folding would move the later `call_ref` before the later-field wrapper.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization folds pure set values into later-field result try_table call_ref constructors`
- `heap-store-optimization keeps effectful call_ref values after later-field result try_table constructors`

Starshine already matched both Binaryen shapes. This extends the `1015` direct-call split to typed-function-reference calls without claiming coverage for indirect calls, tail calls, descriptor constructors, or old-field result-wrapper combinations.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'later-field result try_table call_ref'
```

Result: `389/389` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior split, Starshine match. Pure moved values can fold across the typed-function-reference result-typed `try_table` later field; effectful `call_ref` moved values cannot be moved before that later-field wrapper.

Reopen if Binaryen changes either side of this split, if Starshine starts folding effectful `call_ref` values before later-field result wrappers, or if indirect-call, tail-call, descriptor, old-field, or branch/catch variants show distinct behavior.
