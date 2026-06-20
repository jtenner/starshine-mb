---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0829-2026-06-20-heap-store-optimization-wrapped-bulk-fill-boundaries.md
  - ./0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ./0838-2026-06-20-heap-store-optimization-branch-wrapper-table-global-swap.md
  - ./0839-2026-06-20-heap-store-optimization-branch-wrapper-constructor-pingpong.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` branch-wrapper bulk-fill boundaries

Question: after the branch-containing wrapper positives for unrelated global writes and constructor ping-pong wrappers, does Binaryen still keep the same-effect-family bulk-fill no-fold boundary when the intervening `memory.fill` / `table.fill` root branches out of its wrapper?

## Answer

Yes for the probed Binaryen `version_130` shapes. Binaryen kept the later `struct.set` for:

- `memory.size $m` before a block-wrapped `memory.fill $m` followed by `br` to the wrapper end;
- `memory.size $m` before an if-arm `memory.fill $m` followed by `br` to an outer wrapper end;
- `memory.size $m` before a loop-body `memory.fill $m` followed by `br` to an outer wrapper end;
- the matching `table.size $t` / `table.fill $t` block, if-arm, and loop-body shapes.

Starshine already matched all six no-fold boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative block-wrapped memory-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1)
  (func $test (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size $m)
        (i32.const 2)))
    (block $blk
      (memory.fill $m (i32.const 0) (i32.const 9) (i32.const 1))
      (br $blk))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Representative if-wrapped table-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 1 funcref)
  (func $test (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size $t)
        (i32.const 2)))
    (block $blk
      (if (i32.const 1)
        (then
          (table.fill $t (i32.const 0) (ref.null func) (i32.const 1))
          (br $blk))))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Command shape:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-branch-wrapper-same-effect-probe/<probe>.wat \
  -o .tmp/hso-branch-wrapper-same-effect-probe/<probe>.opt.wat
```

Observed result: all six optimized outputs preserved the constructor `memory.size` / `table.size` operand, the branch-containing `memory.fill` / `table.fill` wrapper, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before branch-containing memory.fill wrappers`
- `heap-store-optimization keeps table.size constructors before branch-containing table.fill wrappers`

Each test iterates block, if-arm, and loop-body branch-containing wrappers and asserts Starshine keeps `struct.set` when folding would move the constructor memory/table-size operand across a same-effect-family bulk-fill root.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 187, passed: 187, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` branch-containing wrapper coverage from unrelated global-write positives and constructor-ping-pong positives to same-effect-family bulk-fill no-fold barriers.
- Confirms Binaryen's branch-containing wrapper treatment is not a blanket fold/no-fold rule: unrelated global-write and constructor-ping-pong wrappers can fold, but same-effect-family bulk-fill wrappers remain barriers.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper variants beyond the covered roots.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
