---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0826-2026-06-20-heap-store-optimization-multi-index-bulk-boundaries.md
  - ./0827-2026-06-20-heap-store-optimization-multi-index-copy-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` mixed-index memory/table copy boundaries

Question: after `0827` showed Binaryen keeps `struct.set` when a constructor `memory.size` / `table.size` would cross a same-index copy in a different memory/table, does the same no-fold boundary apply when only one copy endpoint uses the constructor-observed memory/table?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` for both mixed copy directions:

- `memory.size $ma` before `memory.copy $mb $ma`;
- `memory.size $ma` before `memory.copy $ma $mb`;
- `table.size $ta` before `table.copy $tb $ta`; and
- `table.size $ta` before `table.copy $ta $tb`.

Starshine already matched all four boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Mixed-destination memory copy probe:

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
    (memory.copy $mb $ma (i32.const 0) (i32.const 4) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Mixed-source memory copy probe:

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
    (memory.copy $ma $mb (i32.const 0) (i32.const 4) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Mixed-destination table copy probe:

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
    (table.copy $tb $ta (i32.const 0) (i32.const 0) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Mixed-source table copy probe:

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
    (table.copy $ta $tb (i32.const 0) (i32.const 0) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Command shape:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/<probe>.wat \
  -o .tmp/hso-slice-probe/<probe>.opt.wat
```

Observed result: all four optimized outputs preserved the constructor `memory.size` / `table.size` operand, the intervening `memory.copy` / `table.copy` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before mixed-destination memory copy`
- `heap-store-optimization keeps memory.size constructors before mixed-source memory copy`
- `heap-store-optimization keeps table.size constructors before mixed-destination table copy`
- `heap-store-optimization keeps table.size constructors before mixed-source table copy`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor memory/table-size operand across a copy root that has one endpoint on the observed memory/table and one endpoint on another memory/table.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 125, passed: 125, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` multi-index copy coverage from different-memory/table copies in `0827` to mixed source/destination endpoint copies.
- Documents that Binaryen `version_130` does not prove mixed-index copy roots safe for HSO folding; the pass keeps the later `struct.set` rather than treating one-endpoint overlap as reorderable for these effects.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, additional wrapper drift, and any unprobed multi-index roots.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
