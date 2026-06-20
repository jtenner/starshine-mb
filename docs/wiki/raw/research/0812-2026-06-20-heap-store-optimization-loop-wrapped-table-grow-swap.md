---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0811-2026-06-20-heap-store-optimization-loop-wrapped-memory-grow-swap.md
  - ./0810-2026-06-20-heap-store-optimization-loop-wrapped-table-size-swap.md
  - ./0808-2026-06-20-heap-store-optimization-if-wrapped-table-grow-swap.md
  - ./0805-2026-06-20-heap-store-optimization-block-wrapped-table-grow-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` loop-wrapped table-grow swap coverage

Question: does Binaryen `version_130` allow `trySwap(...)` to move a fresh `local.set(struct.new ...)` whose constructor operand is `table.grow` across a loop-wrapped unrelated mutable `global.set` to reach a later `struct.set`?

## Answer

Yes. A local Binaryen `version_130` probe folded the later `struct.set` when the intervening blocker was a single-entry `loop` whose body contains only an unrelated mutable `global.set`. The optimized output preserved the loop-wrapped global write, preserved `table.grow`, rebuilt the constructor after the loop, and folded the later field value into `struct.new`.

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
        (table.grow (ref.null func) (i32.const 1))
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
  .tmp/hso-slice-probe/table-grow-loop-global-set.wat \
  -o .tmp/hso-slice-probe/table-grow-loop-global-set.opt.wat
```

Observed output retained the `loop` and `global.set`, removed the later `struct.set`, and rebuilt the fresh constructor as `struct.new $pair (table.grow (ref.null func) (i32.const 1)) (i32.const 7)` after the loop. This reorders `table.grow` after the unrelated global write, matching Binaryen's directional `trySwap(...)` legality for this side-effect combination.

## Local coverage

Added focused test:

- `heap-store-optimization folds table.grow constructor operands across loop-wrapped global.set`

The test builds a table+global fixture with a loop-wrapped `global.set` between the fresh constructor local assignment and the later store, runs the direct pass, and asserts that `table.grow`, `loop`, and `global.set` remain while `struct.set` is removed.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 96, passed: 96, failed: 0.
```

## Audit impact

- Narrows `[O4Z-AUDIT-HSO-G]` around HOT wrapper peeling / wrapper-root swap drift: a branchless loop-wrapped unrelated global write does not block Binaryen's swap when the constructor operand is `table.grow`.
- Complements direct, block-wrapped, and if-wrapped `table.grow` coverage from `0801`, `0805`, and `0808`, plus loop-wrapped `table.size` / `memory.grow` coverage from `0810` and `0811`.
- Confirms Starshine's loop-wrapper traversal reaches the same behavior while preserving loop control, table-growth, and global side effects.
- No direct compare or native rebuild was run because this was coverage-only documentation of behavior Starshine already matched.

Remaining HSO-G work still includes broader swap operands/effects, constructor ping-pong variants, and additional HOT wrapper peeling drift. HSO-B still needs saved early/late O4z slot or neighborhood evidence before final closeout.
