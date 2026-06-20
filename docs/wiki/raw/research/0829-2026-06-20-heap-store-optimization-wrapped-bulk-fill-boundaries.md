---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ./0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ./0826-2026-06-20-heap-store-optimization-multi-index-bulk-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` wrapped bulk-fill boundaries

Question: after the same-effect-family bulk boundaries in `0819`, `0821`, and `0826`, does Binaryen still keep `struct.set` when the intervening bulk root is wrapped in a shallow `block` or `if`?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` for:

- `memory.size $m` before a block-wrapped `memory.fill $m`;
- `memory.size $m` before an if-wrapped `memory.fill $m`;
- `table.size $t` before a block-wrapped `table.fill $t`; and
- `table.size $t` before an if-wrapped `table.fill $t`.

Starshine already matched all four boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Block-wrapped memory-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1)
  (func $test (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size $m)
        (i32.const 2)))
    (block
      (memory.fill $m (i32.const 0) (i32.const 9) (i32.const 1)))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

If-wrapped memory-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1)
  (func $test (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size $m)
        (i32.const 2)))
    (if (i32.const 1)
      (then (memory.fill $m (i32.const 0) (i32.const 9) (i32.const 1))))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Block-wrapped table-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 1 funcref)
  (func $test (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size $t)
        (i32.const 2)))
    (block
      (table.fill $t (i32.const 0) (ref.null func) (i32.const 1)))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

If-wrapped table-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 1 funcref)
  (func $test (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size $t)
        (i32.const 2)))
    (if (i32.const 1)
      (then (table.fill $t (i32.const 0) (ref.null func) (i32.const 1))))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Command shape:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-wrapper-probe/<probe>.wat \
  -o .tmp/hso-wrapper-probe/<probe>.opt.wat
```

Observed result: all four optimized outputs preserved the constructor `memory.size` / `table.size` operand, the wrapped `memory.fill` / `table.fill` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before block-wrapped memory.fill`
- `heap-store-optimization keeps memory.size constructors before if-wrapped memory.fill`
- `heap-store-optimization keeps table.size constructors before block-wrapped table.fill`
- `heap-store-optimization keeps table.size constructors before if-wrapped table.fill`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor memory/table-size operand across a shallow wrapper around a same-effect-family bulk fill root.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 129, passed: 129, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` wrapper drift coverage from wrapper-positive unrelated global writes to wrapper-negative same-effect-family bulk-fill barriers.
- Documents that Binaryen `version_130` still treats shallow wrappers around `memory.fill` / `table.fill` as preserving the no-fold boundary when the constructor operand observes the same memory/table family.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional wrapper variants.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
