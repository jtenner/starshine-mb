# Heap-store-optimization nested try_table global-set coverage

Date: 2026-06-21

## Question

After `0927` fixed the block-wrapped non-throwing `try_table` / unrelated `global.set` swap gap, do additional inert block wrappers around the same `try_table` body still match Binaryen `version_130` for constructor-operand movement?

## Scope

This is a focused HSO-G coverage slice for the exact shape:

- constructor field operand: `memory.size` or `table.size`;
- fresh `struct.new` stored in a local;
- intervening `block(block(try_table ...))` wrapper;
- `try_table` body only performs an unrelated mutable `global.set` and does not throw;
- later `struct.set` writes the same fresh struct field.

It does not claim coverage for throwing `try_table` bodies, catch-taken paths, typed branch results, descriptor `br_on_non_null`, or same-effect memory/table roots.

## Finding

Starshine already matched the Binaryen behavior for both memory and table constructor operands. The pass folds the later `struct.set` into the fresh constructor while preserving the nested block / `try_table` / `global.set` wrapper side effect.

This extends the `0927` fixed family from one block wrapper to nested inert block wrappers. It is coverage-only; no implementation change was needed.

## Tests

Added focused encoded-wasm tests in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds memory.size constructors across nested non-throwing try_table global stores`
- `heap-store-optimization folds table.size constructors across nested non-throwing try_table global stores`

Both assert the optimized function keeps the constructor operand and `try_table` / `global.set`, and removes the redundant `struct.set`.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'nested non-throwing try_table global stores'` — `345/345` passed.

## Reopening criteria

Reopen HSO-G for this subfamily if a future Binaryen release preserves the later `struct.set`, if Starshine drops or misorders the `try_table` / `global.set` side effect, or if additional `try_table` body effects/catches are claimed under this narrow note without separate probes and tests.
