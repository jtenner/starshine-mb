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

# HSO later-field result-typed `try_table` descriptor old-field fold

## Question

When a descriptor constructor has a later constructor field that is a non-tail result-typed `try_table`, does Binaryen still fold a pure later same-field store if the overwritten field has a call side effect or exact trap that must be preserved?

This extends the plain-constructor old-field fold from `1019` to immutable-descriptor `struct.new_desc`. It is distinct from the descriptor result-wrapper old-field boundaries in `1006`, `1009`, and `1010`, where the result wrapper appears after the constructor rather than inside another constructor field.

## Binaryen probes

Probe files:

- `.tmp/hso-later-field-result-try-desc-call-oldfield-call-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-desc-call-oldfield-div-zero-moved-const-catchall.wat`

Commands used local Binaryen `version_130`:

```sh
wasm-opt --all-features .tmp/hso-later-field-result-try-desc-call-oldfield-call-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-desc-call-oldfield-call-moved-const-catchall.opt.wat
wasm-opt --all-features .tmp/hso-later-field-result-try-desc-call-oldfield-div-zero-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-desc-call-oldfield-div-zero-moved-const-catchall.opt.wat
```

Result: Binaryen folds the pure `i32.const 9` into field `0` of `struct.new_desc`, removes the later `struct.set`, preserves the old-field direct call or exact trapping `i32.div_s` under `drop`, preserves the later-field result-typed `try_table` / direct call, and preserves the immutable descriptor `global.get`.

## Starshine coverage

Starshine already matched the Binaryen behavior. Added focused tests:

- `heap-store-optimization preserves descriptor old direct-call fields while folding later-field result try_table calls`
- `heap-store-optimization preserves descriptor old trapping fields while folding later-field result try_table calls`

The tests assert that the optimized output still contains `struct.new_desc`, `try_table`, and the old-field side effect/trap under `drop`, but no longer contains `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'descriptor later-field result try_table old-field'
```

Result: `400/400` passed.

No native rebuild or direct compare was required because this was coverage-only documentation of behavior Starshine already had.

## Classification and reopening criteria

Classification: Binaryen behavior parity coverage. Immutable-descriptor constructors follow the plain-constructor `1019` old-field fold rule for non-tail later-field result-typed `try_table` wrappers: pure same-field stores can fold while old-field calls/traps are preserved in order.

Reopen if Binaryen changes descriptor old-field folding across later-field result wrappers, if mutable descriptor globals show a different rule, if call_indirect/call_ref descriptor later-field variants differ from the direct-call descriptor probe, or if Starshine reorders old-field effects after the descriptor read or result wrapper.
