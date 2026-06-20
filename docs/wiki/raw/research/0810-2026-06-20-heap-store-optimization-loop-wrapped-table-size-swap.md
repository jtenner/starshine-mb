---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0809-2026-06-20-heap-store-optimization-if-wrapped-table-size-swap.md
  - ./0804-2026-06-20-heap-store-optimization-block-wrapped-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` loop-wrapped table-size swap coverage

Question: does Binaryen `version_130` allow `trySwap(...)` to move a fresh `local.set(struct.new ...)` whose constructor operand is `table.size` across a loop-wrapped unrelated mutable `global.set` to reach a later `struct.set`?

## Answer

Yes. A local Binaryen `version_130` probe folded the later `struct.set` when the intervening blocker was a single-entry `loop` whose body contains only an unrelated mutable `global.set`. The optimized output preserved the loop-wrapped global write, preserved `table.size`, rebuilt the constructor after the loop, and folded the later field value into `struct.new`.

Starshine already matched this Binaryen behavior. This slice added focused coverage only; no HSO implementation code changed.

## Binaryen probe

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table 1 funcref)
  (global $g (mut i32) (i32.const 0))
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size 0)
        (i32.const 2)))
    (loop
      (global.set $g (i32.const 9)))
    (struct.set $pair 1
      (local.get $x)
      (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/table-size-loop-global-set.wat \
  -o .tmp/hso-slice-probe/table-size-loop-global-set.opt.wat
```

Observed output retained the `loop` and `global.set`, removed the later `struct.set`, and rebuilt the fresh constructor as `struct.new $pair (table.size $0) (i32.const 7)` after the loop.

## Local coverage

Added focused test:

- `heap-store-optimization folds table.size constructor operands across loop-wrapped global.set`

The test builds a table+global fixture with a loop-wrapped `global.set` between the fresh constructor local assignment and the later store, runs the direct pass, and asserts that `table.size`, `loop`, and `global.set` remain while `struct.set` is removed.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 94, passed: 94, failed: 0.
```

## Audit impact

- Narrows `[O4Z-AUDIT-HSO-G]` around HOT wrapper peeling / wrapper-root swap drift: a branchless loop-wrapped unrelated global write does not block Binaryen's swap when the constructor operand is reorderable `table.size`.
- Complements the direct `table.size` / unrelated `global.set` coverage from `0800`, the block-wrapped memory-size coverage from `0804`, and the if-wrapped table-size coverage from `0809`.
- Confirms Starshine's loop-wrapper traversal reaches the same behavior while preserving loop control and table/global side effects.
- No direct compare or native rebuild was run because this was coverage-only documentation of behavior Starshine already matched.

Remaining HSO-G work still includes broader swap operands/effects, constructor ping-pong variants, and additional HOT wrapper peeling drift. HSO-B still needs saved early/late O4z slot or neighborhood evidence before final closeout.
