---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0783-2026-06-20-heap-store-optimization-swap-memory-and-pingpong.md
  - ./0801-2026-06-20-heap-store-optimization-table-grow-swap.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` memory-grow swap coverage

Question: does Starshine match Binaryen `version_130` when `trySwap(...)` moves a fresh-struct `local.set` whose constructor includes a memory-growing operand across an unrelated mutable-global write to reach a later `struct.set`?

## Answer

Yes. A local Binaryen `version_130` probe shows that `memory.grow` in the constructor operand does not block swapping the fresh local assignment across an unrelated `global.set`; Binaryen preserves the `memory.grow` and `global.set` side effects, moves the global write before the fresh local assignment, folds the later value into `struct.new`, and removes the redundant `struct.set`.

Starshine already matched this behavior. This is a coverage-only HSO-G slice that narrows the remaining swap operand/effect surface beyond the prior `memory.size`, `table.size`, and `table.grow` coverage.

## Binaryen probe

Probe input:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (global $g (mut i32) (i32.const 0))
  (func (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.grow (i32.const 1))
        (i32.const 2)))
    (global.set $g (i32.const 9))
    (struct.set $pair 1
      (local.get $x)
      (i32.const 7))
    (struct.get $pair 1 (local.get $x)))
)
```

Command:

```sh
mkdir -p .tmp/hso-memory-grow-probe
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-memory-grow-probe/memory-grow-global-set.wat \
  -o .tmp/hso-memory-grow-probe/memory-grow-global-set.opt.wat
```

Observed output moves the unrelated global write before the fresh local assignment, preserves `memory.grow`, and removes the later `struct.set`:

```wat
(global.set $g
 (i32.const 9)
)
(nop)
(local.set $x
 (struct.new $pair
  (memory.grow
   (i32.const 1)
  )
  (i32.const 7)
 )
)
```

## Local change

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds memory.grow constructor operands across unrelated global.set`

The test keeps both `memory.grow` and `global.set` observable in the optimized body and asserts that the redundant `struct.set` disappears.

## Evidence

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 86, passed: 86, failed: 0.
```

No implementation code changed in this slice, so no native rebuild or direct 10000-case compare was required for behavior signoff. This is source/probe-backed coverage for behavior that Starshine already matched.

## Remaining HSO-G work

This narrows the memory/table effect part of HSO-G, but the audit remains open for broader swap operands/effects, constructor ping-pong variants, and HOT wrapper peeling/flattening drift.
