---
kind: research
status: supported
date: 2026-06-21
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
---

# HSO catch-taken `try_table` throw boundary

## Question

Does Binaryen `version_130` fold a later `struct.set` into a constructor local when an intervening `try_table` can catch a thrown exception and skip the local-set/root sequence?

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe file: `.tmp/hso-try-throw-default.wat`.

Command:

```sh
wasm-opt --all-features .tmp/hso-try-throw-default.wat --heap-store-optimization -S -o .tmp/hso-try-throw-default.opt.wat
```

Finding: Binaryen preserves the constructor local assignment, the `try_table` / `throw`, and the later `struct.set`. It does not fold the later value into `struct.new_default` for this catch-taken `try_table` root.

## Starshine coverage

Added `heap-store-optimization keeps struct.set across catch-taken try_table throws after constructor locals` to `src/passes/heap_store_optimization_test.mbt`.

The fixture builds the constructor local before a `try_table` whose body throws to the function-local catch target, then performs the later same-field `struct.set`. Starshine already matched Binaryen by preserving `try_table`, `throw`, `struct.new_default`, and `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'catch-taken try_table throws after constructor locals'
```

Result: `348/348` passed.

## Scope and reopening criteria

This note covers only the direct catch-taken `try_table` / `throw` boundary after a constructor local assignment. It does not generalize to non-throwing `try_table` bodies, which are separately covered by `0927`, `0979`, and `0980`, or to caught calls, typed result `try_table`, descriptor roots, same-effect memory/table roots, or typed-function-reference catch/branch cases.

Reopen if Binaryen changes this catch-taken `try_table` boundary, if Starshine starts folding this shape, or if a broader `try_table` audit finds a narrower safety condition that permits folding without changing catch-local execution.
