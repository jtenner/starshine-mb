---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# Heap-store-optimization memory.fill old-field boundary

## Question

When a constructor field that will later be overwritten is a value-producing block whose observable work is `memory.fill`, and an intervening root writes an unrelated mutable global before the later `struct.set`, does Binaryen `version_130` preserve the old field and the later store instead of folding?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe file: `.tmp/hso-probe-fill-old-field.wat`.

Shape:

```wat
(func $memory_fill_old (result (ref $s))
  (local $x (ref null $s))
  (local.set $x
    (struct.new $s
      (block (result i32)
        (memory.fill (i32.const 0) (i32.const 0) (i32.const 1))
        (i32.const 1))
      (i32.const 2)))
  (global.set $g (i32.const 9))
  (struct.set $s 0 (local.get $x) (i32.const 7))
  (ref.as_non_null (local.get $x)))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-fill-old-field.wat --heap-store-optimization -S -o .tmp/hso-probe-fill-old-field.opt.wat
```

## Result

Binaryen preserved the constructor's old field block, preserved the intervening `global.set`, and kept the later `struct.set`. It did not fold the later store into the constructor.

Relevant optimized shape:

```wat
(local.set $x
  (struct.new $s
    (block (result i32)
      (memory.fill (i32.const 0) (i32.const 0) (i32.const 1))
      (i32.const 1))
    (i32.const 2)))
(global.set $g (i32.const 9))
(struct.set $s 0 (local.get $x) (i32.const 7))
```

## Classification

Binaryen behavior-parity negative / boundary.

This is not a Starshine-specific win. Starshine should match Binaryen by keeping the later `struct.set` when an overwritten old constructor field performs `memory.fill` before an intervening root write. This boundary is narrower than “all side-effectful old fields”: `memory.grow`, `table.grow`, unrelated `global.set`, `data.drop`, and `elem.drop` old fields have documented fold positives, while `i32.store`, `table.set`, and now `memory.fill` are documented no-fold boundaries in the probed unrelated-global-write shape.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps old field memory.fill before unrelated global write`

The test passed on first run, so this was coverage-only and did not require implementation changes.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# Total tests: 262, passed: 262, failed: 0.
```

## Durable conclusion

For old constructor fields that are overwritten by a later `struct.set`, `memory.fill` in a value-producing old-field block is a keep-store boundary under Binaryen `version_130` in the probed unrelated-global-write shape. HSO-D/G should count this as a covered old-field negative, not as a general side-effectful-old-field rule.

## Reopening criteria

Reopen if a future Binaryen release folds this shape, if a no-intervening-root or different-intervening-root probe proves a narrower split, or if Starshine starts folding/dropping/duplicating the `memory.fill` in this old-field boundary.
