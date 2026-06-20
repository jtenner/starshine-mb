---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0820-2026-06-20-heap-store-optimization-memory-size-data-segment-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` memory.grow / data-segment swap boundaries

Question: after `0820` showed that Binaryen keeps `struct.set` when a constructor `memory.size` operand would cross `memory.init` or `data.drop`, does Binaryen apply the same no-fold boundary to a side-effecting constructor `memory.grow` operand?

## Answer

Yes. Local Binaryen `version_130` probes kept the later `struct.set` for both shapes:

- a constructor `memory.grow` operand before an intervening `memory.init`; and
- a constructor `memory.grow` operand before an intervening `data.drop`.

This extends the same-kind memory/data-segment boundary from a non-trapping memory read (`memory.size`) to a side-effecting memory growth operand (`memory.grow`). Starshine already matched both boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Memory-init probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (data $d "x")
  (func (export "f") (result i32)
    (local $s (ref null $pair))
    (memory.grow (i32.const 1))
    (i32.const 2)
    (struct.new $pair)
    (local.set $s)
    (memory.init $d (i32.const 0) (i32.const 0) (i32.const 1))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Data-drop probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (data $d "x")
  (func (export "f") (result i32)
    (local $s (ref null $pair))
    (memory.grow (i32.const 1))
    (i32.const 2)
    (struct.new $pair)
    (local.set $s)
    (data.drop $d)
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-grow-memory-init-blocker.wat \
  -o .tmp/hso-slice-probe/memory-grow-memory-init-blocker.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-grow-data-drop-blocker.wat \
  -o .tmp/hso-slice-probe/memory-grow-data-drop-blocker.opt.wat
```

Observed result: both optimized outputs preserved the constructor `memory.grow` operand, the intervening `memory.init` / `data.drop` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory-growing constructors before memory.init`
- `heap-store-optimization keeps memory-growing constructors before data.drop`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor `memory.grow` operand across memory bulk / passive data-segment operations.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 113, passed: 113, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` swap legality coverage for memory bulk / passive data-segment boundaries from `memory.size` to `memory.grow` constructor operands.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper drift.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
