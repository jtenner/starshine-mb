---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0832-2026-06-20-heap-store-optimization-wrapped-passive-boundaries.md
  - ./0840-2026-06-20-heap-store-optimization-branch-wrapper-bulk-fill-boundaries.md
  - ./0841-2026-06-20-heap-store-optimization-branch-wrapper-copy-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` branch-wrapper passive boundaries

Question: after branch-containing no-fold coverage for same-effect-family bulk-fill and copy roots, does Binaryen also keep passive data/element roots as barriers when those roots sit inside branch-containing block/if/loop wrappers?

## Answer

Yes for the probed Binaryen `version_130` shapes. Binaryen kept the later `struct.set` for:

- `memory.size $m` before a block-wrapped `memory.init $d` followed by `br` to the wrapper end;
- `memory.size $m` before an if-arm `memory.init $d` followed by `br` to an outer wrapper end;
- `memory.size $m` before a loop-body `memory.init $d` followed by `br` to an outer wrapper end;
- the matching block/if/loop branch-containing shapes for `data.drop $d`;
- `table.size $t` before the matching block/if/loop branch-containing shapes for `table.init $e`;
- `table.size $t` before the matching block/if/loop branch-containing shapes for `elem.drop $e`.

Starshine already matched all twelve no-fold boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative block-wrapped memory-init probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1 1)
  (data $d "a")
  (func $test (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (memory.size $m)
        (i32.const 2)))
    (block $blk
      (memory.init $d (i32.const 0) (i32.const 0) (i32.const 1))
      (br $blk))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Representative if-wrapped table-init probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 2 2 funcref)
  (elem $e funcref)
  (func $test (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (table.size $t)
        (i32.const 2)))
    (block $blk
      (if (i32.const 1)
        (then
          (table.init $e (i32.const 0) (i32.const 0) (i32.const 1))
          (br $blk))))
    (struct.set $pair 1 (local.get $x) (i32.const 7))
    (struct.get $pair 1 (local.get $x))))
```

Command shape:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-branch-wrapper-passive-probe/<probe>.wat \
  -o .tmp/hso-branch-wrapper-passive-probe/<probe>.opt.wat
```

Observed result: all twelve optimized outputs preserved the constructor `memory.size` / `table.size` operand, the branch-containing passive data/element wrapper root, the branch, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before branch-containing passive data wrappers`
- `heap-store-optimization keeps table.size constructors before branch-containing passive element wrappers`

Each test iterates block, if-arm, and loop-body branch-containing wrappers for the relevant passive roots and asserts Starshine keeps `struct.set` when folding would move the constructor memory/table-size operand across a same-effect-family passive data/element operation.

A small shared test helper now constructs the branch-containing block/if/loop wrapper family used by the existing branch-wrapper copy tests and the new passive tests.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 191, passed: 191, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` branch-containing same-effect-family no-fold coverage from bulk-fill and copy roots to passive data/element roots.
- Confirms Binaryen keeps passive data/element roots as barriers even when the wrapper itself contains an exiting branch.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper variants beyond the covered roots.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
