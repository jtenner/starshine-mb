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

# HSO result-typed `try_table` direct `return_call` old-field boundary

## Question

Does Binaryen `version_130` fold away a later same-field `struct.set` when the overwritten constructor field has a direct-call side effect and a result-typed `try_table` body contains a direct `return_call` before the later store?

This narrows the result-typed `try_table` tail-call space from `0996`, `0999`, and `1000` by checking an old-field side-effect variant rather than the `struct.new_default` set-value shape. Do not infer this from the direct-root tail-call wins: the `try_table` wrapper is locally catchable and result-typed.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-return-call-old-field.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-return-call-old-field.wat --heap-store-optimization -S -o .tmp/hso-result-try-return-call-old-field.opt.wat
```

Result: Binaryen preserves the `struct.new` with its overwritten direct-call field, the result-typed `try_table`, the direct `return_call`, and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps result try_table return_call old fields`

Starshine already matched Binaryen by preserving the result wrapper, old-field call, and later `struct.set`; this was coverage-only HSO-D/F/G evidence, not an implementation change.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'result try_table return_call old fields'
```

Result: `370/370` passed.

No native rebuild or direct compare was required because Starshine already matched the probed Binaryen behavior and no implementation behavior changed.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. A direct `return_call` inside a result-typed `try_table` wrapper keeps the later store even when the overwritten constructor field has a preserved call side effect.

Reopen if Binaryen starts folding this locally catchable result-wrapper old-field shape, if Starshine later drops the store by overgeneralizing direct-root tail-call wins, or if direct compare exposes a narrower old-field/tail-call result-wrapper family with different behavior.
