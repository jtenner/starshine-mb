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

# HSO result-typed `try_table` `return_call_ref` set-value boundary

## Question

Does the narrow direct-root `return_call_ref` set-value Starshine win from `0920`/`0921` extend to a later store after a result-typed `try_table` body that contains `return_call_ref`?

This probes a typed-function-reference branch root inside the result-typed `try_table` wrapper space audited in `0985` through `0995`.

## Binaryen probe

Probe file: `.tmp/hso-try-result-return-call-ref-dead-set.wat`.

Command:

```sh
wasm-opt --all-features .tmp/hso-try-result-return-call-ref-dead-set.wat --heap-store-optimization -S -o .tmp/hso-try-result-return-call-ref-dead-set.opt.wat
```

Result: Binaryen preserves the constructor `local.set`, result-typed `try_table`, `return_call_ref`, and later `struct.set`. This differs from the direct-root `return_call_ref` set-value shape because the branch root is inside a locally catchable result wrapper; the local catch edge means the following store cannot be classified as the same direct dead-tail-call store.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps result try_table return_call_ref set values`

Starshine already matched Binaryen by preserving the result `try_table`, `return_call_ref`, `struct.new_default`, and later `struct.set`.

This is not a new Starshine-win boundary. The existing `0920`/`0921` Starshine wins remain limited to direct-root set-value shapes where the tail call exits before the store can execute; this result-typed `try_table` case is a Binaryen-match no-fold boundary.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'result try_table return_call_ref set values'
```

Result: `365/365` passed.

No native rebuild or direct compare was required because Starshine already matched the probed Binaryen behavior and no implementation behavior changed.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. Result-typed `try_table` wrappers with local catches do not inherit the direct-root `return_call_ref` dead-store Starshine-win classification.

Reopen if Binaryen changes HSO to drop this later store, if Starshine starts treating this wrapper as a direct tail-call dead-store root, or if a separate result-typed `try_table` tail-call family proves the following store cannot execute and merits a distinct Starshine-win classification with validation evidence.
