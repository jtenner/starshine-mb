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
  - Builds `local.set(struct.new_default)` followed by an ordinary `i32.store` blocker and then a later `struct.set`.
  - Expects both the memory store and the `struct.set` to remain, locking that ordinary memory stores are not folded through by this pass.

These are intentional fail-closed / boundary tests for `[O4Z-AUDIT-HSO-H]`. They do not assert that Starshine is better than Binaryen; they preserve the current source-backed scope while the HSO audit continues.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `69/69` passed.

No implementation behavior changed and no direct compare was required for this coverage-only boundary slice.

## Remaining risk

`[O4Z-AUDIT-HSO-H]` remains open. Still needed before closeout:

- explicit table-store / table-effect boundary coverage if representable in the local test surface;
- generic heap DSE/load-forwarding non-goal wording with reopening criteria if Binaryen expands the pass in a future release;
- unreachable constructor/set no-fold boundary coverage;
- local WAT/HOT exact-cast surface limits, including the descriptor exact `ref.cast` blocker recorded in `0789`.
