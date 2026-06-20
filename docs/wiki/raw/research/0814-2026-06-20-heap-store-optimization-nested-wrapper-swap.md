---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0813-2026-06-20-heap-store-optimization-wrapped-constructor-pingpong.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` nested wrapper swap coverage

Question: after covering direct `block`, `if`, and branchless `loop` wrappers around unrelated mutable `global.set` roots, does Binaryen `version_130` still fold when the global write is inside mixed nested wrappers?

## Answer

Yes. Local Binaryen `version_130` probes folded a later `struct.set` into a fresh constructor when a `memory.grow` constructor operand had to move across unrelated mutable `global.set` roots nested as:

- `block` containing `if`;
- `if` containing `block`;
- branchless `loop` containing `block`.

The optimized outputs preserved the wrapper side effects and removed the later `struct.set`. Starshine already matched this behavior, so this slice added focused coverage only and did not change HSO implementation code.

## Binaryen probes

Representative mixed-wrapper source:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (global $g (mut i32) (i32.const 0))
  (func $block_if (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.grow 0 (i32.const 1))
        (i32.const 2)))
    (block
      (if (i32.const 1)
        (then (global.set $g (i32.const 9)))))
    (struct.set $pair 1
      (local.get $x)
      (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/mixed-wrapped-memory-grow-global-set.wat \
  -o .tmp/hso-slice-probe/mixed-wrapped-memory-grow-global-set.opt.wat
```

A simpler nested-block probe was also run:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/nested-wrapper-global-set.wat \
  -o .tmp/hso-slice-probe/nested-wrapper-global-set.opt.wat
```

Observed output for the mixed-wrapper probe retained `global.set` inside the wrapper structures and rebuilt the constructor with the final field value, leaving no `struct.set` in `$block_if`, `$if_block`, or `$loop_block`.

## Local coverage

Added focused test:

- `heap-store-optimization folds memory.grow constructor operands across nested wrapped global.set`

The test covers the same mixed wrapper classes as the Binaryen probe and checks that Starshine preserves `memory.grow` and `global.set` while removing `struct.set`.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 98, passed: 98, failed: 0.
```

## Audit impact

- Narrows `[O4Z-AUDIT-HSO-G]` wrapper drift: nested mixed `block` / `if` / branchless `loop` wrappers around unrelated mutable global writes are now source/probe-backed Binaryen folds and locally covered.
- Keeps HSO-G open for broader swap operands/effects and any remaining wrapper families not yet probed.
- No native rebuild or direct compare was run because this was coverage-only documentation of behavior Starshine already matched.
