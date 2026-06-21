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

# HSO result-typed `try_table` catchable indirect-call cross-store boundary

## Question

Does Binaryen `version_130` fold a `memory.size` / `table.size` constructor operand across a result-typed `try_table` body that contains a catchable `call_indirect` before an otherwise cross-family ordinary store root?

This narrows the result-typed `try_table` space from `0990`, `0993`, `0995`, and `0997`: non-throwing result-typed cross-family ordinary-store roots fold, same-effect fill roots after catchable indirect calls do not fold, typed-function-reference calls keep the later store even for cross-family ordinary stores, and direct calls keep the later store in the same cross-store setup. This note checks the indirect-call counterpart for cross-family ordinary stores.

## Binaryen probe

Probe files:

- `.tmp/hso-try-result-call-indirect-cross-store-memory.wat`
- `.tmp/hso-try-result-call-indirect-cross-store.wat`

Commands:

```sh
wasm-opt --all-features .tmp/hso-try-result-call-indirect-cross-store-memory.wat --heap-store-optimization -S -o .tmp/hso-try-result-call-indirect-cross-store-memory.opt.wat
wasm-opt --all-features .tmp/hso-try-result-call-indirect-cross-store.wat --heap-store-optimization -S -o .tmp/hso-try-result-call-indirect-cross-store.opt.wat
```

Result: Binaryen preserves the constructor `local.set`, the result-typed `try_table`, `call_indirect`, the cross-family ordinary store root (`table.set` for the `memory.size` constructor case, `i32.store` for the `table.size` case), and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps result try_table cross stores after catchable indirect calls`

The test covers both sides:

- `memory.size` constructor field before result `try_table` / catchable `call_indirect` / unrelated `table.set`;
- `table.size` constructor field before result `try_table` / catchable `call_indirect` / unrelated `i32.store`.

Starshine already matched Binaryen by preserving the constructor resource read and later `struct.set`; this was coverage-only HSO-F/G evidence, not an implementation change.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'result try_table cross stores after catchable indirect calls'
```

Result: `367/367` passed.

No native rebuild or direct compare was required because Starshine already matched the probed Binaryen behavior and no implementation behavior changed.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. A catchable indirect call inside a result-typed `try_table` body prevents the non-throwing cross-family ordinary-store fold proven in `0990`.

Reopen if Binaryen changes HSO to commute constructor resource reads across catchable indirect calls in result-typed `try_table` bodies, if Starshine later peels this wrapper and drops the later store, or if a compare lane exposes a distinct indirect-call/cross-store result-wrapper family that folds safely and needs separate proof.
