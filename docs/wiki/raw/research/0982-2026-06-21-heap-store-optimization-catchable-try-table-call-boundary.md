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

# HSO catchable `try_table` call boundary

## Question

Does Binaryen `version_130` fold a later `struct.set` into a constructor local when an intervening `try_table` body calls a function whose exception may be caught inside the current function?

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe file: `.tmp/hso-try-call-default.wat`.

Command:

```sh
wasm-opt --all-features .tmp/hso-try-call-default.wat --heap-store-optimization -S -o .tmp/hso-try-call-default.opt.wat
```

Finding: Binaryen preserves the constructor local assignment, the `try_table` / `call`, and the later `struct.set`. It does not fold the later value into `struct.new_default` when the intervening call may be caught by the local `try_table`.

## Starshine coverage

Added `heap-store-optimization keeps struct.set across catchable try_table calls after constructor locals` to `src/passes/heap_store_optimization_test.mbt`.

The fixture builds the constructor local before a `try_table` whose body calls the imported helper and drops its result, then performs the later same-field `struct.set`. Starshine already matched Binaryen by preserving `try_table`, `call`, `struct.new_default`, and `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'catchable try_table calls after constructor locals'
```

Result: `349/349` passed.

## Scope and reopening criteria

This note covers only the direct catchable-call `try_table` boundary after a constructor local assignment. It complements `0981`'s explicit `throw` boundary and the older caught-call negative inside the `struct.set` value path. It does not generalize to non-throwing `try_table` bodies, typed result `try_table`, descriptor roots, same-effect memory/table roots, or typed-function-reference catch/branch cases.

Reopen if Binaryen changes this catchable-call boundary, if Starshine starts folding this shape, or if a broader `try_table` audit proves a narrower call-effect/catch condition that permits folding without changing local catch reachability.
