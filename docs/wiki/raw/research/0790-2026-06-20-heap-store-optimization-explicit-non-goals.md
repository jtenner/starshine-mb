---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0789-2026-06-20-heap-store-optimization-core-chain-coverage.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO explicit non-goal coverage

Question: are the current Binaryen `heap-store-optimization` non-goal boundaries around non-struct heap/memory stores locked by focused Starshine tests?

## Coverage added

Added two focused boundary tests for source-backed pass scope limits:

- `heap-store-optimization leaves array stores as an explicit non-goal`
  - Builds an `array.new_default` / `array.set` / `array.get` shape.
  - Expects `array.new_default`, `array.set`, and `array.get` to remain.
  - This locks the current Binaryen owner-file surface, which records `StructSet` and `Block` action sites rather than array-store DSE/load-forwarding.
- `heap-store-optimization keeps struct.set behind ordinary memory stores`
  - Built `local.set(struct.new_default)` followed by an ordinary `i32.store` blocker and then a later `struct.set`.
  - This expectation was superseded by `0791`: a direct Binaryen `version_130` probe shows `trySwap(...)` crosses the ordinary memory store when the constructor has no ordered operand effects, then folds the later `struct.set` into the constructor while preserving the `i32.store`.

The array-store test remains an intentional fail-closed / boundary test for `[O4Z-AUDIT-HSO-H]`. The memory-store claim was a conservative misclassification and is superseded by `0791`; ordinary memory/table blockers are not generic DSE/load-forwarding targets, but they can be crossed to reach a later fresh-struct `struct.set` fold.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `69/69` passed.

No implementation behavior changed and no direct compare was required for this coverage-only boundary slice.

## Remaining risk

`[O4Z-AUDIT-HSO-H]` remains open. Still needed before closeout:

- generic heap DSE/load-forwarding non-goal wording with reopening criteria if Binaryen expands the pass in a future release;
- final wording for unreachable constructor/set no-fold boundaries now that `0792` added focused coverage;
- local WAT/HOT surface limits, including the descriptor exact `ref.cast` blocker recorded in `0789` and the direct-root unreachable set-value fixture limitation recorded in `0792`.
