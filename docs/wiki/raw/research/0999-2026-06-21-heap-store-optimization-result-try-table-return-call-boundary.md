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

# HSO result-typed `try_table` direct `return_call` boundary

## Question

Does Binaryen `version_130` fold away a later `struct.set` when a result-typed `try_table` body contains a direct `return_call` before returning a dropped fallback value?

This narrows the result-typed `try_table` tail-call space from `0996`: Binaryen already preserves a `return_call_ref` set-value store in this wrapper shape. This note checks the direct `return_call` counterpart rather than inferring it from the typed-function-reference case or from the older function-external `return_call` positives.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-return-call-store.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-return-call-store.wat --heap-store-optimization -S -o .tmp/hso-result-try-return-call-store.opt.wat
```

Result: Binaryen preserves the constructor `struct.new_default`, the result-typed `try_table`, the direct `return_call`, and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps result try_table return_call set values`

Starshine already matched Binaryen by preserving the result wrapper and later `struct.set`; this was coverage-only HSO-F/G evidence, not an implementation change.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'result try_table return_call set values'
```

Result: `368/368` passed.

No native rebuild or direct compare was required because Starshine already matched the probed Binaryen behavior and no implementation behavior changed.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. A direct `return_call` inside a result-typed `try_table` wrapper does not inherit the older function-external return-call fold behavior; Binaryen keeps the later store, and Starshine matches.

Reopen if Binaryen starts folding this locally catchable result-wrapper tail-call shape, if Starshine later drops the store by overgeneralizing the direct-root tail-call win, or if direct compare exposes a narrower direct `return_call` result-wrapper family with different behavior.
