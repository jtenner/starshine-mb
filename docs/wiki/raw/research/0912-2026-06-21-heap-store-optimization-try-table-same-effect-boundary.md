# `heap-store-optimization` try_table same-effect boundary

Question: does Binaryen `version_130` let `memory.size` / `table.size` constructor operands cross `try_table` wrappers whose bodies perform same-effect-family bulk roots (`memory.fill` / `table.fill`)?

## Answer

No. Binaryen preserves the constructor `memory.size` before `try_table` / `memory.fill`, preserves the constructor `table.size` before `try_table` / `table.fill`, and keeps the later `struct.set` in both functions. Starshine already matched these no-fold boundaries, so this slice is behavior-parity coverage, not an implementation change.

This is a narrow `try_table` wrapper boundary for same-effect-family bulk roots. It does not supersede existing block/if/loop wrapper boundary coverage for bulk roots or the br_table/cross-family ordinary-store split.

## Evidence

Local oracle:

- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- Probe file: `.tmp/hso-probe-try-table-more.wat`.
- Command: `wasm-opt --all-features --heap-store-optimization .tmp/hso-probe-try-table-more.wat -S -o .tmp/hso-probe-try-table-more.opt.wat`.
- Grep of the optimized output showed `memory.size`, `try_table`, `memory.fill`, and `struct.set` all preserved in `$memory_size_memory_fill`.
- The same grep showed `table.size`, `try_table`, `table.fill`, and `struct.set` all preserved in `$table_size_table_fill`.

Focused Starshine coverage:

- `src/passes/heap_store_optimization_test.mbt` adds `heap-store-optimization keeps memory.size constructors before try_table-wrapped memory.fill`.
- `src/passes/heap_store_optimization_test.mbt` adds `heap-store-optimization keeps table.size constructors before try_table-wrapped table.fill`.
- The tests check that optimized functions still contain the constructor root, `try_table`, the same-effect bulk root, and `struct.set`.

Validation:

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `271/271` after adding this focused coverage.

## Classification

Binaryen behavior-parity negative/boundary. Not a Starshine win and not an accepted non-goal.

Reopen if Binaryen changes `trySwap(...)` / CFG wrapper handling to fold across these `try_table` same-effect bulk-root shapes, or if Starshine starts folding this shape without a source-backed better-than-Binaryen argument.
