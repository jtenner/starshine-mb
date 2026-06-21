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

# HSO result-typed `try_table` catchable direct-call cross-store boundary

## Question

Does Binaryen `version_130` fold a `memory.size` / `table.size` constructor operand across a result-typed `try_table` body that contains a catchable direct call before an otherwise cross-family ordinary store root?

This narrows the result-typed `try_table` space from `0990`, `0991`, and `0995`: non-throwing result-typed cross-family ordinary-store roots fold, same-effect fill roots after catchable direct calls do not fold, and typed-function-reference calls keep the later store even for cross-family ordinary stores. This note checks the ordinary direct-call counterpart for cross-family ordinary stores.

## Binaryen probe

Probe files:

- `.tmp/hso-try-result-call-cross-store.wat`
- `.tmp/hso-try-result-call-cross-store-table.wat`

Commands:

```sh
wasm-opt --all-features .tmp/hso-try-result-call-cross-store.wat --heap-store-optimization -S -o .tmp/hso-try-result-call-cross-store.opt.wat
wasm-opt --all-features .tmp/hso-try-result-call-cross-store-table.wat --heap-store-optimization -S -o .tmp/hso-try-result-call-cross-store-table.opt.wat
```

Result: Binaryen preserves the constructor `local.set`, the result-typed `try_table`, the direct `call`, the cross-family ordinary store root (`table.set` for the `memory.size` constructor case, `i32.store` for the `table.size` case), and the later `struct.set`.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps result try_table cross stores after catchable calls`

The test covers both sides:

- `memory.size` constructor field before result `try_table` / catchable direct `call` / unrelated `table.set`;
- `table.size` constructor field before result `try_table` / catchable direct `call` / unrelated `i32.store`.

Starshine already matched Binaryen by preserving the constructor resource read and later `struct.set`; this was coverage-only HSO-F/G evidence, not an implementation change.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'result try_table cross stores after catchable calls'
```

Result: `366/366` passed.

No native rebuild or direct compare was required because Starshine already matched the probed Binaryen behavior and no implementation behavior changed.

## Classification and reopening criteria

Classification: Binaryen behavior boundary, Starshine match. A catchable direct call inside a result-typed `try_table` body prevents the non-throwing cross-family ordinary-store fold proven in `0990`.

Reopen if Binaryen changes HSO to commute constructor resource reads across catchable direct calls in result-typed `try_table` bodies, if Starshine later peels this wrapper and drops the later store, or if a compare lane exposes a distinct direct-call/cross-store result-wrapper family that folds safely and needs separate proof.
