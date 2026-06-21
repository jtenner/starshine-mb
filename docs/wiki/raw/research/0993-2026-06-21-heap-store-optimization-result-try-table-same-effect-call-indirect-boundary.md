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

# HSO result `try_table` same-effect `call_indirect` boundary

## Question

Does Binaryen `version_130` fold result-typed `try_table` same-effect `memory.fill` / `table.fill` boundaries when the `try_table` body also contains a potentially catchable `call_indirect`?

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe file: `.tmp/hso-try-result-same-effect-call-indirect.wat`.

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-try-result-same-effect-call-indirect.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-try-result-same-effect-call-indirect.opt.wat
```

Finding: Binaryen preserves the constructor local assignment, the result-typed `try_table`, the `call_indirect`, the same-effect `memory.fill` / `table.fill`, and the later `struct.set` in both probed shapes:

- `memory.size` in a constructor field before a result `try_table` body containing `call_indirect` plus `memory.fill`.
- `table.size` in a constructor field before a result `try_table` body containing `call_indirect` plus `table.fill`.

This narrows the result-typed same-effect notes `0986`, `0988`, and `0991`: an indirect call inside the same result `try_table` body does not make the same-resource fill boundary foldable.

## Starshine coverage

Added focused coverage to `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps result try_table same-effect fills after catchable indirect calls`

The fixture covers both memory and table sides with a result-typed, value-dropped `try_table` body that performs `call_indirect`, drops its result, performs the same-effect fill, and returns a dropped value. Starshine already matched Binaryen by preserving `memory.size` / `table.size`, `try_table`, `call_indirect`, `memory.fill` / `table.fill`, and `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'result try_table same-effect fills after catchable indirect calls'
```

Result: `362/362` passed.

No native rebuild or direct compare was required because this was coverage-only and Starshine already matched Binaryen.

## Classification

This is HSO-F/G coverage, not a Starshine win and not a non-goal. Binaryen treats the result-typed `try_table` body as a no-fold boundary when the constructor resource read would cross both a potentially catchable indirect call and a same-resource fill. Starshine's current conservative behavior matches that boundary.

## Reopening criteria

Reopen if Binaryen starts folding same-effect result-typed `try_table` fill bodies containing `call_indirect`, if Starshine starts dropping the later `struct.set` for this shape, or if a later source/lit refresh proves a narrower indirect-call/catch condition that permits folding while preserving local catch reachability and same-resource ordering.
