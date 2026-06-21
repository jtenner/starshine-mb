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

# Heap-store-optimization data.drop old-field preservation

## Question

When a constructor field that will later be overwritten is a value-producing block whose only observable work is `data.drop`, does Binaryen `version_130` preserve that old-field side effect while still folding the later `struct.set` into `struct.new`?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe file: `.tmp/hso-probe-data-elem-drop-old-field.wat`.

Shape:

```wat
(func (export "data_drop") (result (ref $s))
  (local $x (ref null $s))
  (local.set $x
    (struct.new $s
      (block (result i32)
        (data.drop $d)
        (i32.const 1))
      (i32.const 2)))
  (struct.set $s 0
    (local.get $x)
    (i32.const 7))
  (ref.as_non_null (local.get $x)))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-data-elem-drop-old-field.wat --heap-store-optimization -S -o .tmp/hso-probe-data-elem-drop-old-field.opt.wat
```

## Result

Binaryen folded the later `struct.set` into the constructor field, replaced the root `struct.set` with `nop`, and preserved the old-field `data.drop` as a dropped value block inside the replacement constructor operand.

Relevant optimized shape:

```wat
(struct.new $s
  (block (result i32)
    (drop
      (block (result i32)
        (data.drop $d)
        (i32.const 1)))
    (i32.const 7))
  (i32.const 2))
(nop)
```

## Classification

Binaryen behavior-parity positive.

This is not a Starshine-specific win: Starshine should match Binaryen by folding the store and preserving `data.drop` exactly as old-field side-effect debris. This is the passive-data counterpart to the growth and global-write old-field positives, and it must not be conflated with the memory-store/table-store old-field no-fold boundaries from `0900` and `0901`.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization preserves old field data.drop when folding`

The test passed on first run, so this was coverage-only and did not require implementation changes.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# Total tests: 260, passed: 260, failed: 0.
```

## Durable conclusion

For old constructor fields that are overwritten by a later `struct.set`, `data.drop` inside a value-producing block is preserve-and-fold behavior under Binaryen `version_130`. HSO-D/G should count this as a covered old-field positive, not as an unsupported boundary.

## Reopening criteria

Reopen if a future Binaryen release preserves the `struct.set`, drops or duplicates the `data.drop`, changes passive segment effects, or if Starshine later stops preserving the `data.drop` while folding the later store.
