# `heap-store-optimization` try_table growth-root boundary

Question: does Binaryen `version_130` let `memory.size` / `table.size` constructor operands cross `try_table` wrappers whose bodies perform cross-family growth roots (`table.grow` / `memory.grow`)?

## Answer

No. Binaryen preserves the constructor `memory.size` before `try_table` / `table.grow`, preserves the constructor `table.size` before `try_table` / `memory.grow`, and keeps the later `struct.set` in both functions. Starshine already matched these no-fold boundaries, so this slice is behavior-parity coverage, not an implementation change.

This narrows the earlier direct cross-family growth positive from `0888`: direct `memory.size` across `table.grow` and direct `table.size` across `memory.grow` fold, but the probed `try_table`-wrapped growth roots do not.

## Evidence

Local oracle:

- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- Probe file: `.tmp/hso-probe-try-table-more.wat`.
- Command: `wasm-opt --all-features --heap-store-optimization .tmp/hso-probe-try-table-more.wat -S -o .tmp/hso-probe-try-table-more.opt.wat`.
- Grep of the optimized output showed `memory.size`, `try_table`, `table.grow`, and `struct.set` all preserved in `$memory_size_table_grow`.
- The same grep showed `table.size`, `try_table`, `memory.grow`, and `struct.set` all preserved in `$table_size_memory_grow`.

Focused Starshine coverage:

- `src/passes/heap_store_optimization_test.mbt` adds `heap-store-optimization keeps memory.size constructors before try_table-wrapped table.grow`.
- `src/passes/heap_store_optimization_test.mbt` adds `heap-store-optimization keeps table.size constructors before try_table-wrapped memory.grow`.
- The tests check that optimized functions still contain the constructor root, `try_table`, the cross-family growth root, and `struct.set`.

Validation:

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `273/273` after adding this focused coverage.

## Classification

Binaryen behavior-parity negative/boundary. Not a Starshine win and not an accepted non-goal.

Reopen if Binaryen changes `trySwap(...)` / CFG wrapper handling to fold across these `try_table` growth-root shapes, or if Starshine starts folding this shape without a source-backed better-than-Binaryen argument.
