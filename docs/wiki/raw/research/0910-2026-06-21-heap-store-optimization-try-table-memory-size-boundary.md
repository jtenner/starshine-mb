# `heap-store-optimization` try_table memory-size/table-store boundary

Question: does Binaryen `version_130` let a `memory.size` constructor operand cross a `try_table` wrapper whose body performs a cross-family `table.set`, matching the block/if/loop/br_table wrapper positives?

## Answer

No. Binaryen preserves the constructor `memory.size`, the `try_table` / `table.set` wrapper, and the later `struct.set`. Starshine already matched this no-fold boundary, so this slice is behavior-parity coverage, not an implementation change.

This is a narrow `try_table` wrapper boundary. It does not supersede the existing block/if/loop/br_table cross-family ordinary-store positives, and it is not a generic statement that all wrappers block swaps.

## Evidence

Local oracle:

- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- Probe file: `.tmp/hso-probe-try-table-cross-store.wat`.
- Command: `wasm-opt --all-features --heap-store-optimization .tmp/hso-probe-try-table-cross-store.wat -S -o .tmp/hso-probe-try-table-cross-store.opt.wat`.
- Grep of the optimized output showed `memory.size`, `try_table`, `table.set`, and `struct.set` all preserved in `$memory_size_table_store`.

Focused Starshine coverage:

- `src/passes/heap_store_optimization_test.mbt` adds `heap-store-optimization keeps memory.size constructors before try_table-wrapped table stores`.
- The test checks that the optimized function still contains `memory.size`, `try_table`, `table.set`, and `struct.set`.

Validation:

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `269/269` after adding both try-table wrapper tests in this recursion.

## Classification

Binaryen behavior-parity negative/boundary. Not a Starshine win and not an accepted non-goal.

Reopen if Binaryen changes `trySwap(...)` / CFG wrapper handling to fold across catchless or catch-all `try_table` wrappers, or if Starshine starts folding this shape without a source-backed better-than-Binaryen argument.
