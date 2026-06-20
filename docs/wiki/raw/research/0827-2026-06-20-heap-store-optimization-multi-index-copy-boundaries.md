---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ./0825-2026-06-20-heap-store-optimization-table-grow-bulk-boundaries.md
  - ./0826-2026-06-20-heap-store-optimization-multi-index-bulk-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` multi-index memory/table copy boundaries

Question: after `0826` showed that Binaryen keeps `struct.set` when a constructor `memory.size` / `table.size` observes one memory/table and an intervening bulk fill writes a different memory/table, does the same no-fold boundary apply to copy roots with different memory/table indices?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` when the constructor observed one memory/table and the intervening copy root copied within a different memory/table:

- `memory.size $ma` before `memory.copy $mb $mb`; and
- `table.size $ta` before `table.copy $tb $tb`.

Starshine already matched both boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Different-memory copy probe:

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
    (memory.copy $mb $mb (i32.const 0) (i32.const 4) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Different-table copy probe:

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
    (table.copy $tb $tb (i32.const 0) (i32.const 0) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-size-memory-copy-different-memory.wat \
  -o .tmp/hso-slice-probe/memory-size-memory-copy-different-memory.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-size-table-copy-different-table.wat \
  -o .tmp/hso-slice-probe/table-size-table-copy-different-table.opt.wat
```

Observed result: both optimized outputs preserved the constructor `memory.size` / `table.size` operand, the intervening `memory.copy` / `table.copy` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before different-memory copy`
- `heap-store-optimization keeps table.size constructors before different-table copy`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor memory/table-size operand across a copy root on a different memory/table index.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 121, passed: 121, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` same-effect-family swap legality coverage from cross-index bulk fills to cross-index bulk copies.
- Documents that Binaryen `version_130` does not prove the probed cross-index copy roots safe for HSO folding; the pass keeps the later `struct.set` rather than treating different memories/tables as independently reorderable for these effects.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, additional wrapper drift, and any unprobed multi-index roots.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
