---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` table.size / element-segment swap boundaries

Question: after `0818` showed that Binaryen keeps `struct.set` when a constructor `table.size` operand would cross `table.set`, does the same no-fold boundary apply to table bulk / passive element roots such as `table.init` and `elem.drop`?

## Answer

Yes. Local Binaryen `version_130` probes kept the later `struct.set` for both shapes:

- a constructor `table.size` operand before an intervening `table.init`; and
- a constructor `table.size` operand before an intervening `elem.drop`.

The `table.init` result matches the same-kind table read/write boundary from `0818`. The `elem.drop` result is a useful granularity detail: even though the root mutates a passive element segment rather than table contents, Binaryen `version_130` still does not fold the later store through it in this shape. Starshine already matched both boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Table-init probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (type $f (func))
  (func $g)
  (table $t 4 funcref)
  (elem $e func $g)
  (func (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (table.size $t)
        (i32.const 0)))
    (table.init $t $e (i32.const 0) (i32.const 0) (i32.const 1))
    (struct.set $pair 1 (local.get $s) (i32.const 42))
    (i32.const 0))
)
```

Elem-drop probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (type $f (func))
  (func $g)
  (table $t 4 funcref)
  (elem $e func $g)
  (func (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (table.size $t)
        (i32.const 0)))
    (elem.drop $e)
    (struct.set $pair 1 (local.get $s) (i32.const 42))
    (i32.const 0))
)
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-size-table-init-blocker.wat \
  -o .tmp/hso-slice-probe/table-size-table-init-blocker.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-size-elem-drop-blocker.wat \
  -o .tmp/hso-slice-probe/table-size-elem-drop-blocker.opt.wat
```

Observed result: both optimized outputs preserved the constructor `table.size` operand, the intervening `table.init` / `elem.drop` root, and the later `struct.set`.

## Local coverage

Added a passive-element test helper and focused tests:

- `heap-store-optimization keeps table.size constructors before table.init`
- `heap-store-optimization keeps table.size constructors before elem.drop`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor `table.size` operand across passive element-segment operations.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 109, passed: 109, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` swap legality coverage from `table.set` to table bulk / passive element-segment operations.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper drift.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
