---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0829-2026-06-20-heap-store-optimization-wrapped-bulk-fill-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` loop-wrapped bulk-fill boundaries

Question: after `0829` covered block/if wrappers around same-effect-family bulk fills, does Binaryen also keep the no-fold boundary when the intervening bulk root is wrapped in a branchless `loop`?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` for:

- `memory.size $m` before a loop-wrapped `memory.fill $m`; and
- `table.size $t` before a loop-wrapped `table.fill $t`.

Starshine already matched both boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Loop-wrapped memory-fill probe:

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
    (loop
      (memory.fill $m (i32.const 0) (i32.const 9) (i32.const 1)))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Loop-wrapped table-fill probe:

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
    (loop
      (table.fill $t (i32.const 0) (ref.null func) (i32.const 1)))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-loop-wrapper-probe/memory-size-loop-memory-fill.wat \
  -o .tmp/hso-loop-wrapper-probe/memory-size-loop-memory-fill.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-loop-wrapper-probe/table-size-loop-table-fill.wat \
  -o .tmp/hso-loop-wrapper-probe/table-size-loop-table-fill.opt.wat
```

Observed result: both optimized outputs preserved the constructor `memory.size` / `table.size` operand, the loop-wrapped `memory.fill` / `table.fill` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before loop-wrapped memory.fill`
- `heap-store-optimization keeps table.size constructors before loop-wrapped table.fill`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor memory/table-size operand across a branchless loop wrapper around a same-effect-family bulk fill root.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 131, passed: 131, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` wrapper drift coverage for same-effect-family bulk-fill barriers from `block` / `if` to branchless `loop` wrappers.
- Documents that Binaryen `version_130` still preserves the no-fold boundary when a loop wrapper surrounds `memory.fill` / `table.fill` and the constructor operand observes the same memory/table family.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, wrapper drift around copy roots, and final direct/O4z closeout evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
