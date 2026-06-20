---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0831-2026-06-20-heap-store-optimization-wrapped-copy-boundaries.md
  - ./0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ./0838-2026-06-20-heap-store-optimization-branch-wrapper-table-global-swap.md
  - ./0840-2026-06-20-heap-store-optimization-branch-wrapper-bulk-fill-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` branch-wrapper copy boundaries

Question: after branch-containing wrapper positives for unrelated global writes and branch-containing no-fold barriers for bulk-fill roots, does Binaryen also keep the same-effect-family copy no-fold boundary when an intervening `memory.copy` / `table.copy` root branches out of its wrapper?

## Answer

Yes for the probed Binaryen `version_130` shapes. Binaryen kept the later `struct.set` for:

- `memory.size $m` before a block-wrapped `memory.copy $m $m` followed by `br` to the wrapper end;
- `memory.size $m` before an if-arm `memory.copy $m $m` followed by `br` to an outer wrapper end;
- `memory.size $m` before a loop-body `memory.copy $m $m` followed by `br` to an outer wrapper end;
- the matching `table.size $t` / `table.copy $t $t` block, if-arm, and loop-body shapes.

Starshine already matched all six no-fold boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative block-wrapped memory-copy probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1)
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size $m)
        (i32.const 2)))
    (block $blk
      (memory.copy $m $m (i32.const 0) (i32.const 4) (i32.const 1))
      (br $blk))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Representative if-wrapped table-copy probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 10 funcref)
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size $t)
        (i32.const 2)))
    (block $blk
      (if (i32.const 1)
        (then
          (table.copy $t $t (i32.const 0) (i32.const 4) (i32.const 1))
          (br $blk))))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Command shape:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-branch-wrapper-copy-probe/<probe>.wat \
  -o .tmp/hso-branch-wrapper-copy-probe/<probe>.opt.wat
```

Observed result: all six optimized outputs preserved the constructor `memory.size` / `table.size` operand, the branch-containing `memory.copy` / `table.copy` wrapper, the branch, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before branch-containing memory.copy wrappers`
- `heap-store-optimization keeps table.size constructors before branch-containing table.copy wrappers`

Each test iterates block, if-arm, and loop-body branch-containing wrappers and asserts Starshine keeps `struct.set` when folding would move the constructor memory/table-size operand across a same-effect-family copy root.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 189, passed: 189, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` branch-containing wrapper coverage from unrelated global-write positives, constructor-ping-pong positives, and bulk-fill no-fold barriers to same-effect-family copy no-fold barriers.
- Confirms Binaryen keeps same-effect-family copy roots as barriers even when the wrapper itself contains an exiting branch.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper variants beyond the covered roots.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
