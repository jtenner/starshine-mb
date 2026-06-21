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

# HSO result-typed `try_table` mutable descriptor `return_call_ref` boundary

## Question

Does Binaryen `version_130` preserve descriptor constructors across dropped result-typed `try_table` wrappers with `return_call_ref` when the descriptor operand is a mutable descriptor global?

This completes the mutable-descriptor tail-call counterpart to `1013` and keeps the typed-function-reference result-wrapper tail-call boundary narrow. Moving `struct.new_desc` after the locally catchable result wrapper would move the mutable descriptor read across the `return_call_ref` effect.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-desc-mutable-return-call-ref-value.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-mutable-return-call-ref-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-mutable-return-call-ref-value.opt.wat
```

Result: Binaryen preserves the descriptor `struct.new_desc`, the mutable descriptor `global.get`, the dropped result-typed `try_table`, the `return_call_ref`, and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps descriptor result try_table mutable descriptor return_call_ref`

Starshine already matched Binaryen. The test keeps the direct-root/active-catch `return_call_ref` Starshine wins from `0920`/`0921` scoped away from locally catchable result wrappers and keeps mutable descriptor reads ordered before typed-function-reference tail-call effects.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'mutable descriptor return_call_ref'
```

Result: `385/385` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched the probed Binaryen behavior.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. Mutable descriptor reads stay ordered before locally catchable result-typed `try_table` / `return_call_ref` wrappers, so the later `struct.set` is preserved.

Reopen if Binaryen starts folding this mutable-descriptor `return_call_ref` result-wrapper shape, if Starshine later moves mutable descriptor `global.get` across typed-function-reference tail-call effects, or if broader typed-function-reference branch/catch root families reveal a distinct descriptor-read split.
