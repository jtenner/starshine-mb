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

# HSO result-typed `try_table` mutable descriptor `call_ref` boundary

## Question

Does the mutable-descriptor result-wrapper boundary from `1011` also apply when the wrapper body uses typed-function-reference `call_ref`?

This narrows the descriptor result-wrapper `call_ref` fold from `1008`, which used an immutable descriptor global. If the descriptor global is mutable, moving `struct.new_desc` after a catchable `call_ref` would move the descriptor read across call effects.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-desc-mutable-call-ref-value.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-mutable-call-ref-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-mutable-call-ref-value.opt.wat
```

Result: Binaryen preserves the descriptor `struct.new_desc`, the dropped result-typed `try_table`, the catchable `call_ref`, the mutable descriptor `global.get`, and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps descriptor result try_table mutable descriptor call_ref`

Starshine already matched Binaryen. The test extends the descriptor/call-ref helper so it can build a mutable descriptor-global import while preserving the existing immutable-descriptor call-ref tests.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'mutable descriptor call_ref'
```

Result: `382/382` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. The descriptor result-typed `try_table` `call_ref` set-value positive from `1008` applies to immutable descriptor reads; mutable descriptor reads remain ordered before catchable `call_ref` effects, so the later `struct.set` is preserved.

Reopen if Binaryen starts folding this mutable-descriptor `call_ref` result-wrapper shape, if Starshine later treats mutable descriptor `global.get` as movable across `call_ref` effects, or if tail-call descriptor result-wrapper variants show a different mutable-descriptor split.
