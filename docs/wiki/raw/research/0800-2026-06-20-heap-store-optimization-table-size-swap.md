---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0783-2026-06-20-heap-store-optimization-swap-memory-and-pingpong.md
  - ./0799-2026-06-20-heap-store-optimization-final-root-no-swap.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` table-size swap coverage

Question: does Starshine match Binaryen `version_130` when `trySwap(...)` must move a fresh-struct `local.set` with a table-size constructor operand across an unrelated mutable-global write to reach a later `struct.set`?

## Answer

Yes. A local Binaryen `version_130` probe shows that a readonly `table.size` constructor operand does not block the fresh local assignment from being swapped past an unrelated `global.set`; Binaryen then folds the later `struct.set` value into the constructor. Starshine already matched this behavior, and this slice promoted the probe into focused coverage.

This is a coverage-only HSO-G slice. It narrows the pending "table combinations" swap work by covering the table-size constructor-operand side of the same directionality family previously covered for `memory.size`.

## Binaryen probe

Probe input:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (global $g (mut i32) (i32.const 0))
  (table 1 funcref)
  (func $f (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size 0)
        (i32.const 2)))
    (global.set $g (i32.const 3))
    (struct.set $pair 1
      (local.get $x)
      (i32.const 7))
    (struct.get $pair 1 (local.get $x)))
  (export "f" (func $f)))
```

Command:

```sh
mkdir -p .tmp/hso-table-swap-probe
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-table-swap-probe/table-size-global-set.wat \
  -o .tmp/hso-table-swap-probe/table-size-global-set.opt.wat
```

Observed output moves the unrelated global write before the fresh local assignment and removes the later `struct.set`:

```wat
(global.set $g
 (i32.const 3)
)
(nop)
(local.set $x
 (struct.new $pair
  (table.size $0)
  (i32.const 7)
 )
)
```

## Local change

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds table.size constructor operands across unrelated global.set`

The test uses a new table+global fixture helper, keeps both `table.size` and `global.set` observable in the optimized body, and asserts that the redundant `struct.set` disappears.

## Evidence

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 84, passed: 84, failed: 0.
```

No implementation code changed in this slice, so no native rebuild or direct 10000-case compare was required for behavior signoff. This is source/probe-backed coverage for behavior that Starshine already matched.

## Remaining HSO-G work

This narrows the table-combination part of HSO-G, but the audit remains open for broader swap operands/effects, additional constructor ping-pong variants, trapping table-effect negatives such as `table.grow` if Binaryen probes expose them cleanly, and HOT wrapper peeling/flattening drift.
