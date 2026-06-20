---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ./0822-2026-06-20-heap-store-optimization-table-grow-elem-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` table.grow / table-bulk swap boundaries

Question: after `0821` showed that Binaryen keeps `struct.set` when a constructor `table.size` operand would cross passive element roots, and `0822` showed the side-effecting `table.grow` counterpart for `table.init` / `elem.drop`, does Binaryen also keep the same no-fold boundary for `table.grow` across table-bulk writes?

## Answer

Yes. Local Binaryen `version_130` probes kept the later `struct.set` for both shapes:

- a constructor `table.grow` operand before an intervening `table.fill`; and
- a constructor `table.grow` operand before an intervening `table.copy`.

This extends the same-kind table boundary matrix beyond `table.init`, `elem.drop`, and `table.set`: side-effecting `table.grow` operands also do not cross table-bulk writes. Starshine already matched both new boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Table-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table 10 funcref)
  (func (export "f") (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (table.grow (ref.null func) (i32.const 1))
        (i32.const 2)))
    (table.fill (i32.const 0) (ref.null func) (i32.const 1))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Table-copy probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table 10 funcref)
  (func (export "f") (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (table.grow (ref.null func) (i32.const 1))
        (i32.const 2)))
    (table.copy (i32.const 0) (i32.const 4) (i32.const 1))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-grow-table-fill-blocker.wat \
  -o .tmp/hso-slice-probe/table-grow-table-fill-blocker.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-grow-table-copy-blocker.wat \
  -o .tmp/hso-slice-probe/table-grow-table-copy-blocker.opt.wat
```

Observed result: both optimized outputs preserved the constructor `table.grow` operand, the intervening `table.fill` / `table.copy` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps table-growing constructors before table.fill`
- `heap-store-optimization keeps table-growing constructors before table.copy`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor `table.grow` operand across table-bulk writes.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 117, passed: 117, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` swap legality coverage for table-bulk boundaries from passive element roots to `table.fill` / `table.copy` with a side-effecting `table.grow` constructor operand.
- Together with `0818`, `0821`, and `0822`, records that the probed same-kind table roots (`table.set`, `table.init`, `elem.drop`, `table.fill`, and `table.copy`) block folding for table-observing or table-growing constructor operands, matching Binaryen.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper drift.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
