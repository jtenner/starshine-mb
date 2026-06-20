---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
---

# `heap-store-optimization` table-size/table-store swap boundary

## Question

Does Binaryen `version_130` fold when a constructor operand is `table.size $ta`, an intervening root writes an unrelated table with `table.set $tb`, and the later `struct.set` targets the fresh struct?

This is a same-effect-family follow-up to `0815`, which covered `table.grow` not crossing `table.set` and `memory.grow` not crossing `i32.store`.

## Answer

No. A local `wasm-opt version_130` probe kept the later `struct.set` when the earlier constructor operand was `table.size` and the intervening root was `table.set`, even though the probe used different tables (`$ta` for the size read and `$tb` for the store).

Starshine already matched this Binaryen boundary. This slice added focused negative coverage only; no implementation code changed.

## Probe

Input shape:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $ta 1 funcref)
  (table $tb 1 funcref)
  (func $f (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size $ta)
        (i32.const 2)))
    (table.set $tb
      (i32.const 0)
      (ref.null func))
    (struct.set $pair 1
      (local.get $x)
      (i32.const 7))
    (struct.get $pair 1 (local.get $x)))
  (export "f" (func $f)))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-size-unrelated-table-set.wat \
  -o .tmp/hso-slice-probe/table-size-unrelated-table-set.opt.wat
```

Observed optimized evidence:

```text
(struct.new $pair
 (table.size $ta)
...
(table.set $tb
...
(struct.set $pair 1
```

The optimized output retained `struct.set`.

## Starshine coverage

Added focused test:

- `heap-store-optimization keeps table.size constructors before table stores`

The test constructs:

1. `struct.new(pair, table.size 0, i32.const 2)` assigned to the fresh local,
2. an intervening `table.set 0`,
3. a later `struct.set` to field 1 of the fresh local.

Expected behavior: preserve `table.size`, preserve `table.set`, and keep `struct.set` rather than moving the table-size read across the table write.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 103, passed: 103, failed: 0.
```

This was coverage-only. No native rebuild or direct 10000-case compare was required because no implementation behavior changed.

## Audit impact

- HSO-G swap legality now has a narrower same-family table boundary for `table.size` across `table.set`, complementing the `0815` `table.grow`/`table.set` no-swap boundary.
- The different-table probe suggests Binaryen's HSO swap check is conservative at table-effect family granularity here, not table-index-disjoint granularity.
- Broader swap operands/effects, additional wrapper variants, and final HSO-G closeout remain open.
