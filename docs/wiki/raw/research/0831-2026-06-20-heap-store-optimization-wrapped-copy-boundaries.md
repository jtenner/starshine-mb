---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0827-2026-06-20-heap-store-optimization-multi-index-copy-boundaries.md
  - ./0828-2026-06-20-heap-store-optimization-mixed-index-copy-boundaries.md
  - ./0830-2026-06-20-heap-store-optimization-loop-wrapped-bulk-fill-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` wrapped copy boundaries

Question: after `0827` / `0828` covered direct same-effect-family copy barriers and `0829` / `0830` covered block/if/loop wrappers around bulk fills, does Binaryen also keep the no-fold boundary when the intervening copy root is wrapped in block, if, or branchless loop wrappers?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` for:

- `memory.size $m` before block-, if-, and loop-wrapped `memory.copy $m $m`; and
- `table.size $t` before block-, if-, and loop-wrapped `table.copy $t $t`.

Starshine already matched all six boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative block-wrapped memory-copy probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1 1)
  (func $f (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (memory.size $m)
        (i32.const 2)))
    (block
      (memory.copy $m $m (i32.const 0) (i32.const 4) (i32.const 1)))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Representative loop-wrapped table-copy probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 2 2 funcref)
  (func $f (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (table.size $t)
        (i32.const 2)))
    (loop
      (table.copy $t $t (i32.const 0) (i32.const 1) (i32.const 1)))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-copy-wrapper-probe/memory-size-block-memory-copy.wat \
  -o .tmp/hso-copy-wrapper-probe/memory-size-block-memory-copy.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-copy-wrapper-probe/memory-size-if-memory-copy.wat \
  -o .tmp/hso-copy-wrapper-probe/memory-size-if-memory-copy.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-copy-wrapper-probe/memory-size-loop-memory-copy.wat \
  -o .tmp/hso-copy-wrapper-probe/memory-size-loop-memory-copy.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-copy-wrapper-probe/table-size-block-table-copy.wat \
  -o .tmp/hso-copy-wrapper-probe/table-size-block-table-copy.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-copy-wrapper-probe/table-size-if-table-copy.wat \
  -o .tmp/hso-copy-wrapper-probe/table-size-if-table-copy.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-copy-wrapper-probe/table-size-loop-table-copy.wat \
  -o .tmp/hso-copy-wrapper-probe/table-size-loop-table-copy.opt.wat
```

Observed result: all optimized outputs preserved the constructor `memory.size` / `table.size` operand, the wrapped `memory.copy` / `table.copy` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before block-wrapped memory.copy`
- `heap-store-optimization keeps memory.size constructors before if-wrapped memory.copy`
- `heap-store-optimization keeps memory.size constructors before loop-wrapped memory.copy`
- `heap-store-optimization keeps table.size constructors before block-wrapped table.copy`
- `heap-store-optimization keeps table.size constructors before if-wrapped table.copy`
- `heap-store-optimization keeps table.size constructors before loop-wrapped table.copy`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor memory/table-size operand across same-effect-family copy roots hidden under simple structured wrappers.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 137, passed: 137, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` wrapper drift coverage from bulk fills to copy roots for the same-effect-family memory/table-size boundaries.
- Confirms Binaryen `version_130` keeps the no-fold boundary for block-, if-, and branchless loop-wrapped `memory.copy` / `table.copy` roots when the constructor operand observes the same memory/table family.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, wrapper drift around passive/bulk init/drop roots, final direct compare, and O4z slot evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
