---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0791-2026-06-20-heap-store-optimization-memory-table-swap.md
  - ./0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` memory.size / bulk-memory swap boundaries

Question: after proving Binaryen can cross ordinary memory/table store blockers when the fresh constructor has no ordered operand effects, does `version_130` fold a constructor `memory.size` operand across bulk-memory writes such as `memory.fill` or `memory.copy`?

## Answer

No. Local Binaryen `version_130` probes kept the later `struct.set` when folding would require moving a constructor `memory.size` operand after an intervening bulk-memory write:

- `memory.fill`; and
- `memory.copy`.

This further narrows the `0791` ordinary-memory/table-store finding. Binaryen may cross ordinary blockers for constructors without ordered memory/table effects, but a constructor operand that reads memory sizing remains ordered before bulk-memory writes in the current effect model. Starshine already matched these no-fold boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Memory-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size)
        (i32.const 2)))
    (memory.fill (i32.const 0) (i32.const 9) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x)))
)
```

Memory-copy probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size)
        (i32.const 2)))
    (memory.copy (i32.const 0) (i32.const 4) (i32.const 1))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x)))
)
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-size-memory-fill-blocker.wat \
  -o .tmp/hso-slice-probe/memory-size-memory-fill-blocker.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-size-memory-copy-blocker.wat \
  -o .tmp/hso-slice-probe/memory-size-memory-copy-blocker.opt.wat
```

Observed result: both optimized outputs preserved the constructor `memory.size` operand, the intervening bulk-memory root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before memory.fill`
- `heap-store-optimization keeps memory.size constructors before memory.copy`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor `memory.size` operand across bulk-memory writes.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 105, passed: 105, failed: 0.
```

## Audit impact

- Adds same-kind memory read/write bulk-memory boundaries to `[O4Z-AUDIT-HSO-G]` swap legality coverage.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper drift.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
