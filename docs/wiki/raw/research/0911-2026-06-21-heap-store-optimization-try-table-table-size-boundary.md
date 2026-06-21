# `heap-store-optimization` try_table table-size/memory-store boundary

Question: does Binaryen `version_130` let a `table.size` constructor operand cross a `try_table` wrapper whose body performs a cross-family `i32.store`, matching the block/if/loop/br_table wrapper positives?

## Answer

No. Binaryen preserves the constructor `table.size`, the `try_table` / `i32.store` wrapper, and the later `struct.set`. Starshine already matched this no-fold boundary, so this slice is behavior-parity coverage, not an implementation change.

This is the table-side counterpart to `0910`. It narrows the remaining HSO-G wrapper surface by showing that `try_table` behaves as a no-fold boundary in this cross-family ordinary-store wrapper shape, unlike the already-covered `br_table` wrapper positives.

## Evidence

Local oracle:

- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- Probe file: `.tmp/hso-probe-try-table-cross-store.wat`.
- Command: `wasm-opt --all-features --heap-store-optimization .tmp/hso-probe-try-table-cross-store.wat -S -o .tmp/hso-probe-try-table-cross-store.opt.wat`.
- Grep of the optimized output showed `table.size`, `try_table`, `i32.store`, and `struct.set` all preserved in `$table_size_memory_store`.

Focused Starshine coverage:

- `src/passes/heap_store_optimization_test.mbt` adds `heap-store-optimization keeps table.size constructors before try_table-wrapped memory stores`.
- The test checks that the optimized function still contains `table.size`, `try_table`, `i32.store`, and `struct.set`.

Validation:

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `269/269` after adding both try-table wrapper tests in this recursion.

## Classification

Binaryen behavior-parity negative/boundary. Not a Starshine win and not an accepted non-goal.

Reopen if Binaryen changes `trySwap(...)` / CFG wrapper handling to fold across catchless or catch-all `try_table` wrappers, or if Starshine starts folding this shape without a source-backed better-than-Binaryen argument.
