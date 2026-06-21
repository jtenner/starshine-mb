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

# HSO result-typed `try_table` mutable descriptor tail-call boundary

## Question

Do Binaryen `version_130` descriptor result-typed `try_table` tail-call boundaries preserve `struct.set` when the descriptor operand is a mutable descriptor global?

This narrows the immutable descriptor result-wrapper positives from `1005` and `1007` plus the result-typed tail-call no-fold boundaries from `0999` and `1000`. If the descriptor global is mutable, moving `struct.new_desc` after the locally catchable result wrapper would move the descriptor read across tail-call effects.

## Binaryen probes

Probe files:

- `.tmp/hso-result-try-desc-mutable-return-call-value.wat`
- `.tmp/hso-result-try-desc-mutable-return-call-indirect-value.wat`

Commands:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-mutable-return-call-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-mutable-return-call-value.opt.wat
wasm-opt --all-features .tmp/hso-result-try-desc-mutable-return-call-indirect-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-mutable-return-call-indirect-value.opt.wat
```

Result: Binaryen preserves the descriptor `struct.new_desc`, the mutable descriptor `global.get`, the dropped result-typed `try_table`, the direct or indirect tail call, and the later `struct.set` in both probes.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps descriptor result try_table mutable descriptor return_call`
- `heap-store-optimization keeps descriptor result try_table mutable descriptor return_call_indirect`

Starshine already matched Binaryen. These tests keep the immutable-descriptor result-wrapper folds narrow and keep result-typed tail-call no-fold behavior explicit for mutable descriptor reads.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'mutable descriptor return_call'
```

Result: `384/384` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. Mutable descriptor reads stay ordered before locally catchable result-typed `try_table` tail-call wrappers, so the later `struct.set` is preserved.

Reopen if Binaryen starts folding mutable-descriptor result-wrapper tail-call shapes, if Starshine later moves mutable descriptor `global.get` across tail-call effects, or if the typed-function-reference tail-call counterpart shows a different mutable-descriptor split.
