---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0803-2026-06-20-heap-store-optimization-call-swap-negative.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` block-wrapped swap coverage

Question: does Binaryen `version_130` allow `trySwap(...)` to move a fresh `local.set(struct.new ...)` whose constructor operand is `memory.size` across a block-wrapped unrelated mutable `global.set` to reach a later `struct.set`?

## Answer

Yes. A local Binaryen `version_130` probe folded the later `struct.set` when the intervening blocker was a `block` whose body only performed an unrelated mutable `global.set`. The optimized output preserved the block-wrapped global write, moved the constructor local assignment after that block, and folded the later field value into `struct.new`.

Starshine already matched the Binaryen behavior. This slice added focused coverage only; no implementation code changed.

## Binaryen probe

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (global $g (mut i32) (i32.const 0))
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size)
        (i32.const 2)))
    (block
      (global.set $g (i32.const 9)))
    (struct.set $pair 1
      (local.get $x)
      (i32.const 42))
    (struct.get $pair 1 (local.get $x)))
)
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-block-swap-probe/memory-size-block-global-set-field1.wat \
  -o .tmp/hso-block-swap-probe/memory-size-block-global-set-field1.opt.wat
```

Observed output retained the `block (global.set ...)`, removed the later `struct.set`, and rebuilt the fresh constructor as `struct.new $pair (memory.size) (i32.const 42)` after the block.

## Local coverage

Added focused test:

- `heap-store-optimization folds memory.size constructor operands across block-wrapped global.set`

The test builds a memory+global fixture with a block-wrapped `global.set` between the fresh constructor local assignment and the later store, runs the direct pass, and asserts that `memory.size` and `global.set` remain while `struct.set` is removed.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 88, passed: 88, failed: 0.
```

## Audit impact

- Narrows `[O4Z-AUDIT-HSO-G]` around HOT wrapper peeling / block-root swap drift: a block-wrapped unrelated global write does not block Binaryen's swap when the constructor operand is a reorderable `memory.size`.
- Confirms Starshine's wrapper/flattening path reaches the same behavior while preserving the block's side effect.
- No direct compare or native rebuild was run because this was coverage-only documentation of behavior Starshine already matched.

Remaining HSO-G work still includes broader swap operands/effects and constructor ping-pong variants. HSO-B still needs saved early/late O4z slot or neighborhood evidence before final closeout.
