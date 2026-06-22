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

# HSO later-field result-typed `try_table` old-field fold

## Question

When another constructor field is a result-typed `try_table` with a non-tail catchable call, does Binaryen still fold a pure later same-field `struct.set` if the overwritten constructor field has side effects or a trap that must be preserved?

This narrows the `1015`-`1017` later-field result-wrapper pure-fold family with old-field preservation. It is separate from the descriptor old-field result-wrapper boundaries in `1006`, `1009`, and `1010`, and from the tail-call no-fold boundary in `1018`.

## Binaryen probes

Probe files:

- `.tmp/hso-later-field-result-try-call-oldfield-call-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-call-indirect-oldfield-call-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-call-ref-oldfield-call-ref-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-call-oldfield-div-zero-moved-const-catchall.wat`

Commands used the local Binaryen `version_130` oracle, for example:

```sh
wasm-opt --all-features .tmp/hso-later-field-result-try-call-oldfield-call-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-call-oldfield-call-moved-const-catchall.opt.wat
wasm-opt --all-features .tmp/hso-later-field-result-try-call-oldfield-div-zero-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-call-oldfield-div-zero-moved-const-catchall.opt.wat
```

Result: Binaryen folds the pure `i32.const 9` into the overwritten field of `struct.new`, removes the later `struct.set`, and preserves the overwritten old-field call or exact trapping `i32.div_s` under `drop` before the later-field result-typed `try_table`. The same fold shape was also observed for later-field `call_indirect` and `call_ref` wrappers.

## Starshine coverage

Starshine already matched the Binaryen behavior. Added focused tests:

- `heap-store-optimization preserves old direct-call fields while folding later-field result try_table calls`
- `heap-store-optimization preserves old trapping fields while folding later-field result try_table calls`

The tests assert that the optimized output still contains the old-field side effect/trap, `drop`, `struct.new`, and `try_table`, but no longer contains `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'later-field result try_table old-field'
```

Result: `396/396` passed.

No native rebuild or direct compare was required because this was coverage-only documentation of behavior Starshine already had.

## Classification and reopening criteria

Classification: Binaryen behavior parity coverage. Non-tail later-field result-typed `try_table` wrappers still allow pure same-field stores to fold even when the overwritten old field must be preserved for side effects or traps.

Reopen if a later-field result-wrapper body with a different local branch/catch shape changes Binaryen's fold decision, if old-field preservation reorders the old effect after the later-field wrapper, or if descriptor/default variants prove a different old-field rule than the plain-constructor cases covered here.
