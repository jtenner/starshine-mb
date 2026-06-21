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

# HSO result-typed `try_table` indirect `return_call` boundary

## Question

Does Binaryen `version_130` fold away a later `struct.set` when a result-typed `try_table` body contains `return_call_indirect` before returning a dropped fallback value?

This narrows the result-typed `try_table` tail-call space from `0996` and `0999`: Binaryen preserves both the typed-function-reference `return_call_ref` and direct `return_call` set-value shapes in locally catchable result wrappers. This note checks the indirect-tail-call counterpart.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-return-call-indirect-store.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-return-call-indirect-store.wat --heap-store-optimization -S -o .tmp/hso-result-try-return-call-indirect-store.opt.wat
```

Result: Binaryen preserves the constructor `struct.new_default`, the result-typed `try_table`, `return_call_indirect`, and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps result try_table return_call_indirect set values`

Starshine already matched Binaryen by preserving the result wrapper and later `struct.set`; this was coverage-only HSO-F/G evidence, not an implementation change.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'result try_table return_call_indirect set values'
```

Result: `369/369` passed.

No native rebuild or direct compare was required because Starshine already matched the probed Binaryen behavior and no implementation behavior changed.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. `return_call_indirect` inside a result-typed `try_table` wrapper follows the direct and typed-function-reference tail-call boundaries: Binaryen keeps the later store, and Starshine matches.

Reopen if Binaryen starts folding this locally catchable result-wrapper tail-call shape, if Starshine later drops the store by overgeneralizing the direct-root tail-call win, or if direct compare exposes a narrower indirect tail-call result-wrapper family with different behavior.
