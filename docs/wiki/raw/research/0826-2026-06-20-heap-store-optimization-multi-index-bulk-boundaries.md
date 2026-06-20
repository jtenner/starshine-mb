---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ./0825-2026-06-20-heap-store-optimization-table-grow-bulk-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` multi-index memory/table bulk boundaries

Question: after the same-kind memory/table boundary probes showed that Binaryen keeps `struct.set` when constructor operands such as `memory.size`, `table.size`, `memory.grow`, or `table.grow` would need to cross bulk roots, does Binaryen refine this by memory/table index for multi-memory or multi-table modules?

## Answer

No, not for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` even when the constructor observed one memory/table and the intervening bulk root wrote a different memory/table:

- `memory.size $ma` before an intervening `memory.fill $mb`; and
- `table.size $ta` before an intervening `table.fill $tb`.

This matches the earlier `0818` table-size/table-set result where Binaryen kept `struct.set` even with different table indices. Starshine already matched both new multi-index boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Different-memory probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $ma 1)
  (memory $mb 1)
  (func (export "run") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size $ma)
        (i32.const 2)))
    (memory.fill $mb (i32.const 0) (i32.const 9) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Different-table probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $ta 1 funcref)
  (table $tb 1 funcref)
  (func (export "run") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size $ta)
        (i32.const 2)))
    (table.fill $tb (i32.const 0) (ref.null func) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-size-memory-fill-different-memory.wat \
  -o .tmp/hso-slice-probe/memory-size-memory-fill-different-memory.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-size-table-fill-different-table.wat \
  -o .tmp/hso-slice-probe/table-size-table-fill-different-table.opt.wat
```

Observed result: both optimized outputs preserved the constructor `memory.size` / `table.size` operand, the intervening `memory.fill` / `table.fill` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before different-memory fill`
- `heap-store-optimization keeps table.size constructors before different-table fill`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor memory/table-size operand across a bulk write to a different memory/table index.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 119, passed: 119, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` swap legality coverage for same-effect-family boundaries to multi-memory and multi-table index variants.
- Documents that Binaryen `version_130` does not prove these two cross-index bulk-write cases safe for HSO folding; the pass keeps the later `struct.set` rather than treating different memories/tables as independently reorderable for these bulk effects.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, other multi-index roots, and additional HOT wrapper drift.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
