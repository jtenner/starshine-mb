---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0844-2026-06-20-heap-store-optimization-cross-family-store-swap.md
  - ./0845-2026-06-20-heap-store-optimization-br-table-swap-wrappers.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO `br_table` table-side memory-store wrappers

Question: does Binaryen `version_130` treat table-observing constructor operands crossing `br_table`-ending memory-store wrappers like the already-covered `memory.size` / `table.set` wrapper surface?

## Answer

Binaryen distinguishes readonly table observation from side-effecting table growth:

- Binaryen folds a fresh-struct store when a constructor `table.size` operand crosses a `block` root that performs an ordinary `i32.store` and exits through `br_table`.
- Binaryen keeps the later `struct.set` when a constructor `table.grow` operand would need to cross a `block` root that performs an `i32.store` and exits through `br_table`.
- Starshine already matched both observed behaviors. This slice added focused coverage only; no implementation code changed.

This narrows HSO-G's remaining `trySwap(...)` wrapper/effect matrix: `br_table` wrappers do not by themselves block crossing unrelated ordinary stores, but side-effecting growth operands remain more conservative than readonly size operands even when the intervening store is from the other memory/table family.

## Binaryen probes

Local oracle:

```text
wasm-opt version 130 (version_130)
```

Probe commands:

```sh
wasm-opt --all-features --heap-store-optimization -S .tmp/hso-br-table-wrapper-probe3/table-size-i32-store-br-table.wat -o .tmp/hso-br-table-wrapper-probe3/table-size-i32-store-br-table.opt.wat
wasm-opt --all-features --heap-store-optimization -S .tmp/hso-br-table-wrapper-probe3/table-grow-i32-store-br-table.wat -o .tmp/hso-br-table-wrapper-probe3/table-grow-i32-store-br-table.opt.wat
grep -E 'table.size|table.grow|i32.store|struct.set|struct.new|br_table' .tmp/hso-br-table-wrapper-probe3/table-size-i32-store-br-table.opt.wat
grep -E 'table.size|table.grow|i32.store|struct.set|struct.new|br_table' .tmp/hso-br-table-wrapper-probe3/table-grow-i32-store-br-table.opt.wat
```

Observed optimized markers:

```text
--- table.size ---
   (i32.store
   (br_table $exit $exit
   (struct.new $pair
    (table.size $t)
--- table.grow ---
   (struct.new $pair
    (table.grow $t
   (i32.store
   (br_table $exit $exit
  (struct.set $pair 1
```

Interpretation:

- The `table.size` / `i32.store` wrapper preserved the memory store and `br_table`, removed `struct.set`, and folded the later field value into `struct.new`.
- The `table.grow` / `i32.store` wrapper preserved `table.grow`, `i32.store`, `br_table`, and `struct.set`.

## Starshine coverage

Added focused tests in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds table.size constructors across br_table-wrapped memory stores`
- `heap-store-optimization keeps table-growing constructors before br_table-wrapped memory stores`

The first test covers the table-side counterpart to the prior cross-family ordinary-store `br_table` positive. The second locks the observed side-effecting growth no-fold boundary for the same wrapper/store shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 199, passed: 199, failed: 0.
```

No native rebuild or direct compare was run because this was coverage-only and changed no implementation behavior.

## Follow-up

HSO-G remains open. Remaining work should either gather exact early/late O4z slot evidence for HSO-B, or probe a truly distinct unresolved behavior family such as broader in-function branch/catch negatives, arbitrary descriptor operands, or another source-backed swap effect family that is not only a wrapper variant of already-covered roots.
