---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0791-2026-06-20-heap-store-optimization-memory-table-swap.md
  - ./0801-2026-06-20-heap-store-optimization-table-grow-swap.md
  - ./0802-2026-06-20-heap-store-optimization-memory-grow-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` growth/store swap boundaries

Question: after proving Binaryen crosses ordinary memory/table store blockers when the fresh constructor has no ordered operand effects, does `version_130` still refuse to fold when crossing the blocker would move a growth operation past the same storage kind?

## Answer

Yes. Local Binaryen `version_130` probes kept the later `struct.set` when folding would require moving:

- a constructor `memory.grow` operand after an intervening `i32.store`; or
- a constructor `table.grow` operand after an intervening `table.set`.

This narrows the `0791` ordinary-store finding: Binaryen can cross ordinary memory/table store roots for constructors with no ordered memory/table operand effects, but growth operands are real same-kind ordering barriers. Starshine already matched these no-fold boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Memory-growth probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.grow (i32.const 1))
        (i32.const 2)))
    (i32.store (i32.const 0) (i32.const 9))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x)))
)
```

Table-growth probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table 2 funcref)
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.grow (ref.null func) (i32.const 1))
        (i32.const 2)))
    (table.set (i32.const 0) (ref.null func))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x)))
)
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-grow-memory-store-blocker.wat \
  -o .tmp/hso-slice-probe/memory-grow-memory-store-blocker.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-grow-table-set-blocker.wat \
  -o .tmp/hso-slice-probe/table-grow-table-set-blocker.opt.wat
```

Observed result: both optimized outputs preserved the constructor growth operand, the intervening store root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory-growing constructors before memory stores`
- `heap-store-optimization keeps table-growing constructors before table stores`

These tests check that Starshine keeps `struct.set` when a fold would move a same-kind growth operand across a memory/table store.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 100, passed: 100, failed: 0.
```

## Audit impact

- Narrows `[O4Z-AUDIT-HSO-G]` swap legality around ordinary store blockers: ordinary stores are crossable only when the constructor operand effects do not require same-kind ordering.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, wrapper drift, and any additional same-kind barrier variants not yet probed.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior Starshine already matched.
