---
kind: research
status: complete
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# HSO many-fields and pattern-breaker lit coverage

Question: do remaining Binaryen `version_130` dedicated lit chain families need additional focused Starshine coverage before `heap-store-optimization` HSO-C closeout?

## Answer

This slice added coverage-only tests for two source-backed lit families that were not named in the focused HSO test map:

- `$many-fields`: independent immediate `local.tee(struct.new)` roots can fold different fields of different fresh structs in the same function.
- `$pattern-breaker`: an intervening unswappable local copy between `local.set(struct.new)` and the later `struct.set(local.get)` breaks the subsequent-chain pattern, so the `struct.set` is preserved.

Starshine already matched both Binaryen-observable behaviors. No implementation change was needed.

## Evidence

Focused test command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 202, passed: 202, failed: 0.
```

The tests added were:

- `heap-store-optimization folds Binaryen many-fields tee roots independently`
- `heap-store-optimization keeps Binaryen pattern-breaker local copy chains`

Because this was coverage-only and the tests were green on first run, no red-first behavior gap or direct 10000-case compare was required for this slice.

## HSO-C impact

HSO-C is narrower after this slice: immediate tee roots now have explicit coverage for repeated independent roots in one function, and subsequent-chain scanning now has an explicit local-copy pattern-breaker negative. Remaining HSO-C work is broader lit review for `$many-news` / any debris or output-shape classification not already covered by the tee-plus-later-chain, repeated-store last-value, wrong-target-local, many-fields, and pattern-breaker tests.
