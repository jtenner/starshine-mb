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

# HSO result `try_table` same-effect throw boundary

## Question

Does Binaryen `version_130` fold result-typed `try_table` same-effect `memory.fill` / `table.fill` boundaries when the `try_table` body performs the fill and then throws to a local catch target?

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe file: `.tmp/hso-try-result-same-effect-throw.wat`.

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-try-result-same-effect-throw.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-try-result-same-effect-throw.opt.wat
```

Finding: Binaryen preserves the constructor local assignment, the result-typed `try_table`, the same-effect `memory.fill` / `table.fill`, the caught `throw`, and the later `struct.set` in both probed shapes:

- `memory.size` in a constructor field before a result `try_table` body containing `memory.fill` followed by `throw`.
- `table.size` in a constructor field before a result `try_table` body containing `table.fill` followed by `throw`.

This narrows the result-typed same-effect notes `0986` and `0988`, and complements the direct constructor-local catch-taken boundary from `0981`: a result-typed, value-dropped body does not become foldable when the same-effect fill executes before a caught throw.

## Starshine coverage

Added focused coverage to `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps result try_table same-effect fills before caught throws`

The fixture covers both memory and table sides with a result-typed, value-dropped `try_table` body that performs the same-resource fill, throws to the local catch target, and keeps a dead result value after the throw to mirror the Binaryen WAT probe. Starshine already matched Binaryen by preserving `memory.size` / `table.size`, `try_table`, `memory.fill` / `table.fill`, `throw`, and `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'result try_table same-effect fills before caught throws'
```

Result: `361/361` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched Binaryen.

## Classification

This is HSO-F/G coverage, not a Starshine win and not a non-goal. Binaryen treats the result-typed `try_table` body as a no-fold boundary when the constructor resource read would cross a same-resource fill and a locally caught throw. Starshine's current behavior matches that boundary.

## Reopening criteria

Reopen if Binaryen starts folding same-effect result-typed `try_table` fill bodies containing caught throws, if Starshine starts dropping the later `struct.set` for this shape, or if a later source/lit refresh proves a narrower catch-taken condition that permits folding while preserving local catch reachability and same-resource ordering.
