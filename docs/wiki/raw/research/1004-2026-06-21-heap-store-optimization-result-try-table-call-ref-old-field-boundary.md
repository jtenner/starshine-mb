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

# HSO result-typed `try_table` `call_ref` old-field boundary

## Question

Does Binaryen `version_130` fold away a later same-field `struct.set` when the overwritten constructor field is produced by `call_ref` and a result-typed `try_table` body contains a catchable `call_ref` before the later store?

This complements `1003` by checking the non-tail typed-function-reference call root inside the same locally catchable result-wrapper and old-field side-effect space.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-call-ref-old-field.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-call-ref-old-field.wat --heap-store-optimization -S -o .tmp/hso-result-try-call-ref-old-field.opt.wat
```

Result: Binaryen preserves the `struct.new` with its overwritten `call_ref` field, the result-typed `try_table`, the catchable `call_ref`, and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps result try_table call_ref old fields`

Starshine already matched Binaryen by preserving the result wrapper, old-field `call_ref`, catchable `call_ref`, and later `struct.set`; this was coverage-only HSO-D/F/G evidence, not an implementation change.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'result try_table call_ref old fields'
```

Result: `373/373` passed.

No native rebuild or direct compare was required because Starshine already matched the probed Binaryen behavior and no implementation behavior changed.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. A catchable `call_ref` inside a result-typed `try_table` wrapper keeps the later store when the overwritten constructor field has a preserved `call_ref` side effect.

Reopen if Binaryen starts folding this locally catchable result-wrapper old-field shape, if Starshine later drops the store by overgeneralizing typed-function-reference wrapper positives, or if direct compare exposes a narrower `call_ref` old-field result-wrapper family with different behavior.
