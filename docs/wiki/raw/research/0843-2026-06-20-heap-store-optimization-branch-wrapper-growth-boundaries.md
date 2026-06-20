---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0833-2026-06-20-heap-store-optimization-wrapped-growth-passive-boundaries.md
  - ./0835-2026-06-20-heap-store-optimization-nested-wrapped-growth-bulk-boundaries.md
  - ./0840-2026-06-20-heap-store-optimization-branch-wrapper-bulk-fill-boundaries.md
  - ./0841-2026-06-20-heap-store-optimization-branch-wrapper-copy-boundaries.md
  - ./0842-2026-06-20-heap-store-optimization-branch-wrapper-passive-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` branch-wrapper growth boundaries

Question: after branch-containing no-fold coverage for `memory.size` / `table.size` constructor operands, does Binaryen also keep the no-fold boundary when the constructor operand itself is a side-effecting `memory.grow` / `table.grow` and the same-effect-family blocker root is hidden under a branch-containing wrapper?

## Answer

Yes for the probed Binaryen `version_130` shapes. Binaryen kept the later `struct.set` when:

- a constructor `memory.grow $m` would need to cross branch-containing block/if/loop wrappers around `memory.fill $m`;
- a constructor `memory.grow $m` would need to cross branch-containing block/if/loop wrappers around `memory.copy $m $m`;
- a constructor `memory.grow $m` would need to cross branch-containing block/if/loop wrappers around `memory.init $d`;
- a constructor `memory.grow $m` would need to cross branch-containing block/if/loop wrappers around `data.drop $d`;
- a constructor `table.grow $t` would need to cross branch-containing block/if/loop wrappers around `table.fill $t`;
- a constructor `table.grow $t` would need to cross branch-containing block/if/loop wrappers around `table.copy $t $t`;
- a constructor `table.grow $t` would need to cross branch-containing block/if/loop wrappers around `table.init $e`;
- a constructor `table.grow $t` would need to cross branch-containing block/if/loop wrappers around `elem.drop $e`.

Starshine already matched all probed no-fold boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative memory-growth / memory-fill block-wrapper probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1)
  (data $d "x")
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (i32.const 1)
    (memory.grow $m)
    (i32.const 2)
    (struct.new $pair)
    (local.set $x)
    (block $blk
      (i32.const 0)
      (i32.const 9)
      (i32.const 1)
      (memory.fill $m)
      (br $blk))
    (local.get $x)
    (i32.const 7)
    (struct.set $pair 1)
    (local.get $x)
    (struct.get $pair 1)))
```

Representative table-growth / passive-element if-wrapper probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 1 funcref)
  (elem $e func)
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (ref.null func)
    (i32.const 1)
    (table.grow $t)
    (i32.const 2)
    (struct.new $pair)
    (local.set $x)
    (block $blk
      (if (i32.const 1)
        (then
          (elem.drop $e)
          (br $blk))))
    (local.get $x)
    (i32.const 7)
    (struct.set $pair 1)
    (local.get $x)
    (struct.get $pair 1)))
```

Command shape:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-branch-wrapper-growth-boundary-probe/<probe>.wat \
  -o .tmp/hso-branch-wrapper-growth-boundary-probe/<probe>.opt.wat
```

Observed result: all probed optimized outputs preserved the constructor `memory.grow` / `table.grow` operand, the branch-containing same-effect-family wrapper root, the branch, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.grow constructors before branch-containing memory roots`
- `heap-store-optimization keeps table.grow constructors before branch-containing table roots`

The memory test iterates branch-containing block, if-arm, and loop-body wrappers for `memory.fill`, `memory.copy`, `memory.init`, and `data.drop`. The table test does the same for `table.fill`, `table.copy`, `table.init`, and `elem.drop`. Each assertion keeps the side-effecting growth operand, the blocker root, and the later `struct.set` in the optimized output.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 193, passed: 193, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` branch-containing same-effect-family no-fold coverage from non-side-effecting `memory.size` / `table.size` constructors to side-effecting `memory.grow` / `table.grow` constructors.
- Confirms Binaryen keeps bulk-memory/table and passive data/element roots as barriers even when hidden inside branch-containing wrappers and even when the constructor operand itself has same-effect-family growth effects.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper variants beyond the covered roots.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
