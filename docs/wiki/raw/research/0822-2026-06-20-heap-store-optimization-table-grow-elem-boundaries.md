---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` table.grow / element-segment swap boundaries

Question: after `0821` showed that Binaryen keeps `struct.set` when a constructor `table.size` operand would cross `table.init` or `elem.drop`, does Binaryen apply the same no-fold boundary to a side-effecting constructor `table.grow` operand?

## Answer

Yes. Local Binaryen `version_130` probes kept the later `struct.set` for both shapes:

- a constructor `table.grow` operand before an intervening `table.init`; and
- a constructor `table.grow` operand before an intervening `elem.drop`.

This extends the same-kind table/elements boundary from a non-trapping table read (`table.size`) to a side-effecting table growth operand (`table.grow`). Starshine already matched both boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Table-init probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 1 funcref)
  (elem $e func $f)
  (func $f)
  (func (export "run") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.grow $t (ref.null func) (i32.const 1))
        (i32.const 2)))
    (table.init $t $e (i32.const 0) (i32.const 0) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Elem-drop probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 1 funcref)
  (elem $e func $f)
  (func $f)
  (func (export "run") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.grow $t (ref.null func) (i32.const 1))
        (i32.const 2)))
    (elem.drop $e)
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-grow-table-init-blocker.wat \
  -o .tmp/hso-slice-probe/table-grow-table-init-blocker.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-grow-elem-drop-blocker.wat \
  -o .tmp/hso-slice-probe/table-grow-elem-drop-blocker.opt.wat
```

Observed result: both optimized outputs preserved the constructor `table.grow` operand, the intervening `table.init` / `elem.drop` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps table-growing constructors before table.init`
- `heap-store-optimization keeps table-growing constructors before elem.drop`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor `table.grow` operand across table bulk / passive element-segment operations.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 111, passed: 111, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` swap legality coverage for table bulk / passive element-segment boundaries from `table.size` to `table.grow` constructor operands.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper drift.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
