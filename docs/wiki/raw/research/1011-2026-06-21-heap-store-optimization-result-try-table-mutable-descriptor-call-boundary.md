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

# HSO result-typed `try_table` mutable descriptor call boundary

## Question

Does Binaryen `version_130` still fold descriptor constructors across dropped result-typed `try_table` call wrappers when the descriptor operand is a mutable descriptor global?

This narrows the descriptor result-wrapper positives from `1005` and `1007`. Those positives used an immutable descriptor global. If the descriptor global is mutable, moving `struct.new_desc` after a catchable direct or indirect call would move the descriptor read across call effects.

## Binaryen probes

Probe files:

- `.tmp/hso-result-try-desc-mutable-call-value.wat`
- `.tmp/hso-result-try-desc-mutable-call-indirect-value.wat`

Commands:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-mutable-call-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-mutable-call-value.opt.wat
wasm-opt --all-features .tmp/hso-result-try-desc-mutable-call-indirect-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-mutable-call-indirect-value.opt.wat
```

Result: Binaryen preserves the descriptor `struct.new_desc`, the dropped result-typed `try_table`, the catchable direct or indirect call, the mutable descriptor `global.get`, and the later `struct.set` in both probes.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps descriptor result try_table mutable descriptor calls`
- `heap-store-optimization keeps descriptor result try_table mutable descriptor call_indirect`

Starshine already matched Binaryen. These tests keep the immutable-descriptor set-value positives narrow: result-wrapper calls do not make it safe to move a mutable descriptor read across the wrapper body's call effects.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'mutable descriptor call'
```

Result: `381/381` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. The descriptor result-typed `try_table` direct-call and `call_indirect` set-value positives from `1005` and `1007` apply to immutable descriptor reads; mutable descriptor reads remain ordered before catchable wrapper calls, so the later `struct.set` is preserved.

Reopen if Binaryen starts folding mutable-descriptor result-wrapper shapes, if Starshine later treats mutable descriptor `global.get` as movable across call or `call_indirect` effects, or if typed-function-reference or tail-call descriptor result-wrapper variants show a different mutable-descriptor split.
