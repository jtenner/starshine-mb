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

# HSO later-field result-typed `try_table` tail-call old-field boundary

## Question

Does the `1018` later-field tail-call no-fold boundary still hold when the overwritten constructor field has an old call or exact trap that would need preservation?

This narrows the plain-constructor tail-call result-wrapper behavior and keeps it separate from the non-tail old-field fold in `1019`.

## Binaryen probes

Probe files:

- `.tmp/hso-later-field-result-try-return-call-oldfield-call-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-return-call-oldfield-div-zero-moved-const-catchall.wat`

Commands:

```sh
wasm-opt --all-features .tmp/hso-later-field-result-try-return-call-oldfield-call-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-return-call-oldfield-call-moved-const-catchall.opt.wat
wasm-opt --all-features .tmp/hso-later-field-result-try-return-call-oldfield-div-zero-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-return-call-oldfield-div-zero-moved-const-catchall.opt.wat
```

Result: Binaryen preserves `struct.new`, the old-field call or exact trapping `i32.div_s`, the later-field result-typed `try_table` with `return_call`, and the later `struct.set`. It does not fold the pure later same-field value into the constructor.

## Starshine coverage

Starshine already matched this boundary after the `1018` tail/throw-escape fix. Added focused tests:

- `heap-store-optimization keeps old direct-call fields across later-field result try_table return_call constructors`
- `heap-store-optimization keeps old trapping fields across later-field result try_table return_call constructors`

Both tests assert that the optimized output retains `struct.new`, `try_table`, `return_call`, the old-field effect/trap marker, and `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'later-field result try_table return_call old-field'
```

Result: `398/398` passed.

No native rebuild or direct compare was required because this was coverage-only documentation of behavior Starshine already had.

## Classification and reopening criteria

Classification: Binaryen behavior parity coverage. Later constructor fields that contain result-typed `try_table` tail-call bodies remain no-fold barriers even when folding would otherwise preserve an overwritten old-field call or trap.

Reopen if Binaryen starts folding old-field-preserving pure stores across later-field tail-call result wrappers, if non-tail old-field folds from `1019` regress, or if `return_call_indirect` / `return_call_ref` old-field variants prove narrower than the direct `return_call` boundary covered here.
